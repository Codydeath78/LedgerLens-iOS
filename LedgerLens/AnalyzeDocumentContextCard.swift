import SwiftUI

struct AnalyzeDocumentContextCard: View {

    let displayName:
        String?

    let summary:
        HistoryDocumentSummary?

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack(
                spacing: 10
            ) {

                ZStack {

                    Circle()
                        .fill(
                            Color.indigo
                                .opacity(0.10)
                        )
                        .frame(
                            width: 38,
                            height: 38
                        )

                    Image(
                        systemName:
                            "arrow.triangle.2.circlepath.doc.on.clipboard"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .indigo
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(
                        displayName
                        ??
                        "Current document"
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )

                    Text(
                        summary == nil
                        ? "Ready for questions"
                        : "Document context restored"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()
            }


            if let summary {

                Divider()

                Text(
                    summary.headline
                )
                .font(
                    .subheadline
                    .weight(.semibold)
                )

                if let subheadline =
                    summary
                        .subheadline {

                    Text(
                        subheadline
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }


                if !summary
                    .items
                    .isEmpty {

                    ScrollView(
                        .horizontal,
                        showsIndicators:
                            false
                    ) {

                        HStack(
                            spacing: 8
                        ) {

                            ForEach(
                                summary
                                    .items
                                    .prefix(4)
                            ) {
                                item in

                                VStack(
                                    alignment:
                                        .leading,
                                    spacing: 4
                                ) {

                                    Label(
                                        item.label,
                                        systemImage:
                                            item
                                                .systemImage
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
                                        .caption
                                        .weight(.semibold)
                                    )
                                    .foregroundStyle(
                                        .primary
                                    )
                                    .lineLimit(1)
                                }
                                .padding(
                                    .horizontal,
                                    11
                                )
                                .padding(
                                    .vertical,
                                    9
                                )
                                .background(
                                    Color.indigo
                                        .opacity(0.055)
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 13,
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
        .padding(15)
        .background(
            Color.indigo
                .opacity(0.045)
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
                Color.indigo
                    .opacity(0.10)
            )
        }
    }
}
