import Foundation

struct RestoredDocumentContext {

    let financialDocument:
        FinancialDocument

    let summary:
        HistoryDocumentSummary?

    let conversations:
        [DocumentConversation]
}


@MainActor
final class DocumentContinuityService {

    static let shared =
        DocumentContinuityService()

    private init() {}


    func load(
        document:
            HistoryDocument
    ) async throws
        -> RestoredDocumentContext {

        async let payloadTask =
            DocumentHistoryService
                .shared
                .fetchPayloadData(
                    id:
                        document.id
                )

        async let summaryTask =
            try? await
                DocumentHistoryService
                    .shared
                    .fetchSummary(
                        id:
                            document.id,
                        classification:
                            document
                                .documentType
                    )

        async let conversationTask =
            ConversationService
                .shared
                .fetch(
                    documentID:
                        document.id
                )

        let payloadData =
            try await payloadTask

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

        let financialDocument =
            try VeryfiService
                .restoreFinancialDocument(
                    payload:
                        payload,
                    classification:
                        document
                            .documentType
                )

        let summary =
            await summaryTask

        let conversations =
            try await
                conversationTask

        return
            RestoredDocumentContext(
                financialDocument:
                    financialDocument,
                summary:
                    summary,
                conversations:
                    conversations
            )
    }
}
