// Builds a deterministic Home attention feed.
//
// Fast metadata checks:
// - all saved documents
// - due dates
// - recent documents
//
// Deeper payload checks:
// - bounded to the most relevant/recent documents
// - cached for the lifetime of the app process
// - no new Veryfi request needed
// - no new OpenAI request needed

import Foundation


actor HomeFinancialAttentionService {

    static let shared =
        HomeFinancialAttentionService()


    private let maximumDeepAnalysisDocuments =
        10

    private let maximumFeedItems =
        7

    private var intelligenceCache:
        [UUID: DocumentIntelligence] = [:]


    private init() {}


    func load(
        documents:
            [HistoryDocument]
    ) async
        -> HomeFinancialAttentionFeed {

        guard
            !documents
                .isEmpty
        else {

            return
                HomeFinancialAttentionFeed(
                    items: [],
                    urgentCount: 0,
                    reviewCount: 0,
                    informationCount: 0,
                    deepAnalyzedDocumentCount: 0,
                    totalDocumentCount: 0,
                    failedDeepAnalysisCount: 0
                )
        }


        let deepCandidates =
            selectDeepAnalysisCandidates(
                documents
            )


        var intelligenceByDocumentID:
            [UUID: DocumentIntelligence] = [:]

        var missing:
            [HistoryDocument] = []


        for document
            in deepCandidates {

            if let cached =
                intelligenceCache[
                    document.id
                ] {

                intelligenceByDocumentID[
                    document.id
                ] =
                    cached

            } else {

                missing.append(
                    document
                )
            }
        }


        var failedCount =
            0


        if !missing
            .isEmpty {

            await withTaskGroup(
                of:
                    (
                        UUID,
                        DocumentIntelligence?
                    )
                .self
            ) {
                group in

                for document
                    in missing {

                    group.addTask {

                        do {

                            let intelligence =
                                try await
                                    Self
                                        .loadIntelligence(
                                            document:
                                                document
                                        )

                            return (
                                document.id,
                                intelligence
                            )

                        } catch {

                            return (
                                document.id,
                                nil
                            )
                        }
                    }
                }


                for await (
                    id,
                    intelligence
                ) in group {

                    if let intelligence {

                        intelligenceByDocumentID[
                            id
                        ] =
                            intelligence

                        intelligenceCache[
                            id
                        ] =
                            intelligence

                    } else {

                        failedCount +=
                            1
                    }
                }
            }
        }


        let items =
            buildFeedItems(
                documents:
                    documents,
                intelligenceByDocumentID:
                    intelligenceByDocumentID
            )


        let urgentCount =
            items
                .filter {
                    $0.priority
                    ==
                    .urgent
                }
                .count

        let reviewCount =
            items
                .filter {
                    $0.priority
                    ==
                    .review
                }
                .count

        let informationCount =
            items
                .filter {
                    $0.priority
                    ==
                    .information
                }
                .count


        return
            HomeFinancialAttentionFeed(
                items:
                    items,
                urgentCount:
                    urgentCount,
                reviewCount:
                    reviewCount,
                informationCount:
                    informationCount,
                deepAnalyzedDocumentCount:
                    intelligenceByDocumentID
                        .count,
                totalDocumentCount:
                    documents
                        .count,
                failedDeepAnalysisCount:
                    failedCount
            )
    }


    // Candidate Selection
    
    
    private func selectDeepAnalysisCandidates(
        _ documents:
            [HistoryDocument]
    ) -> [HistoryDocument] {

        let calendar =
            Calendar.current

        let today =
            calendar
                .startOfDay(
                    for:
                        Date()
                )


        let dueSoon =
            documents
                .filter {
                    document in

                    guard
                        let dueDate =
                            document
                                .dueDate
                    else {
                        return false
                    }


                    let days =
                        calendar
                            .dateComponents(
                                [
                                    .day
                                ],
                                from:
                                    today,
                                to:
                                    calendar
                                        .startOfDay(
                                            for:
                                                dueDate
                                        )
                            )
                            .day
                    ??
                    999


                    return
                        days >= 0
                        &&
                        days <= 30
                }
                .sorted {
                    ($0.dueDate ?? .distantFuture)
                    <
                    ($1.dueDate ?? .distantFuture)
                }


        let favorites =
            documents
                .filter {
                    $0.isFavorite
                }
                .sorted {
                    $0.createdAt
                    >
                    $1.createdAt
                }


        let newest =
            documents
                .sorted {
                    $0.createdAt
                    >
                    $1.createdAt
                }


        var seen:
            Set<UUID> = []

        var result:
            [HistoryDocument] = []


        for document
            in dueSoon
            +
            favorites
            +
            newest {

            guard
                !seen
                    .contains(
                        document.id
                    )
            else {
                continue
            }


            seen.insert(
                document.id
            )

            result.append(
                document
            )


            if result.count
                >=
                maximumDeepAnalysisDocuments {

                break
            }
        }


        return result
    }


    // Intelligence Restore

    private static func loadIntelligence(
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


    // Feed Construction

    private func buildFeedItems(
        documents:
            [HistoryDocument],
        intelligenceByDocumentID:
            [UUID: DocumentIntelligence]
    ) -> [HomeFinancialAttentionItem] {

        var items:
            [HomeFinancialAttentionItem] = []


        appendDueItems(
            documents:
                documents,
            into:
                &items
        )


        for document
            in documents {

            guard
                let intelligence =
                    intelligenceByDocumentID[
                        document.id
                    ]
            else {
                continue
            }


            appendRepeatedChargeItem(
                document:
                    document,
                intelligence:
                    intelligence,
                into:
                    &items
            )


            appendUnusualChargeItem(
                document:
                    document,
                intelligence:
                    intelligence,
                into:
                    &items
            )


            appendMajorBalanceMovementItem(
                document:
                    document,
                intelligence:
                    intelligence,
                into:
                    &items
            )
        }


        appendRecentDocumentItems(
            documents:
                documents,
            existingItems:
                items,
            into:
                &items
        )


        items.sort {
            lhs,
            rhs in

            if lhs.priority
                !=
                rhs.priority {

                return
                    lhs.priority.rawValue
                    <
                    rhs.priority.rawValue
            }


            switch (
                lhs.kind,
                rhs.kind
            ) {

            case (
                .billDue,
                .billDue
            ):

                let left =
                    lhs
                        .document
                        .dueDate
                    ??
                    .distantFuture

                let right =
                    rhs
                        .document
                        .dueDate
                    ??
                    .distantFuture

                return
                    left
                    <
                    right


            default:

                return
                    lhs.createdAt
                    >
                    rhs.createdAt
            }
        }


        return
            Array(
                items
                    .prefix(
                        maximumFeedItems
                    )
            )
    }


    // Due Dates

    private func appendDueItems(
        documents:
            [HistoryDocument],
        into items:
            inout [HomeFinancialAttentionItem]
    ) {

        let calendar =
            Calendar.current

        let today =
            calendar
                .startOfDay(
                    for:
                        Date()
                )


        for document
            in documents {

            guard
                let dueDate =
                    document
                        .dueDate
            else {
                continue
            }


            let dueDay =
                calendar
                    .startOfDay(
                        for:
                            dueDate
                    )


            let days =
                calendar
                    .dateComponents(
                        [
                            .day
                        ],
                        from:
                            today,
                        to:
                            dueDay
                    )
                    .day
            ??
            999


            guard
                days >= 0,
                days <= 7
            else {
                continue
            }


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


            let reminderText =
                document
                    .reminderEnabled
                ? "Reminder on"
                : "No reminder set"


            items.append(
                HomeFinancialAttentionItem(
                    id:
                        "due-\(document.id.uuidString)",
                    kind:
                        .billDue,
                    priority:
                        days <= 2
                        ? .urgent
                        : .review,
                    document:
                        document,
                    title:
                        title,
                    detail:
                        "\(document.resolvedDisplayName) • \(dueDate.formatted(date: .abbreviated, time: .omitted)) • \(reminderText)",
                    createdAt:
                        dueDate
                )
            )
        }
    }


    // Possible Repeated Charges

    private func appendRepeatedChargeItem(
        document:
            HistoryDocument,
        intelligence:
            DocumentIntelligence,
        into items:
            inout [HomeFinancialAttentionItem]
    ) {

        let candidates =
            intelligence
                .duplicateCandidates


        guard
            let first =
                candidates
                    .first
        else {
            return
        }


        let title =
            candidates.count
            ==
            1
            ? "Possible repeated charge"
            : "\(candidates.count) possible repeated charges"


        let amount =
            CrossDocumentAnalysisEngine
                .formatMoney(
                    first.amount,
                    currency:
                        first.currency
                )


        let detail =
            candidates.count
            ==
            1
            ? "\(document.resolvedDisplayName) • \(first.merchant) • \(amount) • \(first.daysApart) day\(first.daysApart == 1 ? "" : "s") apart"
            : "\(document.resolvedDisplayName) • First signal: \(first.merchant) • \(amount)"


        items.append(
            HomeFinancialAttentionItem(
                id:
                    "duplicate-\(document.id.uuidString)",
                kind:
                    .repeatedCharge,
                priority:
                    .review,
                document:
                    document,
                title:
                    title,
                detail:
                    detail,
                createdAt:
                    document
                        .createdAt
            )
        )
    }


    // Large / Unusual Charge Signals

    private func appendUnusualChargeItem(
        document:
            HistoryDocument,
        intelligence:
            DocumentIntelligence,
        into items:
            inout [HomeFinancialAttentionItem]
    ) {

        let signals =
            intelligence
                .unusualChargeSignals


        guard
            let first =
                signals
                    .first
        else {
            return
        }


        let amount =
            CrossDocumentAnalysisEngine
                .formatMoney(
                    first
                        .charge
                        .amount,
                    currency:
                        first
                            .charge
                            .currency
                )


        let multiple =
            String(
                format:
                    "%.1f×",
                first
                    .multipleOfTypical
            )


        let title =
            signals.count
            ==
            1
            ? "Large charge stands out"
            : "\(signals.count) large charges stand out"


        items.append(
            HomeFinancialAttentionItem(
                id:
                    "unusual-\(document.id.uuidString)",
                kind:
                    .unusualCharge,
                priority:
                    .review,
                document:
                    document,
                title:
                    title,
                detail:
                    "\(document.resolvedDisplayName) • \(first.charge.merchant) • \(amount) • \(multiple) typical",
                createdAt:
                    document
                        .createdAt
            )
        )
    }


    // Major Balance Movement

    private func appendMajorBalanceMovementItem(
        document:
            HistoryDocument,
        intelligence:
            DocumentIntelligence,
        into items:
            inout [HomeFinancialAttentionItem]
    ) {

        guard
            let movement =
                intelligence
                    .balanceMovement
        else {
            return
        }


        let beginning =
            abs(
                NSDecimalNumber(
                    decimal:
                        movement
                            .beginning
                )
                .doubleValue
            )


        let delta =
            abs(
                NSDecimalNumber(
                    decimal:
                        movement
                            .delta
                )
                .doubleValue
            )


        guard
            beginning
            >
            0
        else {
            return
        }


        let percent =
            delta
            /
            beginning


        // "Major" is intentionally relative so the rule remains
        // currency-safe without silently converting currencies.
        guard
            percent
            >=
            0.25
        else {
            return
        }


        let amount =
            CrossDocumentAnalysisEngine
                .formatMoney(
                    absoluteDecimal(
                        movement
                            .delta
                    ),
                    currency:
                        movement
                            .currency
                )


        let percentText =
            String(
                format:
                    "%.0f%%",
                percent
                *
                100
            )


        items.append(
            HomeFinancialAttentionItem(
                id:
                    "balance-\(document.id.uuidString)",
                kind:
                    .balanceMovement,
                priority:
                    .information,
                document:
                    document,
                title:
                    "\(movement.directionText) \(percentText)",
                detail:
                    "\(document.resolvedDisplayName) • Net movement \(amount)",
                createdAt:
                    document
                        .createdAt
            )
        )
    }


    // Recent Documents

    private func appendRecentDocumentItems(
        documents:
            [HistoryDocument],
        existingItems:
            [HomeFinancialAttentionItem],
        into items:
            inout [HomeFinancialAttentionItem]
    ) {

        let alreadyRepresented =
            Set(
                existingItems
                    .map {
                        $0.document.id
                    }
            )


        let cutoff =
            Calendar.current
                .date(
                    byAdding:
                        .day,
                    value:
                        -7,
                    to:
                        Date()
                )
            ??
            .distantPast


        let recent =
            documents
                .filter {
                    document in

                    document.createdAt
                    >=
                    cutoff
                    &&
                    !alreadyRepresented
                        .contains(
                            document.id
                        )
                }
                .sorted {
                    $0.createdAt
                    >
                    $1.createdAt
                }
                .prefix(
                    2
                )


        for document
            in recent {

            items.append(
                HomeFinancialAttentionItem(
                    id:
                        "recent-\(document.id.uuidString)",
                    kind:
                        .recentDocument,
                    priority:
                        .information,
                    document:
                        document,
                    title:
                        "New document ready to review",
                    detail:
                        "\(document.resolvedDisplayName) • \(document.prettyDocumentType)",
                    createdAt:
                        document
                            .createdAt
                )
            )
        }
    }


    // Helpers

    private func absoluteDecimal(
        _ value:
            Decimal
    ) -> Decimal {

        value
        <
        0
        ? -value
        : value
    }
}
