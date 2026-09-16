import Foundation




enum BackendConfigurationError: LocalizedError {

    case missingProjectReference
    case missingPublishableKey
    case invalidProjectReference

    var errorDescription: String? {

        switch self {

        case .missingProjectReference:
            return "Supabase project reference is not configured."

        case .missingPublishableKey:
            return "Supabase publishable key is not configured."

        case .invalidProjectReference:
            return "The Supabase project reference is invalid."
        }
    }
}

struct BackendConfiguration {

    let baseURL: URL
    let publishableKey: String

    static func fromBundle(
        _ bundle: Bundle = .main
    ) throws -> BackendConfiguration {

        // Project reference

        guard
            let rawProjectRef =
                bundle.object(
                    forInfoDictionaryKey:
                        "SUPABASE_PROJECT_REF"
                ) as? String
        else {
            throw BackendConfigurationError
                .missingProjectReference
        }

        let projectRef =
            rawProjectRef
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard
            !projectRef.isEmpty,
            !projectRef.contains("$(")
        else {
            throw BackendConfigurationError
                .missingProjectReference
        }

        // Only the project reference belongs in
        // Config.xcconfig.
        //
        // We build https:// here so xcconfig does not
        // interpret // as a comment.
        let urlString =
            "https://\(projectRef).supabase.co"

        guard let baseURL =
            URL(string: urlString)
        else {
            throw BackendConfigurationError
                .invalidProjectReference
        }

        // Publishable key

        guard
            let rawKey =
                bundle.object(
                    forInfoDictionaryKey:
                        "SUPABASE_PUBLISHABLE_KEY"
                ) as? String
        else {
            throw BackendConfigurationError
                .missingPublishableKey
        }

        let publishableKey =
            rawKey
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard
            !publishableKey.isEmpty,
            !publishableKey.contains("$(")
        else {
            throw BackendConfigurationError
                .missingPublishableKey
        }

        return BackendConfiguration(
            baseURL: baseURL,
            publishableKey: publishableKey
        )
    }

    func functionURL(
        _ functionName: String
    ) -> URL {

        baseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent(functionName)
    }

    func authorize(
        _ request: inout URLRequest
    ) async throws {

        // Public project identifier.
        request.setValue(
            publishableKey,
            forHTTPHeaderField:
                "apikey"
        )

        // Real authenticated-user JWT.
        let accessToken =
            try await
                SupabaseAuthManager
                    .shared
                    .accessToken()

        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField:
                "Authorization"
        )
    }
}
