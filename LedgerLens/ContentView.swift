import SwiftUI
import UniformTypeIdentifiers
import VisionKit
import UIKit

struct ContentView: View {

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
    
    
    @State private var currentHistoryDocumentID:
        UUID?

    @State private var currentDocumentDisplayName:
        String?

    @State private var currentDocumentSummary:
        HistoryDocumentSummary?

    @State private var conversationEntries:
        [DocumentConversation] = []

    @State private var currentAnswerConversationID:
        UUID?

    @State private var conversationErrorMessage:
        String?

    @FocusState private var isQuestionFocused: Bool
    
    
    @ObservedObject private var network =
        NetworkMonitor.shared

    @State private var documentErrorMessage:
        String?

    @State private var questionErrorMessage:
        String?
    
    @EnvironmentObject private var documentWorkspace:
        DocumentWorkspace

    let embeddingProvider = OpenAIEmbeddingProvider()
    let chatProvider: ChatProvider = OpenAIResponsesProvider()

    private let questionSuggestions = [
        "What did I spend the most on?",
        "Are there any pending transactions?",
        "How much did I spend in total?",
        "Explain this bill to me"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {

                        
                        
                        heroSection

                        if !network.isConnected {

                            OfflineBanner(
                                message:
                                    """
                                    Uploading, scanning analysis, AI questions, and cloud history require an internet connection.
                                    """
                            )
                        }

                        documentInputSection

                        if let documentErrorMessage {

                            AppErrorCard(
                                title:
                                    "Couldn't analyze document",
                                message:
                                    documentErrorMessage
                            )
                            .transition(.opacity)
                        }
                        
                        if isProcessingDocument {
                            VeryfiProcessingCard()
                                .transition(
                                    .scale(scale: 0.96)
                                    .combined(with: .opacity)
                                )
                        }

                        if !chunks.isEmpty && !isProcessingDocument {
                            documentReadyCard
                                .transition(
                                    .move(edge: .top)
                                    .combined(with: .opacity)
                                )
                            
                            
                            if currentDocumentDisplayName
                                != nil
                                ||
                                currentDocumentSummary
                                != nil {

                                AnalyzeDocumentContextCard(
                                    displayName:
                                        currentDocumentDisplayName,
                                    summary:
                                        currentDocumentSummary
                                )
                            }


                            if !previousConversationEntries
                                .isEmpty {

                                ConversationHistoryView(
                                    conversations:
                                        previousConversationEntries,
                                    onDelete: {
                                        conversation in

                                        deleteConversation(
                                            conversation
                                        )
                                    },
                                    onClear: {

                                        clearConversation()
                                    }
                                )
                            }


                            if let conversationErrorMessage {

                                AppErrorCard(
                                    title:
                                        "Conversation history",
                                    message:
                                        conversationErrorMessage
                                )
                            }

                            questionSection
                                .transition(
                                    .move(edge: .bottom)
                                    .combined(with: .opacity)
                                )
                            
                            
                            if let questionErrorMessage {

                                AppErrorCard(
                                    title:
                                        "Couldn't answer question",
                                    message:
                                        questionErrorMessage,
                                    retryTitle:
                                        network.isConnected
                                        ? "Try Again"
                                        : nil,
                                    retry: {

                                        submitQuestion()
                                    }
                                )
                                .transition(.opacity)
                            }
                            
                        }

                        if !answer.isEmpty {
                            answerCard
                                .transition(
                                    .move(edge: .bottom)
                                    .combined(with: .opacity)
                                )
                        }

                        #if DEBUG
                        if !chunks.isEmpty {
                            debugSection
                        }
                        #endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 50)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(
                .spring(response: 0.46, dampingFraction: 0.84),
                value: isProcessingDocument
            )
            .animation(
                .spring(response: 0.46, dampingFraction: 0.84),
                value: chunks.count
            )
            .animation(
                .spring(response: 0.46, dampingFraction: 0.84),
                value: answer
            )
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

                    documentErrorMessage =
                        """
                        Unable to open that file.

                        \(error.localizedDescription)
                        """
                }
            }
            .fullScreenCover(
                isPresented: $showDocumentScanner
            ) {
                DocumentScannerView(
                    onComplete: { images in
                        showDocumentScanner = false
                        Task {
                            await processScannedPages(images)
                        }
                    },
                    onCancel: {
                        showDocumentScanner = false
                    },
                    onError: { error in
                        showDocumentScanner = false
                        documentErrorMessage =
                            """
                            Camera scanning error:

                            \(error.localizedDescription)
                            """
                    }
                )
            }
            
            
            .onAppear {

                restoreHistoryDocumentIfNeeded()

                handleAnalyzeLaunchActionIfNeeded()
            }
            
            
            
            
            .onChange(
                of: documentWorkspace
                    .pendingDocument?
                    .id
            ) { _, _ in

                restoreHistoryDocumentIfNeeded()
            }
            
            .onChange(
                of: documentWorkspace
                    .pendingAnalyzeAction?
                    .id
            ) { _, _ in

                handleAnalyzeLaunchActionIfNeeded()
            }
            
            
            
        }
    }
    
    private var previousConversationEntries:
        [DocumentConversation] {

        conversationEntries
            .filter {
                $0.id
                    !=
                currentAnswerConversationID
            }
    }
    
    // Persistent Conversation

    @MainActor
    private func persistCurrentExchange(
        question:
            String
    ) async {

        guard
            !answer
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        else {
            return
        }

        guard
            let documentID =
                currentHistoryDocumentID
        else {

            conversationErrorMessage =
                """
                The answer is available now, but it cannot be added to persistent conversation history because this document does not have a saved History record.
                """

            return
        }


        do {

            let saved =
                try await
                    ConversationService
                        .shared
                        .save(
                            documentID:
                                documentID,
                            question:
                                question,
                            answer:
                                answer,
                            retrievalMode:
                                retrievalMode
                        )

            conversationEntries
                .append(
                    saved
                )

            currentAnswerConversationID =
                saved.id

            conversationErrorMessage =
                nil

        } catch {

            conversationErrorMessage =
                """
                The answer was generated successfully, but it could not be saved to conversation history.

                \(AppFriendlyError.message(
                    for: error,
                    context: .history,
                    isConnected: network.isConnected
                ))
                """
        }
    }
    
    
    // Home go to Analyze Action

    @MainActor
    private func handleAnalyzeLaunchActionIfNeeded() {

        guard
            let pending =
                documentWorkspace
                    .consumeAnalyzeAction()
        else {
            return
        }

        switch pending.action {

        case .upload:

            showDocumentPicker =
                true

        case .scan:

            guard
                VNDocumentCameraViewController
                    .isSupported
            else {

                documentErrorMessage =
                    """
                    Document scanning is not supported on this device.
                    Try running the app on a physical iPhone.
                    """

                return
            }

            showDocumentScanner =
                true
        }
    }

    // Polished UI

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                HeroSparkleIcon()

                Text("AI Document & Bill Explainer")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text("Understand your money\nin seconds.")
                .font(
                    .system(
                        size: 36,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .tracking(-0.8)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                "Upload or scan a financial statement or bill, then ask questions in plain English."
            )
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var documentInputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(chunks.isEmpty ? "Add a financial document" : "Analyze another document")
                .font(.title3.weight(.semibold))

            DocumentActionButton(
                title: "Upload financial document",
                subtitle: "Choose a PDF, JPG or PNG",
                systemImage: "arrow.up.doc.fill",
                style: .primary
            ) {
                showDocumentPicker = true
            }
            .disabled(isProcessingDocument || isProcessingQuestion)

            DocumentActionButton(
                title: "Scan statement or bill",
                subtitle: "Use your iPhone camera",
                systemImage: "camera.viewfinder",
                style: .secondary
            ) {
                guard VNDocumentCameraViewController.isSupported else {
                    answer = """
                    Document scanning is not supported on this device.
                    Try running the app on a physical iPhone.
                    """
                    return
                }

                showDocumentScanner = true
            }
            .disabled(isProcessingDocument || isProcessingQuestion)
        }
    }

    private var documentReadyCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.13))
                    .frame(width: 50, height: 50)

                Image(systemName: "checkmark")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Document ready")
                    .font(.headline)

                Text(
                    "\(prettyDocumentType) • \(transactions.count) financial \(transactions.count == 1 ? "record" : "records")"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.green.opacity(0.065))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.green.opacity(0.14), lineWidth: 1)
        }
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Ask about your document")
                    .font(.title2.weight(.bold))

                Text(
                    "Ask about transactions, totals, dates, categories, charges, fees, or anything else."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .bottom, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 10)

                TextField(
                    "Ask anything about this document…",
                    text: $question,
                    axis: .vertical
                )
                .focused($isQuestionFocused)
                .lineLimit(1...5)
                .font(.system(size: 17))
                .submitLabel(.send)
                .onSubmit {
                    submitQuestion()
                }

                Button {
                    submitQuestion()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                questionCanSubmit
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.blue, .indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                : AnyShapeStyle(Color.secondary.opacity(0.15))
                            )
                            .frame(width: 43, height: 43)

                        if isProcessingQuestion {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(questionCanSubmit ? .white : .secondary)
                        }
                    }
                }
                .buttonStyle(AnimatedScaleButtonStyle())
                .disabled(!questionCanSubmit)
                .accessibilityLabel("Send question")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(Color(.secondarySystemBackground))
            .clipShape(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isQuestionFocused
                        ? Color.blue
                        : Color.primary.opacity(0.09),
                        lineWidth: isQuestionFocused ? 2 : 1
                    )
            }
            .shadow(
                color: isQuestionFocused
                ? Color.blue.opacity(0.13)
                : .clear,
                radius: 15,
                y: 4
            )
            .animation(.easeOut(duration: 0.2), value: isQuestionFocused)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(questionSuggestions, id: \.self) { suggestion in
                        Button {
                            question = suggestion
                            isQuestionFocused = true
                        } label: {
                            Text(suggestion)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08))
                                }
                        }
                        .buttonStyle(AnimatedScaleButtonStyle())
                    }
                }
                .padding(.vertical, 1)
            }

            if isProcessingQuestion {
                ThinkingIndicator()
                    .transition(.opacity)
            }
        }
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Answer")
                        .font(.headline)

                    if retrievalMode != "None" {
                        Text("\(prettyRetrievalMode) analysis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                
                if currentAnswerConversationID
                    != nil {

                    Menu {

                        Button(
                            role:
                                .destructive
                        ) {

                            deleteCurrentAnswerConversation()
                        } label: {

                            Label(
                                "Delete This Q&A",
                                systemImage:
                                    "trash"
                            )
                        }


                        Button(
                            role:
                                .destructive
                        ) {

                            clearConversation()
                        } label: {

                            Label(
                                "Clear Entire Conversation",
                                systemImage:
                                    "trash.slash"
                            )
                        }

                    } label: {

                        Image(
                            systemName:
                                "ellipsis.circle"
                        )
                        .font(
                            .title3
                        )
                    }
                }
            }

            Text(
                PlainTextSanitizer.clean(
                    answer
                )
            )
            .font(.system(size: 17))
            .lineSpacing(5)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .textSelection(.enabled)
            
            
            
            if !followUpSuggestions.isEmpty &&
               !isProcessingQuestion {

                Divider()

                FollowUpSuggestionsView(
                    suggestions:
                        followUpSuggestions
                ) {
                    suggestion in

                    askFollowUp(
                        suggestion
                    )
                }
            }
            
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.indigo.opacity(0.11), lineWidth: 1)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Document type")
                    Spacer()
                    Text(prettyDocumentType)
                }

                HStack {
                    Text("Normalized records")
                    Spacer()
                    Text("\(transactions.count)")
                }

                HStack {
                    Text("Document chunks")
                    Spacer()
                    Text("\(chunks.count)")
                }

                HStack {
                    Text("Retrieval mode")
                    Spacer()
                    Text(retrievalMode)
                }

                HStack {
                    Text("Retrieved chunks")
                    Spacer()
                    Text("\(retrievedChunks.count)")
                }

                if !retrievedChunks.isEmpty {
                    Divider()

                    ForEach(
                        Array(retrievedChunks.enumerated()),
                        id: \.element.id
                    ) { index, chunk in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Retrieved #\(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(chunk.text)
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.yellow.opacity(0.16))
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                    }
                }

                if !extractedText.isEmpty {
                    Divider()

                    Text("Extracted Veryfi text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(extractedText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(20)
                }
            }
            .padding(.top, 10)
        } label: {
            Label("Developer diagnostics", systemImage: "wrench.and.screwdriver")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(15)
        .background(Color.primary.opacity(0.035))
        .clipShape(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
    #endif

    private var prettyDocumentType: String {
        let cleaned = documentType
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty || cleaned == "None" {
            return "Financial Document"
        }

        return cleaned.capitalized
    }

    private var prettyRetrievalMode: String {
        retrievalMode.lowercased().capitalized
    }

    private var questionCanSubmit: Bool {
        !question
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        && !isProcessingQuestion
        && !isProcessingDocument
        && !chunks.isEmpty
    }

    private func submitQuestion() {
        guard questionCanSubmit else { return }

        isQuestionFocused = false

        Task {
            await processQuestion()
        }
    }
    
    
    
    private var followUpSuggestions:
        [String] {

        FollowUpSuggestionEngine
            .suggestions(
                documentType:
                    documentType,
                previousQuestion:
                    question
            )
    }


    private func askFollowUp(
        _ suggestion: String
    ) {

        guard
            !isProcessingQuestion
        else {
            return
        }

        guard
            network.isConnected
        else {

            questionErrorMessage =
                """
                You're offline. Reconnect before asking another question.
                """

            return
        }

        question =
            suggestion

        isQuestionFocused =
            false

        questionErrorMessage =
            nil

        Task {

            await processQuestion()
        }
    }
    
    
    @MainActor
    private func deleteConversation(
        _ conversation:
            DocumentConversation
    ) {

        guard
            network.isConnected
        else {

            conversationErrorMessage =
                "Reconnect before deleting saved Q&A."

            return
        }

        Task {

            do {

                try await
                    ConversationService
                        .shared
                        .delete(
                            id:
                                conversation.id
                        )

                conversationEntries
                    .removeAll {
                        $0.id
                            ==
                        conversation.id
                    }

            } catch {

                conversationErrorMessage =
                    AppFriendlyError
                        .message(
                            for: error,
                            context:
                                .history,
                            isConnected:
                                network
                                    .isConnected
                        )
            }
        }
    }


    @MainActor
    private func deleteCurrentAnswerConversation() {

        guard
            let id =
                currentAnswerConversationID
        else {
            return
        }

        guard
            network.isConnected
        else {

            conversationErrorMessage =
                "Reconnect before deleting saved Q&A."

            return
        }

        Task {

            do {

                try await
                    ConversationService
                        .shared
                        .delete(
                            id: id
                        )

                conversationEntries
                    .removeAll {
                        $0.id == id
                    }

                currentAnswerConversationID =
                    nil

                answer =
                    ""

                retrievalMode =
                    "None"

            } catch {

                conversationErrorMessage =
                    AppFriendlyError
                        .message(
                            for: error,
                            context:
                                .history,
                            isConnected:
                                network
                                    .isConnected
                        )
            }
        }
    }


    @MainActor
    private func clearConversation() {

        guard
            let documentID =
                currentHistoryDocumentID
        else {
            return
        }

        guard
            network.isConnected
        else {

            conversationErrorMessage =
                "Reconnect before clearing this conversation."

            return
        }

        Task {

            do {

                try await
                    ConversationService
                        .shared
                        .clear(
                            documentID:
                                documentID
                        )

                conversationEntries =
                    []

                currentAnswerConversationID =
                    nil

                answer =
                    ""

                question =
                    ""

                retrievalMode =
                    "None"

                citedChunkIDs =
                    []

                retrievedChunks =
                    []

                conversationErrorMessage =
                    nil

            } catch {

                conversationErrorMessage =
                    AppFriendlyError
                        .message(
                            for: error,
                            context:
                                .history,
                            isConnected:
                                network
                                    .isConnected
                        )
            }
        }
    }
    
    
    // Restore From History

    @MainActor
    private func restoreHistoryDocumentIfNeeded() {

        guard
            let pending =
                documentWorkspace
                    .consumePendingDocument()
        else {
            return
        }
        
        currentHistoryDocumentID =
            pending
                .historyDocumentID

        currentDocumentDisplayName =
            pending
                .displayName

        currentDocumentSummary =
            pending
                .summary

        conversationEntries =
            pending
                .conversations

        currentAnswerConversationID =
            nil

        conversationErrorMessage =
            nil

        // Stop editing/processing UI from the previous document.
        isQuestionFocused = false
        isProcessingQuestion = false
        isProcessingDocument = false

        // Clear previous question state.
        question = ""
        answer = ""
        retrievalMode = "None"
        citedChunkIDs = []
        retrievedChunks = []
        chunkEmbeddings = [:]
        
        documentErrorMessage =
            nil

        questionErrorMessage =
            nil

        // Load the FinancialDocument rebuilt from saved Veryfi JSON.
        documentType =
            pending
                .financialDocument
                .documentType

        extractedText =
            pending
                .financialDocument
                .displayText

        chunks =
            pending
                .financialDocument
                .chunks

        transactions =
            pending
                .financialDocument
                .records

        print("")
        print("==============================")
        print("HISTORY DOCUMENT RESTORED")
        print("==============================")
        print(
            "Name:",
            pending.displayName
        )
        print(
            "Document type:",
            documentType
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
        
        
        guard
            network.isConnected
        else {

            documentErrorMessage =
                """
                You're offline. Connect to the internet before analyzing this document.
                """

            return
        }
        
        
        currentHistoryDocumentID =
            nil

        currentDocumentDisplayName =
            nil

        currentDocumentSummary =
            nil

        conversationEntries =
            []

        currentAnswerConversationID =
            nil

        conversationErrorMessage =
            nil

        documentErrorMessage =
            nil

        questionErrorMessage =
            nil

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

            let processed =
                try await service
                    .processFinancialDocumentWithHistory(
                        data: data,
                        fileName: fileName
                    )

            let document =
                processed.document

            currentHistoryDocumentID =
                processed
                    .historyDocumentID
            
            
            if processed
                .historyDocumentID
                == nil {

                conversationErrorMessage =
                    """
                    This document was analyzed successfully, but its History record was not saved. Questions will work, but this conversation cannot be persisted for this document.
                    """
            }
            
            

            currentDocumentDisplayName =
                defaultDocumentDisplayName(
                    fileName:
                        fileName,
                    documentType:
                        document
                            .documentType
                )

            currentDocumentSummary =
                nil

            conversationEntries =
                []

            currentAnswerConversationID =
                nil

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

            documentErrorMessage =
                AppFriendlyError
                    .message(
                        for: error,
                        context:
                            .documentProcessing,
                        isConnected:
                            network
                                .isConnected
                    )
            
            

            documentType = "None"

            chunks = []

            transactions = []

            extractedText = ""

            citedChunkIDs = []

            retrievedChunks = []

            chunkEmbeddings = [:]
            
            
            currentHistoryDocumentID =
                nil

            currentDocumentDisplayName =
                nil

            currentDocumentSummary =
                nil

            conversationEntries =
                []

            currentAnswerConversationID =
                nil

        }

    }
    

    private func defaultDocumentDisplayName(
        fileName: String,
        documentType: String
    ) -> String {

        let prettyType =
            documentType
                .replacingOccurrences(
                    of: "_",
                    with: " "
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .capitalized

        if fileName
            .lowercased()
            .hasPrefix(
                "financial-scan-"
            ) {

            return
                "Scanned \(prettyType.isEmpty ? "Financial Document" : prettyType)"
        }

        let base =
            (
                fileName
                as NSString
            )
            .deletingPathExtension
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return
            base.isEmpty
            ? (
                prettyType.isEmpty
                ? "Financial Document"
                : prettyType
            )
            : base
    }



    // Camera Scan Processing

    @MainActor

    private func processScannedPages(

        _ images: [UIImage]

    ) async {

        guard !images.isEmpty else {

            documentErrorMessage =

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

                documentErrorMessage =

                    "Failed to convert the scanned page to an image."

                return

            }

            let fileName = "financial-scan-\(UUID().uuidString).jpg"

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

        // This uses UIKit, NOT PDFKit.


        let pdfData =

            makePDF(

                from: images

            )

        guard !pdfData.isEmpty else {

            documentErrorMessage =

                "Failed to create a multi-page scanned document."

            return

        }

        let fileName = "financial-scan-\(UUID().uuidString).pdf"

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
        
        guard
            network.isConnected
        else {

            questionErrorMessage =
                """
                You're offline. Reconnect before asking AI questions.
                """

            return
        }

        questionErrorMessage =
            nil
        
        isProcessingQuestion = true

        citedChunkIDs = []

        retrievedChunks = []
        
        
        // The previous current answer is now an older saved Q&A.
        currentAnswerConversationID =
            nil

        conversationErrorMessage =
            nil

        answer = ""

        defer {

            isProcessingQuestion = false

        }

        do {

            let mode = RAGQueryAnalyzer.retrievalMode(for: trimmedQuestion)

            switch mode {

            case .aggregation:

                retrievalMode =
                    "AGGREGATION"

                try await
                    processAggregationQuestion(
                        trimmedQuestion
                    )

                await persistCurrentExchange(
                    question:
                        trimmedQuestion
                )

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
                    
                    await persistCurrentExchange(
                        question:
                            trimmedQuestion
                    )

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

            guard
                !relevantChunks
                    .isEmpty
            else {

                answer =
                    "I don't know based on the provided document."

                await persistCurrentExchange(
                    question:
                        trimmedQuestion
                )

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

            let rawAnswer =
                try await chatProvider.complete(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt
                )

            answer =
                PlainTextSanitizer.clean(
                    rawAnswer
                )
            
            await persistCurrentExchange(
                question:
                    trimmedQuestion
            )

        } catch {

            questionErrorMessage =
                AppFriendlyError
                    .message(
                        for: error,
                        context:
                            .question,
                        isConnected:
                            network
                                .isConnected
                    )

            answer =
                ""

            citedChunkIDs =
                []

            retrievedChunks =
                []
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

        let rawAnswer =
            try await chatProvider.complete(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )

        answer =
            PlainTextSanitizer.clean(
                rawAnswer
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


// UI Components

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.055),
                    Color.clear,
                    Color.indigo.opacity(0.065)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.blue.opacity(0.055))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: 150, y: -290)

            Circle()
                .fill(Color.indigo.opacity(0.045))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: -150, y: 330)
        }
    }
}

private struct HeroSparkleIcon: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.10))
                .frame(width: 52, height: 52)
                .scaleEffect(pulse ? 1.12 : 0.96)
                .opacity(pulse ? 0.55 : 1)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)

            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(pulse && !reduceMotion ? 8 : 0))
        }
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(
                .easeInOut(duration: 1.8)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}

private struct DocumentActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let subtitle: String
    let systemImage: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 54, height: 54)

                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(
                            style == .primary
                            ? Color.white.opacity(0.78)
                            : .secondary
                        )
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .opacity(0.68)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
            )
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(Color.primary.opacity(0.09), lineWidth: 1)
                }
            }
            .shadow(
                color: style == .primary ? Color.blue.opacity(0.18) : .clear,
                radius: 18,
                y: 7
            )
        }
        .buttonStyle(AnimatedScaleButtonStyle())
    }

    private var background: AnyShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.blue, .indigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

        case .secondary:
            return AnyShapeStyle(.thinMaterial)
        }
    }

    private var foreground: Color {
        style == .primary ? .white : .primary
    }

    private var iconBackground: Color {
        style == .primary ? .white.opacity(0.17) : .blue.opacity(0.11)
    }

    private var iconForeground: Color {
        style == .primary ? .white : .blue
    }
}

private struct AnimatedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.91 : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.68),
                value: configuration.isPressed
            )
    }
}

private struct DocumentProcessingCard: View {
    @State private var rotation: Double = 0
    @State private var messageIndex = 0
    @State private var pulse = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let messages = [
        "Sending your document securely…",
        "Reading financial details…",
        "Organizing transactions and charges…",
        "Preparing your AI workspace…"
    ]

    var body: some View {
        VStack(spacing: 21) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.11), lineWidth: 8)
                    .frame(width: 88, height: 88)

                Circle()
                    .trim(from: 0.05, to: 0.72)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round
                        )
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(rotation))

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(.blue)
                    .scaleEffect(pulse ? 1.06 : 0.96)
            }

            VStack(spacing: 7) {
                Text("Analyzing document")
                    .font(.title3.weight(.bold))

                Text(messages[messageIndex])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .id(messageIndex)
            }

            HStack(spacing: 6) {
                ForEach(0..<messages.count, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == messageIndex
                            ? Color.blue
                            : Color.secondary.opacity(0.18)
                        )
                        .frame(
                            width: index == messageIndex ? 24 : 7,
                            height: 7
                        )
                        .animation(.spring(response: 0.32), value: messageIndex)
                }
            }

            Text("Your document is being processed through your secure backend.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color.blue.opacity(0.10), lineWidth: 1)
        }
        .task {
            guard !reduceMotion else { return }

            withAnimation(
                .linear(duration: 1.05)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }

            withAnimation(
                .easeInOut(duration: 0.85)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.45))

                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.25)) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
}

private struct ThinkingIndicator: View {
    @State private var activeDot = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 9) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .scaleEffect(activeDot == index ? 1.35 : 0.75)
                        .opacity(activeDot == index ? 1 : 0.35)
                        .animation(.easeInOut(duration: 0.25), value: activeDot)
                }
            }

            Text("Thinking through your financial document…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .task {
            guard !reduceMotion else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(360))

                guard !Task.isCancelled else { return }
                activeDot = (activeDot + 1) % 3
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(
            DocumentWorkspace()
        )
}
