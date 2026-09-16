import Foundation

struct OpenAIEmbeddingProvider:
    EmbeddingProvider {

    private struct Response:
        Decodable {

        let embeddings:
            [[Float]]
    }

    func embeddings(
        for texts: [String]
    ) async throws
        -> [EmbeddingVector] {

        guard !texts.isEmpty else {
            return []
        }

        let backend =
            try BackendConfiguration
                .fromBundle()

        let url =
            backend.functionURL(
                "openai-embeddings"
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
                        "texts":
                            texts
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
                OpenAIError
                    .invalidResponse
        }

        let decoded =
            try JSONDecoder()
                .decode(
                    Response.self,
                    from: data
                )

        guard
            decoded.embeddings.count
                == texts.count
        else {

            throw
                OpenAIError
                    .missingEmbedding
        }

        return
            decoded.embeddings
                .map {
                    EmbeddingVector(
                        vector: $0
                    )
                }
    }
}

// Response Types

struct OpenAIEmbeddingResponse:
    Decodable {

    struct EmbeddingData:
        Decodable {

        let index: Int
        let embedding: [Float]
    }

    let data:
        [EmbeddingData]
}

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse
    case missingEmbedding
}
