import SwiftUI
import UniformTypeIdentifiers
import VisionKit
import UIKit

struct DebuggerContentView: View {
    @State private var showDocumentPicker = false
    @State private var showDocumentScanner = false
    @State private var extractedText = ""
    @State private var documentType = "None"
    @State private var chunks: [TextChunk] = []
    @State private var transactions: [TransactionRecord] = []
    @State private var chunkEmbeddings: [UUID: EmbeddingVector] = [:]
    @State private var question = ""
    @State private var answer = ""
    @State private var citedChunkIDs: [UUID] = []
    @State private var retrievedChunks: [TextChunk] = []
    @State private var retrievalMode = "None"
    @State private var isProcessingQuestion = false
    @State private var isProcessingDocument = false

    let embeddingProvider = OpenAIEmbeddingProvider()
    let chatProvider: ChatProvider = OpenAIResponsesProvider()

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {

                // Upload File

                Button {

                    showDocumentPicker = true

                } label: {

                    Label(
                        isProcessingDocument
                            ? "Processing Document..."
                            : "Select Financial Document",
                        systemImage: "doc.text"
                    )
                    .font(.title2)
                }
                .disabled(
                    isProcessingDocument ||
                    isProcessingQuestion
                )

                // Scan With Camera

                Button {

                    guard
                        VNDocumentCameraViewController
                            .isSupported
                    else {

                        answer =
                            """
                            Document scanning is not supported on this device.
                            Try running the app on a physical iPhone.
                            """

                        return
                    }

                    showDocumentScanner = true

                } label: {

                    Label(
                        "Scan Statement or Bill",
                        systemImage: "camera.viewfinder"
                    )
                    .font(.title2)
                }
                .disabled(
                    isProcessingDocument ||
                    isProcessingQuestion
                )
            }
        
            .disabled(isProcessingDocument || isProcessingQuestion)

            if !extractedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Veryfi document type: \(documentType)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Normalized financial records: \(transactions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    Text(extractedText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            } else {
                Text(isProcessingDocument ? "Sending document to Veryfi..." : "No document loaded.")
                    .foregroundStyle(.secondary)
            }

            if !chunks.isEmpty {
                Divider()

                Text("Document Chunks (\(chunks.count))")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(chunks) { chunk in
                            Text(chunk.text)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    citedChunkIDs.contains(chunk.id)
                                    ? Color.yellow.opacity(0.4)
                                    : Color.clear
                                )
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(height: 140)

                Divider()

                TextField(
                    "Ask a question about the document...",
                    text: $question
                )
                .textFieldStyle(.roundedBorder)

                Button(
                    isProcessingQuestion ? "Processing..." : "Ask AI"
                ) {
                    Task {
                        await processQuestion()
                    }
                }
                .disabled(
                    isProcessingQuestion ||
                    isProcessingDocument ||
                    chunks.isEmpty ||
                    question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                if retrievalMode != "None" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Retrieval: \(retrievalMode)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Retrieved \(retrievedChunks.count) chunks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !retrievedChunks.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(
                                        Array(retrievedChunks.enumerated()),
                                        id: \.element.id
                                    ) { index, chunk in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Retrieved #\(index + 1)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                            Text(chunk.text)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.yellow.opacity(0.25))
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 220)
                        }
                    }
                }

                if !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Answer:")
                            .font(.headline)

                        ScrollView {
                            Text(answer)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .jpeg, .png],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await processFinancialDocument(from: url)
                }

            case .failure(let error):
                answer = "Failed to select document: \(error.localizedDescription)"
            }
        }
        
        .fullScreenCover(
            isPresented: $showDocumentScanner
        ) {

            DocumentScannerView(

                onComplete: { images in

                    showDocumentScanner = false

                    Task {

                        await processScannedPages(
                            images
                        )
                    }
                },

                onCancel: {

                    showDocumentScanner = false
                },

                onError: { error in

                    showDocumentScanner = false

                    answer =
                        """
                        Camera scanning error:
                        \(error.localizedDescription)
                        """
                }
            )
        }
        
    }
    
    
    
    
    

    // Veryfi Document Processing

    // File Processing

    @MainActor
    private func processFinancialDocument(
        from url: URL
    ) async {

        do {

            let didAccess =
                url.startAccessingSecurityScopedResource()

            defer {

                if didAccess {

                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data =
                try Data(
                    contentsOf: url
                )

            await processFinancialDocument(
                data: data,
                fileName: url.lastPathComponent
            )

        } catch {

            answer =
                """
                Failed to read document:
                \(error.localizedDescription)
                """
        }
    }


    // Shared Veryfi Processing

    @MainActor
    private func processFinancialDocument(
        data: Data,
        fileName: String
    ) async {

        isProcessingDocument = true

        answer = ""
        question = ""

        retrievalMode = "None"

        citedChunkIDs = []
        retrievedChunks = []

        chunks = []
        transactions = []

        extractedText = ""

        chunkEmbeddings = [:]

        documentType = "None"

        defer {

            isProcessingDocument = false
        }

        do {

            let backend =
                try BackendConfiguration
                .fromBundle()

            let service =
                VeryfiService(
                    backend: backend
                )

            let document =
                try await service
                    .processFinancialDocument(
                        data: data,
                        fileName: fileName
                    )

            documentType =
                document.documentType

            extractedText =
                document.displayText

            chunks =
                document.chunks

            transactions =
                document.records

            print("")
            print("==============================")
            print("VERYFI PROCESSING COMPLETE")
            print("==============================")

            print(
                "Document type:",
                document.documentType
            )

            print(
                "Normalized records:",
                transactions.count
            )

            print(
                "Created chunks:",
                chunks.count
            )

            print("==============================")
            print("")

        } catch {

            print(
                "Veryfi document processing error:",
                error
            )

            answer =
                """
                Document processing error:
                \(error.localizedDescription)
                """

            documentType = "None"

            chunks = []
            transactions = []
            extractedText = ""

            citedChunkIDs = []
            retrievedChunks = []
            chunkEmbeddings = [:]
        }
    }
    
    
    // Camera Scan Processing

    @MainActor
    private func processScannedPages(
        _ images: [UIImage]
    ) async {

        guard !images.isEmpty else {

            answer =
                "No scanned document pages were received."

            return
        }

        // ONE PAGE
        //
        // Send JPEG directly to Veryfi.

        if images.count == 1 {

            guard let jpegData =
                images[0].jpegData(
                    compressionQuality: 0.92
                )
            else {

                answer =
                    "Failed to convert the scanned page to an image."

                return
            }

            let fileName =
                """
                financial-scan-\(UUID().uuidString).jpg
                """

            await processFinancialDocument(
                data: jpegData,
                fileName: fileName
            )

            return
        }

        // MULTIPLE PAGES
        //
        // Convert scanned pages into one PDF.
        //
        // This uses UIKit — NOT PDFKit.

        let pdfData =
            makePDF(
                from: images
            )

        guard !pdfData.isEmpty else {

            answer =
                "Failed to create a multi-page scanned document."

            return
        }

        let fileName =
            """
            financial-scan-\(UUID().uuidString).pdf
            """

        await processFinancialDocument(
            data: pdfData,
            fileName: fileName
        )
    }
    
    
    private func makePDF(
        from images: [UIImage]
    ) -> Data {

        guard !images.isEmpty else {
            return Data()
        }

        // Standard US Letter PDF page.
        let pageRect =
            CGRect(
                x: 0,
                y: 0,
                width: 612,
                height: 792
            )

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageRect
            )

        return renderer.pdfData { context in

            for image in images {

                context.beginPage()

                let margin: CGFloat = 18

                let availableRect =
                    pageRect.insetBy(
                        dx: margin,
                        dy: margin
                    )

                let targetRect =
                    aspectFitRect(
                        imageSize: image.size,
                        inside: availableRect
                    )

                image.draw(
                    in: targetRect
                )
            }
        }
    }

    
    
    private func aspectFitRect(
        imageSize: CGSize,
        inside boundingRect: CGRect
    ) -> CGRect {

        guard
            imageSize.width > 0,
            imageSize.height > 0
        else {
            return boundingRect
        }

        let widthRatio =
            boundingRect.width
            / imageSize.width

        let heightRatio =
            boundingRect.height
            / imageSize.height

        let scale =
            min(
                widthRatio,
                heightRatio
            )

        let width =
            imageSize.width * scale

        let height =
            imageSize.height * scale

        let x =
            boundingRect.midX
            - width / 2

        let y =
            boundingRect.midY
            - height / 2

        return CGRect(
            x: x,
            y: y,
            width: width,
            height: height
        )
    }
    

    // Question Processing

    @MainActor
    private func processQuestion() async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuestion.isEmpty, !chunks.isEmpty else {
            return
        }

        isProcessingQuestion = true
        citedChunkIDs = []
        retrievedChunks = []
        answer = ""

        defer {
            isProcessingQuestion = false
        }

        do {
            let mode = RAGQueryAnalyzer.retrievalMode(for: trimmedQuestion)

            switch mode {
            case .aggregation:
                retrievalMode = "AGGREGATION"
                try await processAggregationQuestion(trimmedQuestion)
                return

            case .structured:
                retrievalMode = "STRUCTURED"

            case .exhaustive:
                retrievalMode = "EXHAUSTIVE"

            case .semantic:
                retrievalMode = "SEMANTIC"
            }

            var relevantChunks: [TextChunk] = []

            // MODE 3: STRUCTURED
            if mode == .structured {
                let matches = RAGQueryAnalyzer.structuredMatches(
                    question: trimmedQuestion,
                    transactions: transactions
                )

                relevantChunks = chunksForTransactions(matches)

                guard !relevantChunks.isEmpty else {
                    answer = "I don't know based on the provided document."
                    return
                }
            }

            // MODE 2: EXHAUSTIVE
            else if mode == .exhaustive {
                let terms = RAGQueryAnalyzer.meaningfulTerms(from: trimmedQuestion)

                if !terms.isEmpty {
                    relevantChunks = chunks.filter { chunk in
                        let text = chunk.text.lowercased()
                        return terms.allSatisfy { text.contains($0) }
                    }
                }

                if relevantChunks.isEmpty {
                    try await ensureEmbeddings()
                    relevantChunks = try await semanticChunks(
                        for: trimmedQuestion,
                        topK: 8
                    )
                }
            }

            // MODE 1: SEMANTIC
            else {
                try await ensureEmbeddings()
                relevantChunks = try await semanticChunks(
                    for: trimmedQuestion,
                    topK: 8
                )
            }

            guard !relevantChunks.isEmpty else {
                answer = "I don't know based on the provided document."
                return
            }

            retrievedChunks = relevantChunks
            citedChunkIDs = relevantChunks.map(\.id)

            let contextText = relevantChunks
                .enumerated()
                .map { index, chunk in
                    """
                    [Document Chunk \(index + 1)]
                    \(chunk.text)
                    """
                }
                .joined(separator: "\n\n--------------------\n\n")

            let systemPrompt = """
            You are an AI assistant that answers questions about a financial document.

            Use ONLY the document context provided by Veryfi and the application.

            Rules:
            1. Carefully examine all provided chunks.
            2. Never invent transactions, dates, amounts, merchants, vendors, categories, or statuses.
            3. For list questions, include every matching item present in the provided context.
            4. Preserve dates, descriptions, amounts, status, vendor, and category when available.
            5. For structured questions, trust the records selected deterministically by the application.
            6. If the information is truly absent, reply exactly:
               "I don't know based on the provided document."
            """

            let userPrompt = """
            DOCUMENT CONTEXT:

            \(contextText)

            USER QUESTION:

            \(trimmedQuestion)
            """

            answer = try await chatProvider.complete(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        } catch {
            answer = "Error: \(error.localizedDescription)"
            citedChunkIDs = []
            retrievedChunks = []
        }
    }

    // Mode 4 Aggregation

    @MainActor
    private func processAggregationQuestion(_ question: String) async throws {
        guard let query = RAGQueryAnalyzer.aggregationQuery(from: question) else {
            answer = "I couldn't determine the requested calculation."
            return
        }

        let result = AggregationEngine.execute(
            query: query,
            records: transactions
        )

        retrievedChunks = chunksForTransactions(result.matchingRecords)
        citedChunkIDs = retrievedChunks.map(\.id)

        let verifiedResult = aggregationResultText(result)
        let supportingRecords = result.matchingRecords
            .enumerated()
            .map { index, record in
                """
                [Record \(index + 1)]
                \(financialRecordText(record))
                """
            }
            .joined(separator: "\n\n")

        let systemPrompt = """
        You are explaining a financial result that has already been calculated deterministically by Swift.

        The VERIFIED RESULT is authoritative.
        Do not perform your own arithmetic.
        Do not change the calculated value.
        Do not add or remove records from the verified result.
        Do not invent financial information.
        Explain the result naturally and concisely.
        If maximum or minimum has multiple tied records, mention the tie.
        """

        let userPrompt = """
        VERIFIED RESULT:

        \(verifiedResult)

        SUPPORTING RECORDS:

        \(supportingRecords.isEmpty ? "No matching records." : supportingRecords)

        ORIGINAL QUESTION:

        \(question)
        """

        answer = try await chatProvider.complete(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
    }

    // Embedding Helpers

    @MainActor
    private func ensureEmbeddings() async throws {
        let allCurrent =
            chunkEmbeddings.count == chunks.count &&
            chunks.allSatisfy { chunkEmbeddings[$0.id] != nil }

        guard !allCurrent else {
            return
        }

        let embeddings = try await embeddingProvider.embeddings(
            for: chunks.map(\.text)
        )

        guard embeddings.count == chunks.count else {
            throw VeryfiError.malformedResponse
        }

        var temp: [UUID: EmbeddingVector] = [:]
        for (index, chunk) in chunks.enumerated() {
            temp[chunk.id] = embeddings[index]
        }
        chunkEmbeddings = temp
    }

    private func semanticChunks(
        for question: String,
        topK: Int
    ) async throws -> [TextChunk] {
        let queryEmbedding = try await embeddingProvider.embedding(for: question)
        let document = RAGDocument(
            chunks: chunks,
            embeddings: chunkEmbeddings
        )
        return document.retrieveRelevantChunks(
            for: queryEmbedding,
            topK: topK
        )
    }

    private func chunksForTransactions(
        _ records: [TransactionRecord]
    ) -> [TextChunk] {
        let ids = Set(records.map(\.chunkID))
        return chunks.filter { ids.contains($0.id) }
    }

    // Formatting

    private func formatCurrency(
        _ value: Decimal,
        currency: String = "USD"
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(
            from: NSDecimalNumber(decimal: value)
        ) ?? "\(currency) \(value)"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }

    private func financialRecordText(
        _ record: TransactionRecord
    ) -> String {
        """
        Date: \(formatDate(record.date))
        Description: \(record.description)
        Vendor: \(record.vendor ?? "Unknown")
        Amount: \(formatCurrency(record.amount, currency: record.currency))
        Flow: \(record.flow.rawValue)
        Role: \(record.role.rawValue)
        Status: \(record.status.rawValue)
        Category: \(record.category ?? "Unknown")
        """
    }

    private func aggregationResultText(
        _ result: AggregationResult
    ) -> String {
        switch result.operation {
        case .count:
            return """
            Operation: COUNT
            Scope: \(result.scope.rawValue)
            Verified count: \(result.countValue)
            """

        case .sum:
            return """
            Operation: SUM
            Scope: \(result.scope.rawValue)
            Verified result: \(formatCurrency(result.decimalValue ?? .zero))
            Matching records: \(result.countValue)
            """

        case .average:
            guard let value = result.decimalValue else {
                return "Operation: AVERAGE\nNo matching monetary records."
            }
            return """
            Operation: AVERAGE
            Scope: \(result.scope.rawValue)
            Verified result: \(formatCurrency(value))
            Matching records: \(result.countValue)
            """

        case .maximum:
            guard let value = result.decimalValue else {
                return "Operation: MAXIMUM\nNo matching monetary records."
            }
            let selected = result.selectedRecords
                .map(financialRecordText)
                .joined(separator: "\n\n")
            return """
            Operation: MAXIMUM
            Scope: \(result.scope.rawValue)
            Verified amount: \(formatCurrency(value))
            Tied records: \(result.selectedRecords.count)

            \(selected)
            """

        case .minimum:
            guard let value = result.decimalValue else {
                return "Operation: MINIMUM\nNo matching monetary records."
            }
            let selected = result.selectedRecords
                .map(financialRecordText)
                .joined(separator: "\n\n")
            return """
            Operation: MINIMUM
            Scope: \(result.scope.rawValue)
            Verified amount: \(formatCurrency(value))
            Tied records: \(result.selectedRecords.count)

            \(selected)
            """
        }
    }
}

#Preview {
    ContentView()
}
