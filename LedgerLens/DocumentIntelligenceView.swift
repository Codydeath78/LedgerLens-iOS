import SwiftUI


struct DocumentIntelligenceView:
    View {

    let intelligence:
        DocumentIntelligence?

    let currentName:
        String

    let isLoading:
        Bool

    let errorMessage:
        String?

    let isApplyingSmartName:
        Bool

    let onApplySuggestedName:
        (String) -> Void


    @State private var showDetails =
        true

    @State private var showChargeAnalysis =
        false


    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                15
        ) {

            header


            if isLoading {

                loadingView

            } else if
                let intelligence {

                smartIdentitySection(
                    intelligence
                )


                attentionSection(
                    intelligence
                )


                DisclosureGroup(
                    isExpanded:
                        $showDetails
                ) {

                    detailIntelligence(
                        intelligence
                    )
                    .padding(
                        .top,
                        10
                    )

                } label: {

                    Label(
                        "Detected document details",
                        systemImage:
                            "doc.text.magnifyingglass"
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )
                }


                DisclosureGroup(
                    isExpanded:
                        $showChargeAnalysis
                ) {

                    chargeAnalysis(
                        intelligence
                    )
                    .padding(
                        .top,
                        10
                    )

                } label: {

                    Label(
                        "Charge intelligence",
                        systemImage:
                            "waveform.path.ecg.rectangle"
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )
                }


                intelligenceDisclaimer

            } else {

                Text(
                    errorMessage
                    ??
                    "No additional deterministic intelligence was available for this document."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            17
        )
        .background(
            LinearGradient(
                colors: [
                    Color.teal
                        .opacity(
                            0.065
                        ),
                    Color.indigo
                        .opacity(
                            0.04
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
                    22,
                style:
                    .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    22,
                style:
                    .continuous
            )
            .stroke(
                Color.teal
                    .opacity(
                        0.14
                    )
            )
        }
    }


    // Header

    private var header:
        some View {

        HStack(
            spacing:
                12
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius:
                        14,
                    style:
                        .continuous
                )
                .fill(
                    Color.teal
                        .opacity(
                            0.12
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
                        "sparkles.rectangle.stack.fill"
                )
                .foregroundStyle(
                    .teal
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {

                Text(
                    "Document intelligence"
                )
                .font(
                    .headline
                )


                Text(
                    "Deterministic signals from the saved document"
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
    }


    private var loadingView:
        some View {

        HStack(
            spacing:
                10
        ) {

            ProgressView()


            Text(
                "Analyzing saved financial data locally…"
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .vertical,
            6
        )
    }


    // Smart Identity / Naming

    @ViewBuilder
    private func smartIdentitySection(
        _ intelligence:
            DocumentIntelligence
    ) -> some View {

        if intelligence
            .institution
            !=
            nil
            ||
            intelligence
                .suggestedName
            !=
            nil {

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                if let institution =
                    intelligence
                        .institution {

                    HStack(
                        alignment:
                            .top,
                        spacing:
                            10
                    ) {

                        Image(
                            systemName:
                                "building.2.crop.circle"
                        )
                        .foregroundStyle(
                            .teal
                        )
                        .frame(
                            width:
                                23
                        )


                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                3
                        ) {

                            Text(
                                "Detected institution / merchant"
                            )
                            .font(
                                .caption2
                                .weight(.semibold)
                            )
                            .foregroundStyle(
                                .secondary
                            )


                            Text(
                                institution
                                    .name
                            )
                            .font(
                                .subheadline
                                .weight(.semibold)
                            )


                            Text(
                                "\(institution.confidence.rawValue) • \(institution.source)"
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .tertiary
                            )
                        }


                        Spacer()
                    }
                }


                if let suggestedName =
                    intelligence
                        .suggestedName,
                   suggestedName
                    !=
                    currentName {

                    Divider()


                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            8
                    ) {

                        Label(
                            "Smart name suggestion",
                            systemImage:
                                "wand.and.stars"
                        )
                        .font(
                            .caption
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .indigo
                        )


                        Text(
                            suggestedName
                        )
                        .font(
                            .subheadline
                            .weight(.semibold)
                        )
                        .fixedSize(
                            horizontal:
                                false,
                            vertical:
                                true
                        )


                        Button {

                            onApplySuggestedName(
                                suggestedName
                            )

                        } label: {

                            HStack {

                                if isApplyingSmartName {

                                    ProgressView()

                                } else {

                                    Image(
                                        systemName:
                                            "checkmark.circle"
                                    )
                                }


                                Text(
                                    "Use Smart Name"
                                )
                            }
                        }
                        .buttonStyle(
                            .bordered
                        )
                        .disabled(
                            isApplyingSmartName
                        )
                    }
                }
            }
            .padding(
                13
            )
            .background(
                Color(
                    .secondarySystemBackground
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


    // Attention

    private func attentionSection(
        _ intelligence:
            DocumentIntelligence
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {

            Label(
                "What should I pay attention to?",
                systemImage:
                    "scope"
            )
            .font(
                .subheadline
                .weight(.bold)
            )


            ForEach(
                intelligence
                    .attentionItems
            ) {
                item in

                attentionRow(
                    item
                )
            }
        }
    }


    private func attentionRow(
        _ item:
            DocumentAttentionItem
    ) -> some View {

        HStack(
            alignment:
                .top,
            spacing:
                11
        ) {

            ZStack {

                Circle()
                    .fill(
                        attentionTint(
                            item.level
                        )
                        .opacity(
                            0.10
                        )
                    )
                    .frame(
                        width:
                            34,
                        height:
                            34
                    )


                Image(
                    systemName:
                        item
                            .systemImage
                )
                .font(
                    .caption
                    .weight(.bold)
                )
                .foregroundStyle(
                    attentionTint(
                        item.level
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
                    item
                        .title
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


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
            }


            Spacer()
        }
        .padding(
            11
        )
        .background(
            attentionTint(
                item.level
            )
            .opacity(
                0.04
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    14,
                style:
                    .continuous
            )
        )
    }


    private func attentionTint(
        _ level:
            DocumentAttentionItem
                .Level
    ) -> Color {

        switch level {

        case .action:
            return .red

        case .review:
            return .orange

        case .information:
            return .blue
        }
    }

    // Details

    private func detailIntelligence(
        _ intelligence:
            DocumentIntelligence
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                11
        ) {

            if !intelligence
                .importantDates
                .isEmpty {

                intelligenceSubheading(
                    "Important dates"
                )


                ForEach(
                    intelligence
                        .importantDates
                ) {
                    item in

                    intelligenceRow(
                        icon:
                            item
                                .systemImage,
                        title:
                            item
                                .label,
                        value:
                            item
                                .value
                    )
                }
            }


            if let movement =
                intelligence
                    .balanceMovement {

                if !intelligence
                    .importantDates
                    .isEmpty {

                    Divider()
                }


                intelligenceSubheading(
                    "Balance movement"
                )


                intelligenceRow(
                    icon:
                        movement
                            .delta
                        >=
                        0
                        ? "arrow.up.right.circle"
                        : "arrow.down.right.circle",
                    title:
                        movement
                            .directionText,
                    value:
                        "\(money(movement.beginning, currency: movement.currency)) → \(money(movement.ending, currency: movement.currency))"
                )


                Text(
                    "Net change: \(money(absDecimal(movement.delta), currency: movement.currency))"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            if let spendingBasis =
                intelligence
                    .spendingBasis {

                Divider()


                intelligenceRow(
                    icon:
                        "checkmark.shield",
                    title:
                        "Spending analysis basis",
                    value:
                        spendingBasis
                )


                Text(
                    "\(intelligence.analyzedSpendingRecordCount) cleaned spending record\(intelligence.analyzedSpendingRecordCount == 1 ? "" : "s") analyzed."
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


    // Charge Analysis

    private func chargeAnalysis(
        _ intelligence:
            DocumentIntelligence
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                13
        ) {

            if !intelligence
                .largestCharges
                .isEmpty {

                intelligenceSubheading(
                    "Largest included charges"
                )


                ForEach(
                    Array(
                        intelligence
                            .largestCharges
                            .prefix(
                                3
                            )
                    )
                ) {
                    charge in

                    chargeRow(
                        charge
                    )
                }
            }


            if !intelligence
                .duplicateCandidates
                .isEmpty {

                Divider()


                intelligenceSubheading(
                    "Possible repeated charges"
                )


                ForEach(
                    intelligence
                        .duplicateCandidates
                ) {
                    candidate in

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            4
                    ) {

                        HStack {

                            Text(
                                candidate
                                    .merchant
                            )
                            .font(
                                .subheadline
                                .weight(.semibold)
                            )


                            Spacer()


                            Text(
                                money(
                                    candidate
                                        .amount,
                                    currency:
                                        candidate
                                            .currency
                                )
                            )
                            .font(
                                .subheadline
                                .weight(.bold)
                            )
                        }


                        Text(
                            "\(candidate.firstDate.formatted(date: .abbreviated, time: .omitted)) and \(candidate.secondDate.formatted(date: .abbreviated, time: .omitted)) • \(candidate.daysApart) day\(candidate.daysApart == 1 ? "" : "s") apart"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .padding(
                        11
                    )
                    .background(
                        Color.orange
                            .opacity(
                                0.055
                            )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                13,
                            style:
                                .continuous
                        )
                    )
                }


                Text(
                    "Same-day repeats are intentionally not flagged because OCR or statement layouts can duplicate a row."
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )
            }


            if !intelligence
                .unusualChargeSignals
                .isEmpty {

                Divider()


                intelligenceSubheading(
                    "Large-charge signals"
                )


                ForEach(
                    intelligence
                        .unusualChargeSignals
                ) {
                    signal in

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            5
                    ) {

                        HStack {

                            Text(
                                signal
                                    .charge
                                    .merchant
                            )
                            .font(
                                .subheadline
                                .weight(.semibold)
                            )


                            Spacer()


                            Text(
                                money(
                                    signal
                                        .charge
                                        .amount,
                                    currency:
                                        signal
                                            .charge
                                            .currency
                                )
                            )
                            .font(
                                .subheadline
                                .weight(.bold)
                            )
                        }


                        Text(
                            "\(String(format: "%.1f×", signal.multipleOfTypical)) this document's typical included charge of \(money(signal.typicalAmount, currency: signal.charge.currency))"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .padding(
                        11
                    )
                    .background(
                        Color.orange
                            .opacity(
                                0.055
                            )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                13,
                            style:
                                .continuous
                        )
                    )
                }
            }


            if intelligence
                .duplicateCandidates
                .isEmpty
                &&
                intelligence
                    .unusualChargeSignals
                    .isEmpty
                &&
                intelligence
                    .largestCharges
                    .isEmpty {

                Text(
                    "There were not enough cleaned spending records to produce charge-pattern insights."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    private func chargeRow(
        _ charge:
            DocumentChargeInsight
    ) -> some View {

        HStack(
            alignment:
                .top,
            spacing:
                10
        ) {

            Image(
                systemName:
                    "dollarsign.circle"
            )
            .foregroundStyle(
                .indigo
            )
            .frame(
                width:
                    22
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    charge
                        .merchant
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                HStack(
                    spacing:
                        5
                ) {

                    if let date =
                        charge
                            .date {

                        Text(
                            date.formatted(
                                date:
                                    .abbreviated,
                                time:
                                    .omitted
                            )
                        )
                    }


                    if let category =
                        charge
                            .category,
                       !category
                        .isEmpty {

                        Text(
                            "•"
                        )

                        Text(
                            category
                        )
                    }
                }
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Text(
                money(
                    charge
                        .amount,
                    currency:
                        charge
                            .currency
                )
            )
            .font(
                .subheadline
                .weight(.bold)
            )
        }
    }


    // Helpers

    private func intelligenceSubheading(
        _ title:
            String
    ) -> some View {

        Text(
            title
        )
        .font(
            .caption
            .weight(.bold)
        )
        .foregroundStyle(
            .secondary
        )
        .textCase(
            .uppercase
        )
    }


    private func intelligenceRow(
        icon:
            String,
        title:
            String,
        value:
            String
    ) -> some View {

        HStack(
            alignment:
                .top,
            spacing:
                10
        ) {

            Image(
                systemName:
                    icon
            )
            .foregroundStyle(
                .indigo
            )
            .frame(
                width:
                    22
            )


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
                )
                .foregroundStyle(
                    .secondary
                )


                Text(
                    value
                )
                .font(
                    .subheadline
                    .weight(.semibold)
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
    }


    private var intelligenceDisclaimer:
        some View {

        Text(
            "Duplicate and unusual-charge signals are deterministic review aids, not proof of an error, duplicate payment, fraud, or unauthorized activity. Verify important findings against the original document."
        )
        .font(
            .caption2
        )
        .foregroundStyle(
            .tertiary
        )
        .fixedSize(
            horizontal:
                false,
            vertical:
                true
        )
    }


    private func money(
        _ value:
            Decimal,
        currency:
            String
    ) -> String {

        CrossDocumentAnalysisEngine
            .formatMoney(
                value,
                currency:
                    currency
            )
    }


    private func absDecimal(
        _ value:
            Decimal
    ) -> Decimal {

        value
        <
        0
        ? -value
        : value
    }
}
