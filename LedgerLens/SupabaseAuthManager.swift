import Foundation
import Supabase

actor SupabaseAuthManager {

    static let shared =
        SupabaseAuthManager()

    struct SessionInfo:
        Sendable,
        Equatable {

        let userID: String
        let email: String?
        let isAnonymous: Bool
    }

    enum SignUpResult:
        Sendable,
        Equatable {

        case signedIn(SessionInfo)

        case confirmationRequired(
            email: String
        )
    }

    enum AccountError:
        LocalizedError {

        case invalidServerResponse

        case serverError(
            statusCode: Int,
            message: String
        )

        var errorDescription:
            String? {

            switch self {

            case .invalidServerResponse:

                return
                    "The account service returned an invalid response."

            case .serverError(
                let statusCode,
                let message
            ):

                return
                    "Account request failed (HTTP \(statusCode)): \(message)"
            }
        }
    }

    private var client:
        SupabaseClient?

    private init() {}

    // Client

    private func supabaseClient()
        throws -> SupabaseClient {

        if let client {
            return client
        }

        let configuration =
            try BackendConfiguration
                .fromBundle()

        let newClient =
            SupabaseClient(
                supabaseURL:
                    configuration.baseURL,
                supabaseKey:
                    configuration.publishableKey
            )

        client =
            newClient

        return newClient
    }

    func databaseClient()
        throws -> SupabaseClient {

        try supabaseClient()
    }

    // Existing Session

    func currentSessionInfo()
        async -> SessionInfo? {

        do {

            let client =
                try supabaseClient()

            let session =
                try await client.auth
                    .session

            return SessionInfo(
                userID:
                    session.user.id
                        .uuidString,
                email:
                    session.user.email,
                isAnonymous:
                    session.user.email == nil
            )

        } catch {

            return nil
        }
    }

    // Access Token

    func accessToken()
        async throws -> String {

        let client =
            try supabaseClient()

        let session =
            try await client.auth
                .session

        return session.accessToken
    }

    // Login

    func signIn(
        email: String,
        password: String
    ) async throws
        -> SessionInfo {

        let client =
            try supabaseClient()

        if let existing =
            try? await client.auth.session,
           existing.user.email == nil {

            try? await client.auth
                .signOut()
        }

        let session =
            try await client.auth
                .signIn(
                    email: email,
                    password: password
                )

        return SessionInfo(
            userID:
                session.user.id
                    .uuidString,
            email:
                session.user.email,
            isAnonymous:
                false
        )
    }

    // Create Account

    func signUp(
        email: String,
        password: String
    ) async throws
        -> SignUpResult {

        let client =
            try supabaseClient()

        if let existing =
            try? await client.auth.session,
           existing.user.email == nil {

            try? await client.auth
                .signOut()
        }

        _ =
            try await client.auth
                .signUp(
                    email: email,
                    password: password,
                    redirectTo:
                        AppAuthConfiguration
                            .accountActivationRedirectURL
                )

        if let session =
            try? await client.auth.session {

            return .signedIn(
                SessionInfo(
                    userID:
                        session.user.id
                            .uuidString,
                    email:
                        session.user.email,
                    isAnonymous:
                        false
                )
            )
        }

        return .confirmationRequired(
            email: email
        )
    }

    // New Account Activation

    func completeAccountActivationURL(
        _ url: URL
    ) async throws {

        let client =
            try supabaseClient()

        // Supabase Swift uses PKCE for browser-based email
        // confirmations. Exchanging the callback proves that
        // this confirmation link completed successfully.
        _ =
            try await client.auth
                .session(
                    from:
                        url
                )

        // activation confirms the account, but the user should
        // return to the signed-out/login experience instead of
        // being silently logged in by the confirmation callback.
        try await client.auth
            .signOut()
    }


    // Developer Skip

    func developerSignInAnonymously()
        async throws
        -> SessionInfo {

        let client =
            try supabaseClient()

        if let existing =
            try? await client.auth.session,
           existing.user.email == nil {

            return SessionInfo(
                userID:
                    existing.user.id
                        .uuidString,
                email: nil,
                isAnonymous: true
            )
        }

        let session =
            try await client.auth
                .signInAnonymously()

        return SessionInfo(
            userID:
                session.user.id
                    .uuidString,
            email: nil,
            isAnonymous: true
        )
    }

    // Password Recovery

    func sendPasswordReset(
        email: String
    ) async throws {

        let client =
            try supabaseClient()

        try await client.auth
            .resetPasswordForEmail(
                email,
                redirectTo:
                    AppAuthConfiguration
                        .passwordRecoveryRedirectURL
            )
    }

    func handleIncomingAuthURL(
        _ url: URL
    ) throws {

        let client =
            try supabaseClient()

        client.handle(url)
    }

    func updatePassword(
        _ password: String
    ) async throws {

        let client =
            try supabaseClient()

        _ =
            try await client.auth
                .update(
                    user:
                        UserAttributes(
                            password:
                                password
                        )
                )
    }

    // Email Management

    func updateEmail(
        _ email: String
    ) async throws {

        let client =
            try supabaseClient()

        _ =
            try await client.auth
                .update(
                    user:
                        UserAttributes(
                            email: email
                        ),
                    redirectTo:
                        AppAuthConfiguration
                            .emailChangeRedirectURL
                )
    }


    func completeEmailChangeURL(
        _ url: URL
    ) async throws
        -> SessionInfo {

        let client =
            try supabaseClient()

        // Swift uses PKCE by default. The second secure-email
        // confirmation redirects back with an auth code.
        // Await the exchange here so the account UI can update
        // immediately instead of waiting for an eventual event.
        let session =
            try await client.auth
                .session(
                    from: url
                )

        // Fetch the freshest Auth user after the exchange.
        let user =
            try await client.auth
                .user(
                    jwt:
                        session
                            .accessToken
                )

        return
            SessionInfo(
                userID:
                    user.id
                        .uuidString,
                email:
                    user.email,
                isAnonymous:
                    user.email == nil
            )
    }

    // Delete Account

    func deleteAccount()
        async throws {

        let configuration =
            try BackendConfiguration
                .fromBundle()

        var request =
            URLRequest(
                url:
                    configuration
                        .functionURL(
                            "delete-account"
                        )
            )

        request.httpMethod =
            "POST"

        request.timeoutInterval =
            60

        try await configuration
            .authorize(
                &request
            )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )

        request.httpBody =
            try JSONSerialization
                .data(
                    withJSONObject: [
                        "confirmation":
                            "DELETE_MY_ACCOUNT"
                    ]
                )

        let (
            data,
            response
        ) =
            try await URLSession
                .shared
                .data(
                    for: request
                )

        guard
            let http =
                response as?
                    HTTPURLResponse
        else {

            throw AccountError
                .invalidServerResponse
        }

        guard
            (200...299)
                .contains(
                    http.statusCode
                )
        else {

            let message =
                String(
                    data: data,
                    encoding: .utf8
                )
                ?? "Unknown error"

            throw AccountError
                .serverError(
                    statusCode:
                        http.statusCode,
                    message:
                        message
                )
        }

        if let client =
            try? supabaseClient() {

            try? await client.auth
                .signOut()
        }
    }

    // Sign Out

    func signOut()
        async throws {

        let client =
            try supabaseClient()

        try await client.auth
            .signOut()
    }

    // User ID

    func userID()
        async throws -> String? {

        let client =
            try supabaseClient()

        let claims =
            try await client.auth
                .getClaims()

        return claims.claims.sub
    }
}
