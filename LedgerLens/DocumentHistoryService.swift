import Foundation
import Supabase

struct HistoryDocument:
    Decodable,
    Identifiable,
    Equatable,
    Sendable {

    let id: UUID
    let fileName: String
    let sourceType: String
    let documentType: String
    let createdAt: Date

    var displayName: String?

    let storagePath: String?
    let originalMimeType: String?
    let originalSizeBytes: Int64?

    let folderID: UUID?
    let isFavorite: Bool

    let dueDateRaw: String?
    let reminderEnabled: Bool
    let reminderDaysBefore: Int
    let reminderHour: Int

    enum CodingKeys:
        String,
        CodingKey {

        case id

        case fileName =
            "file_name"

        case sourceType =
            "source_type"

        case documentType =
            "document_type"

        case createdAt =
            "created_at"

        case displayName =
            "display_name"

        case storagePath =
            "storage_path"

        case originalMimeType =
            "original_mime_type"

        case originalSizeBytes =
            "original_size_bytes"

        case folderID =
            "folder_id"

        case isFavorite =
            "is_favorite"

        case dueDateRaw =
            "due_date"

        case reminderEnabled =
            "reminder_enabled"

        case reminderDaysBefore =
            "reminder_days_before"

        case reminderHour =
            "reminder_hour"
    }

    var dueDate:
        Date? {

        guard
            let raw =
                dueDateRaw?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !raw.isEmpty
        else {
            return nil
        }


        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        formatter.timeZone =
            TimeZone.current

        formatter.dateFormat =
            "yyyy-MM-dd"

        formatter.isLenient =
            false


        return
            formatter.date(
                from:
                    raw
            )
    }

    var prettyDocumentType:
        String {

        documentType
            .replacingOccurrences(
                of: "_",
                with: " "
            )
            .capitalized
    }

    var fallbackDisplayName:
        String {

        if sourceType == "scan" {

            return
                "Scanned \(prettyDocumentType)"
        }

        let name =
            (
                fileName
                as NSString
            )
            .deletingPathExtension

        return name.isEmpty
            ? prettyDocumentType
            : name
    }

    var resolvedDisplayName:
        String {

        let custom =
            displayName?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if let custom,
           !custom.isEmpty {

            return custom
        }

        return fallbackDisplayName
    }

    var hasStoredOriginal:
        Bool {

        guard
            let storagePath
        else {
            return false
        }

        return !storagePath.isEmpty
    }
}


struct HistorySummaryItem:
    Identifiable,
    Sendable,
    Equatable {

    let id:
        String

    let label:
        String

    let value:
        String

    let systemImage:
        String
}


struct HistoryDocumentSummary:
    Sendable,
    Equatable {

    let headline:
        String

    let subheadline:
        String?

    let items:
        [HistorySummaryItem]
}


enum DocumentHistoryError:
    LocalizedError {

    case malformedSavedDocument
    case missingStoredOriginal
    case invalidRename
    case invalidReminderPreference

    var errorDescription:
        String? {

        switch self {

        case .malformedSavedDocument:
            return "The saved document data is incomplete or could not be read."

        case .missingStoredOriginal:
            return "The original file is not stored for this history item."

        case .invalidRename:
            return "Enter a name for this document."

        case .invalidReminderPreference:
            return "Choose a supported bill-reminder time."
        }
    }
}


actor DocumentHistoryService {

    static let shared =
        DocumentHistoryService()

    static let bucketName =
        "financial-documents"

    private init() {}


    // History List

    func fetchDocuments()
        async throws
        -> [HistoryDocument] {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        let documents:
            [HistoryDocument] =
            try await client
                .from(
                    "financial_documents"
                )
                .select(
                    """
                    id,
                    file_name,
                    source_type,
                    document_type,
                    created_at,
                    display_name,
                    storage_path,
                    original_mime_type,
                    original_size_bytes,
                    folder_id,
                    is_favorite,
                    due_date,
                    reminder_enabled,
                    reminder_days_before,
                    reminder_hour
                    """
                )
                .order(
                    "created_at",
                    ascending: false
                )
                .execute()
                .value

        return documents
    }


    func fetchDocument(
        id:
            UUID
    ) async throws
        -> HistoryDocument {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        let document:
            HistoryDocument =
            try await client
                .from(
                    "financial_documents"
                )
                .select(
                    """
                    id,
                    file_name,
                    source_type,
                    document_type,
                    created_at,
                    display_name,
                    storage_path,
                    original_mime_type,
                    original_size_bytes,
                    folder_id,
                    is_favorite,
                    due_date,
                    reminder_enabled,
                    reminder_days_before,
                    reminder_hour
                    """
                )
                .eq(
                    "id",
                    value:
                        id.uuidString
                )
                .limit(1)
                .single()
                .execute()
                .value

        return document
    }


    // Saved Veryfi Payload

    func fetchPayloadData(
        id: UUID
    ) async throws -> Data {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        let response =
            try await client
                .from(
                    "financial_documents"
                )
                .select(
                    "veryfi_payload"
                )
                .eq(
                    "id",
                    value:
                        id.uuidString
                )
                .limit(1)
                .single()
                .execute()

        return response.data
    }


    // Deterministic Detail Summary

    func fetchSummary(
        id: UUID,
        classification: String
    ) async throws
        -> HistoryDocumentSummary {

        let data =
            try await
                fetchPayloadData(
                    id: id
                )

        let rootObject =
            try JSONSerialization
                .jsonObject(
                    with: data
                )

        guard
            let root =
                rootObject
                    as? [String: Any],

            let payload =
                root[
                    "veryfi_payload"
                ]
                    as? [String: Any]
        else {

            throw DocumentHistoryError
                .malformedSavedDocument
        }

        return makeSummary(
            payload:
                payload,
            classification:
                classification
        )
    }


    // Rename

    func renameDocument(
        id: UUID,
        displayName: String
    ) async throws {

        let cleanName =
            displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanName.isEmpty
        else {

            throw DocumentHistoryError
                .invalidRename
        }

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        try await client
            .from(
                "financial_documents"
            )
            .update(
                [
                    "display_name":
                        cleanName
                ]
            )
            .eq(
                "id",
                value:
                    id.uuidString
            )
            .execute()
    }


    // Organization

    func setFavorite(
        id:
            UUID,
        isFavorite:
            Bool
    ) async throws {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        try await client
            .from(
                "financial_documents"
            )
            .update(
                FavoriteUpdate(
                    isFavorite:
                        isFavorite
                )
            )
            .eq(
                "id",
                value:
                    id.uuidString
            )
            .execute()
    }


    func setFolder(
        id:
            UUID,
        folderID:
            UUID?
    ) async throws {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        try await client
            .from(
                "financial_documents"
            )
            .update(
                FolderAssignmentUpdate(
                    folderID:
                        folderID
                )
            )
            .eq(
                "id",
                value:
                    id.uuidString
            )
            .execute()
    }


    func updateOrganization(
        id:
            UUID,
        isFavorite:
            Bool,
        folderID:
            UUID?
    ) async throws {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        try await client
            .from(
                "financial_documents"
            )
            .update(
                OrganizationUpdate(
                    isFavorite:
                        isFavorite,
                    folderID:
                        folderID
                )
            )
            .eq(
                "id",
                value:
                    id.uuidString
            )
            .execute()
    }


    // Bill Reminder Preferences

    func updateReminderPreference(
        id:
            UUID,
        enabled:
            Bool,
        daysBefore:
            Int,
        hour:
            Int
    ) async throws {

        let allowedDays =
            [
                0,
                1,
                3,
                7
            ]


        guard
            allowedDays.contains(
                daysBefore
            ),
            (0...23).contains(
                hour
            )
        else {

            throw
                DocumentHistoryError
                    .invalidReminderPreference
        }


        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()


        try await client
            .from(
                "financial_documents"
            )
            .update(
                ReminderPreferenceUpdate(
                    enabled:
                        enabled,
                    daysBefore:
                        daysBefore,
                    hour:
                        hour
                )
            )
            .eq(
                "id",
                value:
                    id
                        .uuidString
            )
            .execute()
    }


    // Download Original

    func downloadOriginal(
        path: String
    ) async throws -> Data {

        guard
            !path.isEmpty
        else {

            throw DocumentHistoryError
                .missingStoredOriginal
        }

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        return try await client
            .storage
            .from(
                Self.bucketName
            )
            .download(
                path: path
            )
    }


    // Delete

    func deleteDocument(
        _ document:
            HistoryDocument
    ) async throws {

        let client =
            try await
                SupabaseAuthManager
                    .shared
                    .databaseClient()

        if let path =
            document.storagePath,
           !path.isEmpty {

            _ =
                try await client
                    .storage
                    .from(
                        Self.bucketName
                    )
                    .remove(
                        paths: [path]
                    )
        }

        try await client
            .from(
                "financial_documents"
            )
            .delete()
            .eq(
                "id",
                value:
                    document.id
                        .uuidString
            )
            .execute()
    }


    // MARK: - Summary Builder

    private func makeSummary(
        payload:
            [String: Any],
        classification:
            String
    ) -> HistoryDocumentSummary {

        let type =
            classification
                .lowercased()

        if type.contains(
            "bank"
        )
        || type.contains(
            "statement"
        ) {

            return makeBankStatementSummary(
                payload
            )
        }

        return makeBillSummary(
            payload
        )
    }


    private func makeBankStatementSummary(
        _ payload:
            [String: Any]
    ) -> HistoryDocumentSummary {

        let accounts =
            payload["accounts"]
                as?
                [[String: Any]]
            ?? []

        var transactionCount =
            0

        var allDates:
            [Date] = []

        for account
            in accounts {

            let transactions =
                account["transactions"]
                    as?
                    [[String: Any]]
                ?? []

            transactionCount +=
                transactions.count

            for transaction
                in transactions {

                if let date =
                    parseDate(
                        string(
                            transaction[
                                "date"
                            ]
                        )
                    ) {

                    allDates.append(
                        date
                    )
                }
            }
        }

        let firstAccount =
            accounts.first

        let currency =
            string(
                firstAccount?[
                    "currency"
                ]
            )
            ??
            string(
                firstAccount?[
                    "currency_code"
                ]
            )
            ??
            "USD"

        var items:
            [HistorySummaryItem] = []

        items.append(
            HistorySummaryItem(
                id: "transactions",
                label:
                    "Transactions",
                value:
                    "\(transactionCount)",
                systemImage:
                    "list.bullet.rectangle"
            )
        )

        if let beginning =
            decimal(
                firstAccount?[
                    "beginning_balance"
                ]
            ) {

            items.append(
                HistorySummaryItem(
                    id:
                        "beginning_balance",
                    label:
                        "Beginning balance",
                    value:
                        formatMoney(
                            beginning,
                            currency:
                                currency
                        ),
                    systemImage:
                        "arrow.backward.circle"
                )
            )
        }

        if let ending =
            decimal(
                firstAccount?[
                    "ending_balance"
                ]
            ) {

            items.append(
                HistorySummaryItem(
                    id:
                        "ending_balance",
                    label:
                        "Ending balance",
                    value:
                        formatMoney(
                            ending,
                            currency:
                                currency
                        ),
                    systemImage:
                        "arrow.forward.circle"
                )
            )
        }

        if let earliest =
            allDates.min(),
           let latest =
            allDates.max() {

            let value:
                String

            if Calendar.current
                .isDate(
                    earliest,
                    inSameDayAs:
                        latest
                ) {

                value =
                    formatDate(
                        earliest
                    )

            } else {

                value =
                    "\(formatDate(earliest)) – \(formatDate(latest))"
            }

            items.append(
                HistorySummaryItem(
                    id:
                        "date_range",
                    label:
                        "Transaction range",
                    value:
                        value,
                    systemImage:
                        "calendar"
                )
            )
        }

        let accountCount =
            accounts.count

        let headline =
            accountCount > 1
            ? "\(accountCount) accounts"
            : "Statement overview"

        let subheadline =
            transactionCount == 1
            ? "1 financial transaction"
            : "\(transactionCount) financial transactions"

        return HistoryDocumentSummary(
            headline:
                headline,
            subheadline:
                subheadline,
            items:
                items
        )
    }


    private func makeBillSummary(
        _ payload:
            [String: Any]
    ) -> HistoryDocumentSummary {

        let vendorName:
            String? = {

                if let vendor =
                    payload["vendor"]
                        as?
                        [String: Any] {

                    return
                        string(
                            vendor["name"]
                        )
                        ??
                        string(
                            vendor[
                                "raw_name"
                            ]
                        )
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
            }()

        let currency =
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
            "USD"

        var items:
            [HistorySummaryItem] = []

        if let total =
            decimal(
                payload["total"]
            )
            ??
            decimal(
                payload["balance"]
            ) {

            items.append(
                HistorySummaryItem(
                    id: "total",
                    label:
                        "Total",
                    value:
                        formatMoney(
                            total,
                            currency:
                                currency
                        ),
                    systemImage:
                        "dollarsign.circle"
                )
            )
        }

        if let dueDate =
            parseDate(
                string(
                    payload[
                        "due_date"
                    ]
                )
            ) {

            items.append(
                HistorySummaryItem(
                    id:
                        "due_date",
                    label:
                        "Due date",
                    value:
                        formatDate(
                            dueDate
                        ),
                    systemImage:
                        "calendar.badge.clock"
                )
            )
        }

        if let documentDate =
            parseDate(
                string(
                    payload["date"]
                )
            ) {

            items.append(
                HistorySummaryItem(
                    id:
                        "document_date",
                    label:
                        "Document date",
                    value:
                        formatDate(
                            documentDate
                        ),
                    systemImage:
                        "calendar"
                )
            )
        }

        let lineItems =
            payload["line_items"]
                as?
                [[String: Any]]
            ?? []

        if !lineItems.isEmpty {

            items.append(
                HistorySummaryItem(
                    id:
                        "line_items",
                    label:
                        "Extracted charges",
                    value:
                        "\(lineItems.count)",
                    systemImage:
                        "list.bullet.rectangle"
                )
            )
        }

        return HistoryDocumentSummary(
            headline:
                vendorName
                ??
                "Document overview",
            subheadline:
                vendorName == nil
                ? nil
                : "Deterministic summary from saved document data",
            items:
                items
        )
    }


    // Summary Helpers

    private func string(
        _ value: Any?
    ) -> String? {

        if let value =
            value as? String {

            let trimmed =
                value
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            return trimmed.isEmpty
                ? nil
                : trimmed
        }

        if let number =
            value as? NSNumber {

            return
                number.stringValue
        }

        return nil
    }


    private func decimal(
        _ value: Any?
    ) -> Decimal? {

        if let value =
            value as? Decimal {

            return value
        }

        if let number =
            value as? NSNumber {

            return
                number.decimalValue
        }

        if let text =
            value as? String {

            let cleaned =
                text
                    .replacingOccurrences(
                        of: ",",
                        with: ""
                    )
                    .replacingOccurrences(
                        of: "$",
                        with: ""
                    )
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            return
                Decimal(
                    string:
                        cleaned
                )
        }

        return nil
    }


    private func parseDate(
        _ value: String?
    ) -> Date? {

        guard
            let value,
            !value.isEmpty
        else {
            return nil
        }

        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM/dd/yy",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        ]

        for format
            in formats {

            let formatter =
                DateFormatter()

            formatter.locale =
                Locale(
                    identifier:
                        "en_US_POSIX"
                )

            formatter.dateFormat =
                format

            if let date =
                formatter.date(
                    from: value
                ) {

                return date
            }
        }

        return nil
    }


    private func formatDate(
        _ date: Date
    ) -> String {

        date.formatted(
            date: .abbreviated,
            time: .omitted
        )
    }


    private func formatMoney(
        _ value: Decimal,
        currency: String
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
}




// Organization Update Payloads

private struct FavoriteUpdate:
    Encodable {

    let isFavorite:
        Bool

    enum CodingKeys:
        String,
        CodingKey {

        case isFavorite =
            "is_favorite"
    }
}


private struct FolderAssignmentUpdate:
    Encodable {

    let folderID:
        UUID?

    enum CodingKeys:
        String,
        CodingKey {

        case folderID =
            "folder_id"
    }
}


private struct OrganizationUpdate:
    Encodable {

    let isFavorite:
        Bool

    let folderID:
        UUID?

    enum CodingKeys:
        String,
        CodingKey {

        case isFavorite =
            "is_favorite"

        case folderID =
            "folder_id"
    }
}


// Reminder Update Payload

private struct ReminderPreferenceUpdate:
    Encodable {

    let enabled:
        Bool

    let daysBefore:
        Int

    let hour:
        Int


    enum CodingKeys:
        String,
        CodingKey {

        case enabled =
            "reminder_enabled"

        case daysBefore =
            "reminder_days_before"

        case hour =
            "reminder_hour"
    }
}
