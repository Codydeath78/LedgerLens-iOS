import Foundation

struct UsageWindowStatus:
    Decodable,
    Sendable,
    Equatable {

    let used: Int
    let limit: Int
    let resetAt: String?

    var remaining:
        Int {

        max(
            0,
            limit - used
        )
    }

    var fractionUsed:
        Double {

        guard
            limit > 0
        else {
            return 0
        }

        return
            min(
                1,
                max(
                    0,
                    Double(used)
                    /
                    Double(limit)
                )
            )
    }

    var isNearLimit:
        Bool {

        fractionUsed >=
            0.70
    }

    var isVeryNearLimit:
        Bool {

        fractionUsed >=
            0.90
    }
}

struct UsageActionStatus:
    Decodable,
    Sendable,
    Equatable {

    let hourly:
        UsageWindowStatus

    let daily:
        UsageWindowStatus
}


struct AppUsageStatus:
    Decodable,
    Sendable,
    Equatable {

    let veryfi:
        UsageActionStatus

    let chat:
        UsageActionStatus

    let embeddings:
        UsageActionStatus
}


actor UsageStatusService {

    static let shared =
        UsageStatusService()

    private init() {}


    func fetch()
        async throws
        -> AppUsageStatus {

        let configuration =
            try BackendConfiguration
                .fromBundle()

        var request =
            URLRequest(
                url:
                    configuration
                        .functionURL(
                            "usage-status"
                        )
            )

        request.httpMethod =
            "GET"

        request.timeoutInterval =
            30

        try await configuration
            .authorize(
                &request
            )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
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
                response
                    as?
                    HTTPURLResponse
        else {

            throw
                UsageStatusError
                    .invalidResponse
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
                ??
                "Unknown error"

            throw
                UsageStatusError
                    .httpError(
                        status:
                            http.statusCode,
                        message:
                            message
                    )
        }

        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        return
            try decoder
                .decode(
                    AppUsageStatus.self,
                    from: data
                )
    }
}

enum UsageStatusError:
    LocalizedError {

    case invalidResponse

    case httpError(
        status: Int,
        message: String
    )

    var errorDescription:
        String? {

        switch self {

        case .invalidResponse:

            return
                "The usage service returned an invalid response."

        case .httpError(
            let status,
            let message
        ):

            return
                "Usage request failed (HTTP \(status)): \(message)"
        }
    }
}
