// document selection screen.

import SwiftUI


struct CrossDocumentHubView: View {

    @ObservedObject private var network =
        NetworkMonitor.shared

    @State private var documents:
        [HistoryDocument] = []

    @State private var selectedIDs:
        Set<UUID> = []

    @State private var searchText =
        ""

    @State private var isLoading =
        true

    @State private var errorMessage:
        String?

    @State private var showAnalyzer =
        false


    var body: some View {

        NavigationStack {

            ZStack {

                LinearGradient(
                    colors: [
                        Color(
                            .systemBackground
                        ),
                        Color.indigo
                            .opacity(
                                0.035
                            ),
                        Color.blue
                            .opacity(
                                0.025
                            )
                    ],
                    startPoint:
                        .topLeading,
                    endPoint:
                        .bottomTrailing
                )
                .ignoresSafeArea()


                Group {

                    if isLoading {

                        ProgressView(
                            "Loading documents…"
                        )

                    } else if
                        documents
                            .isEmpty {

                        ContentUnavailableView(
                            "No documents yet",
                            systemImage:
                                "doc.text.magnifyingglass",
                            description:
                                Text(
                                    "Analyze at least two statements or bills before using cross-document insights."
                                )
                        )

                    } else {

                        documentSelectionList
                    }
                }
            }
            .navigationTitle(
                "Insights"
            )
            .navigationBarTitleDisplayMode(
                .large
            )
            .searchable(
                text:
                    $searchText,
                prompt:
                    "Search saved documents"
            )
            .safeAreaInset(
                edge:
                    .bottom
            ) {

                analyzeBar
            }
            .task {

                await load()
            }
            .refreshable {

                await load()
            }
            .navigationDestination(
                isPresented:
                    $showAnalyzer
            ) {

                CrossDocumentAnalyzerView(
                    documents:
                        selectedDocuments
                )
            }
        }
    }


    // Selection List

    private var documentSelectionList:
        some View {

        ScrollView {

            LazyVStack(
                alignment:
                    .leading,
                spacing:
                    13
            ) {

                introCard


                if let errorMessage {

                    AppErrorCard(
                        title:
                            "Couldn't refresh documents",
                        message:
                            errorMessage,
                        retryTitle:
                            network
                                .isConnected
                            ? "Try Again"
                            : nil,
                        retry: {

                            Task {

                                await load()
                            }
                        }
                    )
                }


                if visibleDocuments
                    .isEmpty {

                    ContentUnavailableView(
                        "No matching documents",
                        systemImage:
                            "magnifyingglass",
                        description:
                            Text(
                                "Try another search."
                            )
                    )
                    .padding(
                        .top,
                        30
                    )

                } else {

                    ForEach(
                        visibleDocuments
                    ) {
                        document in

                        selectionCard(
                            document
                        )
                    }
                }
            }
            .padding(
                .horizontal,
                16
            )
            .padding(
                .top,
                10
            )
            .padding(
                .bottom,
                120
            )
        }
    }


    private var introCard:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {

            Label(
                "Compare multiple financial documents",
                systemImage:
                    "square.stack.3d.up.fill"
            )
            .font(
                .headline
            )
            .foregroundStyle(
                .indigo
            )


            Text(
                "Select 2–8 saved statements or bills. The app calculates spending differences and recurring-payment patterns in Swift, then AI can explain only those verified facts."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )


            HStack(
                spacing:
                    8
            ) {

                Label(
                    "No new Veryfi charge",
                    systemImage:
                        "checkmark.shield.fill"
                )

                Text(
                    "•"
                )

                Label(
                    "Currencies stay separate",
                    systemImage:
                        "dollarsign.arrow.circlepath"
                )
            }
            .font(
                .caption2
                .weight(.semibold)
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            16
        )
        .background(
            Color.indigo
                .opacity(
                    0.055
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    19,
                style:
                    .continuous
            )
        )
    }


    private func selectionCard(
        _ document:
            HistoryDocument
    ) -> some View {

        let isSelected =
            selectedIDs
                .contains(
                    document.id
                )


        return
            Button {

                toggle(
                    document
                )

            } label: {

                HStack(
                    spacing:
                        13
                ) {

                    Image(
                        systemName:
                            isSelected
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .font(
                        .title2
                    )
                    .foregroundStyle(
                        isSelected
                        ? .blue
                        : .secondary
                    )


                    ZStack {

                        RoundedRectangle(
                            cornerRadius:
                                13,
                            style:
                                .continuous
                        )
                        .fill(
                            documentTint(
                                document
                            )
                            .opacity(
                                0.09
                            )
                        )
                        .frame(
                            width:
                                44,
                            height:
                                44
                        )


                        Image(
                            systemName:
                                documentIcon(
                                    document
                                )
                        )
                        .foregroundStyle(
                            documentTint(
                                document
                            )
                        )
                    }


                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            4
                    ) {

                        Text(
                            document
                                .resolvedDisplayName
                        )
                        .font(
                            .subheadline
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .primary
                        )
                        .lineLimit(
                            2
                        )


                        Text(
                            document
                                .prettyDocumentType
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )


                        Text(
                            "Processed \(document.createdAt.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                    }


                    Spacer()


                    if isSelected {

                        Text(
                            "\(selectionPosition(document.id))"
                        )
                        .font(
                            .caption
                            .weight(.bold)
                        )
                        .foregroundStyle(
                            .blue
                        )
                        .frame(
                            width:
                                26,
                            height:
                                26
                        )
                        .background(
                            Color.blue
                                .opacity(
                                    0.10
                                )
                        )
                        .clipShape(
                            Circle()
                        )
                    }
                }
                .padding(
                    14
                )
                .background(
                    isSelected
                    ? Color.blue
                        .opacity(
                            0.055
                        )
                    : Color(
                        .secondarySystemBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                )
                .overlay {

                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                    .stroke(
                        isSelected
                        ? Color.blue
                            .opacity(
                                0.25
                            )
                        : Color.primary
                            .opacity(
                                0.06
                            )
                    )
                }
            }
            .buttonStyle(
                .plain
            )
            .disabled(
                !isSelected
                &&
                selectedIDs.count
                    >=
                8
            )
    }


    // Bottom Analyze Bar

    private var analyzeBar:
        some View {

        VStack(
            spacing:
                8
        ) {

            if !network
                .isConnected {

                Text(
                    "Reconnect to load saved document data."
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )

            } else if selectedIDs.count
                ==
                1 {

                Text(
                    "Select at least one more document"
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Button {

                showAnalyzer =
                    true

            } label: {

                HStack {

                    Image(
                        systemName:
                            "sparkles.rectangle.stack.fill"
                    )


                    Text(
                        selectedIDs.count
                        >=
                        2
                        ? "Analyze \(selectedIDs.count) Documents"
                        : "Select 2–8 Documents"
                    )


                    Spacer()


                    Image(
                        systemName:
                            "arrow.right"
                    )
                }
                .font(
                    .headline
                )
                .padding(
                    16
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
                            .leading,
                        endPoint:
                            .trailing
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                )
            }
            .buttonStyle(
                .plain
            )
            .disabled(
                selectedIDs.count
                    <
                2
                ||
                !network
                    .isConnected
            )
            .opacity(
                selectedIDs.count
                    >=
                2
                &&
                network
                    .isConnected
                ? 1
                : 0.55
            )
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .vertical,
            10
        )
        .background(
            .ultraThinMaterial
        )
    }


    // Filtering

    private var visibleDocuments:
        [HistoryDocument] {

        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        if query
            .isEmpty {

            return documents
        }


        return
            documents.filter {
                document in

                document
                    .resolvedDisplayName
                    .localizedCaseInsensitiveContains(
                        query
                    )
                ||
                document
                    .prettyDocumentType
                    .localizedCaseInsensitiveContains(
                        query
                    )
                ||
                document
                    .fileName
                    .localizedCaseInsensitiveContains(
                        query
                    )
            }
    }


    private var selectedDocuments:
        [HistoryDocument] {

        documents.filter {
            selectedIDs
                .contains(
                    $0.id
                )
        }
    }


    private func toggle(
        _ document:
            HistoryDocument
    ) {

        if selectedIDs
            .contains(
                document.id
            ) {

            selectedIDs
                .remove(
                    document.id
                )

        } else if
            selectedIDs.count
            <
            8 {

            selectedIDs
                .insert(
                    document.id
                )
        }
    }


    private func selectionPosition(
        _ id:
            UUID
    ) -> Int {

        let ordered =
            documents.filter {
                selectedIDs
                    .contains(
                        $0.id
                    )
            }


        return
            (
                ordered.firstIndex {
                    $0.id
                    ==
                    id
                }
                ??
                0
            )
            +
            1
    }


    // Load

    @MainActor
    private func load()
        async {

        guard
            network
                .isConnected
        else {

            isLoading =
                false

            errorMessage =
                "You're offline. Reconnect to load saved documents."

            return
        }


        if documents
            .isEmpty {

            isLoading =
                true
        }


        do {

            documents =
                try await
                    DocumentHistoryService
                        .shared
                        .fetchDocuments()


            selectedIDs =
                selectedIDs
                    .intersection(
                        Set(
                            documents.map(
                                \.id
                            )
                        )
                    )


            errorMessage =
                nil

        } catch {

            errorMessage =
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


        isLoading =
            false
    }


    // Card Style

    private func documentIcon(
        _ document:
            HistoryDocument
    ) -> String {

        let type =
            document
                .documentType
                .lowercased()


        if type.contains(
            "bank"
        )
        ||
        type.contains(
            "statement"
        ) {

            return
                "building.columns.fill"
        }


        if type.contains(
            "bill"
        )
        ||
        type.contains(
            "invoice"
        ) {

            return
                "doc.text.fill"
        }


        return
            document.sourceType
            ==
            "scan"
            ? "camera.viewfinder"
            : "doc.fill"
    }


    private func documentTint(
        _ document:
            HistoryDocument
    ) -> Color {

        let type =
            document
                .documentType
                .lowercased()


        if type.contains(
            "bank"
        )
        ||
        type.contains(
            "statement"
        ) {

            return
                .blue
        }


        if type.contains(
            "bill"
        )
        ||
        type.contains(
            "invoice"
        ) {

            return
                .orange
        }


        return
            .indigo
    }
}
