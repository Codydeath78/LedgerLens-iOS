// Better Document Intelligence
// Builds on stable organization + reminders.

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct HistoryDocumentDetailView: View {

    @EnvironmentObject private var documentWorkspace:
        DocumentWorkspace

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject private var network =
        NetworkMonitor.shared

    let document:
        HistoryDocument

    let onRenamed:
        (String) -> Void

    @State private var organizationDocument:
        HistoryDocument

    @State private var currentName:
        String

    @State private var renameText:
        String

    @State private var showRename =
        false

    @State private var showOrganize =
        false

    @State private var folders:
        [DocumentFolder] = []

    @State private var isRenaming =
        false

    @State private var isOpening =
        false

    @State private var isDownloading =
        false

    @State private var summary:
        HistoryDocumentSummary?

    @State private var conversations:
        [DocumentConversation] = []

    @State private var isLoadingContext =
        true

    @State private var contextError:
        String?

    @State private var intelligence:
        DocumentIntelligence?

    @State private var isLoadingIntelligence =
        true

    @State private var intelligenceError:
        String?

    @State private var isApplyingSmartName =
        false

    @State private var actionError:
        String?

    @State private var exportDocument:
        HistoryOriginalExportDocument?

    @State private var exportContentType:
        UTType = .data

    @State private var showOriginalExporter =
        false

    @State private var showReportExporter =
        false


    init(
        document:
            HistoryDocument,
        onRenamed:
            @escaping (String) -> Void
    ) {

        self.document =
            document

        self.onRenamed =
            onRenamed

        _organizationDocument =
            State(
                initialValue:
                    document
            )

        let initialName =
            document
                .resolvedDisplayName

        _currentName =
            State(
                initialValue:
                    initialName
            )

        _renameText =
            State(
                initialValue:
                    initialName
            )
    }


    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 20
            ) {

                if !network
                    .isConnected {

                    OfflineBanner(
                        message:
                            "Reopening the document, loading saved Q&A, and downloading its original require an internet connection."
                    )
                }

                heroCard

                summarySection

                DocumentIntelligenceView(
                    intelligence:
                        intelligence,
                    currentName:
                        currentName,
                    isLoading:
                        isLoadingIntelligence,
                    errorMessage:
                        intelligenceError,
                    isApplyingSmartName:
                        isApplyingSmartName
                ) {
                    suggestedName in

                    applySmartName(
                        suggestedName
                    )
                }

                if organizationDocument
                    .dueDate
                    !=
                    nil {

                    BillReminderCard(
                        document:
                            organizationDocument
                    ) {
                        updated in

                        organizationDocument =
                            updated
                    }
                }

                conversationSection

                metadataSection

                openAnalyzeButton

                reportSection

                originalFileSection

                if let actionError {

                    AppErrorCard(
                        title:
                            "Something went wrong",
                        message:
                            actionError
                    )
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.025)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle(
            "Document"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .task {

            await loadSavedContext()
        }
        .alert(
            "Rename Document",
            isPresented:
                $showRename
        ) {

            TextField(
                "Document name",
                text:
                    $renameText
            )

            Button(
                "Cancel",
                role: .cancel
            ) {}

            Button("Save") {
                renameDocument()
            }

        } message: {

            Text(
                "This changes the name shown in History. It does not modify the original file."
            )
        }
        .sheet(
            isPresented:
                $showOrganize
        ) {

            DocumentOrganizationSheet(
                document:
                    organizationDocument,
                folders:
                    folders
            ) {

                await refreshOrganization()
            }
            .presentationDetents(
                [
                    .medium,
                    .large
                ]
            )
        }
        .fileExporter(
            isPresented:
                $showOriginalExporter,
            document:
                exportDocument,
            contentType:
                exportContentType,
            defaultFilename:
                originalExportFileName
        ) {
            result in

            if case .failure(
                let error
            ) = result {

                actionError =
                    error
                        .localizedDescription
            }

            exportDocument =
                nil
        }
        .sheet(
            isPresented:
                $showReportExporter
        ) {

            ReportExportSheet(
                document:
                    renamedDocumentSnapshot,
                summary:
                    summary,
                conversations:
                    conversations
            )
        }
    }


    // Hero

    private var heroCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            HStack(
                alignment: .top,
                spacing: 15
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                    .fill(
                        document
                            .sourceType
                            == "scan"
                        ? Color.purple
                            .opacity(0.11)
                        : Color.blue
                            .opacity(0.10)
                    )
                    .frame(
                        width: 72,
                        height: 72
                    )

                    Image(
                        systemName:
                            heroIcon
                    )
                    .font(
                        .system(
                            size: 29,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        document
                            .sourceType
                            == "scan"
                        ? .purple
                        : .blue
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text(currentName)
                        .font(
                            .title2
                            .weight(.bold)
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    Text(
                        document
                            .prettyDocumentType
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )

                    HStack(
                        spacing: 7
                    ) {

                        metadataPill(
                            document
                                .sourceType
                                .capitalized,
                            icon:
                                document
                                    .sourceType
                                    == "scan"
                                ? "camera.fill"
                                : "arrow.up.doc.fill"
                        )

                        if document
                            .hasStoredOriginal {

                            metadataPill(
                                "Original saved",
                                icon:
                                    "lock.fill"
                            )
                        }

                        if let folderName {

                            metadataPill(
                                folderName,
                                icon:
                                    "folder.fill"
                            )
                        }
                    }
                }

                Spacer()

                VStack(
                    spacing:
                        8
                ) {

                    Button {

                        toggleFavorite()

                    } label: {

                        Image(
                            systemName:
                                organizationDocument.isFavorite
                                ? "star.fill"
                                : "star"
                        )
                        .foregroundStyle(
                            organizationDocument.isFavorite
                            ? .yellow
                            : .secondary
                        )
                    }
                    .buttonStyle(
                        .bordered
                    )
                    .accessibilityLabel(
                        organizationDocument.isFavorite
                        ? "Remove from favorites"
                        : "Add to favorites"
                    )

                    Button {

                        renameText =
                            currentName

                        showRename =
                            true

                    } label: {

                        Image(
                            systemName:
                                "pencil"
                        )
                    }
                    .buttonStyle(
                        .bordered
                    )
                }
            }


            Button {

                showOrganize =
                    true

            } label: {

                HStack {

                    Label(
                        folderName == nil
                        ? "Organize Document"
                        : "Organize • \(folderName!)",
                        systemImage:
                            "folder"
                    )

                    Spacer()

                    Image(
                        systemName:
                            "chevron.right"
                    )
                    .font(
                        .caption
                    )
                }
            }
            .buttonStyle(
                .bordered
            )
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(
                        .secondarySystemBackground
                    ),
                    Color.blue
                        .opacity(0.035)
                ],
                startPoint:
                    .topLeading,
                endPoint:
                    .bottomTrailing
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.07)
            )
        }
    }


    private var heroIcon:
        String {

        let type =
            document.documentType
                .lowercased()

        if document.sourceType
            == "scan" {

            return
                "camera.viewfinder"
        }

        if type.contains(
            "bank"
        )
        || type.contains(
            "statement"
        ) {

            return
                "building.columns.fill"
        }

        return
            "doc.text.fill"
    }


    private var folderName:
        String? {

        guard
            let folderID =
                organizationDocument
                    .folderID
        else {
            return nil
        }


        return
            folders.first {
                $0.id
                ==
                folderID
            }?
            .name
    }


    private func metadataPill(
        _ text: String,
        icon: String
    ) -> some View {

        Label(
            text,
            systemImage:
                icon
        )
        .font(
            .caption2
            .weight(.semibold)
        )
        .foregroundStyle(
            .secondary
        )
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            6
        )
        .background(
            Color.primary
                .opacity(0.045)
        )
        .clipShape(
            Capsule()
        )
    }


    // Summary

    @ViewBuilder
    private var summarySection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 13
        ) {

            Label(
                "Document summary",
                systemImage:
                    "sparkles.rectangle.stack"
            )
            .font(
                .headline
            )

            if isLoadingContext {

                HStack(
                    spacing: 10
                ) {

                    ProgressView()

                    Text(
                        "Restoring saved document context…"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

            } else if
                let summary {

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(
                        summary
                            .headline
                    )
                    .font(
                        .title3
                        .weight(.semibold)
                    )

                    if let subheadline =
                        summary
                            .subheadline {

                        Text(
                            subheadline
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                if !summary
                    .items
                    .isEmpty {

                    LazyVGrid(
                        columns: [
                            GridItem(
                                .flexible(),
                                spacing: 10
                            ),
                            GridItem(
                                .flexible(),
                                spacing: 10
                            )
                        ],
                        spacing: 10
                    ) {

                        ForEach(
                            summary.items
                        ) {
                            item in

                            summaryTile(
                                item
                            )
                        }
                    }
                }

            } else if
                let contextError {

                Text(
                    contextError
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            } else {

                Text(
                    "No additional summary metadata was available."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(17)
        .background(
            Color.indigo
                .opacity(0.045)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }


    private func summaryTile(
        _ item:
            HistorySummaryItem
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Image(
                systemName:
                    item.systemImage
            )
            .foregroundStyle(
                .indigo
            )

            Text(
                item.label
            )
            .font(
                .caption2
                .weight(.semibold)
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                item.value
            )
            .font(
                .subheadline
                .weight(.semibold)
            )
            .lineLimit(2)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 88,
            alignment: .leading
        )
        .padding(12)
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
        )
    }


    // Saved Conversation

    @ViewBuilder
    private var conversationSection:
        some View {

        if !conversations
            .isEmpty {

            ConversationHistoryView(
                conversations:
                    conversations,
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

        } else if
            !isLoadingContext {

            VStack(
                alignment: .leading,
                spacing: 7
            ) {

                Label(
                    "Saved conversation",
                    systemImage:
                        "bubble.left.and.text.bubble.right"
                )
                .font(.headline)

                Text(
                    "No saved Q&A yet. Open this document in Analyze and ask a question to start a persistent conversation."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
            .padding(16)
            .background(
                Color.primary
                    .opacity(0.025)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
    }


    // Metadata

    private var metadataSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "File details",
                systemImage:
                    "info.circle"
            )
            .font(.headline)

            detailRow(
                title:
                    "Processed",
                value:
                    document
                        .createdAt
                        .formatted(
                            date: .long,
                            time: .shortened
                        ),
                icon:
                    "calendar"
            )

            detailRow(
                title:
                    "Original file",
                value:
                    document
                        .fileName,
                icon:
                    "doc"
            )

            detailRow(
                title:
                    "Document type",
                value:
                    document
                        .prettyDocumentType,
                icon:
                    "doc.text"
            )

            if let dueDate =
                organizationDocument
                    .dueDate {

                detailRow(
                    title:
                        "Due date",
                    value:
                        dueDate
                            .formatted(
                                date:
                                    .long,
                                time:
                                    .omitted
                            ),
                    icon:
                        organizationDocument
                            .reminderEnabled
                        ? "bell.badge.fill"
                        : "calendar.badge.clock"
                )
            }

            if let mime =
                document
                    .originalMimeType {

                detailRow(
                    title:
                        "File format",
                    value:
                        mime,
                    icon:
                        "square.and.arrow.down"
                )
            }

            if let bytes =
                document
                    .originalSizeBytes {

                detailRow(
                    title:
                        "Stored size",
                    value:
                        ByteCountFormatter
                            .string(
                                fromByteCount:
                                    bytes,
                                countStyle:
                                    .file
                            ),
                    icon:
                        "externaldrive"
                )
            }
        }
        .padding(17)
        .background(
            Color.primary
                .opacity(0.025)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }


    private func detailRow(
        title: String,
        value: String,
        icon: String
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {

            Image(
                systemName:
                    icon
            )
            .foregroundStyle(
                .blue
            )
            .frame(width: 24)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(title)
                    .font(
                        .caption
                        .weight(.semibold)
                    )
                    .foregroundStyle(
                        .secondary
                    )

                Text(value)
                    .font(.body)
                    .textSelection(
                        .enabled
                    )
            }

            Spacer()
        }
    }


    // Analyze

    private var openAnalyzeButton:
        some View {

        Button {

            openSavedDocument()

        } label: {

            HStack(spacing: 11) {

                if isOpening {

                    ProgressView()
                        .tint(.white)

                } else {

                    Image(
                        systemName:
                            "sparkles"
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(
                        isOpening
                        ? "Restoring document…"
                        : "Continue in Analyze"
                    )
                    .font(
                        .headline
                    )

                    if !isOpening {

                        Text(
                            conversations.isEmpty
                            ? "Ask your first question"
                            : "Restore \(conversations.count) saved Q&A and keep going"
                        )
                        .font(.caption2)
                        .opacity(0.80)
                    }
                }

                Spacer()

                if !isOpening {

                    Image(
                        systemName:
                            "arrow.right"
                    )
                }
            }
            .padding(16)
            .frame(
                maxWidth:
                    .infinity
            )
            .foregroundStyle(
                .white
            )
            .background(
                LinearGradient(
                    colors: [
                        .blue,
                        .indigo
                    ],
                    startPoint:
                        .topLeading,
                    endPoint:
                        .bottomTrailing
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 19,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(
            isOpening
            ||
            !network.isConnected
        )
        .opacity(
            network.isConnected
            ? 1
            : 0.55
        )
    }


    // Report

    private var reportSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 11
        ) {

            HStack(
                spacing: 10
            ) {

                Image(
                    systemName:
                        "doc.richtext.fill"
                )
                .foregroundStyle(
                    .indigo
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(
                        "Explanation report"
                    )
                    .font(.headline)

                    Text(
                        "Export the summary plus selected saved AI explanations."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Button {

                showReportExporter =
                    true

            } label: {

                Label(
                    "Choose Explanations & Export PDF",
                    systemImage:
                        "square.and.arrow.up"
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
            .buttonStyle(
                .bordered
            )
            .disabled(
                isLoadingContext
            )
        }
        .padding(16)
        .background(
            Color.indigo
                .opacity(0.045)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
        )
    }


    // Original

    @ViewBuilder
    private var originalFileSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack(
                spacing: 10
            ) {

                Image(
                    systemName:
                        "lock.doc.fill"
                )
                .foregroundStyle(
                    .green
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(
                        "Original document"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        document
                            .hasStoredOriginal
                        ? "Private Supabase Storage"
                        : "Not available for this older history item"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            if document
                .hasStoredOriginal {

                Button {

                    downloadOriginal()

                } label: {

                    HStack {

                        if isDownloading {

                            ProgressView()

                        } else {

                            Image(
                                systemName:
                                    "square.and.arrow.down"
                            )
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {

                            Text(
                                isDownloading
                                ? "Preparing original…"
                                : "Save Original Copy"
                            )
                            .font(
                                .subheadline
                                .weight(.semibold)
                            )

                            if !isDownloading {

                                Text(
                                    "Recover the stored PDF or scan"
                                )
                                .font(.caption2)
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }

                        Spacer()

                        if !isDownloading {

                            Image(
                                systemName:
                                    "chevron.right"
                            )
                            .font(.caption)
                        }
                    }
                }
                .buttonStyle(
                    .bordered
                )
                .disabled(
                    isDownloading
                    ||
                    !network.isConnected
                )

            } else {

                Text(
                    "This document was saved before original-file Storage was enabled. Its extracted history can still be reopened, but the original PDF/image cannot be recovered."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(16)
        .background(
            Color.green
                .opacity(0.055)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
        )
    }


    // Load Context

    private func loadSavedContext()
        async {

        guard
            network.isConnected
        else {

            isLoadingContext =
                false

            isLoadingIntelligence =
                false

            contextError =
                "Reconnect to load the saved summary and conversation."

            intelligenceError =
                "Reconnect to load document intelligence."

            return
        }

        isLoadingContext =
            true

        isLoadingIntelligence =
            true

        contextError =
            nil

        intelligenceError =
            nil


        async let intelligenceTask:
            DocumentIntelligence? =
            try?
            await DocumentIntelligenceService
                .shared
                .load(
                    document:
                        document
                )


        do {

            async let summaryTask =
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

            async let foldersTask =
                DocumentFolderService
                    .shared
                    .fetchFolders()

            async let organizationTask =
                DocumentHistoryService
                    .shared
                    .fetchDocument(
                        id:
                            document.id
                    )

            let loadedSummary =
                try await
                    summaryTask

            let loadedConversations =
                try await
                    conversationTask

            let loadedFolders =
                try await
                    foldersTask

            let loadedOrganization =
                try await
                    organizationTask


            await MainActor.run {

                summary =
                    loadedSummary

                conversations =
                    loadedConversations

                folders =
                    loadedFolders

                organizationDocument =
                    loadedOrganization
            }

        } catch {

            await MainActor.run {

                contextError =
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


        let loadedIntelligence =
            await intelligenceTask


        var automaticSmartName:
            String?


        await MainActor.run {

            intelligence =
                loadedIntelligence

            intelligenceError =
                loadedIntelligence
                ==
                nil
                ? "The saved document could not be analyzed for additional intelligence."
                : nil


            if let loadedIntelligence,
               loadedIntelligence
                .shouldAutoApplySuggestedName,
               (
                    organizationDocument
                        .displayName?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                    ??
                    true
               ),
               let suggested =
                    loadedIntelligence
                        .suggestedName,
               suggested
                !=
                currentName {

                automaticSmartName =
                    suggested
            }


            isLoadingContext =
                false

            isLoadingIntelligence =
                false
        }


        if let automaticSmartName {

            await MainActor.run {

                applySmartName(
                    automaticSmartName,
                    automatic:
                        true
                )
            }
        }
    }

    // Conversation Actions

    private func deleteConversation(
        _ conversation:
            DocumentConversation
    ) {

        guard
            network.isConnected
        else {

            actionError =
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

                await MainActor.run {

                    conversations
                        .removeAll {
                            $0.id
                                ==
                            conversation.id
                        }
                }

            } catch {

                await MainActor.run {

                    actionError =
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
    }


    private func clearConversation() {

        guard
            network.isConnected
        else {

            actionError =
                "Reconnect before clearing saved Q&A."

            return
        }

        Task {

            do {

                try await
                    ConversationService
                        .shared
                        .clear(
                            documentID:
                                document.id
                        )

                await MainActor.run {

                    conversations =
                        []
                }

            } catch {

                await MainActor.run {

                    actionError =
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
    }


    // Organization

    @MainActor
    private func refreshOrganization()
        async {

        do {

            async let documentTask =
                DocumentHistoryService
                    .shared
                    .fetchDocument(
                        id:
                            document.id
                    )

            async let foldersTask =
                DocumentFolderService
                    .shared
                    .fetchFolders()


            organizationDocument =
                try await documentTask

            folders =
                try await foldersTask

        } catch {

            actionError =
                AppFriendlyError
                    .message(
                        for:
                            error,
                        context:
                            .history,
                        isConnected:
                            network.isConnected
                    )
        }
    }


    private func toggleFavorite() {

        guard
            network.isConnected
        else {

            actionError =
                "Reconnect before changing favorites."

            return
        }


        let newValue =
            !organizationDocument
                .isFavorite


        Task {

            do {

                try await
                    DocumentHistoryService
                        .shared
                        .setFavorite(
                            id:
                                document.id,
                            isFavorite:
                                newValue
                        )


                await refreshOrganization()

            } catch {

                await MainActor.run {

                    actionError =
                        AppFriendlyError
                            .message(
                                for:
                                    error,
                                context:
                                    .history,
                                isConnected:
                                    network.isConnected
                            )
                }
            }
        }
    }


    // Smart Naming

    @MainActor
    private func applySmartName(
        _ proposedName:
            String,
        automatic:
            Bool = false
    ) {

        guard
            !isApplyingSmartName
        else {
            return
        }


        guard
            network
                .isConnected
        else {

            if !automatic {

                actionError =
                    "Reconnect before applying the smart document name."
            }

            return
        }


        let clean =
            proposedName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !clean
                .isEmpty,
            clean
            !=
            currentName
        else {
            return
        }


        isApplyingSmartName =
            true


        Task {

            do {

                try await
                    DocumentHistoryService
                        .shared
                        .renameDocument(
                            id:
                                document
                                    .id,
                            displayName:
                                clean
                        )


                let refreshed =
                    try await
                        DocumentHistoryService
                            .shared
                            .fetchDocument(
                                id:
                                    document
                                        .id
                            )


                await MainActor.run {

                    currentName =
                        clean

                    renameText =
                        clean

                    organizationDocument =
                        refreshed

                    onRenamed(
                        clean
                    )

                    isApplyingSmartName =
                        false
                }


            } catch {

                await MainActor.run {

                    if !automatic {

                        actionError =
                            AppFriendlyError
                                .message(
                                    for:
                                        error,
                                    context:
                                        .history,
                                    isConnected:
                                        network
                                            .isConnected
                                )
                    }

                    isApplyingSmartName =
                        false
                }
            }
        }
    }


    // Rename

    private func renameDocument() {

        guard
            !isRenaming
        else {
            return
        }

        guard
            network.isConnected
        else {

            actionError =
                "Reconnect before renaming this document."

            return
        }

        isRenaming =
            true

        actionError =
            nil

        let proposedName =
            renameText

        Task {

            do {

                try await
                    DocumentHistoryService
                        .shared
                        .renameDocument(
                            id:
                                document.id,
                            displayName:
                                proposedName
                        )

                let clean =
                    proposedName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                await MainActor.run {

                    currentName =
                        clean

                    onRenamed(
                        clean
                    )

                    isRenaming =
                        false
                }

            } catch {

                await MainActor.run {

                    actionError =
                        AppFriendlyError
                            .message(
                                for: error,
                                context:
                                    .history,
                                isConnected:
                                    network
                                        .isConnected
                            )

                    isRenaming =
                        false
                }
            }
        }
    }


    // Original Download

    private func downloadOriginal() {

        guard
            !isDownloading,
            let path =
                document
                    .storagePath
        else {
            return
        }

        guard
            network.isConnected
        else {

            actionError =
                "Reconnect before downloading the saved original."

            return
        }

        isDownloading =
            true

        actionError =
            nil

        Task {

            do {

                let data =
                    try await
                        DocumentHistoryService
                            .shared
                            .downloadOriginal(
                                path:
                                    path
                            )

                let contentType =
                    preferredContentType

                await MainActor.run {

                    exportDocument =
                        HistoryOriginalExportDocument(
                            data:
                                data
                        )

                    exportContentType =
                        contentType

                    isDownloading =
                        false

                    showOriginalExporter =
                        true
                }

            } catch {

                await MainActor.run {

                    actionError =
                        AppFriendlyError
                            .message(
                                for: error,
                                context:
                                    .download,
                                isConnected:
                                    network
                                        .isConnected
                            )

                    isDownloading =
                        false
                }
            }
        }
    }


    // Open in Analyze

    private func openSavedDocument() {

        guard
            !isOpening
        else {
            return
        }

        guard
            network.isConnected
        else {

            actionError =
                "Reconnect before opening this saved document."

            return
        }

        isOpening =
            true

        actionError =
            nil

        Task {

            do {

                let context =
                    try await
                        DocumentContinuityService
                            .shared
                            .load(
                                document:
                                    renamedDocumentSnapshot
                            )

                await MainActor.run {

                    dismiss()

                    documentWorkspace
                        .openFromHistory(
                            financialDocument:
                                context
                                    .financialDocument,
                            historyDocumentID:
                                document.id,
                            displayName:
                                currentName,
                            summary:
                                context
                                    .summary,
                            conversations:
                                context
                                    .conversations
                        )
                }

            } catch {

                await MainActor.run {

                    actionError =
                        AppFriendlyError
                            .message(
                                for: error,
                                context:
                                    .history,
                                isConnected:
                                    network
                                        .isConnected
                            )

                    isOpening =
                        false
                }
            }
        }
    }


    // Export Helpers

    private var preferredContentType:
        UTType {

        if let mime =
            document
                .originalMimeType,
           let type =
            UTType(
                mimeType:
                    mime
            ) {

            return type
        }

        let ext =
            (
                document.fileName
                as NSString
            )
            .pathExtension

        if let type =
            UTType(
                filenameExtension:
                    ext
            ) {

            return type
        }

        return .data
    }


    private var originalExportFileName:
        String {

        if document.sourceType
            != "scan" {

            return
                document.fileName
        }

        let ext =
            (
                document.fileName
                as NSString
            )
            .pathExtension

        let safeBase =
            currentName
                .replacingOccurrences(
                    of: "/",
                    with: "-"
                )
                .replacingOccurrences(
                    of: ":",
                    with: "-"
                )

        if ext.isEmpty {

            return safeBase
        }

        return
            "\(safeBase).\(ext)"
    }


    private var renamedDocumentSnapshot:
        HistoryDocument {

        var snapshot =
            organizationDocument

        snapshot.displayName =
            currentName

        return snapshot
    }
}


// Original File Export

private struct HistoryOriginalExportDocument:
    FileDocument {

    static var readableContentTypes:
        [UTType] {

        [
            .data,
            .pdf,
            .jpeg,
            .png
        ]
    }

    let data: Data

    init(
        data: Data
    ) {

        self.data =
            data
    }

    init(
        configuration:
            ReadConfiguration
    ) throws {

        data =
            configuration
                .file
                .regularFileContents
            ??
            Data()
    }

    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {

        FileWrapper(
            regularFileWithContents:
                data
        )
    }
}
