// Document Organization

import SwiftUI


struct HistoryDocumentCard:
    View {

    let document:
        HistoryDocument

    let folderName:
        String?


    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {

            HStack(
                alignment:
                    .top,
                spacing:
                    14
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius:
                            17,
                        style:
                            .continuous
                    )
                    .fill(
                        iconBackground
                    )
                    .frame(
                        width:
                            58,
                        height:
                            58
                    )


                    Image(
                        systemName:
                            documentIcon
                    )
                    .font(
                        .system(
                            size:
                                23,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        iconForeground
                    )
                }


                VStack(
                    alignment:
                        .leading,
                    spacing:
                        5
                ) {

                    HStack(
                        alignment:
                            .top,
                        spacing:
                            7
                    ) {

                        Text(
                            document
                                .resolvedDisplayName
                        )
                        .font(
                            .headline
                        )
                        .foregroundStyle(
                            .primary
                        )
                        .lineLimit(
                            2
                        )


                        if document
                            .isFavorite {

                            Image(
                                systemName:
                                    "star.fill"
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .yellow
                            )
                            .padding(
                                .top,
                                2
                            )
                        }
                    }


                    Text(
                        document
                            .prettyDocumentType
                    )
                    .font(
                        .subheadline
                    )
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
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                }


                Spacer(
                    minLength:
                        8
                )


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
                .padding(
                    .top,
                    8
                )
            }


            ScrollView(
                .horizontal,
                showsIndicators:
                    false
            ) {

                HStack(
                    spacing:
                        7
                ) {

                    if let folderName {

                        metadataChip(
                            title:
                                folderName,
                            systemImage:
                                "folder.fill"
                        )
                    }


                    if let dueDate =
                        document
                            .dueDate {

                        dueDateChip(
                            dueDate
                        )
                    }


                    if document
                        .reminderEnabled {

                        metadataChip(
                            title:
                                "Reminder on",
                            systemImage:
                                "bell.badge.fill"
                        )
                    }


                    metadataChip(
                        title:
                            document
                                .sourceType
                                .capitalized,
                        systemImage:
                            document
                                .sourceType
                            ==
                            "scan"
                            ? "camera.fill"
                            : "arrow.up.doc.fill"
                    )


                    if document
                        .hasStoredOriginal {

                        metadataChip(
                            title:
                                "Original saved",
                            systemImage:
                                "lock.fill"
                        )
                    }


                    if let bytes =
                        document
                            .originalSizeBytes {

                        metadataChip(
                            title:
                                ByteCountFormatter
                                    .string(
                                        fromByteCount:
                                            bytes,
                                        countStyle:
                                            .file
                                    ),
                            systemImage:
                                "externaldrive"
                        )
                    }
                }
            }
            .lineLimit(
                1
            )
        }
        .padding(
            16
        )
        .background(
            cardBackground
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    24,
                style:
                    .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    24,
                style:
                    .continuous
            )
            .stroke(
                document
                    .isFavorite
                ? Color.yellow
                    .opacity(
                        0.22
                    )
                : Color.primary
                    .opacity(
                        0.07
                    )
            )
        }
        .shadow(
            color:
                Color.black
                    .opacity(
                        0.035
                    ),
            radius:
                14,
            y:
                6
        )
    }


    private var documentIcon:
        String {

        if document
            .sourceType
            ==
            "scan" {

            return
                "camera.viewfinder"
        }


        let lower =
            document
                .documentType
                .lowercased()


        if lower.contains(
            "bank"
        )
        ||
        lower.contains(
            "statement"
        ) {

            return
                "building.columns.fill"
        }


        if lower.contains(
            "bill"
        )
        ||
        lower.contains(
            "invoice"
        ) {

            return
                "doc.text.fill"
        }


        return
            "doc.fill"
    }


    private var iconBackground:
        Color {

        document
            .sourceType
        ==
        "scan"
        ? Color.purple
            .opacity(
                0.11
            )
        : Color.blue
            .opacity(
                0.10
            )
    }


    private var iconForeground:
        Color {

        document
            .sourceType
        ==
        "scan"
        ? .purple
        : .blue
    }


    private var cardBackground:
        some ShapeStyle {

        LinearGradient(
            colors: [
                Color(
                    .secondarySystemBackground
                ),
                document
                    .sourceType
                ==
                "scan"
                ? Color.purple
                    .opacity(
                        0.035
                    )
                : Color.blue
                    .opacity(
                        0.035
                    )
            ],
            startPoint:
                .topLeading,
            endPoint:
                .bottomTrailing
        )
    }


    private func dueDateChip(
        _ dueDate:
            Date
    ) -> some View {

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


        let title:
            String


        switch days {

        case ..<0:

            title =
                "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"

        case 0:

            title =
                "Due today"

        case 1:

            title =
                "Due tomorrow"

        default:

            title =
                days <= 14
                ? "Due in \(days) days"
                : "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }


        return
            Label(
                title,
                systemImage:
                    "calendar.badge.exclamationmark"
            )
            .font(
                .caption2
                .weight(.semibold)
            )
            .foregroundStyle(
                days >= 0
                &&
                days <= 7
                ? Color.orange
                : Color.secondary
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
                (
                    days >= 0
                    &&
                    days <= 7
                    ? Color.orange
                    : Color.primary
                )
                .opacity(
                    0.06
                )
            )
            .clipShape(
                Capsule()
            )
    }


    private func metadataChip(
        title:
            String,
        systemImage:
            String
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
            .secondary
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
            Color.primary
                .opacity(
                    0.045
                )
        )
        .clipShape(
            Capsule()
        )
    }
}
