// Restores saved Veryfi JSON, builds authoritative document
// periods/spending facts, and never reprocesses with Veryfi.

import Foundation


@MainActor
final class CrossDocumentService {

    static let shared =
        CrossDocumentService()

    private init() {}


    // Load Saved Documents

    func load(
        documents:
            [HistoryDocument]
    ) async throws
        -> CrossDocumentFactPack {

        var loaded:
            [CrossDocumentLoadedDocument] = []


        for document
            in documents {

            let payloadData =
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
                            payloadData
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


            // Same stable normalizer used by History go and open in Analyze.
            // This does NOT call Veryfi.
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


            loaded.append(
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
            )
        }


        return
            CrossDocumentAnalysisEngine
                .analyze(
                    loaded
                )
    }


    // AI Explanation

    func answer(
        question: String,
        pack:
            CrossDocumentFactPack
    ) async throws
        -> String {

        let cleanQuestion =
            PlainTextSanitizer
                .clean(
                    question
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !cleanQuestion.isEmpty
        else {
            return ""
        }


        let facts =
            CrossDocumentFactFormatter
                .verifiedFacts(
                    pack
                )


        let systemPrompt =
            """
            You explain VERIFIED financial facts produced deterministically by an iOS application.

            Rules:
            1. Use ONLY the VERIFIED FACTS supplied by the application.
            2. The application's spending totals, period labels, changes, counts, merchant totals, category totals, and recurring-payment calculations are authoritative.
            3. Do NOT perform new arithmetic.
            4. Do NOT silently combine or convert different currencies.
            5. A recurring-payment pattern is a deterministic pattern candidate, not proof that a subscription is currently active.
            6. Never claim that a charge is fraudulent, unauthorized, or incorrect unless the verified facts explicitly say that.
            7. If the requested fact is not present, reply exactly:
               "I don't know based on the selected documents."
            8. Return plain text only.
            9. Never use Markdown formatting, asterisks, Markdown headings, backticks, code fences, Markdown links, or Markdown tables.
            10. For lists, use normal numbered lines or the bullet character •.
            """


        let userPrompt =
            """
            VERIFIED FACTS:
            \(facts)

            USER QUESTION:
            \(cleanQuestion)
            """


        let provider:
            ChatProvider =
            OpenAIResponsesProvider()


        let rawAnswer =
            try await
                provider.complete(
                    systemPrompt:
                        systemPrompt,
                    userPrompt:
                        userPrompt
                )


        return
            PlainTextSanitizer
                .clean(
                    rawAnswer
                )
    }
}


// Profile Resolver

enum CrossDocumentProfileResolver {

    static func makeProfile(
        payload:
            [String: Any],
        history:
            HistoryDocument,
        financialDocument:
            FinancialDocument
    ) -> CrossDocumentDocumentProfile {

        let text =
            ocrText(
                payload
            )

        let kind =
            financialKind(
                classification:
                    history
                        .documentType,
                payloadText:
                    text
            )

        let documentDate =
            firstDate(
                payload,
                keys: [
                    "date",
                    "document_date",
                    "bill_date",
                    "statement_date"
                ]
            )

        let dueDate =
            firstDate(
                payload,
                keys: [
                    "due_date",
                    "payment_due_date"
                ]
            )

        let currency =
            resolveCurrency(
                payload
            )

        let vendor =
            resolveVendor(
                payload
            )


        let period =
            resolvePeriod(
                payload:
                    payload,
                text:
                    text,
                kind:
                    kind,
                documentDate:
                    documentDate,
                financialDocument:
                    financialDocument
            )


        let authoritative:
            Decimal?

        let basis:
            String?


        switch kind {

        case .bill:

            authoritative =
                decimal(
                    payload[
                        "total"
                    ]
                )
                ??
                decimal(
                    payload[
                        "balance"
                    ]
                )

            basis =
                authoritative == nil
                ? nil
                : "Document total"


        case .creditCardStatement:

            authoritative =
                creditCardPurchasesTotal(
                    text
                )

            basis =
                authoritative == nil
                ? nil
                : "Statement purchases"


        case .bankStatement,
             .other:

            authoritative =
                nil

            basis =
                nil
        }


        return
            CrossDocumentDocumentProfile(
                kind:
                    kind,
                period:
                    period,
                documentDate:
                    documentDate,
                dueDate:
                    dueDate,
                currency:
                    currency,
                vendorName:
                    vendor,
                authoritativeSpending:
                    authoritative,
                authoritativeSpendingLabel:
                    basis
            )
    }


    // Kind

    private static func financialKind(
        classification:
            String,
        payloadText:
            String
    ) -> CrossDocumentFinancialKind {

        let type =
            classification
                .lowercased()

        let text =
            payloadText
                .lowercased()


        if type.contains(
            "bill"
        )
        ||
        type.contains(
            "invoice"
        )
        ||
        type.contains(
            "receipt"
        ) {

            return .bill
        }


        let creditCardSignals =
            (
                text.contains(
                    "minimum payment due"
                )
                &&
                (
                    text.contains(
                        "credit line"
                    )
                    ||
                    text.contains(
                        "card ending"
                    )
                    ||
                    text.contains(
                        "account number ending"
                    )
                )
            )
            ||
            (
                text.contains(
                    "open to close date"
                )
                &&
                text.contains(
                    "payment due date"
                )
            )


        if creditCardSignals {

            return
                .creditCardStatement
        }


        if type.contains(
            "bank"
        )
        ||
        type.contains(
            "statement"
        ) {

            return
                .bankStatement
        }


        return .other
    }


    // Period

    private static func resolvePeriod(
        payload:
            [String: Any],
        text:
            String,
        kind:
            CrossDocumentFinancialKind,
        documentDate:
            Date?,
        financialDocument:
            FinancialDocument
    ) -> CrossDocumentPeriod? {

        // 1. Structured top-level period pairs

        let structuredPairs:
            [
                (
                    [String],
                    [String],
                    CrossDocumentPeriod.Kind
                )
            ] =
            [
                (
                    [
                        "statement_start_date",
                        "statement_period_start_date",
                        "period_start_date"
                    ],
                    [
                        "statement_end_date",
                        "statement_period_end_date",
                        "period_end_date"
                    ],
                    .statement
                ),
                (
                    [
                        "service_start_date",
                        "service_period_start_date"
                    ],
                    [
                        "service_end_date",
                        "service_period_end_date"
                    ],
                    .service
                )
            ]


        for (
            startKeys,
            endKeys,
            periodKind
        ) in structuredPairs {

            if let start =
                firstDate(
                    payload,
                    keys:
                        startKeys
                ),
               let end =
                firstDate(
                    payload,
                    keys:
                        endKeys
                ),
               start <= end {

                return
                    CrossDocumentPeriod(
                        kind:
                            periodKind,
                        start:
                            start,
                        end:
                            end
                    )
            }
        }


        // 2. Explicit labeled period in OCR text

        let labels:
            [
                (
                    String,
                    CrossDocumentPeriod.Kind
                )
            ]


        switch kind {

        case .creditCardStatement:

            labels = [
                (
                    #"OPEN\s+TO\s+CLOSE\s+DATE"#,
                    .statement
                ),
                (
                    #"STATEMENT\s+PERIOD"#,
                    .statement
                ),
                (
                    #"STATEMENT\s+FOR"#,
                    .statement
                )
            ]


        case .bankStatement:

            labels = [
                (
                    #"STATEMENT\s+PERIOD"#,
                    .statement
                ),
                (
                    #"STATEMENT\s+FOR"#,
                    .statement
                ),
                (
                    #"OPEN\s+TO\s+CLOSE\s+DATE"#,
                    .statement
                )
            ]


        case .bill:

            labels = [
                (
                    #"NEW\s+CHARGES"#,
                    .charge
                ),
                (
                    #"BILLING\s+PERIOD"#,
                    .service
                ),
                (
                    #"SERVICE\s+PERIOD"#,
                    .service
                )
            ]


        case .other:

            labels = [
                (
                    #"STATEMENT\s+PERIOD"#,
                    .statement
                ),
                (
                    #"BILLING\s+PERIOD"#,
                    .service
                )
            ]
        }


        for (
            label,
            periodKind
        ) in labels {

            if let range =
                labeledDateRange(
                    in:
                        text,
                    labelPattern:
                        label
                ) {

                return
                    CrossDocumentPeriod(
                        kind:
                            periodKind,
                        start:
                            range.0,
                        end:
                            range.1
                    )
            }
        }


        // 3. Bill/service-date heuristic
        //
        // City-style utility bills can contain:
        // - prior meter/usage period
        // - current/future monthly service-charge range
        // - one-day backbill rows
        //
        // Prefer a reasonable multi-day range that ENDS
        // before the bill date. If several end together,
        // choose the longest range.

        if kind == .bill {

            let candidates =
                allDateRanges(
                    payload:
                        payload,
                    text:
                        text
                )
                .filter {
                    reasonableServiceRange(
                        $0
                    )
                }


            if let documentDate {

                let beforeBill =
                    candidates
                        .filter {
                            $0.1
                            <
                            Calendar.current
                                .startOfDay(
                                    for:
                                        documentDate
                                )
                        }
                        .sorted {
                            lhs,
                            rhs in

                            if Calendar.current
                                .isDate(
                                    lhs.1,
                                    inSameDayAs:
                                        rhs.1
                                ) {

                                return
                                    rangeDays(
                                        lhs
                                    )
                                    >
                                    rangeDays(
                                        rhs
                                    )
                            }

                            return
                                lhs.1
                                >
                                rhs.1
                        }


                if let best =
                    beforeBill
                        .first {

                    return
                        CrossDocumentPeriod(
                            kind:
                                .service,
                            start:
                                best.0,
                            end:
                                best.1
                        )
                }
            }


            if let best =
                candidates
                    .max(
                        by: {
                            rangeDays(
                                $0
                            )
                            <
                            rangeDays(
                                $1
                            )
                        }
                    ) {

                return
                    CrossDocumentPeriod(
                        kind:
                            .service,
                        start:
                            best.0,
                        end:
                            best.1
                    )
            }
        }


        // 4. Honest fallback: activity range
        //
        // Never label transaction min/max as a statement
        // or service period.

        let dates =
            financialDocument
                .records
                .compactMap(
                    \.date
                )


        if let earliest =
            dates.min(),
           let latest =
            dates.max() {

            return
                CrossDocumentPeriod(
                    kind:
                        .activity,
                    start:
                        earliest,
                    end:
                        latest
                )
        }


        return nil
    }


    // Authoritative Credit-Card Purchases

    private static func creditCardPurchasesTotal(
        _ text:
            String
    ) -> Decimal? {

        // Example: Discover-style account summary:
        //
        // Purchases +$2,992.54
        //
        // This is more authoritative for spending than adding
        // purchase rows plus card payments.
        let patterns =
            [
                #"(?im)^\s*Purchases\s+\+\s*\$?\s*([0-9][0-9,]*\.\d{2})\s*$"#,
                #"(?im)^\s*Purchases\s+\+\$?\s*([0-9][0-9,]*\.\d{2})\s*$"#,
                #"(?im)^\s*Purchases\s+\$?\s*([0-9][0-9,]*\.\d{2})\s*$"#
            ]


        for pattern
            in patterns {

            if let value =
                firstCapture(
                    pattern:
                        pattern,
                    text:
                        text
                ) {

                return
                    decimal(
                        value
                    )
            }
        }


        return nil
    }


    // Date Range Extraction

    private static var dateToken:
        String {

        #"(?:(?:\d{1,2}/\d{1,2}/(?:\d{4}|\d{2}))|(?:[A-Za-z]{3,9}\s+\d{1,2},\s*\d{4}))"#
    }


    private static func labeledDateRange(
        in text:
            String,
        labelPattern:
            String
    ) -> (Date, Date)? {

        let pattern =
            #"(?is)"#
            +
            labelPattern
            +
            #"\s*:?\s*("#
            +
            dateToken
            +
            #")\s*(?:-|–|—|\bto\b)\s*("#
            +
            dateToken
            +
            #")"#


        return
            firstDateRange(
                pattern:
                    pattern,
                text:
                    text
            )
    }


    private static func allDateRanges(
        payload:
            [String: Any],
        text:
            String
    ) -> [(Date, Date)] {

        var ranges:
            [(Date, Date)] = []


        // Structured line-item ranges.
        let lineItems =
            payload[
                "line_items"
            ]
                as?
                [[String: Any]]
            ??
            []


        for item
            in lineItems {

            let starts =
                [
                    "start_date",
                    "service_start_date",
                    "period_start_date",
                    "date_start"
                ]

            let ends =
                [
                    "end_date",
                    "service_end_date",
                    "period_end_date",
                    "date_end"
                ]


            if let start =
                firstDate(
                    item,
                    keys:
                        starts
                ),
               let end =
                firstDate(
                    item,
                    keys:
                        ends
                ),
               start <= end {

                ranges.append(
                    (
                        start,
                        end
                    )
                )
            }
        }


        // OCR date ranges catch utility layouts where Veryfi
        // extracted start/end dates into text rather than
        // structured line-item keys.
        let pattern =
            #"(?is)("#
            +
            dateToken
            +
            #")\s*(?:-|–|—|\bto\b)\s*("#
            +
            dateToken
            +
            #")"#


        if let regex =
            try?
            NSRegularExpression(
                pattern:
                    pattern
            ) {

            let nsText =
                text
                    as NSString

            let fullRange =
                NSRange(
                    location:
                        0,
                    length:
                        nsText.length
                )


            for match
                in regex.matches(
                    in:
                        text,
                    range:
                        fullRange
                ) {

                guard
                    match.numberOfRanges
                    >=
                    3
                else {
                    continue
                }


                let first =
                    nsText.substring(
                        with:
                            match.range(
                                at:
                                    1
                            )
                    )

                let second =
                    nsText.substring(
                        with:
                            match.range(
                                at:
                                    2
                            )
                    )


                if let start =
                    parseDate(
                        first
                    ),
                   let end =
                    parseDate(
                        second
                    ),
                   start <= end {

                    ranges.append(
                        (
                            start,
                            end
                        )
                    )
                }
            }
        }


        // Remove exact duplicate ranges.
        var seen:
            Set<String> = []

        return
            ranges.filter {
                range in

                let key =
                    "\(range.0.timeIntervalSince1970)|\(range.1.timeIntervalSince1970)"

                return
                    seen
                        .insert(
                            key
                        )
                        .inserted
            }
    }


    private static func firstDateRange(
        pattern:
            String,
        text:
            String
    ) -> (Date, Date)? {

        guard
            let regex =
                try?
                NSRegularExpression(
                    pattern:
                        pattern
                )
        else {
            return nil
        }


        let nsText =
            text
                as NSString

        let fullRange =
            NSRange(
                location:
                    0,
                length:
                    nsText.length
            )


        guard
            let match =
                regex.firstMatch(
                    in:
                        text,
                    range:
                        fullRange
                ),
            match.numberOfRanges
            >=
            3
        else {
            return nil
        }


        let first =
            nsText.substring(
                with:
                    match.range(
                        at:
                            1
                    )
            )

        let second =
            nsText.substring(
                with:
                    match.range(
                        at:
                            2
                    )
            )


        guard
            let start =
                parseDate(
                    first
                ),
            let end =
                parseDate(
                    second
                ),
            start <= end
        else {
            return nil
        }


        return (
            start,
            end
        )
    }


    private static func reasonableServiceRange(
        _ range:
            (Date, Date)
    ) -> Bool {

        let days =
            rangeDays(
                range
            )


        return
            days
            >=
            7
            &&
            days
            <=
            120
    }


    private static func rangeDays(
        _ range:
            (Date, Date)
    ) -> Int {

        Calendar.current
            .dateComponents(
                [
                    .day
                ],
                from:
                    range.0,
                to:
                    range.1
            )
            .day
        ??
        0
    }


    // Payload Helpers

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


    private static func resolveCurrency(
        _ payload:
            [String: Any]
    ) -> String {

        if let direct =
            string(
                payload[
                    "total_currency_code"
                ]
            )
            ??
            string(
                payload[
                    "currency_code"
                ]
            )
            ??
            string(
                payload[
                    "currency"
                ]
            ) {

            return
                direct
                    .uppercased()
        }


        let accounts =
            payload[
                "accounts"
            ]
                as?
                [[String: Any]]
            ??
            []


        if let first =
            accounts.first,
           let accountCurrency =
            string(
                first[
                    "currency"
                ]
            )
            ??
            string(
                first[
                    "currency_code"
                ]
            ) {

            return
                accountCurrency
                    .uppercased()
        }


        return "USD"
    }


    private static func resolveVendor(
        _ payload:
            [String: Any]
    ) -> String? {

        if let vendor =
            payload[
                "vendor"
            ]
                as?
                [String: Any] {

            if let name =
                string(
                    vendor[
                        "name"
                    ]
                )
                ??
                string(
                    vendor[
                        "raw_name"
                    ]
                ) {

                return name
            }
        }


        return
            string(
                payload[
                    "vendor_name"
                ]
            )
            ??
            string(
                payload[
                    "raw_vendor_name"
                ]
            )
    }


    private static func firstDate(
        _ object:
            [String: Any],
        keys:
            [String]
    ) -> Date? {

        for key
            in keys {

            if let date =
                parseDate(
                    string(
                        object[
                            key
                        ]
                    )
                ) {

                return date
            }
        }


        return nil
    }


    private static func parseDate(
        _ value:
            String?
    ) -> Date? {

        guard
            let raw =
                value?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !raw.isEmpty
        else {
            return nil
        }


        let normalized =
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
                        .whitespacesAndNewlines
                )


        // Full ISO timestamps.
        if normalized.contains(
            "T"
        ) {

            let isoWithFraction =
                ISO8601DateFormatter()

            isoWithFraction.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]


            if let date =
                isoWithFraction.date(
                    from:
                        normalized
                ) {

                return
                    Calendar.current
                        .startOfDay(
                            for:
                                date
                        )
            }


            let iso =
                ISO8601DateFormatter()

            iso.formatOptions = [
                .withInternetDateTime
            ]


            if let date =
                iso.date(
                    from:
                        normalized
                ) {

                return
                    Calendar.current
                        .startOfDay(
                            for:
                                date
                        )
            }
        }


        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.timeZone =
            TimeZone(
                secondsFromGMT:
                    0
            )

        formatter.isLenient =
            false


        let formats:
            [String]


        if normalized.range(
            of:
                #"^\d{4}-\d{1,2}-\d{1,2}$"#,
            options:
                .regularExpression
        ) != nil {

            formats = [
                "yyyy-MM-dd"
            ]

        } else if normalized.contains(
            "/"
        ) {

            let yearPart =
                normalized
                    .split(
                        separator:
                            "/"
                    )
                    .last
                    .map(
                        String.init
                    )
                ??
                ""


            formats =
                yearPart.count
                ==
                4
                ? [
                    "M/d/yyyy",
                    "MM/dd/yyyy"
                ]
                : [
                    "M/d/yy",
                    "MM/dd/yy"
                ]

        } else if normalized
            .contains(
                ","
            ) {

            formats = [
                "MMM d, yyyy",
                "MMMM d, yyyy"
            ]

        } else {

            formats = []
        }


        for format
            in formats {

            formatter.dateFormat =
                format


            if let date =
                formatter.date(
                    from:
                        normalized
                ) {

                return date
            }
        }


        return nil
    }

    private static func firstCapture(
        pattern:
            String,
        text:
            String
    ) -> String? {

        guard
            let regex =
                try?
                NSRegularExpression(
                    pattern:
                        pattern
                )
        else {
            return nil
        }


        let nsText =
            text
                as NSString

        let fullRange =
            NSRange(
                location:
                    0,
                length:
                    nsText.length
            )


        guard
            let match =
                regex.firstMatch(
                    in:
                        text,
                    range:
                        fullRange
                ),
            match.numberOfRanges
            >=
            2
        else {
            return nil
        }


        return
            nsText.substring(
                with:
                    match.range(
                        at:
                            1
                    )
            )
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
                trimmed.isEmpty
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

        if let value =
            value
                as?
                Decimal {

            return value
        }


        if let value =
            value
                as?
                NSNumber {

            return
                value
                    .decimalValue
        }


        if let value =
            string(
                value
            ) {

            let cleaned =
                value
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
                        cleaned,
                    locale:
                        Locale(
                            identifier:
                                "en_US_POSIX"
                        )
                )
        }


        return nil
    }
}


// Verified Fact Formatter

enum CrossDocumentFactFormatter {

    static func verifiedFacts(
        _ pack:
            CrossDocumentFactPack
    ) -> String {

        var sections:
            [String] = []


        let documentFacts =
            pack
                .metrics
                .map {
                    metric in

                    let spending =
                        metric
                            .spending
                            .map {
                                CrossDocumentAnalysisEngine
                                    .formatMoney(
                                        $0.amount,
                                        currency:
                                            $0.currency
                                    )
                            }
                            .joined(
                                separator:
                                    " • "
                            )


                    let inflows =
                        metric
                            .inflows
                            .map {
                                CrossDocumentAnalysisEngine
                                    .formatMoney(
                                        $0.amount,
                                        currency:
                                            $0.currency
                                    )
                            }
                            .joined(
                                separator:
                                    " • "
                            )


                    let largest:
                        String

                    if let record =
                        metric
                            .largestCharge {

                        largest =
                            "\(CrossDocumentAnalysisEngine.merchantLabel(record)) • \(CrossDocumentAnalysisEngine.formatMoney(record.amount, currency: record.currency))"

                    } else {

                        largest =
                            "None"
                    }


                    let period =
                        metric
                            .document
                            .periodCaption
                        ??
                        "Period unavailable"


                    return
                        """
                        Document: \(metric.document.displayName)
                        Type: \(metric.document.history.prettyDocumentType)
                        \(period)
                        Verified spending: \(spending.isEmpty ? "None" : spending)
                        Spending basis: \(metric.spendingBasis)
                        Verified inflows: \(inflows.isEmpty ? "None" : inflows)
                        Extracted record count: \(metric.transactionCount)
                        Largest included charge: \(largest)
                        """
                }
                .joined(
                    separator:
                        "\n\n"
                )


        sections.append(
            """
            PER-DOCUMENT VERIFIED METRICS
            \(documentFacts)
            """
        )


        if !pack
            .spendingChanges
            .isEmpty {

            let changes =
                pack
                    .spendingChanges
                    .map {
                        change in

                        let percent =
                            change
                                .percentChange
                                .map {
                                    String(
                                        format:
                                            " (%.1f%%)",
                                        $0
                                    )
                                }
                            ??
                            ""


                        return
                            "\(change.fromDocumentName) -> \(change.toDocumentName): \(CrossDocumentAnalysisEngine.formatMoney(change.previousAmount, currency: change.currency)) -> \(CrossDocumentAnalysisEngine.formatMoney(change.currentAmount, currency: change.currency)); verified delta \(CrossDocumentAnalysisEngine.formatMoney(change.delta, currency: change.currency))\(percent)"
                    }
                    .joined(
                        separator:
                            "\n"
                    )


            sections.append(
                """
                VERIFIED SPENDING CHANGES
                \(changes)
                """
            )
        }


        if !pack
            .recurringPayments
            .isEmpty {

            let recurring =
                pack
                    .recurringPayments
                    .map {
                        pattern in

                        let monthly =
                            pattern
                                .estimatedMonthlyAmount
                                .map {
                                    CrossDocumentAnalysisEngine
                                        .formatMoney(
                                            $0,
                                            currency:
                                                pattern
                                                    .currency
                                        )
                                }
                            ??
                            "N/A"


                        let annual =
                            pattern
                                .estimatedAnnualAmount
                                .map {
                                    CrossDocumentAnalysisEngine
                                        .formatMoney(
                                            $0,
                                            currency:
                                                pattern
                                                    .currency
                                        )
                                }
                            ??
                            "N/A"


                        return
                            "\(pattern.merchant) • \(pattern.cadence.rawValue) • typical \(CrossDocumentAnalysisEngine.formatMoney(pattern.typicalAmount, currency: pattern.currency)) • \(pattern.occurrences.count) occurrences • estimated monthly \(monthly) • estimated annual \(annual) • \(pattern.confidence.rawValue)"
                    }
                    .joined(
                        separator:
                            "\n"
                    )


            sections.append(
                """
                DETERMINISTIC RECURRING PAYMENT PATTERNS
                \(recurring)
                """
            )

        } else {

            sections.append(
                """
                DETERMINISTIC RECURRING PAYMENT PATTERNS
                No recurring payment patterns were detected in the selected documents.
                """
            )
        }


        if !pack
            .merchantTotals
            .isEmpty {

            let merchantFacts =
                pack
                    .merchantTotals
                    .prefix(
                        80
                    )
                    .map {
                        item in

                        "\(item.merchant): \(CrossDocumentAnalysisEngine.formatMoney(item.amount, currency: item.currency)) across \(item.count) included charge(s)"
                    }
                    .joined(
                        separator:
                            "\n"
                    )


            sections.append(
                """
                VERIFIED MERCHANT TOTALS
                \(merchantFacts)
                """
            )
        }


        if !pack
            .categoryTotals
            .isEmpty {

            let categoryFacts =
                pack
                    .categoryTotals
                    .prefix(
                        60
                    )
                    .map {
                        item in

                        "\(item.category): \(CrossDocumentAnalysisEngine.formatMoney(item.amount, currency: item.currency)) across \(item.count) included charge(s)"
                    }
                    .joined(
                        separator:
                            "\n"
                    )


            sections.append(
                """
                VERIFIED CATEGORY TOTALS
                \(categoryFacts)
                """
            )
        }


        return
            sections
                .joined(
                    separator:
                        "\n\n====================\n\n"
                )
    }
}
