import Foundation

private enum ChatProviderError:
    LocalizedError {

    case invalidResponse
    case missingOutput

    var errorDescription:
        String? {

        switch self {

        case .invalidResponse:

            return
                "The AI service returned an invalid response."

        case .missingOutput:

            return
                "The AI service returned no answer."
        }
    }
}

protocol ChatProvider {

    func complete(
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String
}

struct OpenAIResponsesProvider:
    ChatProvider {

    private struct Response:
        Decodable {

        let text: String
    }

    func complete(
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {

        let backend =
            try BackendConfiguration
                .fromBundle()

        let url =
            backend.functionURL(
                "openai-chat"
            )

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod =
            "POST"

        request.timeoutInterval =
            120

        try await backend.authorize(
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
                        "systemPrompt":
                            systemPrompt,

                        "userPrompt":
                            userPrompt
                    ]
                )

        let (
            data,
            response
        ) =
            try await
                URLSession.shared
                    .data(
                        for: request
                    )

        guard
            let http =
                response
                    as? HTTPURLResponse,

            (200...299)
                .contains(
                    http.statusCode
                )
        else {

            throw
                ChatProviderError
                    .invalidResponse
        }

        let result =
            try JSONDecoder()
                .decode(
                    Response.self,
                    from: data
                )

        let output =
            result.text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !output.isEmpty else {

            throw
                ChatProviderError
                    .missingOutput
        }

        return output
    }
}
