import Foundation
import Supabase
internal import Combine

@MainActor
final class AppSessionController:
    ObservableObject {

    enum Phase:
        Equatable {

        case loading
        case signedOut
        case signedIn
    }


    enum EmailChangeConfirmationStage:
        Equatable {

        case firstConfirmed

        case finishing

        case completed(
            email: String
        )

        case failed(
            message: String
        )
    }

    @Published private(set)
    var phase:
        Phase = .loading

    @Published private(set)
    var email:
        String?

    @Published private(set)
    var userID:
        String?

    @Published private(set)
    var isDeveloperSession =
        false

    @Published
    var isPasswordRecoveryPresented =
        false

    @Published private(set)
    var isPasswordRecoveryReady =
        false

    @Published private(set)
    var authLinkError:
        String?


    @Published
    var isAccountActivationNoticePresented =
        false

    @Published private(set)
    var accountActivationNoticeMessage:
        String?


    @Published
    var isEmailChangeConfirmationPresented =
        false

    @Published private(set)
    var emailChangeConfirmationStage:
        EmailChangeConfirmationStage?

    @Published private(set)
    var pendingEmailChangeOldEmail:
        String?

    @Published private(set)
    var pendingEmailChangeNewEmail:
        String?

    private var didRestore =
        false

    private var authObserverTask:
        Task<Void, Never>?

    // MARK: - Launch

    func restoreSessionIfNeeded()
        async {

        startAuthObserverIfNeeded()

        guard !didRestore else {
            return
        }

        didRestore =
            true

        let info =
            await SupabaseAuthManager
                .shared
                .currentSessionInfo()

        guard let info else {

            setSignedOut()
            return
        }

        if info.isAnonymous {

            setSignedOut()

        } else {

            applySignedIn(
                info
            )
        }
    }

    // Auth Observer

    private func startAuthObserverIfNeeded() {

        guard
            authObserverTask == nil
        else {
            return
        }

        authObserverTask =
            Task { [weak self] in

                guard let self else {
                    return
                }

                do {

                    let client =
                        try await
                            SupabaseAuthManager
                                .shared
                                .databaseClient()

                    for await (
                        event,
                        authSession
                    ) in await client.auth
                        .authStateChanges {

                        guard
                            !Task.isCancelled
                        else {
                            return
                        }

                        switch event {

                        case .passwordRecovery:

                            if let authSession {

                                self.applySignedIn(
                                    .init(
                                        userID:
                                            authSession
                                                .user
                                                .id
                                                .uuidString,
                                        email:
                                            authSession
                                                .user
                                                .email,
                                        isAnonymous:
                                            authSession
                                                .user
                                                .email
                                                == nil
                                    )
                                )
                            }

                            self
                                .isPasswordRecoveryReady =
                                true

                            self
                                .isPasswordRecoveryPresented =
                                true

                        case .userUpdated:

                            if let authSession {

                                self.email =
                                    authSession
                                        .user
                                        .email
                            }

                        case .signedOut:

                            self.setSignedOut()

                        default:

                            break
                        }
                    }

                } catch {

                    print(
                        "Auth observer error:",
                        error.localizedDescription
                    )
                }
            }
    }

    // Incoming Auth Link

    func handleIncomingAuthURL(
        _ url: URL
    ) async {

        startAuthObserverIfNeeded()


        // NEW ACCOUNT ACTIVATION

        if AppAuthConfiguration
            .isAccountActivationURL(
                url
            ) {

            await handleAccountActivationURL(
                url
            )

            return
        }


        // SECURE EMAIL CHANGE

        if AppAuthConfiguration
            .isEmailChangeURL(
                url
            ) {

            await handleEmailChangeURL(
                url
            )

            return
        }


        // PASSWORD RECOVERY + OTHER AUTH CALLBACKS

        if AppAuthConfiguration
            .isPasswordRecoveryURL(
                url
            ) {

            isPasswordRecoveryPresented =
                true

            isPasswordRecoveryReady =
                false

            authLinkError =
                nil
        }

        do {

            try await
                SupabaseAuthManager
                    .shared
                    .handleIncomingAuthURL(
                        url
                    )

            if AppAuthConfiguration
                .isPasswordRecoveryURL(
                    url
                ) {

                for _ in 0..<50 {

                    if let info =
                        await SupabaseAuthManager
                            .shared
                            .currentSessionInfo() {

                        applySignedIn(
                            info
                        )

                        isPasswordRecoveryReady =
                            true

                        break
                    }

                    try? await Task.sleep(
                        for:
                            .milliseconds(100)
                    )
                }

                if !isPasswordRecoveryReady {

                    authLinkError =
                        """
                        The password recovery session could not be prepared. Please request a new reset link.
                        """
                }
            }

        } catch {

            authLinkError =
                error.localizedDescription
        }
    }


    private func handleAccountActivationURL(
        _ url: URL
    ) async {

        authLinkError =
            nil


        if let callbackError =
            AppAuthConfiguration
                .accountActivationError(
                    url
                ) {

            setSignedOut()

            accountActivationNoticeMessage =
                """
                The account activation link could not be completed.

                \(callbackError)
                """

            isAccountActivationNoticePresented =
                true

            return
        }


        do {

            try await
                SupabaseAuthManager
                    .shared
                    .completeAccountActivationURL(
                        url
                    )

            // The confirmation callback can create a temporary
            // authenticated PKCE session. The auth manager signs
            // it out, and we deliberately return to the normal
            // login experience.
            setSignedOut()

            accountActivationNoticeMessage =
                "Account activated. You can login!"

            isAccountActivationNoticePresented =
                true

        } catch {

            setSignedOut()

            accountActivationNoticeMessage =
                """
                The account activation link could not be completed.

                \(error.localizedDescription)
                """

            isAccountActivationNoticePresented =
                true
        }
    }


    func dismissAccountActivationNotice() {

        isAccountActivationNoticePresented =
            false

        accountActivationNoticeMessage =
            nil
    }


    private func handleEmailChangeURL(
        _ url: URL
    ) async {

        isEmailChangeConfirmationPresented =
            true

        switch
            AppAuthConfiguration
                .emailChangeCallbackKind(
                    url
                ) {

        case .firstConfirmation:

            // With Secure Email Change enabled, Supabase
            // accepts either inbox first. The callback does
            // not reliably identify whether that first click
            // came from the old or new email address.
            //
            // Therefore the UI truthfully shows "1 of 2"
            // instead of guessing the inbox.
            emailChangeConfirmationStage =
                .firstConfirmed


        case .completion:

            emailChangeConfirmationStage =
                .finishing

            do {

                let info =
                    try await
                        SupabaseAuthManager
                            .shared
                            .completeEmailChangeURL(
                                url
                            )

                // This immediately updates every Account UI
                // that reads session.email.
                applySignedIn(
                    info
                )

                let confirmedEmail =
                    info.email
                    ??
                    pendingEmailChangeNewEmail
                    ??
                    "your new email address"

                emailChangeConfirmationStage =
                    .completed(
                        email:
                            confirmedEmail
                    )

                pendingEmailChangeOldEmail =
                    nil

                pendingEmailChangeNewEmail =
                    nil

            } catch {

                emailChangeConfirmationStage =
                    .failed(
                        message:
                            """
                            The email confirmation link could not be completed.

                            \(error.localizedDescription)
                            """
                    )
            }


        case .failure(
            let message
        ):

            emailChangeConfirmationStage =
                .failed(
                    message:
                        message
                )


        case .unknown:

            emailChangeConfirmationStage =
                .failed(
                    message:
                        """
                        This email confirmation link could not be recognized. Please request the email change again.
                        """
                )
        }
    }

    // Login

    func signIn(
        email: String,
        password: String
    ) async throws {

        dismissAccountActivationNotice()

        let info =
            try await
                SupabaseAuthManager
                    .shared
                    .signIn(
                        email: email,
                        password: password
                    )

        applySignedIn(
            info
        )
    }

    // Sign Up

    func signUp(
        email: String,
        password: String
    ) async throws
        -> SupabaseAuthManager
            .SignUpResult {

        dismissAccountActivationNotice()

        let result =
            try await
                SupabaseAuthManager
                    .shared
                    .signUp(
                        email: email,
                        password: password
                    )

        if case .signedIn(
            let info
        ) = result {

            applySignedIn(
                info
            )
        }

        return result
    }

    // Developer Skip

    func developerSkip()
        async throws {

        dismissAccountActivationNotice()

        let info =
            try await
                SupabaseAuthManager
                    .shared
                    .developerSignInAnonymously()

        applySignedIn(
            info
        )
    }

    // Password

    func sendPasswordReset(
        email: String
    ) async throws {

        try await
            SupabaseAuthManager
                .shared
                .sendPasswordReset(
                    email: email
                )
    }

    func finishPasswordRecovery() {

        isPasswordRecoveryPresented =
            false

        isPasswordRecoveryReady =
            false

        authLinkError =
            nil
    }

    // Email

    func requestEmailChange(
        to newEmail: String
    ) async throws {

        let oldEmail =
            email

        pendingEmailChangeOldEmail =
            oldEmail

        pendingEmailChangeNewEmail =
            newEmail

        do {

            try await
                SupabaseAuthManager
                    .shared
                    .updateEmail(
                        newEmail
                    )

        } catch {

            pendingEmailChangeOldEmail =
                nil

            pendingEmailChangeNewEmail =
                nil

            throw error
        }
    }


    func dismissEmailChangeConfirmation() {

        isEmailChangeConfirmationPresented =
            false

        emailChangeConfirmationStage =
            nil
    }

    // Account Deletion

    func deleteAccount()
        async throws {

        try await
            SupabaseAuthManager
                .shared
                .deleteAccount()

        setSignedOut()
    }

    // Sign Out

    func signOut()
        async throws {

        dismissAccountActivationNotice()

        try await
            SupabaseAuthManager
                .shared
                .signOut()

        setSignedOut()
    }

    // State Helpers

    private func applySignedIn(
        _ info:
            SupabaseAuthManager
                .SessionInfo
    ) {

        userID =
            info.userID

        email =
            info.email

        isDeveloperSession =
            info.isAnonymous

        phase =
            .signedIn
    }

    private func setSignedOut() {

        userID =
            nil

        email =
            nil

        isDeveloperSession =
            false

        isEmailChangeConfirmationPresented =
            false

        emailChangeConfirmationStage =
            nil

        pendingEmailChangeOldEmail =
            nil

        pendingEmailChangeNewEmail =
            nil

        phase =
            .signedOut
    }
}
