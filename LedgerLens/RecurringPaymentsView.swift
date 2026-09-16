import SwiftUI


struct RecurringPaymentsView: View {

    let patterns:
        [RecurringPaymentPattern]


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
                    4
            ) {

                Label(
                    "Recurring payments",
                    systemImage:
                        "repeat.circle.fill"
                )
                .font(
                    .title3
                    .weight(.bold)
                )


                Text(
                    "Detected from repeated merchant, amount, and timing patterns across the selected documents."
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


            if patterns
                .isEmpty {

                ContentUnavailableView(
                    "No recurring patterns detected",
                    systemImage:
                        "repeat.circle",
                    description:
                        Text(
                            "Try selecting statements that cover multiple billing periods."
                        )
                )
                .frame(
                    maxWidth:
                        .infinity
                )
                .padding(
                    .vertical,
                    10
                )

            } else {

                recurringMonthlyTotals


                ForEach(
                    patterns
                ) {
                    pattern in

                    RecurringPaymentCard(
                        pattern:
                            pattern
                    )
                }


                Text(
                    "Recurring detection is a deterministic pattern signal, not proof that a subscription is still active. Review the original statements before canceling or disputing anything."
                )
                .font(
                    .caption2
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
        }
    }


    // Monthly Total

    @ViewBuilder
    private var recurringMonthlyTotals:
        some View {

        let grouped =
            Dictionary(
                grouping:
                    patterns.compactMap {
                        pattern
                        ->
                        (
                            String,
                            Decimal
                        )?
                        in

                        guard
                            let monthly =
                                pattern
                                    .estimatedMonthlyAmount
                        else {
                            return nil
                        }

                        return (
                            pattern
                                .currency,
                            monthly
                        )
                    },
                by:
                    \.0
            )


        if !grouped
            .isEmpty {

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                Text(
                    "Estimated recurring monthly impact"
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )


                HStack(
                    spacing:
                        10
                ) {

                    ForEach(
                        grouped
                            .keys
                            .sorted(),
                        id:
                            \.self
                    ) {
                        currency in

                        let total =
                            grouped[
                                currency,
                                default: []
                            ]
                            .reduce(
                                Decimal.zero
                            ) {
                                partial,
                                item in

                                partial
                                +
                                item.1
                            }


                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                3
                        ) {

                            Text(
                                CrossDocumentAnalysisEngine
                                    .formatMoney(
                                        total,
                                        currency:
                                            currency
                                    )
                            )
                            .font(
                                .title3
                                .weight(.bold)
                            )

                            Text(
                                "\(currency) / month est."
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                        .padding(
                            13
                        )
                        .background(
                            Color.indigo
                                .opacity(
                                    0.065
                                )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius:
                                    15,
                                style:
                                    .continuous
                            )
                        )
                    }
                }
            }
        }
    }
}


// Recurring Card

private struct RecurringPaymentCard:
    View {

    let pattern:
        RecurringPaymentPattern

    @State private var isExpanded =
        false


    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                13
        ) {

            Button {

                withAnimation(
                    .easeInOut(
                        duration:
                            0.2
                    )
                ) {

                    isExpanded
                        .toggle()
                }

            } label: {

                HStack(
                    alignment:
                        .top,
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
                            Color.indigo
                                .opacity(
                                    0.10
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
                                "repeat"
                        )
                        .font(
                            .system(
                                size:
                                    18,
                                weight:
                                    .bold
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
                            5
                    ) {

                        Text(
                            pattern
                                .merchant
                        )
                        .font(
                            .headline
                        )
                        .foregroundStyle(
                            .primary
                        )


                        HStack(
                            spacing:
                                6
                        ) {

                            Text(
                                pattern
                                    .cadence
                                    .rawValue
                            )

                            Text(
                                "•"
                            )

                            Text(
                                pattern
                                    .confidence
                                    .rawValue
                            )
                        }
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )


                        Text(
                            "Typical charge \(CrossDocumentAnalysisEngine.formatMoney(pattern.typicalAmount, currency: pattern.currency))"
                        )
                        .font(
                            .caption
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .primary
                        )
                    }


                    Spacer()


                    VStack(
                        alignment:
                            .trailing,
                        spacing:
                            5
                    ) {

                        if let monthly =
                            pattern
                                .estimatedMonthlyAmount {

                            Text(
                                CrossDocumentAnalysisEngine
                                    .formatMoney(
                                        monthly,
                                        currency:
                                            pattern
                                                .currency
                                    )
                            )
                            .font(
                                .subheadline
                                .weight(.bold)
                            )


                            Text(
                                "/ month est."
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }


                        Image(
                            systemName:
                                isExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                    }
                }
            }
            .buttonStyle(
                .plain
            )


            if isExpanded {

                Divider()


                ForEach(
                    pattern
                        .occurrences
                ) {
                    occurrence in

                    HStack(
                        alignment:
                            .top,
                        spacing:
                            10
                    ) {

                        Image(
                            systemName:
                                "calendar"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .blue
                        )
                        .frame(
                            width:
                                20
                        )


                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                2
                        ) {

                            Text(
                                occurrence
                                    .date
                                    .formatted(
                                        date:
                                            .abbreviated,
                                        time:
                                            .omitted
                                    )
                            )
                            .font(
                                .caption
                                .weight(.semibold)
                            )


                            Text(
                                occurrence
                                    .documentName
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(
                                1
                            )
                        }


                        Spacer()


                        Text(
                            CrossDocumentAnalysisEngine
                                .formatMoney(
                                    occurrence
                                        .amount,
                                    currency:
                                        occurrence
                                            .currency
                                )
                        )
                        .font(
                            .caption
                            .weight(.semibold)
                        )
                    }
                }


                if let annual =
                    pattern
                        .estimatedAnnualAmount {

                    Divider()


                    HStack {

                        Text(
                            "Estimated annual impact"
                        )
                        .font(
                            .caption
                            .weight(.semibold)
                        )


                        Spacer()


                        Text(
                            CrossDocumentAnalysisEngine
                                .formatMoney(
                                    annual,
                                    currency:
                                        pattern
                                            .currency
                                )
                        )
                        .font(
                            .caption
                            .weight(.bold)
                        )
                    }
                }
            }
        }
        .padding(
            15
        )
        .background(
            Color(
                .secondarySystemBackground
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
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    19,
                style:
                    .continuous
            )
            .stroke(
                Color.indigo
                    .opacity(
                        0.10
                    )
            )
        }
    }
}
