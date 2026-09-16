import Foundation
import Supabase


struct DocumentFolder:
    Decodable,
    Identifiable,
    Equatable,
    Sendable {

    let id:
        UUID

    let name:
        String

    let iconName:
        String

    let createdAt:
        Date


    enum CodingKeys:
        String,
        CodingKey {

        case id
        case name

        case iconName =
            "icon_name"

        case createdAt =
            "created_at"
    }
}


enum DocumentFolderError:
    LocalizedError {

    case invalidName

    var errorDescription:
        String? {

        switch self {

        case .invalidName:

            return
                "Enter a folder name."
        }
    }
}


actor DocumentFolderService {

    static let shared =
        DocumentFolderService()

    private init() {}


    // Fetch

    func fetchFolders()
        async throws
        -> [DocumentFolder] {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()


        let folders:
            [DocumentFolder] =
            try await client
                .from(
                    "document_folders"
                )
                .select(
                    """
                    id,
                    name,
                    icon_name,
                    created_at
                    """
                )
                .order(
                    "name",
                    ascending:
                        true
                )
                .execute()
                .value


        return folders
    }


    // Create

    func createFolder(
        name:
            String,
        iconName:
            String
    ) async throws {

        let cleanName =
            name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !cleanName.isEmpty
        else {

            throw
                DocumentFolderError
                    .invalidName
        }


        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()


        try await client
            .from(
                "document_folders"
            )
            .insert(
                FolderInsert(
                    name:
                        cleanName,
                    iconName:
                        iconName
                )
            )
            .execute()
    }


    // Rename / Icon

    func updateFolder(
        id:
            UUID,
        name:
            String,
        iconName:
            String
    ) async throws {

        let cleanName =
            name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !cleanName.isEmpty
        else {

            throw
                DocumentFolderError
                    .invalidName
        }


        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()


        try await client
            .from(
                "document_folders"
            )
            .update(
                FolderUpdate(
                    name:
                        cleanName,
                    iconName:
                        iconName
                )
            )
            .eq(
                "id",
                value:
                    id.uuidString
            )
            .execute()
    }


    // Delete

    func deleteFolder(
        id:
            UUID
    ) async throws {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()


        // folder_id uses ON DELETE SET NULL, so documents are
        // preserved when their organizational folder is deleted.
        try await client
            .from(
                "document_folders"
            )
            .delete()
            .eq(
                "id",
                value:
                    id.uuidString
            )
            .execute()
    }


    // MARK: - Suggested Starter Folders

    func createSuggestedFolders()
        async throws {

        let existing =
            try await
                fetchFolders()


        let existingNames =
            Set(
                existing.map {
                    $0.name
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .lowercased()
                }
            )


        let suggestions =
            [
                (
                    "Bank",
                    "building.columns.fill"
                ),
                (
                    "Utilities",
                    "bolt.fill"
                ),
                (
                    "Medical",
                    "cross.case.fill"
                ),
                (
                    "Taxes",
                    "doc.text.fill"
                ),
                (
                    "Credit Cards",
                    "creditcard.fill"
                )
            ]


        for (
            name,
            icon
        ) in suggestions
        where
            !existingNames
                .contains(
                    name.lowercased()
                ) {

            try await
                createFolder(
                    name:
                        name,
                    iconName:
                        icon
                )
        }
    }
}


// Payloads

private struct FolderInsert:
    Encodable {

    let name:
        String

    let iconName:
        String


    enum CodingKeys:
        String,
        CodingKey {

        case name

        case iconName =
            "icon_name"
    }
}


private struct FolderUpdate:
    Encodable {

    let name:
        String

    let iconName:
        String


    enum CodingKeys:
        String,
        CodingKey {

        case name

        case iconName =
            "icon_name"
    }
}
