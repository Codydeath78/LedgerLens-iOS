// Deterministic cross-document calculations, authoritative
// period resolution, and recurring-payment detection.
//
// IMPORTANT:
// Financial totals and recurring-pattern decisions are made
// in Swift. AI receives verified facts only.

import Foundation


// Document Profile

enum CrossDocumentFinancialKind:
    String {

    case creditCardStatement
    case bankStatement
    case bill
    case other
}


struct CrossDocumentPeriod {

    enum Kind:
        String {

        case statement =
            "Statement period"

        case service =
            "Service period"

        case charge =
            "Charge period"

        case activity =
            "Transaction activity"
    }


    let kind:
        Kind

    let start:
        Date

    let end:
        Date


    var formatted:
        String {

        if Calendar.current
            .isDate(
                start,
                inSameDayAs:
                    end
            ) {

            return
                start.formatted(
                    date:
                        .abbreviated,
                    time:
                        .omitted
                )
        }


        return
            "\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }


    var caption:
        String {

        "\(kind.rawValue): \(formatted)"
    }
}


struct CrossDocumentDocumentProfile {

    let kind:
        CrossDocumentFinancialKind

    let period:
        CrossDocumentPeriod?

    let documentDate:
        Date?

    let dueDate:
        Date?

    let currency:
        String

    let vendorName:
        String?

    let authoritativeSpending:
        Decimal?

    let authoritativeSpendingLabel:
        String?
}


// Loaded Document

struct CrossDocumentLoadedDocument:
    Identifiable {

    var id:
        UUID {

        history.id
    }

    let history:
        HistoryDocument

    let financialDocument:
        FinancialDocument

    let summary:
        HistoryDocumentSummary?

    let conversations:
        [DocumentConversation]

    let profile:
        CrossDocumentDocumentProfile


    var displayName:
        String {

        history
            .resolvedDisplayName
    }


    // It now represents the resolved document period.
    var transactionPeriodText:
        String? {

        profile
            .period?
            .formatted
    }


    var periodCaption:
        String? {

        profile
            .period?
            .caption
    }


    var resolvedPeriodStartDate:
        Date? {

        profile
            .period?
            .start
    }


    var resolvedPeriodEndDate:
        Date? {

        profile
            .period?
            .end
    }
}


// Transaction Wrapper

struct CrossDocumentTransaction:
    Identifiable {

    let documentID:
        UUID

    let documentName:
        String

    let documentKind:
        CrossDocumentFinancialKind

    let record:
        TransactionRecord

    // Cross-document-only corrected date.
    // The stable FinancialDocument is never mutated.
    let effectiveDate:
        Date?


    var id:
        String {

        "\(documentID.uuidString)-\(record.id.uuidString)"
    }
}


// Deterministic Totals

struct CrossDocumentCurrencyTotal:
    Identifiable,
    Equatable {

    let currency:
        String

    let amount:
        Decimal

    var id:
        String {

        currency
    }
}


struct CrossDocumentMetric:
    Identifiable {

    var id:
        UUID {

        document.id
    }

    let document:
        CrossDocumentLoadedDocument

    let spending:
        [CrossDocumentCurrencyTotal]

    let inflows:
        [CrossDocumentCurrencyTotal]

    let transactionCount:
        Int

    let largestCharge:
        TransactionRecord?

    let spendingBasis:
        String
}


struct CrossDocumentSpendingChange:
    Identifiable {

    let id:
        String

    let fromDocumentName:
        String

    let toDocumentName:
        String

    let currency:
        String

    let previousAmount:
        Decimal

    let currentAmount:
        Decimal

    let delta:
        Decimal

    let percentChange:
        Double?
}


struct CrossDocumentMerchantTotal:
    Identifiable {

    let id:
        String

    let merchant:
        String

    let currency:
        String

    let amount:
        Decimal

    let count:
        Int
}


struct CrossDocumentCategoryTotal:
    Identifiable {

    let id:
        String

    let category:
        String

    let currency:
        String

    let amount:
        Decimal

    let count:
        Int
}


// Recurring Payments

struct RecurringPaymentOccurrence:
    Identifiable {

    let id:
        String

    let documentID:
        UUID

    let documentName:
        String

    let date:
        Date

    let amount:
        Decimal

    let currency:
        String

    let description:
        String
}


struct RecurringPaymentPattern:
    Identifiable {

    enum Cadence:
        String {

        case weekly =
            "Weekly"

        case biweekly =
            "Every 2 weeks"

        case monthly =
            "Monthly"

        case quarterly =
            "Quarterly"

        case yearly =
            "Yearly"

        case repeating =
            "Repeating"
    }


    enum Confidence:
        String {

        case high =
            "High confidence"

        case medium =
            "Likely recurring"
    }


    let id:
        String

    let merchant:
        String

    let currency:
        String

    let typicalAmount:
        Decimal

    let cadence:
        Cadence

    let confidence:
        Confidence

    let occurrences:
        [RecurringPaymentOccurrence]

    let estimatedMonthlyAmount:
        Decimal?

    let estimatedAnnualAmount:
        Decimal?
}


// Analysis Pack

struct CrossDocumentFactPack {

    let documents:
        [CrossDocumentLoadedDocument]

    let metrics:
        [CrossDocumentMetric]

    let spendingChanges:
        [CrossDocumentSpendingChange]

    let recurringPayments:
        [RecurringPaymentPattern]

    let merchantTotals:
        [CrossDocumentMerchantTotal]

    let categoryTotals:
        [CrossDocumentCategoryTotal]

    let transactions:
        [CrossDocumentTransaction]

    let spendingTransactions:
        [CrossDocumentTransaction]
}


// Deterministic Engine

enum CrossDocumentAnalysisEngine {

    static func analyze(
        _ documents:
            [CrossDocumentLoadedDocument]
    ) -> CrossDocumentFactPack {

        let orderedDocuments =
            documents.sorted {
                sortDate(
                    $0
                )
                <
                sortDate(
                    $1
                )
            }


        let allTransactions =
            orderedDocuments.flatMap {
                makeWrappedTransactions(
                    for:
                        $0
                )
            }


        let safeSpendingTransactions =
            orderedDocuments.flatMap {
                spendingTransactions(
                    for:
                        $0
                )
            }


        let metrics =
            orderedDocuments.map {
                makeMetric(
                    $0
                )
            }


        let recurring =
            detectRecurringPayments(
                transactions:
                    safeSpendingTransactions
            )


        return
            CrossDocumentFactPack(
                documents:
                    orderedDocuments,
                metrics:
                    metrics,
                spendingChanges:
                    makeSpendingChanges(
                        metrics:
                            metrics
                    ),
                recurringPayments:
                    recurring,
                merchantTotals:
                    makeMerchantTotals(
                        transactions:
                            safeSpendingTransactions
                    ),
                categoryTotals:
                    makeCategoryTotals(
                        transactions:
                            safeSpendingTransactions
                    ),
                transactions:
                    allTransactions,
                spendingTransactions:
                    safeSpendingTransactions
            )
    }


    // Record Wrapping / Year Repair

    private static func makeWrappedTransactions(
        for document:
            CrossDocumentLoadedDocument
    ) -> [CrossDocumentTransaction] {

        document
            .financialDocument
            .records
            .map {
                record in

                CrossDocumentTransaction(
                    documentID:
                        document.id,
                    documentName:
                        document
                            .displayName,
                    documentKind:
                        document
                            .profile
                            .kind,
                    record:
                        record,
                    effectiveDate:
                        correctedDate(
                            record.date,
                            within:
                                document
                                    .profile
                                    .period
                        )
                )
            }
    }


    private static func correctedDate(
        _ date:
            Date?,
        within period:
            CrossDocumentPeriod?
    ) -> Date? {

        guard
            let date,
            let period
        else {
            return date
        }


        let calendar =
            Calendar.current

        let day =
            calendar
                .startOfDay(
                    for:
                        date
                )

        let start =
            calendar
                .startOfDay(
                    for:
                        period.start
                )

        let end =
            calendar
                .startOfDay(
                    for:
                        period.end
                )


        if day >= start,
           day <= end {

            return day
        }


        let candidates =
            [
                calendar.date(
                    byAdding:
                        .year,
                    value:
                        -1,
                    to:
                        day
                ),
                calendar.date(
                    byAdding:
                        .year,
                    value:
                        1,
                    to:
                        day
                )
            ]
            .compactMap {
                $0
            }


        if let exactPeriodCandidate =
            candidates.first(
                where: {
                    $0 >= start
                    &&
                    $0 <= end
                }
            ) {

            return exactPeriodCandidate
        }


        return day
    }


    // Spending Dataset

    private static func spendingTransactions(
        for document:
            CrossDocumentLoadedDocument
    ) -> [CrossDocumentTransaction] {

        switch document
            .profile
            .kind {

        case .bill:

            // A bill can expose the same financial charge in
            // several OCR regions (table, chart, summary, etc.).
            // Use one document-level total when available.
            if let total =
                document
                    .profile
                    .authoritativeSpending,
               total > 0 {

                let date =
                    document
                        .profile
                        .documentDate
                    ??
                    document
                        .profile
                        .period?
                        .end
                    ??
                    document
                        .history
                        .createdAt


                let record =
                    TransactionRecord(
                        chunkID:
                            UUID(),
                        date:
                            date,
                        amount:
                            total,
                        currency:
                            document
                                .profile
                                .currency,
                        status:
                            .unknown,
                        flow:
                            .outflow,
                        role:
                            .billCharge,
                        description:
                            document
                                .displayName,
                        vendor:
                            document
                                .profile
                                .vendorName,
                        category:
                            "Bill total",
                        sourceText:
                            "Authoritative bill total"
                    )


                return [
                    CrossDocumentTransaction(
                        documentID:
                            document.id,
                        documentName:
                            document
                                .displayName,
                        documentKind:
                            .bill,
                        record:
                            record,
                        effectiveDate:
                            date
                    )
                ]
            }


            return
                deduplicatedBillOutflows(
                    document
                )


        case .creditCardStatement:

            return
                makeWrappedTransactions(
                    for:
                        document
                )
                .filter {
                    isCreditCardPurchase(
                        $0.record
                    )
                }


        case .bankStatement,
             .other:

            return
                makeWrappedTransactions(
                    for:
                        document
                )
                .filter {
                    item in

                    item
                        .record
                        .flow
                    ==
                    .outflow
                    &&
                    item
                        .record
                        .amount
                    >
                    0
                    &&
                    !isExplicitCreditOrRefund(
                        item
                            .record
                    )
                }
        }
    }


    private static func isCreditCardPurchase(
        _ record:
            TransactionRecord
    ) -> Bool {

        guard
            record.flow
            ==
            .outflow,
            record.amount
            >
            0
        else {
            return false
        }


        switch record.role {

        case .credit,
             .refund,
             .deposit,
             .payment:

            return false

        default:
            break
        }


        let text =
            record
                .searchableText
                .lowercased()


        let paymentSignals =
            [
                "internet payment",
                "online payment",
                "automatic payment",
                "autopay payment",
                "payment - thank you",
                "payment thank you",
                "payment received",
                "payments and credits",
                "statement credit",
                "cashback bonus",
                "reward credit",
                "rewards credit"
            ]


        if paymentSignals
            .contains(
                where: {
                    text.contains(
                        $0
                    )
                }
            ) {

            return false
        }


        if text.contains(
            "payment"
        )
        &&
        text.contains(
            "thank you"
        ) {

            return false
        }


        return true
    }


    private static func isExplicitCreditOrRefund(
        _ record:
            TransactionRecord
    ) -> Bool {

        switch record.role {

        case .credit,
             .refund,
             .deposit:

            return true

        default:
            return false
        }
    }


    private static func deduplicatedBillOutflows(
        _ document:
            CrossDocumentLoadedDocument
    ) -> [CrossDocumentTransaction] {

        let wrapped =
            makeWrappedTransactions(
                for:
                    document
            )
            .filter {
                $0.record.flow
                ==
                .outflow
                &&
                $0.record.amount
                >
                0
                &&
                !isExplicitCreditOrRefund(
                    $0.record
                )
            }


        var seen:
            Set<String> = []

        var result:
            [CrossDocumentTransaction] = []


        for item
            in wrapped {

            let descriptionKey =
                normalizedBillDescription(
                    item
                        .record
                        .description
                )

            let amountKey =
                NSDecimalNumber(
                    decimal:
                        item
                            .record
                            .amount
                )
                .stringValue

            let dateKey =
                item
                    .effectiveDate
                    .map {
                        ISO8601DateFormatter()
                            .string(
                                from:
                                    $0
                            )
                    }
                ??
                "no-date"

            let key =
                "\(descriptionKey)|\(amountKey)|\(item.record.currency)|\(dateKey)"


            if seen
                .insert(
                    key
                )
                .inserted {

                result.append(
                    item
                )
            }
        }


        return result
    }


    private static func normalizedBillDescription(
        _ text:
            String
    ) -> String {

        text
            .lowercased()
            .replacingOccurrences(
                of:
                    #"\bmonthly\b"#,
                with:
                    "",
                options:
                    .regularExpression
            )
            .replacingOccurrences(
                of:
                    #"\bcharge\b"#,
                with:
                    "",
                options:
                    .regularExpression
            )
            .replacingOccurrences(
                of:
                    #"[^a-z0-9]+"#,
                with:
                    " ",
                options:
                    .regularExpression
            )
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


    // Per-Document Metrics

    private static func makeMetric(
        _ document:
            CrossDocumentLoadedDocument
    ) -> CrossDocumentMetric {

        let safeTransactions =
            spendingTransactions(
                for:
                    document
            )


        let spending:
            [CrossDocumentCurrencyTotal]

        let spendingBasis:
            String


        if let authoritative =
            document
                .profile
                .authoritativeSpending,
           authoritative >= 0 {

            spending = [
                CrossDocumentCurrencyTotal(
                    currency:
                        document
                            .profile
                            .currency,
                    amount:
                        authoritative
                )
            ]

            spendingBasis =
                document
                    .profile
                    .authoritativeSpendingLabel
                ??
                "Authoritative document total"

        } else {

            spending =
                groupedCurrencyTotals(
                    safeTransactions
                        .map(
                            \.record
                        )
                )

            spendingBasis =
                "Normalized purchase/outflow records"
        }


        let inflows =
            groupedCurrencyTotals(
                document
                    .financialDocument
                    .records
                    .filter {
                        $0.flow
                        ==
                        .inflow
                    }
            )


        let largest =
            safeTransactions
                .map(
                    \.record
                )
                .max {
                    $0.amount
                    <
                    $1.amount
                }


        return
            CrossDocumentMetric(
                document:
                    document,
                spending:
                    spending,
                inflows:
                    inflows,
                transactionCount:
                    document
                        .financialDocument
                        .records
                        .count,
                largestCharge:
                    largest,
                spendingBasis:
                    spendingBasis
            )
    }


    private static func groupedCurrencyTotals(
        _ records:
            [TransactionRecord]
    ) -> [CrossDocumentCurrencyTotal] {

        let grouped =
            Dictionary(
                grouping:
                    records,
                by:
                    \.currency
            )


        return
            grouped
                .map {
                    currency,
                    records in

                    CrossDocumentCurrencyTotal(
                        currency:
                            currency,
                        amount:
                            records.reduce(
                                Decimal.zero
                            ) {
                                partial,
                                record in

                                partial
                                +
                                record.amount
                            }
                    )
                }
                .sorted {
                    $0.currency
                    <
                    $1.currency
                }
    }


    // Spending Changes

    private static func makeSpendingChanges(
        metrics:
            [CrossDocumentMetric]
    ) -> [CrossDocumentSpendingChange] {

        guard
            metrics.count
            >= 2
        else {
            return []
        }


        var results:
            [CrossDocumentSpendingChange] = []


        for index
            in 1..<metrics.count {

            let previous =
                metrics[
                    index - 1
                ]

            let current =
                metrics[
                    index
                ]


            let previousByCurrency =
                Dictionary(
                    uniqueKeysWithValues:
                        previous
                            .spending
                            .map {
                                (
                                    $0.currency,
                                    $0.amount
                                )
                            }
                )

            let currentByCurrency =
                Dictionary(
                    uniqueKeysWithValues:
                        current
                            .spending
                            .map {
                                (
                                    $0.currency,
                                    $0.amount
                                )
                            }
                )


            let currencies =
                Set(
                    previousByCurrency
                        .keys
                )
                .intersection(
                    Set(
                        currentByCurrency
                            .keys
                    )
                )


            for currency
                in currencies {

                guard
                    let previousAmount =
                        previousByCurrency[
                            currency
                        ],
                    let currentAmount =
                        currentByCurrency[
                            currency
                        ]
                else {
                    continue
                }


                let delta =
                    currentAmount
                    -
                    previousAmount

                let previousDouble =
                    double(
                        previousAmount
                    )


                let percent:
                    Double?

                if previousDouble
                    !=
                    0 {

                    percent =
                        double(
                            delta
                        )
                        /
                        abs(
                            previousDouble
                        )
                        *
                        100

                } else {

                    percent =
                        nil
                }


                results.append(
                    CrossDocumentSpendingChange(
                        id:
                            "\(previous.id.uuidString)-\(current.id.uuidString)-\(currency)",
                        fromDocumentName:
                            previous
                                .document
                                .displayName,
                        toDocumentName:
                            current
                                .document
                                .displayName,
                        currency:
                            currency,
                        previousAmount:
                            previousAmount,
                        currentAmount:
                            currentAmount,
                        delta:
                            delta,
                        percentChange:
                            percent
                    )
                )
            }
        }


        return results
    }


    private static func sortDate(
        _ document:
            CrossDocumentLoadedDocument
    ) -> Date {

        document
            .profile
            .period?
            .start
        ??
        document
            .profile
            .documentDate
        ??
        document
            .history
            .createdAt
    }


    // Recurring Payment Detection

    private struct RecurringCandidate {

        let transaction:
            CrossDocumentTransaction

        let merchant:
            String

        let normalizedMerchant:
            String
    }


    static func detectRecurringPayments(
        transactions:
            [CrossDocumentTransaction]
    ) -> [RecurringPaymentPattern] {

        let candidates =
            transactions
                .compactMap {
                    transaction
                    ->
                    RecurringCandidate?
                    in

                    let record =
                        transaction
                            .record


                    guard
                        record.flow
                        ==
                        .outflow,
                        record.amount
                        >
                        0,
                        transaction
                            .effectiveDate
                        !=
                        nil
                    else {
                        return nil
                    }


                    let merchant =
                        merchantLabel(
                            record
                        )

                    let normalized =
                        merchantKey(
                            merchant
                        )


                    guard
                        !normalized.isEmpty
                    else {
                        return nil
                    }


                    return
                        RecurringCandidate(
                            transaction:
                                transaction,
                            merchant:
                                merchant,
                            normalizedMerchant:
                                normalized
                        )
                }


        let merchantGroups =
            Dictionary(
                grouping:
                    candidates,
                by: {
                    "\($0.normalizedMerchant)|\($0.transaction.record.currency)"
                }
            )


        var patterns:
            [RecurringPaymentPattern] = []


        for (
            merchantCurrencyKey,
            group
        ) in merchantGroups {

            guard
                group.count
                >=
                2
            else {
                continue
            }


            let amountClusters =
                clusterBySimilarAmount(
                    group
                )


            for (
                clusterIndex,
                cluster
            ) in amountClusters
                .enumerated() {

                guard
                    cluster.count
                    >=
                    2
                else {
                    continue
                }


                let distinctDocumentIDs =
                    Set(
                        cluster.map {
                            $0.transaction
                                .documentID
                        }
                    )


                guard
                    distinctDocumentIDs.count
                    >=
                    2
                else {
                    continue
                }


                let sorted =
                    cluster.sorted {
                        ($0.transaction.effectiveDate ?? .distantPast)
                        <
                        ($1.transaction.effectiveDate ?? .distantPast)
                    }


                let intervals =
                    zip(
                        sorted,
                        sorted.dropFirst()
                    )
                    .compactMap {
                        first,
                        second
                        ->
                        Double?
                        in

                        guard
                            let firstDate =
                                first
                                    .transaction
                                    .effectiveDate,
                            let secondDate =
                                second
                                    .transaction
                                    .effectiveDate
                        else {
                            return nil
                        }


                        let days =
                            Calendar.current
                                .dateComponents(
                                    [
                                        .day
                                    ],
                                    from:
                                        firstDate,
                                    to:
                                        secondDate
                                )
                                .day
                            ??
                            0


                        return
                            days > 0
                            ? Double(
                                days
                            )
                            : nil
                    }
                    .sorted()


                guard
                    !intervals.isEmpty
                else {
                    continue
                }


                let medianInterval =
                    median(
                        intervals
                    )

                let cadence =
                    cadenceFor(
                        days:
                            medianInterval
                    )


                if cluster.count
                    ==
                    2,
                   cadence
                    ==
                   .repeating {

                    continue
                }


                let amounts =
                    cluster
                        .map {
                            double(
                                $0.transaction
                                    .record
                                    .amount
                            )
                        }
                        .sorted()


                let typicalDouble =
                    median(
                        amounts
                    )


                guard
                    typicalDouble
                    >
                    0
                else {
                    continue
                }


                let minAmount =
                    amounts.min()
                    ??
                    typicalDouble

                let maxAmount =
                    amounts.max()
                    ??
                    typicalDouble

                let relativeRange =
                    (
                        maxAmount
                        -
                        minAmount
                    )
                    /
                    typicalDouble


                let allowedRange =
                    cluster.count
                    >=
                    3
                    ? 0.25
                    : 0.15


                guard
                    relativeRange
                    <=
                    allowedRange
                else {
                    continue
                }


                let confidence:
                    RecurringPaymentPattern
                        .Confidence =
                    (
                        cluster.count
                        >=
                        3
                        &&
                        cadence
                        !=
                        .repeating
                        &&
                        relativeRange
                        <=
                        0.10
                    )
                    ? .high
                    : .medium


                let typicalAmount =
                    Decimal(
                        typicalDouble
                    )

                let monthly =
                    monthlyEstimate(
                        typical:
                            typicalAmount,
                        cadence:
                            cadence
                    )


                let occurrences =
                    sorted.compactMap {
                        item
                        ->
                        RecurringPaymentOccurrence?
                        in

                        guard
                            let date =
                                item
                                    .transaction
                                    .effectiveDate
                        else {
                            return nil
                        }


                        return
                            RecurringPaymentOccurrence(
                                id:
                                    item
                                        .transaction
                                        .id,
                                documentID:
                                    item
                                        .transaction
                                        .documentID,
                                documentName:
                                    item
                                        .transaction
                                        .documentName,
                                date:
                                    date,
                                amount:
                                    item
                                        .transaction
                                        .record
                                        .amount,
                                currency:
                                    item
                                        .transaction
                                        .record
                                        .currency,
                                description:
                                    item
                                        .transaction
                                        .record
                                        .description
                            )
                    }


                guard
                    let first =
                        cluster.first
                else {
                    continue
                }


                patterns.append(
                    RecurringPaymentPattern(
                        id:
                            "\(merchantCurrencyKey)-\(clusterIndex)",
                        merchant:
                            first.merchant,
                        currency:
                            first
                                .transaction
                                .record
                                .currency,
                        typicalAmount:
                            typicalAmount,
                        cadence:
                            cadence,
                        confidence:
                            confidence,
                        occurrences:
                            occurrences,
                        estimatedMonthlyAmount:
                            monthly,
                        estimatedAnnualAmount:
                            monthly.map {
                                $0
                                *
                                12
                            }
                    )
                )
            }
        }


        return
            patterns
                .sorted {
                    lhs,
                    rhs in

                    let left =
                        lhs
                            .estimatedMonthlyAmount
                        ??
                        lhs.typicalAmount

                    let right =
                        rhs
                            .estimatedMonthlyAmount
                        ??
                        rhs.typicalAmount

                    return
                        left
                        >
                        right
                }
    }


    private static func clusterBySimilarAmount(
        _ candidates:
            [RecurringCandidate]
    ) -> [[RecurringCandidate]] {

        let sorted =
            candidates.sorted {
                $0.transaction
                    .record
                    .amount
                <
                $1.transaction
                    .record
                    .amount
            }


        var clusters:
            [[RecurringCandidate]] = []


        for candidate
            in sorted {

            var inserted =
                false


            for index
                in clusters.indices {

                let currentAmounts =
                    clusters[
                        index
                    ]
                    .map {
                        double(
                            $0.transaction
                                .record
                                .amount
                        )
                    }
                    .sorted()


                let clusterMedian =
                    median(
                        currentAmounts
                    )

                let amount =
                    double(
                        candidate
                            .transaction
                            .record
                            .amount
                    )


                let tolerance =
                    max(
                        1.00,
                        clusterMedian
                        *
                        0.15
                    )


                if abs(
                    amount
                    -
                    clusterMedian
                )
                <=
                tolerance {

                    clusters[
                        index
                    ]
                    .append(
                        candidate
                    )

                    inserted =
                        true

                    break
                }
            }


            if !inserted {

                clusters.append(
                    [
                        candidate
                    ]
                )
            }
        }


        return clusters
    }


    private static func cadenceFor(
        days:
            Double
    ) -> RecurringPaymentPattern
        .Cadence {

        switch days {

        case 5...9:
            return .weekly

        case 11...17:
            return .biweekly

        case 25...35:
            return .monthly

        case 75...100:
            return .quarterly

        case 330...400:
            return .yearly

        default:
            return .repeating
        }
    }


    private static func monthlyEstimate(
        typical:
            Decimal,
        cadence:
            RecurringPaymentPattern
                .Cadence
    ) -> Decimal? {

        switch cadence {

        case .weekly:

            return
                typical
                *
                Decimal(
                    52.0
                    /
                    12.0
                )

        case .biweekly:

            return
                typical
                *
                Decimal(
                    26.0
                    /
                    12.0
                )

        case .monthly:

            return typical

        case .quarterly:

            return
                typical
                /
                3

        case .yearly:

            return
                typical
                /
                12

        case .repeating:

            return nil
        }
    }


    // Merchant Totals

    private struct TotalAccumulator {

        var label:
            String

        var amount:
            Decimal

        var count:
            Int
    }


    private static func makeMerchantTotals(
        transactions:
            [CrossDocumentTransaction]
    ) -> [CrossDocumentMerchantTotal] {

        var totals:
            [String:
                TotalAccumulator] = [:]


        for transaction
            in transactions {

            let record =
                transaction
                    .record


            guard
                record.flow
                ==
                .outflow,
                record.amount
                >
                0
            else {
                continue
            }


            let merchant =
                merchantLabel(
                    record
                )

            let normalized =
                merchantKey(
                    merchant
                )


            guard
                !normalized.isEmpty
            else {
                continue
            }


            let key =
                "\(normalized)|\(record.currency)"


            var current =
                totals[
                    key
                ]
                ??
                TotalAccumulator(
                    label:
                        merchant,
                    amount:
                        0,
                    count:
                        0
                )


            current.amount +=
                record.amount

            current.count +=
                1


            totals[
                key
            ] =
                current
        }


        return
            totals.map {
                key,
                value in

                let currency =
                    key
                        .split(
                            separator:
                                "|"
                        )
                        .last
                        .map(
                            String.init
                        )
                    ??
                    "USD"


                return
                    CrossDocumentMerchantTotal(
                        id:
                            key,
                        merchant:
                            value.label,
                        currency:
                            currency,
                        amount:
                            value.amount,
                        count:
                            value.count
                    )
            }
            .sorted {
                $0.amount
                >
                $1.amount
            }
    }


    // Category Totals

    private static func makeCategoryTotals(
        transactions:
            [CrossDocumentTransaction]
    ) -> [CrossDocumentCategoryTotal] {

        var totals:
            [String:
                TotalAccumulator] = [:]


        for transaction
            in transactions {

            let record =
                transaction
                    .record


            guard
                record.flow
                ==
                .outflow,
                record.amount
                >
                0
            else {
                continue
            }


            let rawCategory =
                record
                    .category?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            let category =
                (
                    rawCategory?
                        .isEmpty
                    ==
                    false
                )
                ? rawCategory!
                : "Uncategorized"


            let key =
                "\(category.lowercased())|\(record.currency)"


            var current =
                totals[
                    key
                ]
                ??
                TotalAccumulator(
                    label:
                        category,
                    amount:
                        0,
                    count:
                        0
                )


            current.amount +=
                record.amount

            current.count +=
                1


            totals[
                key
            ] =
                current
        }


        return
            totals.map {
                key,
                value in

                let currency =
                    key
                        .split(
                            separator:
                                "|"
                        )
                        .last
                        .map(
                            String.init
                        )
                    ??
                    "USD"


                return
                    CrossDocumentCategoryTotal(
                        id:
                            key,
                        category:
                            value.label,
                        currency:
                            currency,
                        amount:
                            value.amount,
                        count:
                            value.count
                    )
            }
            .sorted {
                $0.amount
                >
                $1.amount
            }
    }


    // Merchant Normalization

    static func merchantLabel(
        _ record:
            TransactionRecord
    ) -> String {

        if let vendor =
            record
                .vendor?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
           !vendor.isEmpty {

            return vendor
        }


        let description =
            record
                .description
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        return
            description.isEmpty
            ? "Unknown merchant"
            : description
    }


    static func merchantKey(
        _ value:
            String
    ) -> String {

        var text =
            value
                .lowercased()


        text =
            text.replacingOccurrences(
                of:
                    #"\b(?:payment|purchase|debit|credit|card|pos|online|recurring|subscription|bill)\b"#,
                with:
                    " ",
                options:
                    .regularExpression
            )


        text =
            text.replacingOccurrences(
                of:
                    #"\b\d{4,}\b"#,
                with:
                    " ",
                options:
                    .regularExpression
            )


        text =
            text.replacingOccurrences(
                of:
                    #"[^a-z0-9]+"#,
                with:
                    " ",
                options:
                    .regularExpression
            )


        text =
            text.replacingOccurrences(
                of:
                    #"\s+"#,
                with:
                    " ",
                options:
                    .regularExpression
            )


        return
            text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
    }


    // Math / Formatting

    static func formatMoney(
        _ value:
            Decimal,
        currency:
            String
    ) -> String {

        let formatter =
            NumberFormatter()

        formatter.numberStyle =
            .currency

        formatter.currencyCode =
            currency

        formatter.minimumFractionDigits =
            2

        formatter.maximumFractionDigits =
            2


        return
            formatter.string(
                from:
                    NSDecimalNumber(
                        decimal:
                            value
                    )
            )
            ??
            "\(currency) \(value)"
    }


    static func double(
        _ value:
            Decimal
    ) -> Double {

        NSDecimalNumber(
            decimal:
                value
        )
        .doubleValue
    }


    static func median(
        _ sorted:
            [Double]
    ) -> Double {

        guard
            !sorted.isEmpty
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
}
