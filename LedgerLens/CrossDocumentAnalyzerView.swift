import SwiftUI


struct CrossDocumentAnalyzerView: View {

    let documents:
        [HistoryDocument]

    @ObservedObject private var network =
        NetworkMonitor.shared

    @State private var pack:
        CrossDocumentFactPack?

    @State private var isLoading =
        true

    @State private var loadError:
        String?

    @State private var question =
        ""

    @State private var answer =
        ""

    @State private var isAsking =
        false

    @State private var questionError:
        String?

    @State private var showReportExporter =
        false


    var body: some View {

        ScrollView {

            LazyVStack(
                alignment:
                    .leading,
                spacing:
                    22
            ) {

                if !network
                    .isConnected {

                    OfflineBanner(
                        message:
                            "Cross-document analysis and AI explanations require an internet connection to load saved document data."
                    )
                }


                selectedDocumentHeader


                if isLoading {

                    loadingCard

                } else if
                    let loadError {

                    AppErrorCard(
                        title:
                            "Couldn't compare documents",
                        message:
                            loadError,
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

                } else if
                    let pack {

                    SpendingComparisonView(
                        pack:
                            pack
                    )


                    RecurringPaymentsView(
                        patterns:
                            pack
                                .recurringPayments
                    )


                    topSpendingSection(
                        pack
                    )


                    askSection(
                        pack
                    )


                    exportSection
                }
            }
            .padding(
                18
            )
            .padding(
                .bottom,
                36
            )
        }
        .background(
            LinearGradient(
                colors: [
                    Color(
                        .systemBackground
                    ),
                    Color.indigo
                        .opacity(
                            0.025
                        )
                ],
                startPoint:
                    .top,
                endPoint:
                    .bottom
            )
        )
        .navigationTitle(
            "Cross-Document Analysis"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .task {

            await load()
        }
        .sheet(
            isPresented:
                $showReportExporter
        ) {

            if let pack {

                CrossDocumentReportExportSheet(
                    pack:
                        pack,
                    currentQuestion:
                        question
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? nil
                        : question,
                    currentAnswer:
                        answer
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? nil
                        : answer
                )
            }
        }
    }


    // Header

    private var selectedDocumentHeader:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                11
        ) {

            HStack {

                Label(
                    "\(documents.count) selected documents",
                    systemImage:
                        "square.stack.3d.up.fill"
                )
                .font(
                    .headline
                )


                Spacer()
            }


            ScrollView(
                .horizontal,
                showsIndicators:
                    false
            ) {

                HStack(
                    spacing:
                        8
                ) {

                    ForEach(
                        documents
                    ) {
                        document in

                        Text(
                            document
                                .resolvedDisplayName
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
                                .opacity(
                                    0.08
                                )
                        )
                        .clipShape(
                            Capsule()
                        )
                    }
                }
            }
        }
    }


    private var loadingCard:
        some View {

        VStack(
            spacing:
                15
        ) {

            ProgressView()
                .controlSize(
                    .large
                )


            Text(
                "Building verified cross-document facts…"
            )
            .font(
                .headline
            )


            Text(
                "Restoring the saved Veryfi results locally, calculating spending by period, and detecting recurring payments across documents."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            24
        )
        .background(
            Color.indigo
                .opacity(
                    0.045
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
        )
    }


    // Top Spending

    private func topSpendingSection(
        _ pack:
            CrossDocumentFactPack
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                13
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Where the money went"
                )
                .font(
                    .title3
                    .weight(.bold)
                )


                Text(
                    "Verified totals across the selected documents."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            if !pack
                .merchantTotals
                .isEmpty {

                DisclosureGroup(
                    "Top merchants"
                ) {

                    VStack(
                        spacing:
                            9
                    ) {

                        ForEach(
                            Array(
                                pack
                                    .merchantTotals
                                    .prefix(
                                        10
                                    )
                            )
                        ) {
                            item in

                            totalRow(
                                title:
                                    item
                                        .merchant,
                                subtitle:
                                    "\(item.count) charge\(item.count == 1 ? "" : "s")",
                                amount:
                                    item
                                        .amount,
                                currency:
                                    item
                                        .currency
                            )
                        }
                    }
                    .padding(
                        .top,
                        10
                    )
                }
                .font(
                    .subheadline
                    .weight(.semibold)
                )
            }


            if !pack
                .categoryTotals
                .isEmpty {

                DisclosureGroup(
                    "Top categories"
                ) {

                    VStack(
                        spacing:
                            9
                    ) {

                        ForEach(
                            Array(
                                pack
                                    .categoryTotals
                                    .prefix(
                                        10
                                    )
                            )
                        ) {
                            item in

                            totalRow(
                                title:
                                    item
                                        .category,
                                subtitle:
                                    "\(item.count) charge\(item.count == 1 ? "" : "s")",
                                amount:
                                    item
                                        .amount,
                                currency:
                                    item
                                        .currency
                            )
                        }
                    }
                    .padding(
                        .top,
                        10
                    )
                }
                .font(
                    .subheadline
                    .weight(.semibold)
                )
            }
        }
        .padding(
            16
        )
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
        )
    }


    private func totalRow(
        title:
            String,
        subtitle:
            String,
        amount:
            Decimal,
        currency:
            String
    ) -> some View {

        HStack(
            alignment:
                .top,
            spacing:
                10
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {

                Text(
                    title
                )
                .font(
                    .caption
                    .weight(.semibold)
                )


                Text(
                    subtitle
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Text(
                CrossDocumentAnalysisEngine
                    .formatMoney(
                        amount,
                        currency:
                            currency
                    )
            )
            .font(
                .caption
                .weight(.bold)
            )
        }
    }


    // Ask AI

    private func askSection(
        _ pack:
            CrossDocumentFactPack
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                13
        ) {

            Label(
                "Ask across these documents",
                systemImage:
                    "sparkles"
            )
            .font(
                .title3
                .weight(.bold)
            )


            Text(
                "Swift calculates the financial facts first. AI only explains the verified results."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            TextField(
                "Compare my spending across these statements",
                text:
                    $question,
                axis:
                    .vertical
            )
            .textFieldStyle(
                .roundedBorder
            )
            .lineLimit(
                2...5
            )


            ScrollView(
                .horizontal,
                showsIndicators:
                    false
            ) {

                HStack(
                    spacing:
                        8
                ) {

                    questionSuggestion(
                        "Compare my spending across these documents"
                    )


                    questionSuggestion(
                        "What recurring payments did you detect?"
                    )


                    questionSuggestion(
                        "Which recurring payments cost me the most?"
                    )


                    questionSuggestion(
                        "Which merchants did I spend the most with?"
                    )
                }
            }


            Button {

                ask(
                    pack
                )

            } label: {

                HStack {

                    if isAsking {

                        ProgressView()
                            .tint(
                                .white
                            )

                    } else {

                        Image(
                            systemName:
                                "sparkles"
                        )
                    }


                    Text(
                        isAsking
                        ? "Explaining…"
                        : "Ask About Selected Documents"
                    )


                    Spacer()
                }
                .font(
                    .headline
                )
                .padding(
                    15
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
                            17,
                        style:
                            .continuous
                    )
                )
            }
            .buttonStyle(
                .plain
            )
            .disabled(
                isAsking
                ||
                question
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
                ||
                !network
                    .isConnected
            )


            if let questionError {

                AppErrorCard(
                    title:
                        "Couldn't answer",
                    message:
                        questionError
                )
            }


            if !answer
                .isEmpty {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        9
                ) {

                    HStack {

                        Label(
                            "Verified-facts explanation",
                            systemImage:
                                "checkmark.shield.fill"
                        )
                        .font(
                            .subheadline
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .green
                        )


                        Spacer()
                    }


                    Text(
                        PlainTextSanitizer
                            .clean(
                                answer
                            )
                    )
                    .font(
                        .body
                    )
                    .lineSpacing(
                        4
                    )
                    .textSelection(
                        .enabled
                    )
                }
                .padding(
                    16
                )
                .background(
                    Color.green
                        .opacity(
                            0.045
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
        }
        .padding(
            16
        )
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
        )
    }


    private func questionSuggestion(
        _ text:
            String
    ) -> some View {

        Button {

            question =
                text

        } label: {

            Text(
                text
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
                Color.blue
                    .opacity(
                        0.075
                    )
            )
            .clipShape(
                Capsule()
            )
        }
        .buttonStyle(
            .plain
        )
    }


    // Professional Export

    private var exportSection:
        some View {

        Button {

            showReportExporter =
                true

        } label: {

            HStack(
                spacing:
                    13
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius:
                            14,
                        style:
                            .continuous
                    )
                    .fill(
                        Color.indigo
                            .opacity(
                                0.11
                            )
                    )
                    .frame(
                        width:
                            48,
                        height:
                            48
                    )


                    Image(
                        systemName:
                            "doc.richtext.fill"
                    )
                    .font(
                        .system(
                            size:
                                19,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        .indigo
                    )
                }


                VStack(
                    alignment:
                        .leading,
                    spacing:
                        3
                ) {

                    Text(
                        "Export & Share Analysis"
                    )
                    .font(
                        .headline
                    )
                    .foregroundStyle(
                        .primary
                    )


                    Text(
                        "Professional PDF + combined transaction CSV"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Spacer()


                Image(
                    systemName:
                        "chevron.right"
                )
                .foregroundStyle(
                    .tertiary
                )
            }
            .padding(
                15
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
                        18,
                    style:
                        .continuous
                )
            )
        }
        .buttonStyle(
            .plain
        )
    }


    // Load / Ask

    @MainActor
    private func load()
        async {

        guard
            documents.count
            >=
            2
        else {

            loadError =
                "Select at least two documents."

            isLoading =
                false

            return
        }


        guard
            network
                .isConnected
        else {

            loadError =
                "Reconnect before loading selected documents."

            isLoading =
                false

            return
        }


        isLoading =
            true

        loadError =
            nil


        do {

            pack =
                try await
                    CrossDocumentService
                        .shared
                        .load(
                            documents:
                                documents
                        )

        } catch {

            loadError =
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


    private func ask(
        _ pack:
            CrossDocumentFactPack
    ) {

        guard
            !isAsking
        else {
            return
        }


        let clean =
            question
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !clean.isEmpty
        else {
            return
        }


        isAsking =
            true

        answer =
            ""

        questionError =
            nil


        Task {

            do {

                let result =
                    try await
                        CrossDocumentService
                            .shared
                            .answer(
                                question:
                                    clean,
                                pack:
                                    pack
                            )


                await MainActor.run {

                    answer =
                        result

                    isAsking =
                        false
                }

            } catch {

                await MainActor.run {

                    questionError =
                        AppFriendlyError
                            .message(
                                for:
                                    error,
                                context:
                                    .question,
                                isConnected:
                                    network
                                        .isConnected
                            )

                    isAsking =
                        false
                }
            }
        }
    }
}


// Spending Comparison

private struct SpendingComparisonView:
    View {

    let pack:
        CrossDocumentFactPack


    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Spending comparison"
                )
                .font(
                    .title3
                    .weight(.bold)
                )


                Text(
                    "Uses authoritative statement purchases, bill totals, or cleaned outflow records. Currencies are never silently combined."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            ForEach(
                currencies,
                id:
                    \.self
            ) {
                currency in

                currencySection(
                    currency
                )
            }


            if !pack
                .spendingChanges
                .isEmpty {

                Divider()


                Text(
                    "Changes between periods"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                ForEach(
                    pack
                        .spendingChanges
                ) {
                    change in

                    changeRow(
                        change
                    )
                }
            }
        }
        .padding(
            16
        )
        .background(
            Color.blue
                .opacity(
                    0.045
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
        )
    }


    private var currencies:
        [String] {

        Array(
            Set(
                pack
                    .metrics
                    .flatMap {
                        $0.spending
                            .map(
                                \.currency
                            )
                    }
            )
        )
        .sorted()
    }


    @ViewBuilder
    private func currencySection(
        _ currency:
            String
    ) -> some View {

        let values =
            pack
                .metrics
                .compactMap {
                    metric
                    ->
                    (
                        CrossDocumentMetric,
                        Decimal
                    )?
                    in

                    guard
                        let amount =
                            metric
                                .spending
                                .first(
                                    where: {
                                        $0.currency
                                        ==
                                        currency
                                    }
                                )?
                                .amount
                    else {
                        return nil
                    }


                    return (
                        metric,
                        amount
                    )
                }


        let maximum =
            values
                .map {
                    CrossDocumentAnalysisEngine
                        .double(
                            $0.1
                        )
                }
                .max()
            ??
            0


        VStack(
            alignment:
                .leading,
            spacing:
                11
        ) {

            Text(
                currency
            )
            .font(
                .caption
                .weight(.bold)
            )
            .foregroundStyle(
                .secondary
            )


            ForEach(
                values,
                id:
                    \.0.id
            ) {
                metric,
                amount in

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        6
                ) {

                    HStack {

                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                2
                        ) {

                            Text(
                                metric
                                    .document
                                    .displayName
                            )
                            .font(
                                .caption
                                .weight(.semibold)
                            )
                            .lineLimit(
                                1
                            )


                            if let period =
                                metric
                                    .document
                                    .periodCaption {

                                Text(
                                    period
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


                        Text(
                            CrossDocumentAnalysisEngine
                                .formatMoney(
                                    amount,
                                    currency:
                                        currency
                                )
                        )
                        .font(
                            .caption
                            .weight(.bold)
                        )
                    }


                    GeometryReader {
                        proxy in

                        let value =
                            CrossDocumentAnalysisEngine
                                .double(
                                    amount
                                )


                        let fraction =
                            maximum
                            >
                            0
                            ? max(
                                0.04,
                                min(
                                    1,
                                    value
                                    /
                                    maximum
                                )
                            )
                            : 0


                        ZStack(
                            alignment:
                                .leading
                        ) {

                            Capsule()
                                .fill(
                                    Color.primary
                                        .opacity(
                                            0.06
                                        )
                                )


                            Capsule()
                                .fill(
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
                                .frame(
                                    width:
                                        proxy
                                            .size
                                            .width
                                        *
                                        fraction
                                )
                        }
                    }
                    .frame(
                        height:
                            8
                    )
                }
            }
        }
    }


    private func changeRow(
        _ change:
            CrossDocumentSpendingChange
    ) -> some View {

        HStack(
            alignment:
                .top,
            spacing:
                10
        ) {

            Image(
                systemName:
                    change.delta
                    >=
                    0
                    ? "arrow.up.right"
                    : "arrow.down.right"
            )
            .foregroundStyle(
                change.delta
                >=
                0
                ? .orange
                : .green
            )
            .frame(
                width:
                    20
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "\(change.fromDocumentName) → \(change.toDocumentName)"
                )
                .font(
                    .caption
                    .weight(.semibold)
                )


                Text(
                    spendingChangeText(
                        change
                    )
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()
        }
    }


    private func spendingChangeText(
        _ change:
            CrossDocumentSpendingChange
    ) -> String {

        let sign =
            change.delta
            >=
            0
            ? "+"
            : ""


        let percent =
            change
                .percentChange
                .map {
                    String(
                        format:
                            " (%.1f%%)",
                        $0
                    )
                }
            ??
            ""


        return
            "\(CrossDocumentAnalysisEngine.formatMoney(change.previousAmount, currency: change.currency)) → \(CrossDocumentAnalysisEngine.formatMoney(change.currentAmount, currency: change.currency)) • \(sign)\(CrossDocumentAnalysisEngine.formatMoney(change.delta, currency: change.currency))\(percent)"
    }
}
