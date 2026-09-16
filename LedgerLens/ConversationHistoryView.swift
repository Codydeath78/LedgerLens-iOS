import SwiftUI

struct ConversationHistoryView: View {

    let conversations:
        [DocumentConversation]

    let onDelete:
        (DocumentConversation) -> Void

    let onClear:
        () -> Void

    @State private var showClearConfirmation =
        false

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Label(
                    "Previous conversation",
                    systemImage:
                        "bubble.left.and.text.bubble.right"
                )
                .font(
                    .headline
                )

                Spacer()

                Text(
                    "\(conversations.count)"
                )
                .font(
                    .caption
                    .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )

                Button(
                    role: .destructive
                ) {

                    showClearConfirmation =
                        true

                } label: {

                    Image(
                        systemName:
                            "trash"
                    )
                    .font(
                        .subheadline
                    )
                }
                .buttonStyle(
                    .bordered
                )
                .accessibilityLabel(
                    "Clear conversation"
                )
            }


            ForEach(
                conversations
            ) {
                item in

                conversationCard(
                    item
                )
            }
        }
        .alert(
            "Clear conversation?",
            isPresented:
                $showClearConfirmation
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) {}

            Button(
                "Clear",
                role: .destructive
            ) {

                onClear()
            }

        } message: {

            Text(
                "This removes every saved question and answer for this document. The document itself and its original file stay in History."
            )
        }
    }


    private func conversationCard(
        _ item:
            DocumentConversation
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack(
                alignment: .top,
                spacing: 10
            ) {

                ZStack {

                    Circle()
                        .fill(
                            Color.blue
                                .opacity(0.10)
                        )
                        .frame(
                            width: 34,
                            height: 34
                        )

                    Image(
                        systemName:
                            "person.fill"
                    )
                    .font(
                        .system(
                            size: 13,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        .blue
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(
                        PlainTextSanitizer
                            .clean(
                                item.question
                            )
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )
                    .foregroundStyle(
                        .primary
                    )

                    Text(
                        item.createdAt
                            .formatted(
                                date:
                                    .abbreviated,
                                time:
                                    .shortened
                            )
                    )
                    .font(
                        .caption2
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                }

                Spacer()

                Menu {

                    Button(
                        role:
                            .destructive
                    ) {

                        onDelete(
                            item
                        )

                    } label: {

                        Label(
                            "Delete Q&A",
                            systemImage:
                                "trash"
                        )
                    }

                } label: {

                    Image(
                        systemName:
                            "ellipsis"
                    )
                    .font(
                        .headline
                    )
                    .frame(
                        width: 32,
                        height: 32
                    )
                }
            }


            HStack(
                alignment: .top,
                spacing: 10
            ) {

                ZStack {

                    Circle()
                        .fill(
                            Color.indigo
                                .opacity(0.10)
                        )
                        .frame(
                            width: 34,
                            height: 34
                        )

                    Image(
                        systemName:
                            "sparkles"
                    )
                    .font(
                        .system(
                            size: 13,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        .indigo
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {

                    Text(
                        PlainTextSanitizer
                            .clean(
                                item.answer
                            )
                    )
                    .font(
                        .subheadline
                    )
                    .lineSpacing(3)
                    .foregroundStyle(
                        .primary
                    )
                    .textSelection(
                        .enabled
                    )

                    Text(
                        "\(prettyMode(item.retrievalMode)) analysis"
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
                        8
                    )
                    .padding(
                        .vertical,
                        5
                    )
                    .background(
                        Color.indigo
                            .opacity(0.07)
                    )
                    .clipShape(
                        Capsule()
                    )
                }

                Spacer()
            }
        }
        .padding(15)
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
        .overlay {

            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.06)
            )
        }
    }


    private func prettyMode(
        _ value:
            String
    ) -> String {

        value
            .lowercased()
            .capitalized
    }
}
