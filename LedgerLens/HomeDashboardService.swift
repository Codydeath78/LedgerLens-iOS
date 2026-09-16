import Foundation

struct HomeDashboardActivity:
    Identifiable,
    Sendable,
    Equatable {

    enum Kind:
        String,
        Sendable {

        case document
        case conversation
    }

    let id: String
    let kind: Kind
    let document: HistoryDocument
    let title: String
    let subtitle: String
    let createdAt: Date
}


struct HomeDashboardSnapshot:
    Sendable,
    Equatable {

    let documentCount: Int
    let originalCount: Int
    let recentDocuments:
        [HistoryDocument]

    // Internal Home source crated earlier. This keeps the
    // History fetch single-pass while the attention feed loads
    // asynchronously after the rest of Home is visible.
    let attentionSourceDocuments:
        [HistoryDocument]

    let upcomingBills:
        [HistoryDocument]

    let activeReminderCount:
        Int

    let activities:
        [HomeDashboardActivity]
    let usage:
        AppUsageStatus?

    let usageUnavailable:
        Bool
}


actor HomeDashboardService {

    static let shared =
        HomeDashboardService()

    private init() {}


    func load()
        async throws
        -> HomeDashboardSnapshot {

        async let documentsTask =
            DocumentHistoryService
                .shared
                .fetchDocuments()

        async let conversationsTask =
            ConversationService
                .shared
                .fetchRecent(
                    limit: 8
                )

        async let usageTask =
            loadUsageSafely()

        let documents =
            try await
                documentsTask

        let conversations =
            try await
                conversationsTask

        let usageResult =
            await usageTask

        let usage =
            usageResult.status


        let upcomingBills =
            makeUpcomingBills(
                documents
            )


        let activeReminderCount =
            documents
                .filter {
                    $0.reminderEnabled
                }
                .count


        await BillReminderService
            .shared
            .synchronizeIfAuthorized(
                documents:
                    documents
            )


        let byID =
            Dictionary(
                uniqueKeysWithValues:
                    documents.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )


        var activities:
            [HomeDashboardActivity] = []


        for document
            in documents
                .prefix(5) {

            let verb =
                document.sourceType
                == "scan"
                ? "Scanned"
                : "Uploaded"

            activities.append(
                HomeDashboardActivity(
                    id:
                        "document-\(document.id.uuidString)",
                    kind:
                        .document,
                    document:
                        document,
                    title:
                        "\(verb) \(document.resolvedDisplayName)",
                    subtitle:
                        document.prettyDocumentType,
                    createdAt:
                        document.createdAt
                )
            )
        }


        for conversation
            in conversations {

            guard
                let document =
                    byID[
                        conversation
                            .documentID
                    ]
            else {
                continue
            }

            activities.append(
                HomeDashboardActivity(
                    id:
                        "conversation-\(conversation.id.uuidString)",
                    kind:
                        .conversation,
                    document:
                        document,
                    title:
                        "Asked about \(document.resolvedDisplayName)",
                    subtitle:
                        conversation.question,
                    createdAt:
                        conversation.createdAt
                )
            )
        }


        activities.sort {
            $0.createdAt >
            $1.createdAt
        }


        return
            HomeDashboardSnapshot(
                documentCount:
                    documents.count,
                originalCount:
                    documents.filter {
                        $0.hasStoredOriginal
                    }
                    .count,
                recentDocuments:
                    Array(
                        documents
                            .prefix(4)
                    ),
                attentionSourceDocuments:
                    documents,
                upcomingBills:
                    upcomingBills,
                activeReminderCount:
                    activeReminderCount,
                activities:
                    Array(
                        activities
                            .prefix(6)
                    ),
                usage:
                    usage,
                usageUnavailable:
                    usageResult.unavailable
            )
    }


    private func makeUpcomingBills(
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


        return
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


                    return
                        days >= 0
                        &&
                        days <= 14
                }
                .sorted {
                    lhs,
                    rhs in

                    let left =
                        lhs
                            .dueDate
                    ??
                    .distantFuture

                    let right =
                        rhs
                            .dueDate
                    ??
                    .distantFuture


                    if left
                        ==
                        right {

                        return
                            lhs
                                .resolvedDisplayName
                                .localizedCaseInsensitiveCompare(
                                    rhs
                                        .resolvedDisplayName
                                )
                            ==
                            .orderedAscending
                    }


                    return
                        left
                        <
                        right
                }
                .prefix(
                    5
                )
                .map {
                    $0
                }
    }


    private func loadUsageSafely()
        async
        -> (
            status: AppUsageStatus?,
            unavailable: Bool
        ) {

        do {

            let status =
                try await
                    UsageStatusService
                        .shared
                        .fetch()

            return (
                status,
                false
            )

        } catch {

            // The rest of Home should remain useful even if
            // the optional usage inspector is temporarily
            // unavailable.
            return (
                nil,
                true
            )
        }
    }
}
