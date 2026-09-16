import Foundation
import Supabase

struct DocumentConversation:
    Codable,
    Identifiable,
    Equatable,
    Sendable {

    let id: UUID
    let documentID: UUID
    let question: String
    let answer: String
    let retrievalMode: String
    let createdAt: Date

    enum CodingKeys:
        String,
        CodingKey {

        case id

        case documentID =
            "document_id"

        case question
        case answer

        case retrievalMode =
            "retrieval_mode"

        case createdAt =
            "created_at"
    }
}


private struct NewDocumentConversation:
    Encodable {

    let documentID: UUID
    let question: String
    let answer: String
    let retrievalMode: String

    enum CodingKeys:
        String,
        CodingKey {

        case documentID =
            "document_id"

        case question
        case answer

        case retrievalMode =
            "retrieval_mode"
    }
}


actor ConversationService {

    static let shared =
        ConversationService()

    private init() {}


    // One Document

    func fetch(
        documentID: UUID
    ) async throws
        -> [DocumentConversation] {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        let rows:
            [DocumentConversation] =
            try await client
                .from(
                    "document_conversations"
                )
                .select(
                    """
                    id,
                    document_id,
                    question,
                    answer,
                    retrieval_mode,
                    created_at
                    """
                )
                .eq(
                    "document_id",
                    value:
                        documentID
                            .uuidString
                )
                .order(
                    "created_at",
                    ascending:
                        true
                )
                .execute()
                .value

        return
            rows.map {
                sanitize(
                    $0
                )
            }
    }


    // Recent Across Account

    func fetchRecent(
        limit: Int = 8
    ) async throws
        -> [DocumentConversation] {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        let rows:
            [DocumentConversation] =
            try await client
                .from(
                    "document_conversations"
                )
                .select(
                    """
                    id,
                    document_id,
                    question,
                    answer,
                    retrieval_mode,
                    created_at
                    """
                )
                .order(
                    "created_at",
                    ascending:
                        false
                )
                .limit(
                    max(
                        1,
                        min(
                            limit,
                            30
                        )
                    )
                )
                .execute()
                .value

        return
            rows.map {
                sanitize(
                    $0
                )
            }
    }


    // Save

    func save(
        documentID: UUID,
        question: String,
        answer: String,
        retrievalMode: String
    ) async throws
        -> DocumentConversation {

        let cleanQuestion =
            PlainTextSanitizer
                .clean(
                    question
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanAnswer =
            PlainTextSanitizer
                .clean(
                    answer
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanQuestion.isEmpty,
            !cleanAnswer.isEmpty
        else {

            throw ConversationServiceError
                .emptyConversation
        }

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        let row:
            DocumentConversation =
            try await client
                .from(
                    "document_conversations"
                )
                .insert(
                    NewDocumentConversation(
                        documentID:
                            documentID,
                        question:
                            cleanQuestion,
                        answer:
                            cleanAnswer,
                        retrievalMode:
                            retrievalMode
                    )
                )
                .select(
                    """
                    id,
                    document_id,
                    question,
                    answer,
                    retrieval_mode,
                    created_at
                    """
                )
                .single()
                .execute()
                .value

        return
            sanitize(
                row
            )
    }


    // Sanitization

    private func sanitize(
        _ row:
            DocumentConversation
    ) -> DocumentConversation {

        DocumentConversation(
            id:
                row.id,
            documentID:
                row.documentID,
            question:
                PlainTextSanitizer
                    .clean(
                        row.question
                    ),
            answer:
                PlainTextSanitizer
                    .clean(
                        row.answer
                    ),
            retrievalMode:
                row.retrievalMode,
            createdAt:
                row.createdAt
        )
    }


    // Delete One

    func delete(
        id: UUID
    ) async throws {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        try await client
            .from(
                "document_conversations"
            )
            .delete()
            .eq(
                "id",
                value:
                    id.uuidString
            )
            .execute()
    }


    // Clear One Document Thread

    func clear(
        documentID: UUID
    ) async throws {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        try await client
            .from(
                "document_conversations"
            )
            .delete()
            .eq(
                "document_id",
                value:
                    documentID
                        .uuidString
            )
            .execute()
    }
}


enum ConversationServiceError:
    LocalizedError {

    case emptyConversation

    var errorDescription:
        String? {

        switch self {

        case .emptyConversation:

            return
                "The question and answer must not be empty."
        }
    }
}
