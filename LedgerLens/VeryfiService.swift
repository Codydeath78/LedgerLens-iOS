import Foundation

enum VeryfiError:
    LocalizedError {

    case invalidResponse
    case httpError(
        statusCode: Int,
        message: String
    )

    case malformedResponse
    case noFinancialData

    var errorDescription:
        String? {

        switch self {

        case .invalidResponse:

            return
                "The document service returned an invalid response."

        case .httpError(
            let status,
            let message
        ):

            return
                """
                Document processing failed \
                (HTTP \(status)): \(message)
                """

        case .malformedResponse:

            return
                "The document service returned unexpected data."

        case .noFinancialData:

            return
                "No usable financial records were found."
        }
    }
}



struct ProcessedFinancialDocumentResult {

    let document:
        FinancialDocument

    let historyDocumentID:
        UUID?

    let historySaved:
        Bool
}



struct VeryfiService {

    private let backend:
        BackendConfiguration

    init(
        backend:
            BackendConfiguration
    ) {

        self.backend =
            backend
    }
    
    
    
    // Restore Saved Document
    //
    // Rebuilds FinancialDocument from the Veryfi JSON that is
    // already stored in Supabase. No network request is made.

    static func restoreFinancialDocument(
        payload: [String: Any],
        classification: String
    ) throws -> FinancialDocument {

        let type =
            classification
                .lowercased()

        if type == "bank_statement" ||
           type == "statement" {

            return try
                VeryfiNormalizer
                    .normalizeBankStatement(
                        json: payload,
                        classification:
                            classification
                    )

        } else {

            return try
                VeryfiNormalizer
                    .normalizeBillOrInvoice(
                        json: payload,
                        classification:
                            classification
                    )
        }
    }
    
    func processFinancialDocument(
        data: Data,
        fileName: String
    ) async throws
        -> FinancialDocument {

        let result =
            try await
                processFinancialDocumentWithHistory(
                    data: data,
                    fileName: fileName
                )

        return
            result.document
    }


    func processFinancialDocumentWithHistory(
        data: Data,
        fileName: String
    ) async throws
        -> ProcessedFinancialDocumentResult {

        let url =
            backend.functionURL(
                "veryfi-process"
            )

        let boundary =
            "Boundary-\(UUID().uuidString)"

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod =
            "POST"

        request.timeoutInterval =
            150

        try await backend.authorize(
            &request
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField:
                "Content-Type"
        )

        request.httpBody =
            makeMultipartBody(
                boundary: boundary,
                data: data,
                fileName: fileName
            )

        let (
            responseData,
            response
        ) =
            try await
                URLSession.shared
                    .data(
                        for: request
                    )

        guard
            let httpResponse =
                response
                    as?
                    HTTPURLResponse
        else {

            throw
                VeryfiError
                    .invalidResponse
        }

        guard
            (200...299)
                .contains(
                    httpResponse
                        .statusCode
                )
        else {

            let message =
                String(
                    data:
                        responseData,
                    encoding:
                        .utf8
                )
                ??
                "Unknown error"

            throw
                VeryfiError
                    .httpError(
                        statusCode:
                            httpResponse
                                .statusCode,
                        message:
                            message
                    )
        }

        guard
            let root =
                try JSONSerialization
                    .jsonObject(
                        with:
                            responseData
                    )
                    as?
                    [String: Any],

            let classification =
                root[
                    "classification"
                ]
                    as?
                    String,

            let payload =
                root[
                    "payload"
                ]
                    as?
                    [String: Any]
        else {

            throw
                VeryfiError
                    .malformedResponse
        }


        let historyDocumentID:
            UUID? = {

            guard
                let rawID =
                    root[
                        "documentId"
                    ]
                        as?
                        String
            else {
                return nil
            }

            return
                UUID(
                    uuidString:
                        rawID
                )
        }()


        let historySaved =
            root[
                "historySaved"
            ]
                as?
                Bool
            ??
            (
                historyDocumentID
                != nil
            )


        let type =
            classification
                .lowercased()


        let document:
            FinancialDocument


        if type
            == "bank_statement"
            ||
            type
                == "statement" {

            document =
                try VeryfiNormalizer
                    .normalizeBankStatement(
                        json:
                            payload,
                        classification:
                            classification
                    )

        } else {

            document =
                try VeryfiNormalizer
                    .normalizeBillOrInvoice(
                        json:
                            payload,
                        classification:
                            classification
                    )
        }


        return
            ProcessedFinancialDocumentResult(
                document:
                    document,
                historyDocumentID:
                    historyDocumentID,
                historySaved:
                    historySaved
            )
    }

    private func makeMultipartBody(
        boundary: String,
        data: Data,
        fileName: String
    ) -> Data {

        var body =
            Data()

        func append(
            _ string: String
        ) {

            body.append(
                Data(
                    string.utf8
                )
            )
        }

        append(
            "--\(boundary)\r\n"
        )

        append(
            """
            Content-Disposition: form-data; \
            name="file_name"\r\n\r\n
            """
        )

        append(
            "\(fileName)\r\n"
        )

        append(
            "--\(boundary)\r\n"
        )

        append(
            """
            Content-Disposition: form-data; \
            name="file"; filename="\(fileName)"\r\n
            """
        )

        append(
            "Content-Type: \(mimeType(for: fileName))\r\n\r\n"
        )

        body.append(data)

        append("\r\n")

        append(
            "--\(boundary)--\r\n"
        )

        return body
    }

    private func mimeType(
        for fileName: String
    ) -> String {

        let ext =
            (fileName as NSString)
                .pathExtension
                .lowercased()

        switch ext {

        case "pdf":
            return "application/pdf"

        case "jpg", "jpeg":
            return "image/jpeg"

        case "png":
            return "image/png"

        case "heic", "heif":
            return "image/heic"

        default:
            return
                "application/octet-stream"
        }
    }
}

// Veryfi Normalizer

private enum VeryfiNormalizer {
    static func normalizeBankStatement(
        json: [String: Any],
        classification: String
    ) throws -> FinancialDocument {
        let documentID = int(json["id"])
        let accounts = json["accounts"] as? [[String: Any]] ?? []

        var chunks: [TextChunk] = []
        var records: [TransactionRecord] = []
        var displayLines: [String] = []

        if let holder = string(json["account_holder_name"]) {
            displayLines.append("Account holder: \(holder)")
        }

        for account in accounts {
            let accountCurrency =
                string(account["currency"])
                ?? string(account["currency_code"])
                ?? "USD"

            if let number = string(account["number"]) {
                displayLines.append("Account: \(number)")
            }

            if let beginning = decimal(account["beginning_balance"]) {
                displayLines.append("Beginning balance: \(beginning)")
            }

            if let ending = decimal(account["ending_balance"]) {
                displayLines.append("Ending balance: \(ending)")
            }

            let transactions = account["transactions"] as? [[String: Any]] ?? []
            
            
            // Determine whether this particular statement/account
            // actually provides posted dates.
            //
            // If at least one transaction has a posted_date, then:
            //
            // posted_date != nil → strong evidence of POSTED
            // posted_date == nil → strong evidence of PENDING
            //
            // If NO transactions contain posted_date at all,
            // we do not use its absence as evidence of pending.
            let accountUsesPostedDates =
                transactions.contains { transaction in

                    parseISODate(
                        string(
                            transaction["posted_date"]
                        )
                    ) != nil
                }

            print(
                "Veryfi account uses posted dates:",
                accountUsesPostedDates
            )

            for transaction in transactions {
                let description =
                    string(transaction["description"])
                    ?? string(transaction["vendor"])
                    ?? string(transaction["text"])
                    ?? "Transaction"

                let vendor = string(transaction["vendor"])
                let category = string(transaction["category"])
                let date = parseISODate(string(transaction["date"]))
                let postedDate = parseISODate(string(transaction["posted_date"]))
                let rawText = string(transaction["text"]) ?? description

                let debit = decimal(transaction["debit_amount"])
                let credit = decimal(transaction["credit_amount"])

                let flow: MoneyFlow
                let amount: Decimal
                let role: FinancialRecordRole

                if let debit, debit != 0 {
                    flow = .outflow
                    amount = magnitude(debit)
                    role = .purchase
                } else if let credit, credit != 0 {
                    flow = .inflow
                    amount = magnitude(credit)
                    role = .credit
                } else if let fallback = decimal(transaction["amount"]) {
                    flow = fallback < 0 ? .outflow : .inflow
                    amount = magnitude(fallback)
                    role = flow == .outflow ? .purchase : .credit
                } else {
                    continue
                }
                
                let combinedText =
                    [
                        description,
                        vendor,
                        category,
                        rawText
                    ]
                    .compactMap { $0 }
                    .joined(separator: " ")

                // ==================================================
                // STATUS NORMALIZATION
                //
                // Do NOT blindly default missing status to "posted".
                //
                // Veryfi's bank statement schema provides date and
                // posted_date. Some statement layouts use a separate
                // posted-date column, which gives us a strong,
                // institution-independent pending signal.
                // ==================================================

                let explicitStatus =
                    string(
                        transaction["status"]
                    )?
                    .lowercased()

                let normalizedText =
                    combinedText.lowercased()

                let status: TransactionStatus

                // 1. Explicit API status, if Veryfi ever supplies one.


                if explicitStatus == "pending" ||
                   explicitStatus == "processing" {

                    status = .pending

                } else if explicitStatus == "posted" ||
                          explicitStatus == "completed" {

                    status = .posted


                // 2. Transaction-level OCR/text evidence.


                } else if normalizedText.contains("pending") ||
                          normalizedText.contains("processing") {

                    status = .pending

                } else if normalizedText.contains("posted") ||
                          normalizedText.contains("completed") {

                    status = .posted

                // 3. Posted-date inference.
                //
                // IMPORTANT:
                // Only use this if this statement actually uses
                // posted dates somewhere.
                //
                // This prevents documents that simply don't have a
                // posted-date column from being marked pending.

                } else if accountUsesPostedDates {

                    if postedDate == nil {

                        status = .pending

                    } else {

                        status = .posted
                    }

                // 4. No reliable evidence.
                //
                // UNKNOWN is safer than incorrectly saying POSTED.

                } else {

                    status = .unknown
                }

                let transactionCurrency =
                    string(transaction["currency"])
                    ?? string(transaction["currency_code"])
                    ?? accountCurrency

                let chunkID = UUID()
                let chunkText = makeRecordChunkText(
                    date: date,
                    postedDate: postedDate,
                    description: description,
                    vendor: vendor,
                    amount: amount,
                    currency: transactionCurrency,
                    status: status,
                    category: category,
                    sourceText: rawText
                )

                chunks.append(TextChunk(id: chunkID, text: chunkText))
                records.append(
                    TransactionRecord(
                        chunkID: chunkID,
                        date: date,
                        postedDate: postedDate,
                        amount: amount,
                        currency: transactionCurrency,
                        status: status,
                        flow: flow,
                        role: role,
                        description: description,
                        vendor: vendor,
                        category: category,
                        sourceText: rawText
                    )
                )
                displayLines.append(chunkText)
            }
        }

        guard !records.isEmpty else {
            throw VeryfiError.noFinancialData
        }

        return FinancialDocument(
            veryfiDocumentID: documentID,
            documentType: classification,
            displayText: displayLines.joined(separator: "\n\n"),
            chunks: chunks,
            records: records
        )
    }

    static func normalizeBillOrInvoice(
        json: [String: Any],
        classification: String
    ) throws -> FinancialDocument {
        let documentID = int(json["id"])
        let ocrText = string(json["ocr_text"]) ?? ""
        let documentDate = parseISODate(string(json["date"]))
        let dueDate = parseISODate(string(json["due_date"]))
        let currency =
            string(json["total_currency_code"])
            ?? string(json["currency_code"])
            ?? "USD"

        let vendorName: String? = {
            if let vendor = json["vendor"] as? [String: Any] {
                return string(vendor["name"]) ?? string(vendor["raw_name"])
            }
            return string(json["vendor_name"]) ?? string(json["raw_vendor_name"])
        }()

        var chunks: [TextChunk] = []
        var records: [TransactionRecord] = []

        let lineItems = json["line_items"] as? [[String: Any]] ?? []

        for item in lineItems {
            guard let rawAmount =
                decimal(item["total"])
                ?? decimal(item["net_total"])
                ?? decimal(item["gross_total"])
                ?? decimal(item["subtotal"])
            else {
                continue
            }

            let description =
                string(item["description"])
                ?? string(item["text_v2"])
                ?? string(item["text"])
                ?? string(item["section"])
                ?? "Bill line item"

            if isSummaryLine(description) {
                continue
            }

            let type = string(item["type"])?.lowercased()
            let category =
                string(item["category"])
                ?? type
                ?? string(item["section"])

            let itemDate =
                parseISODate(string(item["date"]))
                ?? parseISODate(string(item["start_date"]))
                ?? documentDate

            let flow: MoneyFlow
            let role: FinancialRecordRole

            switch type {
            case "refund", "discount", "payment", "giftcard":
                flow = .inflow
                role = type == "refund" ? .refund : .credit
            case "fee", "tax", "service", "product", "parking", "fuel", "transportation", "delivery", "food":
                flow = .outflow
                role = type == "fee" ? .fee : .billCharge
            default:
                flow = rawAmount < 0 ? .inflow : .outflow
                role = .billCharge
            }

            let amount = magnitude(rawAmount)
            let chunkID = UUID()
            let sourceText = string(item["text"]) ?? description
            let chunkText = makeRecordChunkText(
                date: itemDate,
                postedDate: nil,
                description: description,
                vendor: vendorName,
                amount: amount,
                currency: currency,
                status: .unknown,
                category: category,
                sourceText: sourceText
            )

            chunks.append(TextChunk(id: chunkID, text: chunkText))
            records.append(
                TransactionRecord(
                    chunkID: chunkID,
                    date: itemDate,
                    amount: amount,
                    currency: currency,
                    status: .unknown,
                    flow: flow,
                    role: role,
                    description: description,
                    vendor: vendorName,
                    category: category,
                    sourceText: sourceText
                )
            )
        }

        // If Veryfi extracted no usable line items, retain the document-level
        // total/balance as a single deterministic charge record. This avoids
        // double-counting totals when line items are present.
        if records.isEmpty,
           let rootAmount = decimal(json["total"]) ?? decimal(json["balance"]) {
            let description =
                string(json["document_title"])
                ?? vendorName
                ?? "Document total"

            let chunkID = UUID()
            let sourceText = ocrText.isEmpty ? description : ocrText
            let chunkText = makeRecordChunkText(
                date: documentDate,
                postedDate: nil,
                description: description,
                vendor: vendorName,
                amount: magnitude(rootAmount),
                currency: currency,
                status: .unknown,
                category: string(json["category"]),
                sourceText: sourceText
            )

            chunks.append(TextChunk(id: chunkID, text: chunkText))
            records.append(
                TransactionRecord(
                    chunkID: chunkID,
                    date: documentDate,
                    amount: magnitude(rootAmount),
                    currency: currency,
                    status: .unknown,
                    flow: .outflow,
                    role: .billCharge,
                    description: description,
                    vendor: vendorName,
                    category: string(json["category"]),
                    sourceText: sourceText
                )
            )
        }

        guard !records.isEmpty else {
            throw VeryfiError.noFinancialData
        }

        // Add a summary chunk for semantic questions that ask about bill-level
        // values such as due date, vendor, total, or balance.
        let summaryParts: [String?] = [
            vendorName.map { "Vendor: \($0)" },
            documentDate.map { "Document date: \(formatISODate($0))" },
            dueDate.map { "Due date: \(formatISODate($0))" },
            decimal(json["total"]).map { "Total: \($0)" },
            decimal(json["balance"]).map { "Balance: \($0)" },
            string(json["document_title"]).map { "Title: \($0)" }
        ]

        let summaryText = summaryParts.compactMap { $0 }.joined(separator: "\n")
        if !summaryText.isEmpty {
            chunks.insert(TextChunk(text: summaryText), at: 0)
        }

        let displayText: String
        if !ocrText.isEmpty {
            displayText = ocrText
        } else {
            displayText = chunks.map(\.text).joined(separator: "\n\n")
        }

        return FinancialDocument(
            veryfiDocumentID: documentID,
            documentType: classification,
            displayText: displayText,
            chunks: chunks,
            records: records
        )
    }

    // Helpers

    private static func isSummaryLine(_ description: String) -> Bool {
        let lower = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let prefixes = [
            "total ",
            "subtotal",
            "amount due",
            "total due",
            "balance due",
            "previous balance",
            "remaining previous balance",
            "new charges",
            "current balance"
        ]

        return prefixes.contains { lower.hasPrefix($0) }
    }

    private static func makeRecordChunkText(
        date: Date?,
        postedDate: Date?,
        description: String,
        vendor: String?,
        amount: Decimal,
        currency: String,
        status: TransactionStatus,
        category: String?,
        sourceText: String
    ) -> String {
        var parts: [String] = []
        if let date { parts.append("Date: \(formatISODate(date))") }
        if let postedDate { parts.append("Posted date: \(formatISODate(postedDate))") }
        parts.append("Description: \(description)")
        if let vendor, !vendor.isEmpty { parts.append("Vendor: \(vendor)") }
        parts.append("Amount: \(amount) \(currency)")
        if status != .unknown { parts.append("Status: \(status.rawValue)") }
        if let category, !category.isEmpty { parts.append("Category: \(category)") }
        if sourceText != description { parts.append("Source text: \(sourceText)") }
        return parts.joined(separator: "\n")
    }

    private static func string(_ value: Any?) -> String? {
        if let string = value as? String, !string.isEmpty {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func decimal(_ value: Any?) -> Decimal? {
        if let decimal = value as? Decimal { return decimal }
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let string = value as? String {
            let cleaned = string
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Decimal(string: cleaned)
        }
        return nil
    }

    private static func magnitude(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }

    private static func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "MM/dd/yyyy",
            "MM/dd/yy"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func formatISODate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
