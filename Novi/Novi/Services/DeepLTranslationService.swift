//
//  DeepLTranslationService.swift
//  Novi
//
//  TranslationService backed by the DeepL API.
//

import Foundation

/// TranslationService backed by the DeepL API. Key from NOVI_DEEPL_API_KEY.
/// Free keys (ending in ":fx") automatically target the free endpoint.
struct DeepLTranslationService: TranslationService {

    var apiKey: String = ProcessInfo.processInfo.environment["NOVI_DEEPL_API_KEY"] ?? ""
    var session: URLSession = .shared

    private var baseURL: URL {
        apiKey.hasSuffix(":fx")
            ? URL(string: "https://api-free.deepl.com")!
            : URL(string: "https://api.deepl.com")!
    }

    func translate(_ text: String, from source: String, to target: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return TranslationResult(text: "", detectedLanguageCode: nil) }
        guard !apiKey.isEmpty else {
            throw NSError(
                domain: "DeepL",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "DeepL API key missing (set NOVI_DEEPL_API_KEY)."]
            )
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("v2/translate"))
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DeepLRequest(
            text: [trimmed],
            targetLang: Self.targetCode(target),
            sourceLang: source == "auto" ? nil : source.uppercased()
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(DeepLErrorResponse.self, from: data))?.message
            throw NSError(
                domain: "DeepL",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: message ?? "DeepL request failed."]
            )
        }

        let decoded = try JSONDecoder().decode(DeepLResponse.self, from: data)
        guard let first = decoded.translations.first else {
            return TranslationResult(text: "", detectedLanguageCode: nil)
        }
        return TranslationResult(
            text: first.text,
            detectedLanguageCode: first.detectedSourceLanguage?.lowercased()
        )
    }

    /// DeepL target codes need a region for some languages.
    private static func targetCode(_ code: String) -> String {
        switch code.lowercased() {
        case "en": return "EN-US"
        case "pt": return "PT-PT"
        default: return code.uppercased()
        }
    }
}

private struct DeepLRequest: Encodable {
    let text: [String]
    let targetLang: String
    let sourceLang: String?

    enum CodingKeys: String, CodingKey {
        case text
        case targetLang = "target_lang"
        case sourceLang = "source_lang"
    }
}

private struct DeepLResponse: Decodable {
    let translations: [Translation]

    struct Translation: Decodable {
        let detectedSourceLanguage: String?
        let text: String

        enum CodingKeys: String, CodingKey {
            case detectedSourceLanguage = "detected_source_language"
            case text
        }
    }
}

private struct DeepLErrorResponse: Decodable {
    let message: String
}
