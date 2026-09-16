// Document Organization

import SwiftUI


struct DocumentOrganizationSheet:
    View {

    @Environment(\.dismiss)
    private var dismiss

    let document:
        HistoryDocument

    let folders:
        [DocumentFolder]

    let onChanged:
        () async -> Void


    @State private var isFavorite:
        Bool

    @State private var selectedFolderID:
        UUID?

    @State private var isSaving =
        false

    @State private var errorMessage:
        String?


    init(
        document:
            HistoryDocument,
        folders:
            [DocumentFolder],
        onChanged:
            @escaping () async -> Void
    ) {

        self.document =
            document

        self.folders =
            folders

        self.onChanged =
            onChanged


        _isFavorite =
            State(
                initialValue:
                    document
                        .isFavorite
            )


        _selectedFolderID =
            State(
                initialValue:
                    document
                        .folderID
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "Favorite"
                ) {

                    Toggle(
                        isFavorite
                        ? "Pinned to Favorites"
                        : "Add to Favorites",
                        isOn:
                            $isFavorite
                    )
                    .disabled(
                        isSaving
                    )


                    Text(
                        "Favorites can be filtered or sorted to the top of History."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Section(
                    "Folder"
                ) {

                    Button {

                        selectedFolderID =
                            nil

                    } label: {

                        HStack {

                            Label(
                                "No Folder",
                                systemImage:
                                    "tray"
                            )
                            .foregroundStyle(
                                .primary
                            )


                            Spacer()


                            if selectedFolderID
                                ==
                                nil {

                                Image(
                                    systemName:
                                        "checkmark"
                                )
                                .foregroundStyle(
                                    .blue
                                )
                            }
                        }
                    }
                    .buttonStyle(
                        .plain
                    )


                    ForEach(
                        folders
                    ) {
                        folder in

                        Button {

                            selectedFolderID =
                                folder.id

                        } label: {

                            HStack {

                                Label(
                                    folder.name,
                                    systemImage:
                                        folder
                                            .iconName
                                )
                                .foregroundStyle(
                                    .primary
                                )


                                Spacer()


                                if selectedFolderID
                                    ==
                                    folder.id {

                                    Image(
                                        systemName:
                                            "checkmark"
                                    )
                                    .foregroundStyle(
                                        .blue
                                    )
                                }
                            }
                        }
                        .buttonStyle(
                            .plain
                        )
                    }


                    if folders
                        .isEmpty {

                        Text(
                            "No folders exist yet. Use Manage Folders in History to create one."
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }


                if let errorMessage {

                    Section {

                        Text(
                            errorMessage
                        )
                        .foregroundStyle(
                            .red
                        )
                    }
                }
            }
            .navigationTitle(
                "Organize Document"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {

                    Button(
                        "Cancel"
                    ) {

                        dismiss()
                    }
                    .disabled(
                        isSaving
                    )
                }


                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button(
                        isSaving
                        ? "Saving…"
                        : "Save"
                    ) {

                        save()
                    }
                    .disabled(
                        isSaving
                    )
                }
            }
        }
    }


    private func save() {

        guard
            !isSaving
        else {
            return
        }


        isSaving =
            true

        errorMessage =
            nil


        Task {

            do {

                // One database UPDATE keeps favorite + folder
                // changes atomic. We never leave a document half
                // organized if the second field fails.
                try await
                    DocumentHistoryService
                        .shared
                        .updateOrganization(
                            id:
                                document.id,
                            isFavorite:
                                isFavorite,
                            folderID:
                                selectedFolderID
                        )


                await onChanged()


                await MainActor.run {

                    dismiss()
                }

            } catch {

                await MainActor.run {

                    errorMessage =
                        friendlyOrganizationError(
                            error
                        )

                    isSaving =
                        false
                }
            }
        }
    }


    private func friendlyOrganizationError(
        _ error:
            Error
    ) -> String {

        let raw =
            error
                .localizedDescription


        if raw
            .localizedCaseInsensitiveContains(
                "folder"
            )
        &&
        raw
            .localizedCaseInsensitiveContains(
                "user"
            ) {

            return
                "That folder is no longer available. Refresh History and try again."
        }


        return raw
    }
}
