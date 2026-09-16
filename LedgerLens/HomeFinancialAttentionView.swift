import SwiftUI


struct HomeFinancialAttentionView:
    View {

    let feed:
        HomeFinancialAttentionFeed?

    let isLoading:
        Bool

    let errorMessage:
        String?

    let onSelectDocument:
        (HistoryDocument) -> Void

    let onOpenHistory:
        () -> Void


    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            header


            if isLoading,
               feed
                ==
                nil {

                loadingCard

            } else if let feed {

                if feed
                    .items
                    .isEmpty {

                    if feed
                        .failedDeepAnalysisCount
                        >
                        0 {

                        incompleteCard

                    } else {

                        caughtUpCard
                    }

                } else {

                    summaryChips(
                        feed
                    )


                    VStack(
                        spacing:
                            9
                    ) {

                        ForEach(
                            feed
                                .items
                        ) {
                            item in

                            Button {

                                onSelectDocument(
                                    item
                                        .document
                                )

                            } label: {

                                attentionCard(
                                    item
                                )
                            }
                            .buttonStyle(
                                .plain
                            )
                        }
                    }
                }


                coverageNote(
                    feed
                )

            } else if let errorMessage {

                Text(
                    errorMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .padding(
                    13
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
                .background(
                    Color.primary
                        .opacity(
                            0.025
                        )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            16,
                        style:
                            .continuous
                    )
                )
            }
        }
    }


    // =====================================================
    // MARK: Header
    // =====================================================

    private var header:
        some View {

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

                HStack(
                    spacing:
                        7
                ) {

                    Image(
                        systemName:
                            "sparkles.rectangle.stack.fill"
                    )
                    .foregroundStyle(
                        .indigo
                    )


                    Text(
                        "Financial attention"
                    )
                    .font(
                        .headline
                    )
                }


                Text(
                    "Deterministic signals worth reviewing across your saved documents."
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Button(
                "History"
            ) {

                onOpenHistory()
            }
            .font(
                .caption
                .weight(.semibold)
            )
        }
    }


    // Summary

    @ViewBuilder
    private func summaryChips(
        _ feed:
            HomeFinancialAttentionFeed
    ) -> some View {

        if feed
            .urgentCount
            >
            0
            ||
            feed
                .reviewCount
            >
            0 {

            HStack(
                spacing:
                    8
            ) {

                if feed
                    .urgentCount
                    >
                    0 {

                    summaryChip(
                        "\(feed.urgentCount) urgent",
                        systemImage:
                            "exclamationmark.circle.fill",
                        tint:
                            .red
                    )
                }


                if feed
                    .reviewCount
                    >
                    0 {

                    summaryChip(
                        "\(feed.reviewCount) review",
                        systemImage:
                            "eye.fill",
                        tint:
                            .orange
                    )
                }


                if feed
                    .informationCount
                    >
                    0 {

                    summaryChip(
                        "\(feed.informationCount) info",
                        systemImage:
                            "info.circle.fill",
                        tint:
                            .blue
                    )
                }


                Spacer()
            }
        }
    }


    private func summaryChip(
        _ title:
            String,
        systemImage:
            String,
        tint:
            Color
    ) -> some View {

        Label(
            title,
            systemImage:
                systemImage
        )
        .font(
            .caption2
            .weight(.semibold)
        )
        .foregroundStyle(
            tint
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
            tint
                .opacity(
                    0.08
                )
        )
        .clipShape(
            Capsule()
        )
    }


    // Item

    private func attentionCard(
        _ item:
            HomeFinancialAttentionItem
    ) -> some View {

        HStack(
            alignment:
                .top,
            spacing:
                12
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius:
                        13,
                    style:
                        .continuous
                )
                .fill(
                    tint(
                        item
                    )
                    .opacity(
                        0.10
                    )
                )
                .frame(
                    width:
                        43,
                    height:
                        43
                )


                Image(
                    systemName:
                        systemImage(
                            item
                        )
                )
                .font(
                    .system(
                        size:
                            17,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    tint(
                        item
                    )
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                HStack(
                    alignment:
                        .firstTextBaseline,
                    spacing:
                        7
                ) {

                    Text(
                        item
                            .title
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )
                    .foregroundStyle(
                        .primary
                    )


                    Spacer()


                    Text(
                        priorityLabel(
                            item
                                .priority
                        )
                    )
                    .font(
                        .caption2
                        .weight(.bold)
                    )
                    .foregroundStyle(
                        tint(
                            item
                        )
                    )
                }


                Text(
                    item
                        .detail
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


                Text(
                    item
                        .kind
                        .displayText
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )
            }


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
                4
            )
        }
        .padding(
            13
        )
        .background(
            LinearGradient(
                colors: [
                    tint(
                        item
                    )
                    .opacity(
                        0.04
                    ),
                    Color(
                        .secondarySystemBackground
                    )
                ],
                startPoint:
                    .topLeading,
                endPoint:
                    .bottomTrailing
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
                tint(
                    item
                )
                .opacity(
                    0.08
                )
            )
        }
    }


    private func tint(
        _ item:
            HomeFinancialAttentionItem
    ) -> Color {

        switch item
            .priority {

        case .urgent:
            return .red

        case .review:
            return .orange

        case .information:

            switch item
                .kind {

            case .balanceMovement:
                return .indigo

            case .recentDocument:
                return .blue

            default:
                return .blue
            }
        }
    }


    private func systemImage(
        _ item:
            HomeFinancialAttentionItem
    ) -> String {

        switch item
            .kind {

        case .billDue:
            return "calendar.badge.exclamationmark"

        case .repeatedCharge:
            return "rectangle.on.rectangle.badge.exclamationmark"

        case .unusualCharge:
            return "chart.line.uptrend.xyaxis.circle"

        case .balanceMovement:
            return "arrow.up.arrow.down.circle"

        case .recentDocument:
            return "doc.badge.plus"
        }
    }


    private func priorityLabel(
        _ priority:
            HomeFinancialAttentionItem
                .Priority
    ) -> String {

        switch priority {

        case .urgent:
            return "URGENT"

        case .review:
            return "REVIEW"

        case .information:
            return "INFO"
        }
    }


    // Empty / Loading


    private var loadingCard:
        some View {

        HStack(
            spacing:
                12
        ) {

            ProgressView()


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Checking your financial documents…"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                Text(
                    "Due dates load immediately; deeper charge and balance signals are restored from recent saved documents."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()
        }
        .padding(
            14
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
                    18,
                style:
                    .continuous
            )
        )
    }


    private var incompleteCard:
        some View {

        HStack(
            alignment:
                .top,
            spacing:
                12
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.orange
                            .opacity(
                                0.10
                            )
                    )
                    .frame(
                        width:
                            42,
                        height:
                            42
                    )


                Image(
                    systemName:
                        "exclamationmark.arrow.triangle.2.circlepath"
                )
                .foregroundStyle(
                    .orange
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Attention check incomplete"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                Text(
                    "Due-date checks completed, but one or more saved documents could not be restored for deeper charge or balance analysis during this refresh."
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
            }


            Spacer()
        }
        .padding(
            14
        )
        .background(
            Color.orange
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


    private var caughtUpCard:
        some View {

        HStack(
            alignment:
                .top,
            spacing:
                12
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.green
                            .opacity(
                                0.10
                            )
                    )
                    .frame(
                        width:
                            42,
                        height:
                            42
                    )


                Image(
                    systemName:
                        "checkmark.shield.fill"
                )
                .foregroundStyle(
                    .green
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "You're caught up"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                Text(
                    "No urgent due-date, repeated-charge, unusual-size, or major balance-movement signals are currently surfaced."
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
            }


            Spacer()
        }
        .padding(
            14
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


    // Coverage

    private func coverageNote(
        _ feed:
            HomeFinancialAttentionFeed
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                3
        ) {

            Text(
                coverageText(
                    feed
                )
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .tertiary
            )


            if feed
                .failedDeepAnalysisCount
                >
                0 {

                Text(
                    "\(feed.failedDeepAnalysisCount) saved document\(feed.failedDeepAnalysisCount == 1 ? "" : "s") could not be restored for deeper Home intelligence during this refresh."
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )
            }


            Text(
                "These are review signals, not fraud or error determinations. Verify important findings against the original document."
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .tertiary
            )
        }
    }


    private func coverageText(
        _ feed:
            HomeFinancialAttentionFeed
    ) -> String {

        if feed
            .totalDocumentCount
            ==
            0 {

            return
                "No saved documents yet."
        }


        if feed
            .deepAnalyzedDocumentCount
            >=
            feed
                .totalDocumentCount {

            return
                "Due-date checks and deeper financial signals covered all \(feed.totalDocumentCount) saved document\(feed.totalDocumentCount == 1 ? "" : "s")."
        }


        return
            "Due dates check all \(feed.totalDocumentCount) saved documents. Deeper repeated-charge, large-charge, and balance checks cover the \(feed.deepAnalyzedDocumentCount) most relevant/recent documents to keep Home fast."
    }
}


private extension HomeFinancialAttentionItem.Kind {

    var displayText:
        String {

        switch self {

        case .billDue:
            return "Due-date attention"

        case .repeatedCharge:
            return "Repeated-charge review signal"

        case .unusualCharge:
            return "Large-charge review signal"

        case .balanceMovement:
            return "Bank balance movement"

        case .recentDocument:
            return "Recently added document"
        }
    }
}
