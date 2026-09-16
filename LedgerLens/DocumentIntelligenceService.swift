// Restores already-saved document data and produces deterministic
// intelligence. It does NOT call Veryfi and does NOT call OpenAI.

import Foundation


@MainActor
final class DocumentIntelligenceService {

    static let shared =
        DocumentIntelligenceService()

    private init() {}


    func load(
        document:
            HistoryDocument
    ) async throws
        -> DocumentIntelligence {

        let data =
            try await
                DocumentHistoryService
                    .shared
                    .fetchPayloadData(
                        id:
                            document.id
                    )


        let rootObject =
            try JSONSerialization
                .jsonObject(
                    with:
                        data
                )


        guard
            let root =
                rootObject
                    as?
                    [String: Any],

            let payload =
                root[
                    "veryfi_payload"
                ]
                    as?
                    [String: Any]
        else {

            throw
                DocumentHistoryError
                    .malformedSavedDocument
        }


        let financialDocument =
            try VeryfiService
                .restoreFinancialDocument(
                    payload:
                        payload,
                    classification:
                        document
                            .documentType
                )


        let profile =
            CrossDocumentProfileResolver
                .makeProfile(
                    payload:
                        payload,
                    history:
                        document,
                    financialDocument:
                        financialDocument
                )


        let loaded =
            CrossDocumentLoadedDocument(
                history:
                    document,
                financialDocument:
                    financialDocument,
                summary:
                    nil,
                conversations:
                    [],
                profile:
                    profile
            )


        let pack =
            CrossDocumentAnalysisEngine
                .analyze(
                    [
                        loaded
                    ]
                )


        return
            DocumentIntelligenceEngine
                .analyze(
                    document:
                        document,
                    payload:
                        payload,
                    loadedDocument:
                        loaded,
                    pack:
                        pack
                )
    }
}


// Deterministic Intelligence Engine

enum DocumentIntelligenceEngine {

    static func analyze(
        document:
            HistoryDocument,
        payload:
            [String: Any],
        loadedDocument:
            CrossDocumentLoadedDocument,
        pack:
            CrossDocumentFactPack
    ) -> DocumentIntelligence {

        let institution =
            resolveInstitution(
                payload:
                    payload,
                profile:
                    loadedDocument
                        .profile
            )


        let suggestedName =
            makeSuggestedName(
                document:
                    document,
                institution:
                    institution?
                        .name,
                profile:
                    loadedDocument
                        .profile
            )


        let importantDates =
            makeImportantDates(
                document:
                    document,
                profile:
                    loadedDocument
                        .profile,
                spendingTransactions:
                    pack
                        .spendingTransactions
            )


        let largestCharges =
            makeLargestCharges(
                pack
                    .spendingTransactions
            )


        let duplicates =
            makeDuplicateCandidates(
                pack
                    .spendingTransactions
            )


        let unusual =
            makeUnusualSignals(
                pack
                    .spendingTransactions
            )


        let balanceMovement =
            makeBalanceMovement(
                payload:
                    payload,
                profile:
                    loadedDocument
                        .profile
            )


        let metric =
            pack
                .metrics
                .first


        let attention =
            makeAttentionItems(
                document:
                    document,
                largestCharges:
                    largestCharges,
                duplicateCandidates:
                    duplicates,
                unusualSignals:
                    unusual,
                balanceMovement:
                    balanceMovement
            )


        return
            DocumentIntelligence(
                institution:
                    institution,
                suggestedName:
                    suggestedName,
                shouldAutoApplySuggestedName:
                    shouldAutoApplySmartName(
                        document
                    )
                    &&
                    (
                        institution
                        ==
                        nil
                        ||
                        institution?
                            .confidence
                        ==
                        .high
                    ),
                importantDates:
                    importantDates,
                largestCharges:
                    largestCharges,
                duplicateCandidates:
                    duplicates,
                unusualChargeSignals:
                    unusual,
                balanceMovement:
                    balanceMovement,
                attentionItems:
                    attention,
                spendingBasis:
                    metric?
                        .spendingBasis,
                analyzedSpendingRecordCount:
                    pack
                        .spendingTransactions
                        .count
            )
    }


    // Institution / Merchant Intelligence
    
    private static func resolveInstitution(
        payload:
            [String: Any],
        profile:
            CrossDocumentDocumentProfile
    ) -> DocumentInstitutionInsight? {

        if let vendor =
            cleanOrganizationName(
                profile
                    .vendorName
            ) {

            return
                DocumentInstitutionInsight(
                    name:
                        vendor,
                    confidence:
                        .high,
                    source:
                        "Structured vendor data"
                )
        }


        let directKeys =
            [
                "bank_name",
                "institution_name",
                "financial_institution",
                "issuer_name",
                "merchant_name",
                "provider_name",
                "company_name"
            ]


        for key
            in directKeys {

            if let value =
                cleanOrganizationName(
                    string(
                        payload[
                            key
                        ]
                    )
                ) {

                return
                    DocumentInstitutionInsight(
                        name:
                            value,
                        confidence:
                            .high,
                        source:
                            "Structured document data"
                    )
            }
        }


        let accounts =
            payload[
                "accounts"
            ]
                as?
                [[String: Any]]
            ??
            []


        let accountKeys =
            [
                "bank_name",
                "institution_name",
                "financial_institution",
                "issuer_name",
                "provider_name",
                "company_name"
            ]


        for account
            in accounts {

            for key
                in accountKeys {

                if let value =
                    cleanOrganizationName(
                        string(
                            account[
                                key
                            ]
                        )
                    ) {

                    return
                        DocumentInstitutionInsight(
                            name:
                                value,
                            confidence:
                                .high,
                            source:
                                "Structured account data"
                        )
                }
            }
        }


        if let heading =
            organizationHeadingCandidate(
                ocrText(
                    payload
                )
            ) {

            return
                DocumentInstitutionInsight(
                    name:
                        heading,
                    confidence:
                        .medium,
                    source:
                        "Document heading"
                )
        }


        return nil
    }


    private static func organizationHeadingCandidate(
        _ text:
            String
    ) -> String? {

        guard
            !text
                .isEmpty
        else {
            return nil
        }


        let organizationSignals =
            [
                "bank",
                "credit union",
                "federal",
                "financial",
                "city of",
                "county of",
                "utilities",
                "utility",
                "water",
                "electric",
                "energy",
                "gas",
                "communications",
                "telecom",
                "insurance",
                "hospital",
                "clinic",
                "pharmacy",
                "mortgage",
                "loan",
                "services",
                "corporation",
                "corp",
                "company",
                " inc",
                " llc"
            ]


        let rejectedSignals =
            [
                "statement",
                "account summary",
                "account number",
                "payment due",
                "due date",
                "amount due",
                "customer service",
                "billing period",
                "service period",
                "transaction",
                "balance",
                "page ",
                "date ",
                "total ",
                "summary",
                "invoice",
                "receipt"
            ]


        let lines =
            text
                .components(
                    separatedBy:
                        .newlines
                )
                .prefix(
                    35
                )
                .map {
                    $0
                        .replacingOccurrences(
                            of:
                                #"\s+"#,
                            with:
                                " ",
                            options:
                                .regularExpression
                        )
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                }
                .filter {
                    !$0
                        .isEmpty
                }


        var candidates:
            [
                (
                    String,
                    Int
                )
            ] = []


        for (
            index,
            line
        ) in lines
            .enumerated() {

            guard
                line.count
                >=
                3,
                line.count
                <=
                70
            else {
                continue
            }


            let lower =
                line
                    .lowercased()


            if rejectedSignals
                .contains(
                    where: {
                        lower
                            .contains(
                                $0
                            )
                    }
                ) {

                continue
            }


            let letters =
                line
                    .unicodeScalars
                    .filter {
                        CharacterSet
                            .letters
                            .contains(
                                $0
                            )
                    }
                    .count

            let digits =
                line
                    .unicodeScalars
                    .filter {
                        CharacterSet
                            .decimalDigits
                            .contains(
                                $0
                            )
                    }
                    .count


            guard
                letters
                >=
                3,
                digits
                <=
                max(
                    2,
                    line.count
                    /
                    5
                )
            else {
                continue
            }


            let hasOrganizationSignal =
                organizationSignals
                    .contains {
                        lower
                            .contains(
                                $0
                            )
                    }


            guard
                hasOrganizationSignal
            else {
                continue
            }


            var score =
                5


            if index < 8 {

                score +=
                    3
            }


            let words =
                line
                    .split(
                        separator:
                            " "
                    )
                    .count


            if words <= 6 {

                score +=
                    1
            }


            if line
                ==
                line
                    .uppercased() {

                score +=
                    1
            }


            candidates.append(
                (
                    line,
                    score
                )
            )
        }


        return
            candidates
                .sorted {
                    lhs,
                    rhs in

                    if lhs.1
                        ==
                        rhs.1 {

                        return
                            lhs.0.count
                            <
                            rhs.0.count
                    }


                    return
                        lhs.1
                        >
                        rhs.1
                }
                .first?
                .0
    }


    private static func cleanOrganizationName(
        _ raw:
            String?
    ) -> String? {

        guard
            let raw
        else {
            return nil
        }


        let cleaned =
            raw
                .replacingOccurrences(
                    of:
                        #"\s+"#,
                    with:
                        " ",
                    options:
                        .regularExpression
                )
                .trimmingCharacters(
                    in:
                        CharacterSet
                            .whitespacesAndNewlines
                            .union(
                                CharacterSet(
                                    charactersIn:
                                        "-–—|"
                                )
                            )
                )


        guard
            cleaned.count
            >=
            2,
            cleaned.count
            <=
            80
        else {
            return nil
        }


        return cleaned
    }


    // Smart Naming

    private static func makeSuggestedName(
        document:
            HistoryDocument,
        institution:
            String?,
        profile:
            CrossDocumentDocumentProfile
    ) -> String? {

        let date =
            profile
                .period?
                .end
            ??
            profile
                .documentDate
            ??
            document
                .dueDate
            ??
            document
                .createdAt


        let monthYear =
            date.formatted(
                .dateTime
                    .month(
                        .wide
                    )
                    .year()
            )


        let kind:
            String


        switch profile.kind {

        case .creditCardStatement,
             .bankStatement:

            kind =
                "Statement"

        case .bill:

            kind =
                "Bill"

        case .other:

            kind =
                document
                    .prettyDocumentType
        }


        let base:
            String


        if let institution,
           !institution
                .isEmpty {

            base =
                "\(institution) - \(monthYear) - \(kind)"

        } else {

            base =
                "\(monthYear) - \(kind)"
        }


        let cleaned =
            base
                .replacingOccurrences(
                    of:
                        #"\s+"#,
                    with:
                        " ",
                    options:
                        .regularExpression
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !cleaned
                .isEmpty,
            cleaned
            !=
            document
                .resolvedDisplayName
        else {

            return nil
        }


        return
            String(
                cleaned
                    .prefix(
                        100
                    )
            )
    }


    private static func shouldAutoApplySmartName(
        _ document:
            HistoryDocument
    ) -> Bool {

        if let custom =
            document
                .displayName?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
           !custom
                .isEmpty {

            return false
        }


        if document
            .sourceType
            ==
            "scan" {

            return true
        }


        let base =
            (
                document
                    .fileName
                as NSString
            )
            .deletingPathExtension
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .lowercased()


        if base
            .hasPrefix(
                "financial-scan-"
            )
            ||
            base
                .hasPrefix(
                    "financial-document-"
                )
            ||
            base
                .hasPrefix(
                    "img_"
                )
            ||
            base
                .hasPrefix(
                    "image_"
                )
            ||
            base
                .hasPrefix(
                    "scan_"
                ) {

            return true
        }


        let genericNames =
            Set(
                [
                    "document",
                    "scan",
                    "scanned document",
                    "image",
                    "photo",
                    "file",
                    "statement",
                    "bill"
                ]
            )


        if genericNames
            .contains(
                base
            ) {

            return true
        }


        let uuidLike =
            base.range(
                of:
                    #"^[0-9a-f]{8}-[0-9a-f-]{20,}$"#,
                options:
                    .regularExpression
            )
            !=
            nil


        return uuidLike
    }


    // Important Dates

    private static func makeImportantDates(
        document:
            HistoryDocument,
        profile:
            CrossDocumentDocumentProfile,
        spendingTransactions:
            [CrossDocumentTransaction]
    ) -> [DocumentImportantDate] {

        var items:
            [DocumentImportantDate] = []


        if let period =
            profile
                .period {

            items.append(
                DocumentImportantDate(
                    id:
                        "period",
                    label:
                        period
                            .kind
                            .rawValue,
                    value:
                        period
                            .formatted,
                    systemImage:
                        "calendar.day.timeline.left",
                    date:
                        period
                            .end
                )
            )
        }


        if let date =
            profile
                .documentDate {

            items.append(
                DocumentImportantDate(
                    id:
                        "document_date",
                    label:
                        "Document date",
                    value:
                        date.formatted(
                            date:
                                .long,
                            time:
                                .omitted
                        ),
                    systemImage:
                        "doc.badge.clock",
                    date:
                        date
                )
            )
        }


        let due =
            document
                .dueDate
            ??
            profile
                .dueDate


        if let due {

            items.append(
                DocumentImportantDate(
                    id:
                        "due_date",
                    label:
                        "Due date",
                    value:
                        due.formatted(
                            date:
                                .long,
                            time:
                                .omitted
                        ),
                    systemImage:
                        "calendar.badge.exclamationmark",
                    date:
                        due
                )
            )
        }


        let activityDates =
            spendingTransactions
                .compactMap(
                    \.effectiveDate
                )


        if let first =
            activityDates
                .min(),
           let last =
            activityDates
                .max() {

            let value:
                String


            if Calendar.current
                .isDate(
                    first,
                    inSameDayAs:
                        last
                ) {

                value =
                    first.formatted(
                        date:
                            .abbreviated,
                        time:
                            .omitted
                    )

            } else {

                value =
                    "\(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))"
            }


            if profile
                .period?
                .formatted
                !=
                value {

                items.append(
                    DocumentImportantDate(
                        id:
                            "spending_activity",
                        label:
                            "Included spending activity",
                        value:
                            value,
                        systemImage:
                            "calendar.badge.checkmark",
                        date:
                            last
                    )
                )
            }
        }


        return items
    }


    // Largest Charges

    private static func makeLargestCharges(
        _ transactions:
            [CrossDocumentTransaction]
    ) -> [DocumentChargeInsight] {

        transactions
            .filter {
                $0.record.amount
                >
                0
            }
            .sorted {
                $0.record.amount
                >
                $1.record.amount
            }
            .prefix(
                5
            )
            .map {
                item in

                DocumentChargeInsight(
                    id:
                        item.id,
                    merchant:
                        CrossDocumentAnalysisEngine
                            .merchantLabel(
                                item.record
                            ),
                    amount:
                        item
                            .record
                            .amount,
                    currency:
                        item
                            .record
                            .currency,
                    date:
                        item
                            .effectiveDate,
                    category:
                        item
                            .record
                            .category
                )
            }
    }


    // Possible Repeated Charges

    private struct DuplicateKey:
        Hashable {

        let merchant:
            String

        let currency:
            String

        let amount:
            String
    }


    private static func makeDuplicateCandidates(
        _ transactions:
            [CrossDocumentTransaction]
    ) -> [DocumentDuplicateChargeCandidate] {

        let candidates =
            transactions
                .filter {
                    item in

                    item
                        .record
                        .amount
                    >
                    0
                    &&
                    item
                        .effectiveDate
                    !=
                    nil
                }


        let grouped =
            Dictionary(
                grouping:
                    candidates
            ) {
                item in

                DuplicateKey(
                    merchant:
                        CrossDocumentAnalysisEngine
                            .merchantKey(
                                CrossDocumentAnalysisEngine
                                    .merchantLabel(
                                        item.record
                                    )
                            ),
                    currency:
                        item
                            .record
                            .currency,
                    amount:
                        NSDecimalNumber(
                            decimal:
                                item
                                    .record
                                    .amount
                        )
                        .rounding(
                            accordingToBehavior:
                                NSDecimalNumberHandler(
                                    roundingMode:
                                        .plain,
                                    scale:
                                        2,
                                    raiseOnExactness:
                                        false,
                                    raiseOnOverflow:
                                        false,
                                    raiseOnUnderflow:
                                        false,
                                    raiseOnDivideByZero:
                                        false
                                )
                        )
                        .stringValue
                )
            }


        var results:
            [DocumentDuplicateChargeCandidate] = []


        for (
            key,
            group
        ) in grouped {

            guard
                !key
                    .merchant
                    .isEmpty,
                group.count
                >=
                2
            else {
                continue
            }


            let sorted =
                group.sorted {
                    ($0.effectiveDate ?? .distantPast)
                    <
                    ($1.effectiveDate ?? .distantPast)
                }


            for firstIndex
                in sorted
                    .indices {

                let nextIndex =
                    firstIndex
                    +
                    1


                guard
                    nextIndex
                    <
                    sorted.count,
                    let firstDate =
                        sorted[
                            firstIndex
                        ]
                        .effectiveDate,
                    let secondDate =
                        sorted[
                            nextIndex
                        ]
                        .effectiveDate
                else {
                    continue
                }


                let days =
                    Calendar.current
                        .dateComponents(
                            [
                                .day
                            ],
                            from:
                                Calendar.current
                                    .startOfDay(
                                        for:
                                            firstDate
                                    ),
                            to:
                                Calendar.current
                                    .startOfDay(
                                        for:
                                            secondDate
                                    )
                        )
                        .day
                    ??
                    0


                // Same-day duplicate rows can be OCR/table duplication.
                // To preserve trust, Phase 6E does not label same-day
                // rows as duplicate-charge candidates.
                guard
                    days
                    >=
                    1,
                    days
                    <=
                    3
                else {
                    continue
                }


                let first =
                    sorted[
                        firstIndex
                    ]

                let second =
                    sorted[
                        nextIndex
                    ]


                results.append(
                    DocumentDuplicateChargeCandidate(
                        id:
                            "\(first.id)-\(second.id)",
                        merchant:
                            CrossDocumentAnalysisEngine
                                .merchantLabel(
                                    first
                                        .record
                                ),
                        amount:
                            first
                                .record
                                .amount,
                        currency:
                            first
                                .record
                                .currency,
                        firstDate:
                            firstDate,
                        secondDate:
                            secondDate,
                        daysApart:
                            days
                    )
                )
            }
        }


        return
            results
                .sorted {
                    lhs,
                    rhs in

                    if lhs.amount
                        ==
                        rhs.amount {

                        return
                            lhs.firstDate
                            <
                            rhs.firstDate
                    }


                    return
                        lhs.amount
                        >
                        rhs.amount
                }
                .prefix(
                    5
                )
                .map {
                    $0
                }
    }


    // Unusual Large-Charge Signals

    private static func makeUnusualSignals(
        _ transactions:
            [CrossDocumentTransaction]
    ) -> [DocumentUnusualChargeSignal] {

        let byCurrency =
            Dictionary(
                grouping:
                    transactions
                        .filter {
                            $0.record.amount
                            >
                            0
                        },
                by: {
                    $0.record.currency
                }
            )


        var results:
            [DocumentUnusualChargeSignal] = []


        for (
            _,
            group
        ) in byCurrency {

            guard
                group.count
                >=
                5
            else {
                continue
            }


            let amounts =
                group
                    .map {
                        NSDecimalNumber(
                            decimal:
                                $0
                                    .record
                                    .amount
                        )
                        .doubleValue
                    }
                    .filter {
                        $0
                        >
                        0
                    }
                    .sorted()


            guard
                amounts.count
                >=
                5
            else {
                continue
            }


            let median =
                median(
                    amounts
                )


            guard
                median
                >
                0
            else {
                continue
            }


            let threshold =
                median
                *
                2.5


            for item
                in group {

                let amount =
                    NSDecimalNumber(
                        decimal:
                            item
                                .record
                                .amount
                    )
                    .doubleValue


                guard
                    amount
                    >=
                    threshold,
                    amount
                    -
                    median
                    >=
                    max(
                        20,
                        median
                    )
                else {
                    continue
                }


                let charge =
                    DocumentChargeInsight(
                        id:
                            item.id,
                        merchant:
                            CrossDocumentAnalysisEngine
                                .merchantLabel(
                                    item.record
                                ),
                        amount:
                            item
                                .record
                                .amount,
                        currency:
                            item
                                .record
                                .currency,
                        date:
                            item
                                .effectiveDate,
                        category:
                            item
                                .record
                                .category
                    )


                results.append(
                    DocumentUnusualChargeSignal(
                        id:
                            "unusual-\(item.id)",
                        charge:
                            charge,
                        typicalAmount:
                            Decimal(
                                median
                            ),
                        multipleOfTypical:
                            amount
                            /
                            median
                    )
                )
            }
        }


        return
            results
                .sorted {
                    $0.multipleOfTypical
                    >
                    $1.multipleOfTypical
                }
                .prefix(
                    5
                )
                .map {
                    $0
                }
    }


    // Balance Movement

    private static func makeBalanceMovement(
        payload:
            [String: Any],
        profile:
            CrossDocumentDocumentProfile
    ) -> DocumentBalanceMovement? {

        guard
            profile.kind
            ==
            .bankStatement
        else {
            return nil
        }


        let accounts =
            payload[
                "accounts"
            ]
                as?
                [[String: Any]]
            ??
            []


        guard
            let account =
                accounts
                    .first,
            let beginning =
                decimal(
                    account[
                        "beginning_balance"
                    ]
                ),
            let ending =
                decimal(
                    account[
                        "ending_balance"
                    ]
                )
        else {

            return nil
        }


        let currency =
            string(
                account[
                    "currency"
                ]
            )
            ??
            string(
                account[
                    "currency_code"
                ]
            )
            ??
            profile
                .currency


        return
            DocumentBalanceMovement(
                beginning:
                    beginning,
                ending:
                    ending,
                delta:
                    ending
                    -
                    beginning,
                currency:
                    currency
            )
    }


    // What Should I Pay Attention To? Feature

    private static func makeAttentionItems(
        document:
            HistoryDocument,
        largestCharges:
            [DocumentChargeInsight],
        duplicateCandidates:
            [DocumentDuplicateChargeCandidate],
        unusualSignals:
            [DocumentUnusualChargeSignal],
        balanceMovement:
            DocumentBalanceMovement?
    ) -> [DocumentAttentionItem] {

        var items:
            [DocumentAttentionItem] = []


        if let dueDate =
            document
                .dueDate {

            let days =
                Calendar.current
                    .dateComponents(
                        [
                            .day
                        ],
                        from:
                            Calendar.current
                                .startOfDay(
                                    for:
                                        Date()
                                ),
                        to:
                            Calendar.current
                                .startOfDay(
                                    for:
                                        dueDate
                                )
                    )
                    .day
                ??
                999


            if days
                >=
                0,
               days
                <=
                7 {

                let title:
                    String


                switch days {

                case 0:
                    title =
                        "Payment due today"

                case 1:
                    title =
                        "Payment due tomorrow"

                default:
                    title =
                        "Payment due in \(days) days"
                }


                items.append(
                    DocumentAttentionItem(
                        id:
                            "due",
                        level:
                            .action,
                        title:
                            title,
                        detail:
                            dueDate.formatted(
                                date:
                                    .long,
                                time:
                                    .omitted
                            ),
                        systemImage:
                            "calendar.badge.exclamationmark"
                    )
                )
            }
        }


        if !duplicateCandidates
            .isEmpty {

            items.append(
                DocumentAttentionItem(
                    id:
                        "duplicates",
                    level:
                        .review,
                    title:
                        duplicateCandidates.count
                        ==
                        1
                        ? "Review 1 possible repeated charge"
                        : "Review \(duplicateCandidates.count) possible repeated charges",
                    detail:
                        "These are same-merchant, same-amount charges 1–3 days apart. This is a review signal, not proof of a duplicate transaction.",
                    systemImage:
                        "rectangle.on.rectangle.badge.exclamationmark"
                )
            )
        }


        if !unusualSignals
            .isEmpty {

            items.append(
                DocumentAttentionItem(
                    id:
                        "unusual",
                    level:
                        .review,
                    title:
                        unusualSignals.count
                        ==
                        1
                        ? "1 charge is much larger than this document's typical charge"
                        : "\(unusualSignals.count) charges are much larger than this document's typical charge",
                    detail:
                        "The app compares included charges within the same currency. This is a size-based pattern signal, not a fraud determination.",
                    systemImage:
                        "exclamationmark.triangle"
                )
            )
        }


        if let balanceMovement {

            let delta =
                abs(
                    NSDecimalNumber(
                        decimal:
                            balanceMovement
                                .delta
                    )
                    .doubleValue
                )


            if delta
                >
                0 {

                items.append(
                    DocumentAttentionItem(
                        id:
                            "balance",
                        level:
                            .information,
                        title:
                            balanceMovement
                                .directionText,
                        detail:
                            "\(formatMoney(absDecimal(balanceMovement.delta), currency: balanceMovement.currency)) from beginning to ending balance.",
                        systemImage:
                            balanceMovement
                                .delta
                            >
                            0
                            ? "arrow.up.right"
                            : "arrow.down.right"
                    )
                )
            }
        }


        if items
            .isEmpty,
           let largest =
            largestCharges
                .first {

            items.append(
                DocumentAttentionItem(
                    id:
                        "largest",
                    level:
                        .information,
                    title:
                        "Largest included charge",
                    detail:
                        "\(largest.merchant) • \(formatMoney(largest.amount, currency: largest.currency))",
                    systemImage:
                        "arrow.up.circle"
                )
            )
        }


        if items
            .isEmpty {

            items.append(
                DocumentAttentionItem(
                    id:
                        "clear",
                    level:
                        .information,
                    title:
                        "No high-priority deterministic signals found",
                    detail:
                        "Review the original document for anything the extracted financial data may not capture.",
                    systemImage:
                        "checkmark.shield"
                )
            )
        }


        return
            Array(
                items
                    .prefix(
                        5
                    )
            )
    }


    // Helpers

    private static func ocrText(
        _ payload:
            [String: Any]
    ) -> String {

        string(
            payload[
                "ocr_text"
            ]
        )
        ??
        string(
            payload[
                "text"
            ]
        )
        ??
        ""
    }


    private static func string(
        _ value:
            Any?
    ) -> String? {

        if let value =
            value
                as?
                String {

            let trimmed =
                value
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            return
                trimmed
                    .isEmpty
                ? nil
                : trimmed
        }


        if let value =
            value
                as?
                NSNumber {

            return
                value
                    .stringValue
        }


        return nil
    }


    private static func decimal(
        _ value:
            Any?
    ) -> Decimal? {

        if let number =
            value
                as?
                NSNumber {

            return
                number
                    .decimalValue
        }


        guard
            let raw =
                string(
                    value
                )
        else {
            return nil
        }


        let clean =
            raw
                .replacingOccurrences(
                    of:
                        "$",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        ",",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        "+",
                    with:
                        ""
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        return
            Decimal(
                string:
                    clean,
                locale:
                    Locale(
                        identifier:
                            "en_US_POSIX"
                    )
            )
    }


    private static func median(
        _ sorted:
            [Double]
    ) -> Double {

        guard
            !sorted
                .isEmpty
        else {
            return 0
        }


        let middle =
            sorted.count
            /
            2


        if sorted.count
            .isMultiple(
                of:
                    2
            ) {

            return
                (
                    sorted[
                        middle - 1
                    ]
                    +
                    sorted[
                        middle
                    ]
                )
                /
                2
        }


        return
            sorted[
                middle
            ]
    }


    private static func absDecimal(
        _ value:
            Decimal
    ) -> Decimal {

        value
        <
        0
        ? -value
        : value
    }


    private static func formatMoney(
        _ value:
            Decimal,
        currency:
            String
    ) -> String {

        CrossDocumentAnalysisEngine
            .formatMoney(
                value,
                currency:
                    currency
            )
    }
}
