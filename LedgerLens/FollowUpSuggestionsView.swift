import SwiftUI

enum FollowUpSuggestionEngine {

    static func suggestions(
        documentType: String,
        previousQuestion: String
    ) -> [String] {

        let type =
            documentType
                .lowercased()

        let candidates:
            [String]

        if type.contains(
            "bank"
        )
        || type.contains(
            "statement"
        ) {

            candidates = [
                "Show me all pending transactions.",
                "What was my largest purchase?",
                "How much did I spend in total?",
                "Show me every transaction over $100."
            ]

        } else if type.contains(
            "bill"
        )
        || type.contains(
            "invoice"
        )
        || type.contains(
            "receipt"
        ) {

            candidates = [
                "What is the total amount due?",
                "When is this bill due?",
                "What are the largest charges?",
                "Explain the charges on this bill."
            ]

        } else {

            candidates = [
                "Summarize the most important information.",
                "What are the largest amounts in this document?",
                "What dates should I know about?",
                "Explain this document in simple terms."
            ]
        }

        let normalizedPrevious =
            previousQuestion
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        return candidates
            .filter {
                $0.lowercased()
                    !=
                normalizedPrevious
            }
            .prefix(3)
            .map { $0 }
    }
}


struct FollowUpSuggestionsView:
    View {

    let suggestions:
        [String]

    let onSelect:
        (String) -> Void

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Label(
                "Try a follow-up",
                systemImage:
                    "arrow.turn.down.right"
            )
            .font(
                .caption
                .weight(.semibold)
            )
            .foregroundStyle(
                .secondary
            )

            VStack(spacing: 8) {

                ForEach(
                    suggestions,
                    id: \.self
                ) {
                    suggestion in

                    Button {

                        onSelect(
                            suggestion
                        )

                    } label: {

                        HStack(
                            spacing: 10
                        ) {

                            Text(
                                suggestion
                            )
                            .font(
                                .subheadline
                                .weight(.medium)
                            )
                            .multilineTextAlignment(
                                .leading
                            )
                            .foregroundStyle(
                                .primary
                            )

                            Spacer()

                            Image(
                                systemName:
                                    "arrow.up.right"
                            )
                            .font(
                                .caption
                                .weight(.bold)
                            )
                            .foregroundStyle(
                                .blue
                            )
                        }
                        .padding(
                            .horizontal,
                            13
                        )
                        .padding(
                            .vertical,
                            11
                        )
                        .background(
                            Color.blue
                                .opacity(0.055)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style:
                                    .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
