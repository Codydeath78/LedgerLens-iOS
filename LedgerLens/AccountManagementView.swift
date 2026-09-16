import SwiftUI

struct AccountManagementView: View {

    @EnvironmentObject private var session:
        AppSessionController

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject private var network =
        NetworkMonitor.shared

    @ObservedObject private var appLock =
        BiometricLockManager.shared

    @State private var isSendingReset =
        false

    @State private var resetMessage:
        String?

    @State private var errorMessage:
        String?

    @State private var isChangingBiometricSetting =
        false

    var body: some View {

        NavigationStack {

            List {

                Section {

                    HStack(spacing: 14) {

                        ZStack {

                            Circle()
                                .fill(
                                    Color.blue
                                        .opacity(0.10)
                                )
                                .frame(
                                    width: 58,
                                    height: 58
                                )

                            Image(
                                systemName:
                                    session
                                    .isDeveloperSession
                                    ? "hammer.fill"
                                    : "person.fill"
                            )
                            .font(
                                .system(
                                    size: 22,
                                    weight: .semibold
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
                                session
                                .isDeveloperSession
                                ? "Developer Session"
                                : "Your Account"
                            )
                            .font(.headline)

                            Text(
                                session.email
                                ?? "Anonymous development user"
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    .padding(
                        .vertical,
                        5
                    )
                }


                Section {

                    Toggle(
                        isOn:
                            biometricBinding
                    ) {

                        Label(
                            biometricToggleTitle,
                            systemImage:
                                biometricIcon
                        )
                    }
                    .disabled(
                        isChangingBiometricSetting
                        ||
                        (
                            !appLock
                                .isBiometryAvailable
                            &&
                            !appLock
                                .isEnabled
                        )
                    )

                    if isChangingBiometricSetting {

                        HStack(
                            spacing: 9
                        ) {

                            ProgressView()

                            Text(
                                "Authenticating…"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }

                    if let message =
                        appLock
                            .lastErrorMessage {

                        Text(message)
                            .font(.caption)
                            .foregroundStyle(
                                .red
                            )
                    }

                } header: {

                    Text(
                        "Privacy & App Lock"
                    )

                } footer: {

                    Text(
                        appLock
                            .isBiometryAvailable
                        ? "When enabled, your document history and analyzer lock after the app goes into the background. \(appLock.biometryName) is tried first; iOS may offer the device passcode as a fallback when unlocking."
                        : "Face ID or Touch ID isn't currently available or enrolled on this device."
                    )
                }


                if !session
                    .isDeveloperSession {

                    Section(
                        "Account Security"
                    ) {

                        NavigationLink {

                            ChangeEmailView()

                        } label: {

                            Label(
                                "Change Email",
                                systemImage:
                                    "envelope"
                            )
                        }
                        .disabled(
                            !network
                                .isConnected
                        )

                        Button {

                            sendPasswordReset()

                        } label: {

                            HStack {

                                Label(
                                    isSendingReset
                                    ? "Sending Reset Link…"
                                    : "Change Password",
                                    systemImage:
                                        "key"
                                )

                                Spacer()

                                if isSendingReset {

                                    ProgressView()
                                }
                            }
                        }
                        .disabled(
                            isSendingReset
                            ||
                            !network
                                .isConnected
                        )
                    }
                }


                if !network
                    .isConnected {

                    Section {

                        Label(
                            "You're offline. Account changes will be available after you reconnect.",
                            systemImage:
                                "wifi.slash"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .orange
                        )
                    }
                }


                if let resetMessage {

                    Section {

                        Label(
                            resetMessage,
                            systemImage:
                                "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .green
                        )
                    }
                }


                if let errorMessage {

                    Section {

                        Label(
                            errorMessage,
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .red
                        )
                    }
                }


                Section {

                    Button(
                        role: .destructive
                    ) {

                        Task {

                            do {

                                try await session
                                    .signOut()

                                dismiss()

                            } catch {

                                errorMessage =
                                    AppFriendlyError
                                        .message(
                                            for: error,
                                            context:
                                                .account,
                                            isConnected:
                                                network
                                                    .isConnected
                                        )
                            }
                        }

                    } label: {

                        Label(
                            "Sign Out",
                            systemImage:
                                "rectangle.portrait.and.arrow.right"
                        )
                    }
                }


                Section {

                    NavigationLink {

                        DeleteAccountView()

                    } label: {

                        Label(
                            session
                            .isDeveloperSession
                            ? "Delete Developer Data"
                            : "Delete Account",
                            systemImage:
                                "trash"
                        )
                        .foregroundStyle(
                            .red
                        )
                    }
                    .disabled(
                        !network
                            .isConnected
                    )

                } footer: {

                    Text(
                        session
                        .isDeveloperSession
                        ? "Deleting this anonymous developer identity also removes its saved document history and stored originals."
                        : "Deleting your account permanently removes your saved document history and stored originals."
                    )
                }
            }
            .navigationTitle(
                "Account"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button("Done") {

                        dismiss()
                    }
                }
            }
            .onAppear {

                appLock
                    .refreshAvailability()
            }
        }
    }


    private var biometricBinding:
        Binding<Bool> {

        Binding(
            get: {

                appLock.isEnabled
            },
            set: {
                newValue in

                guard
                    !isChangingBiometricSetting
                else {
                    return
                }

                if newValue {

                    isChangingBiometricSetting =
                        true

                    Task {

                        _ =
                            await appLock
                                .enableProtection()

                        isChangingBiometricSetting =
                            false
                    }

                } else {

                    appLock
                        .disableProtection()
                }
            }
        )
    }


    private var biometricToggleTitle:
        String {

        appLock
            .isBiometryAvailable
        ? "Use \(appLock.biometryName) to Unlock"
        : "Biometric App Lock"
    }


    private var biometricIcon:
        String {

        switch appLock
            .biometryName {

        case "Face ID":
            return "faceid"

        case "Touch ID":
            return "touchid"

        default:
            return "lock.shield"
        }
    }


    private func sendPasswordReset() {

        guard
            !isSendingReset,
            let email =
                session.email,
            !email.isEmpty
        else {
            return
        }

        guard
            network.isConnected
        else {

            errorMessage =
                "Reconnect before changing your password."

            return
        }

        resetMessage =
            nil

        errorMessage =
            nil

        isSendingReset =
            true

        Task {

            do {

                try await session
                    .sendPasswordReset(
                        email: email
                    )

                resetMessage =
                    "A secure password reset link was sent to \(email)."

            } catch {

                errorMessage =
                    AppFriendlyError
                        .message(
                            for: error,
                            context:
                                .account,
                            isConnected:
                                network
                                    .isConnected
                        )
            }

            isSendingReset =
                false
        }
    }
}


// Change Email

private struct ChangeEmailView:
    View {

    @EnvironmentObject private var session:
        AppSessionController

    @ObservedObject private var network =
        NetworkMonitor.shared

    @State private var newEmail = ""
    @State private var isSaving = false
    @State private var didRequest = false
    @State private var didComplete = false
    @State private var requestedEmail: String?
    @State private var errorMessage: String?

    var body: some View {

        Form {

            if !network
                .isConnected {

                Section {

                    Label(
                        "Reconnect before changing your email.",
                        systemImage:
                            "wifi.slash"
                    )
                    .foregroundStyle(
                        .orange
                    )
                }
            }

            Section(
                "Current Email"
            ) {

                HStack {

                    Image(
                        systemName:
                            "envelope.fill"
                    )
                    .foregroundStyle(
                        .blue
                    )

                    Text(
                        session.email
                        ?? "Unknown"
                    )
                    .textSelection(
                        .enabled
                    )
                }
            }


            Section {

                TextField(
                    "New email address",
                    text:
                        $newEmail
                )
                .textInputAutocapitalization(
                    .never
                )
                .keyboardType(
                    .emailAddress
                )
                .autocorrectionDisabled()

            } header: {

                Text("New Email")

            } footer: {

                Text(
                    "For security, both your current and new email addresses must confirm the change. Each confirmation link will reopen this app instead of sending you to a web page."
                )
            }

            if didRequest {

                Section {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Label(
                            "Confirmation emails sent",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                        .font(
                            .subheadline
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .green
                        )

                        Text(
                            "Confirm the link in BOTH inboxes. After the first confirmation, the app will show 1 of 2 complete. After the second, the new email becomes active immediately."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                        if let requestedEmail {

                            Text(
                                "New email: \(requestedEmail)"
                            )
                            .font(
                                .caption
                                .weight(.semibold)
                            )
                        }
                    }
                }
            }


            if didComplete,
               let activeEmail =
                session.email {

                Section {

                    VStack(
                        alignment: .leading,
                        spacing: 7
                    ) {

                        Label(
                            "Email updated successfully",
                            systemImage:
                                "checkmark.shield.fill"
                        )
                        .font(
                            .subheadline
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .green
                        )

                        Text(
                            "Your sign-in email is now \(activeEmail)."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
            }

            if let errorMessage {

                Section {

                    Text(errorMessage)
                        .foregroundStyle(
                            .red
                        )
                }
            }

            Section {

                Button {

                    updateEmail()

                } label: {

                    HStack {

                        if isSaving {

                            ProgressView()
                        }

                        Text(
                            isSaving
                            ? "Requesting change…"
                            : "Update Email"
                        )
                    }
                }
                .disabled(
                    !canSubmit
                    ||
                    isSaving
                    ||
                    !network
                        .isConnected
                )
            }
        }
        .navigationTitle(
            "Change Email"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .onChange(
            of: session.email
        ) {
            _, activeEmail in

            guard
                let requestedEmail,
                let activeEmail,
                activeEmail
                    .caseInsensitiveCompare(
                        requestedEmail
                    )
                    == .orderedSame
            else {
                return
            }

            didRequest =
                false

            didComplete =
                true

            newEmail =
                ""
        }
    }

    private var canSubmit:
        Bool {

        let clean =
            newEmail
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return
            clean.contains("@")
            &&
            clean.contains(".")
    }

    private func updateEmail() {

        guard
            canSubmit,
            !isSaving,
            network.isConnected
        else {
            return
        }

        isSaving =
            true

        didRequest =
            false

        errorMessage =
            nil

        let clean =
            newEmail
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        Task {

            do {

                try await session
                    .requestEmailChange(
                        to: clean
                    )

                requestedEmail =
                    clean

                didComplete =
                    false

                didRequest =
                    true

            } catch {

                errorMessage =
                    AppFriendlyError
                        .message(
                            for: error,
                            context:
                                .account,
                            isConnected:
                                network
                                    .isConnected
                        )
            }

            isSaving =
                false
        }
    }
}


// Delete Account

private struct DeleteAccountView:
    View {

    @EnvironmentObject private var session:
        AppSessionController

    @ObservedObject private var network =
        NetworkMonitor.shared

    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                ZStack {

                    Circle()
                        .fill(
                            Color.red
                                .opacity(0.10)
                        )
                        .frame(
                            width: 88,
                            height: 88
                        )

                    Image(
                        systemName:
                            "trash.fill"
                    )
                    .font(
                        .system(
                            size: 34
                        )
                    )
                    .foregroundStyle(
                        .red
                    )
                }
                .frame(
                    maxWidth:
                        .infinity
                )

                Text(
                    session
                    .isDeveloperSession
                    ? "Delete developer data?"
                    : "Delete your account?"
                )
                .font(
                    .title2
                    .weight(.bold)
                )

                Text(
                    "This permanently deletes this Supabase user, document history, extracted Veryfi data, and every original PDF/scan stored for the account."
                )
                .foregroundStyle(
                    .secondary
                )

                if !network
                    .isConnected {

                    OfflineBanner(
                        message:
                            "Reconnect before deleting the account."
                    )
                }

                Text(
                    "This cannot be undone."
                )
                .font(.headline)
                .foregroundStyle(
                    .red
                )

                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {

                    Text(
                        "Type DELETE to confirm"
                    )
                    .font(
                        .subheadline
                        .weight(.semibold)
                    )

                    TextField(
                        "DELETE",
                        text:
                            $confirmationText
                    )
                    .textInputAutocapitalization(
                        .characters
                    )
                    .padding(14)
                    .background(
                        Color(
                            .secondarySystemBackground
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 15,
                            style: .continuous
                        )
                    )
                }

                if let errorMessage {

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(
                            .red
                        )
                }

                Button(
                    role: .destructive
                ) {

                    deleteAccount()

                } label: {

                    HStack {

                        if isDeleting {

                            ProgressView()
                                .tint(.white)
                        }

                        Text(
                            isDeleting
                            ? "Deleting…"
                            : session
                                .isDeveloperSession
                              ? "Delete Developer Data"
                              : "Permanently Delete Account"
                        )
                        .font(.headline)
                    }
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        15
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .tint(.red)
                .disabled(
                    confirmationText
                        != "DELETE"
                    ||
                    isDeleting
                    ||
                    !network
                        .isConnected
                )
            }
            .padding(22)
            .frame(
                maxWidth: 560
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .navigationTitle(
            "Delete Account"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private func deleteAccount() {

        guard
            confirmationText
                == "DELETE",
            !isDeleting,
            network.isConnected
        else {
            return
        }

        isDeleting =
            true

        errorMessage =
            nil

        Task {

            do {

                try await session
                    .deleteAccount()

            } catch {

                errorMessage =
                    AppFriendlyError
                        .message(
                            for: error,
                            context:
                                .account,
                            isConnected:
                                network
                                    .isConnected
                        )
            }

            isDeleting =
                false
        }
    }
}
