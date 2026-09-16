import SwiftUI


struct FolderManagerView:
    View {

    @Environment(\.dismiss)
    private var dismiss

    @State private var folders:
        [DocumentFolder] = []

    @State private var isLoading =
        true

    @State private var errorMessage:
        String?

    @State private var editorTarget:
        FolderEditorTarget?

    @State private var folderToDelete:
        DocumentFolder?


    let onChanged:
        () async -> Void


    var body: some View {

        NavigationStack {

            List {

                Section {

                    Button {

                        editorTarget =
                            FolderEditorTarget(
                                folder:
                                    nil
                            )

                    } label: {

                        Label(
                            "Create Folder",
                            systemImage:
                                "folder.badge.plus"
                        )
                    }


                    Button {

                        addSuggestedFolders()

                    } label: {

                        Label(
                            "Add Suggested Folders",
                            systemImage:
                                "sparkles"
                        )
                    }


                    Text(
                        "Suggested folders: Bank, Utilities, Medical, Taxes, and Credit Cards."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Section(
                    "Your Folders"
                ) {

                    if isLoading {

                        HStack {

                            ProgressView()

                            Text(
                                "Loading folders…"
                            )
                        }

                    } else if
                        folders
                            .isEmpty {

                        ContentUnavailableView(
                            "No folders yet",
                            systemImage:
                                "folder",
                            description:
                                Text(
                                    "Create your own folder or add the suggested set."
                                )
                        )

                    } else {

                        ForEach(
                            folders
                        ) {
                            folder in

                            Button {

                                editorTarget =
                                    FolderEditorTarget(
                                        folder:
                                            folder
                                    )

                            } label: {

                                HStack(
                                    spacing:
                                        12
                                ) {

                                    Image(
                                        systemName:
                                            folder
                                                .iconName
                                    )
                                    .foregroundStyle(
                                        .blue
                                    )
                                    .frame(
                                        width:
                                            24
                                    )


                                    Text(
                                        folder
                                            .name
                                    )
                                    .foregroundStyle(
                                        .primary
                                    )


                                    Spacer()


                                    Image(
                                        systemName:
                                            "chevron.right"
                                    )
                                    .font(
                                        .caption
                                    )
                                    .foregroundStyle(
                                        .tertiary
                                    )
                                }
                            }
                            .buttonStyle(
                                .plain
                            )
                            .swipeActions {

                                Button(
                                    role:
                                        .destructive
                                ) {

                                    folderToDelete =
                                        folder

                                } label: {

                                    Label(
                                        "Delete",
                                        systemImage:
                                            "trash"
                                    )
                                }


                                Button {

                                    editorTarget =
                                        FolderEditorTarget(
                                            folder:
                                                folder
                                        )

                                } label: {

                                    Label(
                                        "Edit",
                                        systemImage:
                                            "pencil"
                                    )
                                }
                                .tint(
                                    .blue
                                )
                            }
                        }
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
                "Folders"
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
                        "Done"
                    ) {

                        dismiss()
                    }
                }
            }
            .task {

                await load()
            }
            .sheet(
                item:
                    $editorTarget
            ) {
                target in

                FolderEditorView(
                    folder:
                        target
                            .folder
                ) {

                    await load()

                    await onChanged()
                }
                .presentationDetents(
                    [
                        .medium
                    ]
                )
            }
            .alert(
                "Delete Folder?",
                isPresented:
                    Binding(
                        get: {
                            folderToDelete
                            != nil
                        },
                        set: {
                            if !$0 {

                                folderToDelete =
                                    nil
                            }
                        }
                    )
            ) {

                Button(
                    "Cancel",
                    role:
                        .cancel
                ) {

                    folderToDelete =
                        nil
                }


                Button(
                    "Delete",
                    role:
                        .destructive
                ) {

                    if let folder =
                        folderToDelete {

                        delete(
                            folder
                        )
                    }
                }

            } message: {

                Text(
                    "Documents inside this folder will not be deleted. They will move back to No Folder."
                )
            }
        }
    }


    @MainActor
    private func load()
        async {

        isLoading =
            folders
                .isEmpty


        do {

            folders =
                try await
                    DocumentFolderService
                        .shared
                        .fetchFolders()


            errorMessage =
                nil

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }


        isLoading =
            false
    }


    private func addSuggestedFolders() {

        Task {

            do {

                try await
                    DocumentFolderService
                        .shared
                        .createSuggestedFolders()


                await load()

                await onChanged()

            } catch {

                await MainActor.run {

                    errorMessage =
                        friendlyFolderError(
                            error
                        )
                }
            }
        }
    }


    private func delete(
        _ folder:
            DocumentFolder
    ) {

        folderToDelete =
            nil


        Task {

            do {

                try await
                    DocumentFolderService
                        .shared
                        .deleteFolder(
                            id:
                                folder.id
                        )


                await load()

                await onChanged()

            } catch {

                await MainActor.run {

                    errorMessage =
                        error
                            .localizedDescription
                }
            }
        }
    }


    private func friendlyFolderError(
        _ error:
            Error
    ) -> String {

        let raw =
            error
                .localizedDescription


        if raw
            .localizedCaseInsensitiveContains(
                "duplicate"
            )
            ||
            raw
                .localizedCaseInsensitiveContains(
                    "unique"
                ) {

            return
                "One or more of those folders already exist."
        }


        return raw
    }
}


// Editor

private struct FolderEditorTarget:
    Identifiable {

    let id =
        UUID()

    let folder:
        DocumentFolder?
}


private struct FolderEditorView:
    View {

    @Environment(\.dismiss)
    private var dismiss

    let folder:
        DocumentFolder?

    let onSaved:
        () async -> Void


    @State private var name:
        String

    @State private var iconName:
        String

    @State private var isSaving =
        false

    @State private var errorMessage:
        String?


    private let icons =
        [
            "folder.fill",
            "building.columns.fill",
            "bolt.fill",
            "cross.case.fill",
            "doc.text.fill",
            "creditcard.fill",
            "house.fill",
            "car.fill",
            "graduationcap.fill",
            "cart.fill"
        ]


    init(
        folder:
            DocumentFolder?,
        onSaved:
            @escaping () async -> Void
    ) {

        self.folder =
            folder

        self.onSaved =
            onSaved


        _name =
            State(
                initialValue:
                    folder?
                        .name
                    ??
                    ""
            )


        _iconName =
            State(
                initialValue:
                    folder?
                        .iconName
                    ??
                    "folder.fill"
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "Folder Name"
                ) {

                    TextField(
                        "Example: Utilities",
                        text:
                            $name
                    )
                    .textInputAutocapitalization(
                        .words
                    )
                }


                Section(
                    "Icon"
                ) {

                    LazyVGrid(
                        columns:
                            Array(
                                repeating:
                                    GridItem(
                                        .flexible()
                                    ),
                                count:
                                    5
                            ),
                        spacing:
                            15
                    ) {

                        ForEach(
                            icons,
                            id:
                                \.self
                        ) {
                            icon in

                            Button {

                                iconName =
                                    icon

                            } label: {

                                Image(
                                    systemName:
                                        icon
                                )
                                .font(
                                    .title2
                                )
                                .foregroundStyle(
                                    iconName
                                    ==
                                    icon
                                    ? .white
                                    : .blue
                                )
                                .frame(
                                    width:
                                        46,
                                    height:
                                        46
                                )
                                .background(
                                    iconName
                                    ==
                                    icon
                                    ? Color.blue
                                    : Color.blue
                                        .opacity(
                                            0.08
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
                            .buttonStyle(
                                .plain
                            )
                        }
                    }
                    .padding(
                        .vertical,
                        6
                    )
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
                folder == nil
                ? "New Folder"
                : "Edit Folder"
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
                        ||
                        name
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
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

                if let folder {

                    try await
                        DocumentFolderService
                            .shared
                            .updateFolder(
                                id:
                                    folder.id,
                                name:
                                    name,
                                iconName:
                                    iconName
                            )

                } else {

                    try await
                        DocumentFolderService
                            .shared
                            .createFolder(
                                name:
                                    name,
                                iconName:
                                    iconName
                            )
                }


                await onSaved()


                await MainActor.run {

                    dismiss()
                }

            } catch {

                await MainActor.run {

                    errorMessage =
                        friendlyEditorError(
                            error
                        )

                    isSaving =
                        false
                }
            }
        }
    }

    private func friendlyEditorError(
        _ error:
            Error
    ) -> String {

        let raw =
            error
                .localizedDescription


        if raw
            .localizedCaseInsensitiveContains(
                "duplicate"
            )
        ||
        raw
            .localizedCaseInsensitiveContains(
                "unique"
            ) {

            return
                "A folder with that name already exists."
        }


        return raw
    }

}
