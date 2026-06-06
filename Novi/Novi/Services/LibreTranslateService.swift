//
//  LibreTranslateService.swift
//  Novi
//
//  TranslationService backed by the self-hosted LibreTranslate instance.
//

import Foundation

/// A ``TranslationService`` that talks to a LibreTranslate server.
///
/// Defaults to Novi's self-hosted instance at `libre4echo.de`, which currently
/// requires no API key. The endpoint and key are injectable so the same type
/// works against any LibreTranslate deployment.
struct LibreTranslateService: TranslationService {

    /// Base URL of the LibreTranslate instance.
    var baseURL: URL = URL(string: "https://libre4echo.de")!
    /// Optional API key, if the instance is configured to require one.
    var apiKey: String?

    var session: URLSession = .shared

    func translate(_ text: String, from source: String, to target: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var request = URLRequest(url: baseURL.appendingPathComponent("translate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TranslateRequest(q: trimmed, source: source, target: target, apiKey: apiKey)
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            throw TranslationError.server(status: http.statusCode, message: message)
        }

        return try JSONDecoder().decode(TranslateResponse.self, from: data).translatedText
    }
}

// MARK: - Wire format

/// Request body for `POST /translate`.
private struct TranslateRequest: Encodable {
    let q: String
    let source: String
    let target: String
    let format = "text"
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case q, source, target, format
        case apiKey = "api_key"
    }
}

/// Successful response from `POST /translate`.
private struct TranslateResponse: Decodable {
    let translatedText: String
}

/// Error payload LibreTranslate returns on failure.
private struct ErrorResponse: Decodable {
    let error: String
}

/// Errors surfaced by ``LibreTranslateService``.
enum TranslationError: LocalizedError {
    case invalidResponse
    case server(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The translation server returned an unexpected response."
        case let .server(status, message):
            return message ?? "Translation failed (HTTP \(status))."
        }
    }
}
