// Document Organization
//
// Adds favorites / pinning and user-created folders while
// preserving the existing History -> Detail flow.

import SwiftUI


struct DocumentHistoryView:
    View {

    @EnvironmentObject private var session:
        AppSessionController

    @ObservedObject private var network =
        NetworkMonitor.shared

    @State private var documents:
        [HistoryDocument] = []

    @State private var folders:
        [DocumentFolder] = []

    @State private var isLoading =
        true

    @State private var errorMessage:
        String?

    @State private var showAccount =
        false

    @State private var showFilters =
        false

    @State private var showFolderManager =
        false

    @State private var organizationTarget:
        HistoryOrganizationTarget?

    @State private var searchText =
        ""

    @State private var sortOption:
        HistorySortOption =
        .newest

    @State private var sourceFilter:
        HistorySourceFilter =
        .all

    @State private var originalFilter:
        HistoryOriginalFilter =
        .all

    @State private var favoriteFilter:
        HistoryFavoriteFilter =
        .all

    @State private var documentTypeFilter =
        "ALL"

    @State private var folderFilterID:
        UUID?


    var body: some View {

        NavigationStack {

            ZStack {

                historyBackground


                Group {

                    if isLoading
                        &&
                        documents.isEmpty {

                        loadingState

                    } else if
                        let errorMessage,
                        documents.isEmpty {

                        errorState(
                            message:
                                errorMessage
                        )

                    } else if
                        documents.isEmpty {

                        emptyState

                    } else {

                        documentList
                    }
                }
            }
            .safeAreaInset(
                edge:
                    .top,
                spacing:
                    0
            ) {

                if !network
                    .isConnected {

                    OfflineBanner(
                        message:
                            documents.isEmpty
                            ? "Reconnect to load your saved documents."
                            : "You're viewing the last loaded History list. Reconnect to organize, refresh, reopen, or delete documents."
                    )
                    .padding(
                        .horizontal,
                        16
                    )
                    .padding(
                        .bottom,
                        8
                    )
                }
            }
            .navigationTitle(
                "History"
            )
            .searchable(
                text:
                    $searchText,
                placement:
                    .navigationBarDrawer(
                        displayMode:
                            .always
                    ),
                prompt:
                    "Search documents or folders"
            )
            .toolbar {

                ToolbarItemGroup(
                    placement:
                        .topBarTrailing
                ) {

                    Button {

                        showFolderManager =
                            true

                    } label: {

                        Image(
                            systemName:
                                "folder.badge.gearshape"
                        )
                    }
                    .accessibilityLabel(
                        "Manage folders"
                    )


                    Button {

                        showFilters =
                            true

                    } label: {

                        Image(
                            systemName:
                                hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                    .accessibilityLabel(
                        "Sort and filter history"
                    )


                    Button {

                        showAccount =
                            true

                    } label: {

                        Image(
                            systemName:
                                "person.crop.circle.fill"
                        )
                        .font(
                            .system(
                                size:
                                    22
                            )
                        )
                    }
                    .accessibilityLabel(
                        "Account"
                    )
                }
            }
            .sheet(
                isPresented:
                    $showFilters
            ) {

                HistoryFilterSheet(
                    sortOption:
                        $sortOption,
                    sourceFilter:
                        $sourceFilter,
                    originalFilter:
                        $originalFilter,
                    favoriteFilter:
                        $favoriteFilter,
                    documentTypeFilter:
                        $documentTypeFilter,
                    folderFilterID:
                        $folderFilterID,
                    availableDocumentTypes:
                        availableDocumentTypes,
                    folders:
                        folders
                )
                .presentationDetents(
                    [
                        .medium,
                        .large
                    ]
                )
            }
            .sheet(
                isPresented:
                    $showFolderManager
            ) {

                FolderManagerView {

                    await loadHistory()
                }
            }
            .sheet(
                item:
                    $organizationTarget
            ) {
                target in

                DocumentOrganizationSheet(
                    document:
                        target.document,
                    folders:
                        folders
                ) {

                    await loadHistory()
                }
                .presentationDetents(
                    [
                        .medium,
                        .large
                    ]
                )
            }
            .sheet(
                isPresented:
                    $showAccount
            ) {

                AccountManagementView()
                    .environmentObject(
                        session
                    )
                    .presentationDetents(
                        [
                            .medium,
                            .large
                        ]
                    )
            }
            .task {

                await loadHistory()
            }
            .onAppear {

                Task {

                    if network
                        .isConnected {

                        await loadHistory()
                    }
                }
            }
        }
    }


    // Visible Documents

    private var visibleDocuments:
        [HistoryDocument] {

        var result =
            documents


        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        if !query.isEmpty {

            result =
                result.filter {
                    document in

                    let dateText =
                        document
                            .createdAt
                            .formatted(
                                date:
                                    .abbreviated,
                                time:
                                    .omitted
                            )

                    let folder =
                        folderName(
                            for:
                                document.folderID
                        )
                        ??
                        ""


                    return
                        document
                            .resolvedDisplayName
                            .localizedCaseInsensitiveContains(
                                query
                            )
                        ||
                        document
                            .fileName
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
                            .sourceType
                            .localizedCaseInsensitiveContains(
                                query
                            )
                        ||
                        folder
                            .localizedCaseInsensitiveContains(
                                query
                            )
                        ||
                        dateText
                            .localizedCaseInsensitiveContains(
                                query
                            )
                }
        }


        if favoriteFilter
            ==
            .favorites {

            result =
                result.filter(
                    \.isFavorite
                )
        }


        if let folderFilterID {

            result =
                result.filter {
                    $0.folderID
                    ==
                    folderFilterID
                }
        }


        switch sourceFilter {

        case .all:
            break

        case .uploads:

            result =
                result.filter {
                    $0.sourceType
                    ==
                    "upload"
                }

        case .scans:

            result =
                result.filter {
                    $0.sourceType
                    ==
                    "scan"
                }
        }


        switch originalFilter {

        case .all:
            break

        case .stored:

            result =
                result.filter(
                    \.hasStoredOriginal
                )

        case .missing:

            result =
                result.filter {
                    !$0.hasStoredOriginal
                }
        }


        if documentTypeFilter
            !=
            "ALL" {

            result =
                result.filter {
                    $0.prettyDocumentType
                    ==
                    documentTypeFilter
                }
        }


        switch sortOption {

        case .newest:

            result.sort {
                $0.createdAt
                >
                $1.createdAt
            }

        case .oldest:

            result.sort {
                $0.createdAt
                <
                $1.createdAt
            }

        case .favorites:

            result.sort {
                lhs,
                rhs in

                if lhs.isFavorite
                    !=
                    rhs.isFavorite {

                    return
                        lhs.isFavorite
                }


                return
                    lhs.createdAt
                    >
                    rhs.createdAt
            }

        case .nameAZ:

            result.sort {
                $0.resolvedDisplayName
                    .localizedCaseInsensitiveCompare(
                        $1.resolvedDisplayName
                    )
                ==
                .orderedAscending
            }

        case .nameZA:

            result.sort {
                $0.resolvedDisplayName
                    .localizedCaseInsensitiveCompare(
                        $1.resolvedDisplayName
                    )
                ==
                .orderedDescending
            }

        case .type:

            result.sort {
                lhs,
                rhs in

                if lhs.prettyDocumentType
                    ==
                    rhs.prettyDocumentType {

                    return
                        lhs.createdAt
                        >
                        rhs.createdAt
                }


                return
                    lhs.prettyDocumentType
                        .localizedCaseInsensitiveCompare(
                            rhs.prettyDocumentType
                        )
                    ==
                    .orderedAscending
            }
        }


        return result
    }


    private var availableDocumentTypes:
        [String] {

        Array(
            Set(
                documents.map {
                    $0.prettyDocumentType
                }
            )
        )
        .sorted()
    }


    private var hasActiveFilters:
        Bool {

        favoriteFilter
            !=
            .all
        ||
        folderFilterID
            !=
            nil
        ||
        sourceFilter
            !=
            .all
        ||
        originalFilter
            !=
            .all
        ||
        documentTypeFilter
            !=
            "ALL"
        ||
        sortOption
            !=
            .newest
    }


    // List

    private var documentList:
        some View {

        ScrollView {

            LazyVStack(
                alignment:
                    .leading,
                spacing:
                    14
            ) {

                historyHeader


                if !folders.isEmpty {

                    folderQuickFilters
                }


                if hasActiveFilters {

                    activeFiltersRow
                }


                if visibleDocuments.isEmpty {

                    noResultsState
                        .frame(
                            minHeight:
                                390
                        )

                } else {

                    ForEach(
                        visibleDocuments
                    ) {
                        document in

                        NavigationLink {

                            HistoryDocumentDetailView(
                                document:
                                    document,
                                onRenamed: {
                                    newName in

                                    if let index =
                                        documents.firstIndex(
                                            where: {
                                                $0.id
                                                ==
                                                document.id
                                            }
                                        ) {

                                        documents[
                                            index
                                        ]
                                        .displayName =
                                            newName
                                    }
                                }
                            )

                        } label: {

                            HistoryDocumentCard(
                                document:
                                    document,
                                folderName:
                                    folderName(
                                        for:
                                            document.folderID
                                    )
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                        .contextMenu {

                            Button {

                                toggleFavorite(
                                    document
                                )

                            } label: {

                                Label(
                                    document.isFavorite
                                    ? "Remove Favorite"
                                    : "Add Favorite",
                                    systemImage:
                                        document.isFavorite
                                        ? "star.slash"
                                        : "star"
                                )
                            }


                            Button {

                                organizationTarget =
                                    HistoryOrganizationTarget(
                                        document:
                                            document
                                    )

                            } label: {

                                Label(
                                    "Move / Organize",
                                    systemImage:
                                        "folder"
                                )
                            }


                            Divider()


                            Button(
                                role:
                                    .destructive
                            ) {

                                Task {

                                    await delete(
                                        document
                                    )
                                }

                            } label: {

                                Label(
                                    "Delete",
                                    systemImage:
                                        "trash"
                                )
                            }
                        }
                    }
                }
            }
            .padding(
                .horizontal,
                16
            )
            .padding(
                .top,
                8
            )
            .padding(
                .bottom,
                40
            )
        }
        .refreshable {

            await loadHistory()
        }
    }


    private var historyHeader:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {

            HStack(
                alignment:
                    .bottom
            ) {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        4
                ) {

                    Text(
                        "Your financial documents"
                    )
                    .font(
                        .title3
                        .weight(.bold)
                    )


                    Text(
                        "Pin important documents and organize statements or bills into your own folders."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Spacer()


                Text(
                    "\(visibleDocuments.count)"
                )
                .font(
                    .headline
                    .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
            }


            HStack(
                spacing:
                    8
            ) {

                Label(
                    "\(documents.filter(\.isFavorite).count) favorite\(documents.filter(\.isFavorite).count == 1 ? "" : "s")",
                    systemImage:
                        "star.fill"
                )


                Label(
                    "\(folders.count) folder\(folders.count == 1 ? "" : "s")",
                    systemImage:
                        "folder.fill"
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
            .bottom,
            2
        )
    }


    private var folderQuickFilters:
        some View {

        ScrollView(
            .horizontal,
            showsIndicators:
                false
        ) {

            HStack(
                spacing:
                    8
            ) {

                folderChip(
                    title:
                        "All",
                    icon:
                        "tray.full",
                    id:
                        nil
                )


                ForEach(
                    folders
                ) {
                    folder in

                    folderChip(
                        title:
                            folder.name,
                        icon:
                            folder.iconName,
                        id:
                            folder.id
                    )
                }
            }
        }
    }


    private func folderChip(
        title:
            String,
        icon:
            String,
        id:
            UUID?
    ) -> some View {

        Button {

            withAnimation(
                .easeInOut(
                    duration:
                        0.18
                )
            ) {

                folderFilterID =
                    id
            }

        } label: {

            Label(
                title,
                systemImage:
                    icon
            )
            .font(
                .caption
                .weight(.semibold)
            )
            .padding(
                .horizontal,
                11
            )
            .padding(
                .vertical,
                8
            )
            .background(
                folderFilterID
                ==
                id
                ? Color.blue.opacity(0.13)
                : Color.primary.opacity(0.045)
            )
            .clipShape(
                Capsule()
            )
        }
        .buttonStyle(
            .plain
        )
    }


    private var activeFiltersRow:
        some View {

        ScrollView(
            .horizontal,
            showsIndicators:
                false
        ) {

            HStack(
                spacing:
                    7
            ) {

                if sortOption
                    !=
                    .newest {

                    filterChip(
                        sortOption.rawValue
                    )
                }


                if favoriteFilter
                    ==
                    .favorites {

                    filterChip(
                        "Favorites only"
                    )
                }


                if let folderFilterID,
                   let folder =
                    folders.first(
                        where: {
                            $0.id
                            ==
                            folderFilterID
                        }
                    ) {

                    filterChip(
                        folder.name
                    )
                }


                if sourceFilter
                    !=
                    .all {

                    filterChip(
                        sourceFilter.rawValue
                    )
                }


                if originalFilter
                    !=
                    .all {

                    filterChip(
                        originalFilter.rawValue
                    )
                }


                if documentTypeFilter
                    !=
                    "ALL" {

                    filterChip(
                        documentTypeFilter
                    )
                }


                Button(
                    "Reset"
                ) {

                    resetFilters()
                }
                .font(
                    .caption
                    .weight(.semibold)
                )
            }
        }
    }


    private func filterChip(
        _ title:
            String
    ) -> some View {

        Text(
            title
        )
        .font(
            .caption
            .weight(.semibold)
        )
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            7
        )
        .background(
            Color.blue
                .opacity(0.08)
        )
        .clipShape(
            Capsule()
        )
        .foregroundStyle(
            .blue
        )
    }


    private func folderName(
        for id:
            UUID?
    ) -> String? {

        guard
            let id
        else {
            return nil
        }


        return
            folders.first {
                $0.id
                ==
                id
            }?
            .name
    }


    private func resetFilters() {

        withAnimation {

            sortOption =
                .newest

            sourceFilter =
                .all

            originalFilter =
                .all

            favoriteFilter =
                .all

            documentTypeFilter =
                "ALL"

            folderFilterID =
                nil
        }
    }


    // States

    private var loadingState:
        some View {

        ScrollView {

            VStack(
                spacing:
                    14
            ) {

                HStack {

                    Text(
                        "Loading your documents…"
                    )
                    .font(
                        .headline
                    )


                    Spacer()


                    ProgressView()
                }
                .padding(
                    .horizontal,
                    18
                )


                ForEach(
                    0..<3,
                    id:
                        \.self
                ) {
                    _ in

                    HistorySkeletonCard()
                }
            }
            .padding(
                .top,
                18
            )
        }
    }


    private func errorState(
        message:
            String
    ) -> some View {

        VStack(
            spacing:
                18
        ) {

            Spacer()


            AppErrorCard(
                title:
                    "Couldn't load History",
                message:
                    message,
                retryTitle:
                    network.isConnected
                    ? "Try Again"
                    : nil,
                retry: {

                    Task {

                        await loadHistory()
                    }
                }
            )
            .padding(
                .horizontal,
                20
            )


            Spacer()
        }
    }


    private var emptyState:
        some View {

        VStack(
            spacing:
                18
        ) {

            Spacer()


            ZStack {

                Circle()
                    .fill(
                        Color.blue
                            .opacity(0.09)
                    )
                    .frame(
                        width:
                            100,
                        height:
                            100
                    )


                Image(
                    systemName:
                        "doc.text.magnifyingglass"
                )
                .font(
                    .system(
                        size:
                            39,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    .blue
                )
            }


            VStack(
                spacing:
                    7
            ) {

                Text(
                    network.isConnected
                    ? "No documents yet"
                    : "History needs a connection"
                )
                .font(
                    .title3
                    .weight(.bold)
                )


                Text(
                    network.isConnected
                    ? "Statements and bills you analyze will automatically appear here."
                    : "Reconnect to load your saved documents."
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
            }


            Spacer()
        }
        .padding(
            .horizontal,
            30
        )
    }


    private var noResultsState:
        some View {

        VStack(
            spacing:
                14
        ) {

            Spacer()


            Image(
                systemName:
                    "line.3.horizontal.decrease.circle"
            )
            .font(
                .system(
                    size:
                        40
                )
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                "No matching documents"
            )
            .font(
                .headline
            )


            Text(
                "Try changing your search, folder, or filters."
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )


            if hasActiveFilters {

                Button(
                    "Reset Filters"
                ) {

                    resetFilters()
                }
                .buttonStyle(
                    .bordered
                )
            }


            Spacer()
        }
        .padding(
            30
        )
    }


    private var historyBackground:
        some View {

        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.030),
                Color.indigo.opacity(0.040)
            ],
            startPoint:
                .topLeading,
            endPoint:
                .bottomTrailing
        )
        .ignoresSafeArea()
    }


    // Mutations

    private func toggleFavorite(
        _ document:
            HistoryDocument
    ) {

        guard
            network.isConnected
        else {

            errorMessage =
                "Reconnect before changing favorites."

            return
        }


        Task {

            do {

                try await
                    DocumentHistoryService
                        .shared
                        .setFavorite(
                            id:
                                document.id,
                            isFavorite:
                                !document.isFavorite
                        )


                let refreshed =
                    try await
                        DocumentHistoryService
                            .shared
                            .fetchDocument(
                                id:
                                    document.id
                            )


                await MainActor.run {

                    updateLocalDocument(
                        refreshed
                    )
                }

            } catch {

                await MainActor.run {

                    errorMessage =
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


    @MainActor
    private func updateLocalDocument(
        _ updated:
            HistoryDocument
    ) {

        if let index =
            documents.firstIndex(
                where: {
                    $0.id
                    ==
                    updated.id
                }
            ) {

            documents[
                index
            ] =
                updated
        }
    }


    // Data

    @MainActor
    private func loadHistory()
        async {

        guard
            network.isConnected
        else {

            isLoading =
                false


            if documents.isEmpty {

                errorMessage =
                    "Reconnect to the internet to load your document history."
            }


            return
        }


        if documents.isEmpty {

            isLoading =
                true
        }


        errorMessage =
            nil


        do {

            async let documentsTask =
                DocumentHistoryService
                    .shared
                    .fetchDocuments()

            async let foldersTask =
                DocumentFolderService
                    .shared
                    .fetchFolders()


            documents =
                try await documentsTask

            folders =
                try await foldersTask


            if let folderFilterID,
               !folders.contains(
                    where: {
                        $0.id
                        ==
                        folderFilterID
                    }
               ) {

                self.folderFilterID =
                    nil
            }

        } catch {

            errorMessage =
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


        isLoading =
            false
    }


    @MainActor
    private func delete(
        _ document:
            HistoryDocument
    ) async {

        guard
            network.isConnected
        else {

            errorMessage =
                "Reconnect before deleting a saved document."

            return
        }


        do {

            try await
                DocumentHistoryService
                    .shared
                    .deleteDocument(
                        document
                    )


            await BillReminderService
                .shared
                .cancel(
                    documentID:
                        document.id
                )


            withAnimation {

                documents.removeAll {
                    $0.id
                    ==
                    document.id
                }
            }

        } catch {

            errorMessage =
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


private struct HistoryOrganizationTarget:
    Identifiable {

    let document:
        HistoryDocument

    var id:
        UUID {

        document.id
    }
}


private struct HistorySkeletonCard:
    View {

    @State private var pulse =
        false


    var body: some View {

        RoundedRectangle(
            cornerRadius:
                24,
            style:
                .continuous
        )
        .fill(
            Color.primary
                .opacity(
                    pulse
                    ? 0.055
                    : 0.025
                )
        )
        .frame(
            height:
                142
        )
        .onAppear {

            withAnimation(
                .easeInOut(
                    duration:
                        0.9
                )
                .repeatForever(
                    autoreverses:
                        true
                )
            ) {

                pulse =
                    true
            }
        }
    }
}
