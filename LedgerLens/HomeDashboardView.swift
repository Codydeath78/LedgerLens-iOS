import SwiftUI

struct HomeDashboardView: View {

    @EnvironmentObject private var session:
        AppSessionController

    @EnvironmentObject private var workspace:
        DocumentWorkspace

    @ObservedObject private var network =
        NetworkMonitor.shared

    @State private var snapshot:
        HomeDashboardSnapshot?

    @State private var isLoading =
        true

    @State private var errorMessage:
        String?

    @State private var openingDocumentID:
        UUID?

    @State private var attentionFeed:
        HomeFinancialAttentionFeed?

    @State private var isLoadingAttention =
        false

    @State private var attentionError:
        String?

    @State private var attentionReviewDocument:
        HistoryDocument?

    var body: some View {

        NavigationStack {

            ZStack {

                homeBackground

                ScrollView {

                    LazyVStack(
                        alignment: .leading,
                        spacing: 24
                    ) {

                        hero

                        if !network
                            .isConnected {

                            OfflineBanner(
                                message:
                                    "The dashboard is showing the last loaded information. Upload, scan, cloud history, and AI questions require a connection."
                            )
                        }

                        quickActions

                        statsSection

                        financialAttentionSection

                        billsDueSoonSection

                        usageSection

                        recentDocumentsSection

                        activitySection
                    }
                    .padding(
                        .horizontal,
                        18
                    )
                    .padding(
                        .top,
                        12
                    )
                    .padding(
                        .bottom,
                        38
                    )
                }
                .refreshable {

                    await loadDashboard(
                        force: true
                    )
                }


                if openingDocumentID !=
                    nil {

                    Color.black
                        .opacity(0.12)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {

                        ProgressView()
                            .controlSize(
                                .large
                            )

                        Text(
                            "Opening saved document…"
                        )
                        .font(
                            .headline
                        )
                    }
                    .padding(24)
                    .background(
                        .regularMaterial
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style:
                                .continuous
                        )
                    )
                }
            }
            .toolbar(
                .hidden,
                for:
                    .navigationBar
            )
            .task {

                await loadDashboard(
                    force: false
                )
            }
            .onAppear {

                Task {

                    if snapshot
                        != nil
                        &&
                        network
                            .isConnected {

                        await loadDashboard(
                            force: true
                        )
                    }
                }
            }
            .sheet(
                item:
                    $attentionReviewDocument
            ) {
                document in

                NavigationStack {

                    HistoryDocumentDetailView(
                        document:
                            document
                    ) {
                        _ in

                        Task {

                            await loadDashboard(
                                force:
                                    true
                            )
                        }
                    }
                    .toolbar {

                        ToolbarItem(
                            placement:
                                .topBarLeading
                        ) {

                            Button(
                                "Done"
                            ) {

                                attentionReviewDocument =
                                    nil
                            }
                        }
                    }
                }
                .environmentObject(
                    workspace
                )
                .onDisappear {

                    Task {

                        await loadDashboard(
                            force:
                                true
                        )
                    }
                }
            }
        }
    }


    // Hero

    private var hero:
        some View {

        HStack(
            alignment: .center,
            spacing: 15
        ) {

            AnimatedHomeIcon()

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    greeting
                )
                .font(
                    .system(
                        size: 30,
                        weight: .bold,
                        design: .rounded
                    )
                )

                Text(
                    "Understand your money without digging through paperwork."
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                if let email =
                    session.email {

                    Text(email)
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                }
            }

            Spacer()
        }
    }


    private var greeting:
        String {

        let hour =
            Calendar.current
                .component(
                    .hour,
                    from: Date()
                )

        switch hour {

        case 5..<12:
            return "Good morning"

        case 12..<17:
            return "Good afternoon"

        default:
            return "Good evening"
        }
    }


    // Quick Actions

    private var quickActions:
        some View {

        VStack(
            alignment: .leading,
            spacing: 11
        ) {

            Text(
                "Start something"
            )
            .font(
                .headline
            )

            HStack(
                spacing: 12
            ) {

                dashboardAction(
                    title:
                        "Scan Document",
                    subtitle:
                        "Use your camera",
                    systemImage:
                        "camera.viewfinder",
                    tint:
                        .purple
                ) {

                    workspace
                        .requestAnalyze(
                            .scan
                        )
                }


                dashboardAction(
                    title:
                        "Upload Document",
                    subtitle:
                        "PDF, JPG or PNG",
                    systemImage:
                        "arrow.up.doc.fill",
                    tint:
                        .blue
                ) {

                    workspace
                        .requestAnalyze(
                            .upload
                        )
                }
            }
        }
    }


    private func dashboardAction(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action:
            @escaping () -> Void
    ) -> some View {

        Button {

            action()

        } label: {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .fill(
                        tint.opacity(0.11)
                    )
                    .frame(
                        width: 48,
                        height: 48
                    )

                    Image(
                        systemName:
                            systemImage
                    )
                    .font(
                        .system(
                            size: 21,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        tint
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(title)
                        .font(
                            .subheadline
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .primary
                        )

                    Text(subtitle)
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .secondary
                        )
                }
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
            .padding(15)
            .background(
                Color(
                    .secondarySystemBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .stroke(
                    tint.opacity(0.08)
                )
            }
        }
        .buttonStyle(
            .plain
        )
        .disabled(
            !network
                .isConnected
        )
        .opacity(
            network.isConnected
            ? 1
            : 0.55
        )
    }


    // Stats

    @ViewBuilder
    private var statsSection:
        some View {

        if isLoading &&
            snapshot == nil {

            HStack(
                spacing: 11
            ) {

                dashboardStatSkeleton()
                dashboardStatSkeleton()
            }

        } else if let snapshot {

            VStack(
                alignment: .leading,
                spacing: 11
            ) {

                HStack {

                    Text(
                        "Your document vault"
                    )
                    .font(
                        .headline
                    )

                    Spacer()

                    Button(
                        "View History"
                    ) {

                        workspace
                            .showHistory()
                    }
                    .font(
                        .caption
                        .weight(.semibold)
                    )
                }

                HStack(
                    spacing: 11
                ) {

                    dashboardStat(
                        value:
                            "\(snapshot.documentCount)",
                        label:
                            "Documents",
                        systemImage:
                            "doc.text.fill"
                    )

                    dashboardStat(
                        value:
                            "\(snapshot.originalCount)",
                        label:
                            "Originals saved",
                        systemImage:
                            "lock.doc.fill"
                    )
                }
            }

        } else if let errorMessage {

            AppErrorCard(
                title:
                    "Dashboard couldn't refresh",
                message:
                    errorMessage,
                retryTitle:
                    network
                        .isConnected
                    ? "Try Again"
                    : nil,
                retry: {

                    Task {

                        await loadDashboard(
                            force: true
                        )
                    }
                }
            )
        }
    }


    private func dashboardStat(
        value: String,
        label: String,
        systemImage: String
    ) -> some View {

        HStack(
            spacing: 12
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.blue
                            .opacity(0.09)
                    )
                    .frame(
                        width: 44,
                        height: 44
                    )

                Image(
                    systemName:
                        systemImage
                )
                .foregroundStyle(
                    .blue
                )
            }

            VStack(
                alignment: .leading,
                spacing: 1
            ) {

                Text(value)
                    .font(
                        .title3
                        .weight(.bold)
                        .monospacedDigit()
                    )

                Text(label)
                    .font(
                        .caption2
                    )
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()
        }
        .padding(14)
        .frame(
            maxWidth: .infinity
        )
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


    private func dashboardStatSkeleton()
        -> some View {

        RoundedRectangle(
            cornerRadius: 18,
            style: .continuous
        )
        .fill(
            Color.primary
                .opacity(0.04)
        )
        .frame(
            maxWidth: .infinity,
            minHeight: 72
        )
    }


    // Financial Attention

    private var financialAttentionSection:
        some View {

        HomeFinancialAttentionView(
            feed:
                attentionFeed,
            isLoading:
                isLoadingAttention,
            errorMessage:
                attentionError,
            onSelectDocument: {
                document in

                attentionReviewDocument =
                    document
            },
            onOpenHistory: {

                workspace
                    .showHistory()
            }
        )
    }


    // Bills Due Soon

    @ViewBuilder
    private var billsDueSoonSection:
        some View {

        if let bills =
            snapshot?
                .upcomingBills,
           !bills
                .isEmpty {

            VStack(
                alignment:
                    .leading,
                spacing:
                    11
            ) {

                HStack(
                    alignment:
                        .firstTextBaseline
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            2
                    ) {

                        Text(
                            "Bills due soon"
                        )
                        .font(
                            .headline
                        )


                        if let count =
                            snapshot?
                                .activeReminderCount,
                           count > 0 {

                            Text(
                                "\(count) active reminder\(count == 1 ? "" : "s")"
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }


                    Spacer()


                    Button(
                        "Manage"
                    ) {

                        workspace
                            .showHistory()
                    }
                    .font(
                        .caption
                        .weight(.semibold)
                    )
                }


                VStack(
                    spacing:
                        9
                ) {

                    ForEach(
                        bills
                    ) {
                        document in

                        Button {

                            openDocument(
                                document
                            )

                        } label: {

                            dueSoonCard(
                                document
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                        .disabled(
                            !network
                                .isConnected
                        )
                    }
                }


                Text(
                    "Set or change reminder timing from the document's History detail screen."
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )
            }
        }
    }


    private func dueSoonCard(
        _ document:
            HistoryDocument
    ) -> some View {

        HStack(
            spacing:
                12
        ) {

            ZStack {

                Circle()
                    .fill(
                        dueTint(
                            document
                        )
                        .opacity(
                            0.10
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
                        document
                            .reminderEnabled
                        ? "bell.badge.fill"
                        : "calendar.badge.exclamationmark"
                )
                .foregroundStyle(
                    dueTint(
                        document
                    )
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
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
                    1
                )


                if let dueDate =
                    document
                        .dueDate {

                    Text(
                        dueSoonText(
                            dueDate
                        )
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            Spacer()


            if document
                .reminderEnabled {

                VStack(
                    alignment:
                        .trailing,
                    spacing:
                        2
                ) {

                    Text(
                        "Reminder on"
                    )
                    .font(
                        .caption2
                        .weight(.semibold)
                    )
                    .foregroundStyle(
                        .green
                    )


                    Text(
                        reminderLeadText(
                            document
                                .reminderDaysBefore
                        )
                    )
                    .font(
                        .caption2
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .tertiary
            )
        }
        .padding(
            13
        )
        .background(
            dueTint(
                document
            )
            .opacity(
                0.045
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    17,
                style:
                    .continuous
            )
        )
    }


    private func dueTint(
        _ document:
            HistoryDocument
    ) -> Color {

        guard
            let dueDate =
                document
                    .dueDate
        else {

            return .blue
        }


        let days =
            Calendar.current
                .dateComponents(
                    [
                        .day
                    ],
                    from:
                        Calendar.current
                            .startOfDay(
                                for:
                                    Date()
                            ),
                    to:
                        Calendar.current
                            .startOfDay(
                                for:
                                    dueDate
                            )
                )
                .day
        ??
        999


        switch days {

        case 0...2:
            return .red

        case 3...7:
            return .orange

        default:
            return .blue
        }
    }


    private func dueSoonText(
        _ dueDate:
            Date
    ) -> String {

        let days =
            Calendar.current
                .dateComponents(
                    [
                        .day
                    ],
                    from:
                        Calendar.current
                            .startOfDay(
                                for:
                                    Date()
                            ),
                    to:
                        Calendar.current
                            .startOfDay(
                                for:
                                    dueDate
                            )
                )
                .day
        ??
        0


        switch days {

        case 0:

            return
                "Due today • \(dueDate.formatted(date: .abbreviated, time: .omitted))"

        case 1:

            return
                "Due tomorrow • \(dueDate.formatted(date: .abbreviated, time: .omitted))"

        default:

            return
                "Due in \(days) days • \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }


    private func reminderLeadText(
        _ days:
            Int
    ) -> String {

        switch days {

        case 0:
            return "Due day"

        case 1:
            return "1 day before"

        default:
            return "\(days) days before"
        }
    }


    // MARK: - Usage

    @ViewBuilder
    private var usageSection:
        some View {

        if let usage =
            snapshot?.usage {

            UsageStatusCard(
                usage:
                    usage
            )

        } else if snapshot?
            .usageUnavailable
            == true {

            UsageUnavailableCard()
        }
    }


    // Recent Documents

    @ViewBuilder
    private var recentDocumentsSection:
        some View {

        if let documents =
            snapshot?
                .recentDocuments,
           !documents.isEmpty {

            VStack(
                alignment: .leading,
                spacing: 11
            ) {

                HStack {

                    Text(
                        "Recent documents"
                    )
                    .font(
                        .headline
                    )

                    Spacer()

                    Button(
                        "See all"
                    ) {

                        workspace
                            .showHistory()
                    }
                    .font(
                        .caption
                        .weight(.semibold)
                    )
                }

                ForEach(
                    documents
                ) {
                    document in

                    Button {

                        openDocument(
                            document
                        )

                    } label: {

                        HomeRecentDocumentCard(
                            document:
                                document
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        !network
                            .isConnected
                    )
                }
            }
        }
    }


    // Activity

    @ViewBuilder
    private var activitySection:
        some View {

        if let activities =
            snapshot?
                .activities,
           !activities.isEmpty {

            VStack(
                alignment: .leading,
                spacing: 11
            ) {

                Text(
                    "Recent activity"
                )
                .font(
                    .headline
                )

                VStack(
                    spacing: 0
                ) {

                    ForEach(
                        Array(
                            activities
                                .enumerated()
                        ),
                        id:
                            \.element.id
                    ) {
                        index,
                        activity in

                        Button {

                            openDocument(
                                activity
                                    .document
                            )

                        } label: {

                            HomeActivityRow(
                                activity:
                                    activity
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                        .disabled(
                            !network
                                .isConnected
                        )

                        if index <
                            activities.count
                            - 1 {

                            Divider()
                                .padding(
                                    .leading,
                                    46
                                )
                        }
                    }
                }
                .padding(
                    .horizontal,
                    14
                )
                .background(
                    Color(
                        .secondarySystemBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style:
                            .continuous
                    )
                )
            }
        }
    }


    // Loading

    @MainActor
    private func loadDashboard(
        force: Bool
    ) async {

        if snapshot != nil &&
            !force {

            return
        }

        guard
            network.isConnected
        else {

            isLoading =
                false

            return
        }

        if snapshot == nil {

            isLoading =
                true
        }

        errorMessage =
            nil

        do {

            let loadedSnapshot =
                try await
                    HomeDashboardService
                        .shared
                        .load()


            snapshot =
                loadedSnapshot

            isLoading =
                false


            Task {

                await loadFinancialAttention(
                    documents:
                        loadedSnapshot
                            .attentionSourceDocuments,
                    force:
                        force
                )
            }


        } catch {

            errorMessage =
                AppFriendlyError
                    .message(
                        for: error,
                        context:
                            .history,
                        isConnected:
                            network
                                .isConnected
                    )

            isLoading =
                false
        }
    }


    @MainActor
    private func loadFinancialAttention(
        documents:
            [HistoryDocument],
        force:
            Bool
    ) async {

        if attentionFeed
            !=
            nil,
           !force {

            return
        }


        guard
            network
                .isConnected
        else {

            if attentionFeed
                ==
                nil {

                attentionError =
                    "Reconnect to load your financial attention feed."
            }

            isLoadingAttention =
                false

            return
        }


        if attentionFeed
            ==
            nil {

            isLoadingAttention =
                true
        }


        attentionError =
            nil


        let feed =
            await HomeFinancialAttentionService
                .shared
                .load(
                    documents:
                        documents
                )


        attentionFeed =
            feed

        isLoadingAttention =
            false
    }

    private func openDocument(
        _ document:
            HistoryDocument
    ) {

        guard
            openingDocumentID
                == nil,
            network.isConnected
        else {
            return
        }

        openingDocumentID =
            document.id

        errorMessage =
            nil

        Task {

            do {

                let context =
                    try await
                        DocumentContinuityService
                            .shared
                            .load(
                                document:
                                    document
                            )

                await MainActor.run {

                    openingDocumentID =
                        nil

                    workspace
                        .openFromHistory(
                            financialDocument:
                                context
                                    .financialDocument,
                            historyDocumentID:
                                document.id,
                            displayName:
                                document
                                    .resolvedDisplayName,
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

                    openingDocumentID =
                        nil

                    errorMessage =
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


    private var homeBackground:
        some View {

        LinearGradient(
            colors: [
                Color(
                    .systemBackground
                ),
                Color.blue
                    .opacity(0.035),
                Color.indigo
                    .opacity(0.045)
            ],
            startPoint:
                .topLeading,
            endPoint:
                .bottomTrailing
        )
        .ignoresSafeArea()
    }
}


// Animated Header Icon

private struct AnimatedHomeIcon:
    View {

    @Environment(
        \.accessibilityReduceMotion
    )
    private var reduceMotion

    var body: some View {

        TimelineView(
            .animation(
                minimumInterval:
                    1.0 / 20.0,
                paused:
                    reduceMotion
            )
        ) {
            timeline in

            let time =
                timeline.date
                    .timeIntervalSinceReferenceDate

            let scale =
                0.97
                +
                (
                    (
                        sin(
                            time * 2.7
                        )
                        + 1
                    )
                    * 0.035
                )

            let rotation =
                time * 28

            ZStack {

                Circle()
                    .fill(
                        Color.blue
                            .opacity(0.09)
                    )
                    .frame(
                        width: 70,
                        height: 70
                    )
                    .scaleEffect(
                        reduceMotion
                        ? 1
                        : scale
                    )

                Circle()
                    .trim(
                        from: 0.12,
                        to: 0.72
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                .blue,
                                .indigo,
                                .purple
                            ],
                            startPoint:
                                .leading,
                            endPoint:
                                .trailing
                        ),
                        style:
                            StrokeStyle(
                                lineWidth: 3,
                                lineCap:
                                    .round
                            )
                    )
                    .frame(
                        width: 62,
                        height: 62
                    )
                    .rotationEffect(
                        .degrees(
                            reduceMotion
                            ? 0
                            : rotation
                        )
                    )

                Image(
                    systemName:
                        "sparkles"
                )
                .font(
                    .system(
                        size: 25,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
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
            }
        }
        .frame(
            width: 72,
            height: 72
        )
    }
}


// Recent Document Card

private struct HomeRecentDocumentCard:
    View {

    let document:
        HistoryDocument

    var body: some View {

        HStack(
            spacing: 13
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    document
                        .sourceType
                        == "scan"
                    ? Color.purple
                        .opacity(0.10)
                    : Color.blue
                        .opacity(0.10)
                )
                .frame(
                    width: 50,
                    height: 50
                )

                Image(
                    systemName:
                        document
                            .sourceType
                            == "scan"
                        ? "camera.viewfinder"
                        : "doc.text.fill"
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
                spacing: 4
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
                .lineLimit(1)

                Text(
                    document
                        .prettyDocumentType
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Text(
                    document
                        .createdAt
                        .formatted(
                            date:
                                .abbreviated,
                            time:
                                .shortened
                        )
                )
                .font(.caption2)
                .foregroundStyle(
                    .tertiary
                )
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .caption
                .weight(.bold)
            )
            .foregroundStyle(
                .tertiary
            )
        }
        .padding(14)
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }
}


// Activity Row

private struct HomeActivityRow:
    View {

    let activity:
        HomeDashboardActivity

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {

            ZStack {

                Circle()
                    .fill(
                        activity.kind
                        == .conversation
                        ? Color.indigo
                            .opacity(0.10)
                        : Color.blue
                            .opacity(0.09)
                    )
                    .frame(
                        width: 36,
                        height: 36
                    )

                Image(
                    systemName:
                        activity.kind
                        == .conversation
                        ? "bubble.left.and.text.bubble.right.fill"
                        : "doc.fill"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    activity.kind
                    == .conversation
                    ? .indigo
                    : .blue
                )
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    activity.title
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )
                .foregroundStyle(
                    .primary
                )
                .lineLimit(1)

                Text(
                    activity.subtitle
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(2)

                Text(
                    activity.createdAt
                        .formatted(
                            date:
                                .abbreviated,
                            time:
                                .shortened
                        )
                )
                .font(.caption2)
                .foregroundStyle(
                    .tertiary
                )
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .caption2
                .weight(.bold)
            )
            .foregroundStyle(
                .tertiary
            )
            .padding(
                .top,
                7
            )
        }
        .padding(
            .vertical,
            12
        )
    }
}


// Usage

private struct UsageUnavailableCard:
    View {

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 11
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.orange
                            .opacity(0.10)
                    )
                    .frame(
                        width: 38,
                        height: 38
                    )

                Image(
                    systemName:
                        "gauge"
                )
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .orange
                )
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "Usage temporarily unavailable"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )

                Text(
                    "Your normal server limits still apply. Pull to refresh Home after the usage service is available."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }

            Spacer()
        }
        .padding(15)
        .background(
            Color.orange
                .opacity(0.055)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.orange
                    .opacity(0.12)
            )
        }
    }
}


private struct UsageStatusCard:
    View {

    let usage:
        AppUsageStatus

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        "Usage"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        usageMessage
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        usageTint
                    )
                }

                Spacer()

                Image(
                    systemName:
                        usageIcon
                )
                .foregroundStyle(
                    usageTint
                )
            }

            usageRow(
                title:
                    "Document analyses",
                status:
                    usage
                        .veryfi
                        .hourly
            )

            usageRow(
                title:
                    "AI answers",
                status:
                    usage
                        .chat
                        .hourly
            )

            usageRow(
                title:
                    "AI context inputs",
                status:
                    usage
                        .embeddings
                        .hourly
            )

            if usage.veryfi.daily
                .isNearLimit
                ||
                usage.chat.daily
                    .isNearLimit
                ||
                usage.embeddings.daily
                    .isNearLimit {

                Text(
                    "Daily: \(usage.veryfi.daily.used)/\(usage.veryfi.daily.limit) documents • \(usage.chat.daily.used)/\(usage.chat.daily.limit) AI answers • \(usage.embeddings.daily.used)/\(usage.embeddings.daily.limit) context inputs"
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(16)
        .background(
            usageTint
                .opacity(0.055)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                usageTint
                    .opacity(0.12)
            )
        }
    }


    private func usageRow(
        title: String,
        status:
            UsageWindowStatus
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 6
        ) {

            HStack {

                Text(title)
                    .font(
                        .caption
                        .weight(.semibold)
                    )

                Spacer()

                Text(
                    "\(status.used)/\(status.limit) this hour"
                )
                .font(
                    .caption2
                    .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            ProgressView(
                value:
                    status.fractionUsed
            )
            .tint(
                status.isVeryNearLimit
                ? .red
                : status.isNearLimit
                  ? .orange
                  : .blue
            )
        }
    }


    private var usageMessage:
        String {

        if usage.veryfi.hourly
            .isVeryNearLimit
            ||
            usage.chat.hourly
                .isVeryNearLimit
            ||
            usage.embeddings.hourly
                .isVeryNearLimit {

            return
                "You're very close to a temporary hourly limit."
        }

        if usage.veryfi.hourly
            .isNearLimit
            ||
            usage.chat.hourly
                .isNearLimit
            ||
            usage.embeddings.hourly
                .isNearLimit {

            return
                "You're getting close to a temporary hourly limit."
        }

        return
            "Plenty of room remaining in your current limits."
    }


    private var usageTint:
        Color {

        if usage.veryfi.hourly
            .isVeryNearLimit
            ||
            usage.chat.hourly
                .isVeryNearLimit
            ||
            usage.embeddings.hourly
                .isVeryNearLimit {

            return .red
        }

        if usage.veryfi.hourly
            .isNearLimit
            ||
            usage.chat.hourly
                .isNearLimit
            ||
            usage.embeddings.hourly
                .isNearLimit {

            return .orange
        }

        return .blue
    }


    private var usageIcon:
        String {

        if usage.veryfi.hourly
            .isNearLimit
            ||
            usage.chat.hourly
                .isNearLimit
            ||
            usage.embeddings.hourly
                .isNearLimit {

            return
                "exclamationmark.circle.fill"
        }

        return
            "gauge"
    }
}
