// Document Organization

import SwiftUI


enum HistorySortOption:
    String,
    CaseIterable,
    Identifiable {

    case newest =
        "Newest first"

    case oldest =
        "Oldest first"

    case favorites =
        "Favorites first"

    case nameAZ =
        "Name A–Z"

    case nameZA =
        "Name Z–A"

    case type =
        "Document type"


    var id:
        String {

        rawValue
    }


    var systemImage:
        String {

        switch self {

        case .newest:
            return
                "calendar.badge.clock"

        case .oldest:
            return
                "calendar"

        case .favorites:
            return
                "star.fill"

        case .nameAZ:
            return
                "textformat.abc"

        case .nameZA:
            return
                "textformat.abc"

        case .type:
            return
                "square.grid.2x2"
        }
    }
}


enum HistorySourceFilter:
    String,
    CaseIterable,
    Identifiable {

    case all =
        "All sources"

    case uploads =
        "Uploads"

    case scans =
        "Scans"


    var id:
        String {

        rawValue
    }
}


enum HistoryOriginalFilter:
    String,
    CaseIterable,
    Identifiable {

    case all =
        "All originals"

    case stored =
        "Original saved"

    case missing =
        "Original unavailable"


    var id:
        String {

        rawValue
    }
}


enum HistoryFavoriteFilter:
    String,
    CaseIterable,
    Identifiable {

    case all =
        "All documents"

    case favorites =
        "Favorites only"


    var id:
        String {

        rawValue
    }
}


struct HistoryFilterSheet:
    View {

    @Environment(\.dismiss)
    private var dismiss

    @Binding var sortOption:
        HistorySortOption

    @Binding var sourceFilter:
        HistorySourceFilter

    @Binding var originalFilter:
        HistoryOriginalFilter

    @Binding var favoriteFilter:
        HistoryFavoriteFilter

    @Binding var documentTypeFilter:
        String

    @Binding var folderFilterID:
        UUID?

    let availableDocumentTypes:
        [String]

    let folders:
        [DocumentFolder]


    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "Sort"
                ) {

                    Picker(
                        "Sort order",
                        selection:
                            $sortOption
                    ) {

                        ForEach(
                            HistorySortOption
                                .allCases
                        ) {
                            option in

                            Label(
                                option
                                    .rawValue,
                                systemImage:
                                    option
                                        .systemImage
                            )
                            .tag(
                                option
                            )
                        }
                    }
                    .pickerStyle(
                        .inline
                    )
                    .labelsHidden()
                }


                Section(
                    "Favorites"
                ) {

                    Picker(
                        "Favorites",
                        selection:
                            $favoriteFilter
                    ) {

                        ForEach(
                            HistoryFavoriteFilter
                                .allCases
                        ) {
                            filter in

                            Text(
                                filter
                                    .rawValue
                            )
                            .tag(
                                filter
                            )
                        }
                    }
                    .pickerStyle(
                        .segmented
                    )
                }


                Section(
                    "Folder"
                ) {

                    Picker(
                        "Folder",
                        selection:
                            $folderFilterID
                    ) {

                        Text(
                            "All folders"
                        )
                        .tag(
                            Optional<UUID>
                                .none
                        )


                        ForEach(
                            folders
                        ) {
                            folder in

                            Label(
                                folder
                                    .name,
                                systemImage:
                                    folder
                                        .iconName
                            )
                            .tag(
                                Optional(
                                    folder.id
                                )
                            )
                        }
                    }
                }


                Section(
                    "Source"
                ) {

                    Picker(
                        "Source",
                        selection:
                            $sourceFilter
                    ) {

                        ForEach(
                            HistorySourceFilter
                                .allCases
                        ) {
                            filter in

                            Text(
                                filter
                                    .rawValue
                            )
                            .tag(
                                filter
                            )
                        }
                    }
                    .pickerStyle(
                        .segmented
                    )
                }


                Section(
                    "Original file"
                ) {

                    Picker(
                        "Original file",
                        selection:
                            $originalFilter
                    ) {

                        ForEach(
                            HistoryOriginalFilter
                                .allCases
                        ) {
                            filter in

                            Text(
                                filter
                                    .rawValue
                            )
                            .tag(
                                filter
                            )
                        }
                    }
                }


                Section(
                    "Document type"
                ) {

                    Picker(
                        "Document type",
                        selection:
                            $documentTypeFilter
                    ) {

                        Text(
                            "All document types"
                        )
                        .tag(
                            "ALL"
                        )


                        ForEach(
                            availableDocumentTypes,
                            id:
                                \.self
                        ) {
                            type in

                            Text(
                                type
                            )
                            .tag(
                                type
                            )
                        }
                    }
                }


                Section {

                    Button(
                        "Reset Filters"
                    ) {

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
                    .foregroundStyle(
                        .red
                    )
                }
            }
            .navigationTitle(
                "Sort & Filter"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button(
                        "Done"
                    ) {

                        dismiss()
                    }
                }
            }
        }
    }
}
