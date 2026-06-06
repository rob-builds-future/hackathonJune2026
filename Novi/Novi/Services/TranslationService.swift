//
//  TranslationService.swift
//  Novi
//
//  Abstraction over a machine-translation backend.
//

import Foundation

/// The outcome of a translation request.
struct TranslationResult {
    /// The translated text.
    let text: String
    /// The language the backend detected for the source, if `source` was `"auto"`.
    let detectedLanguageCode: String?
}

/// Translates text from one language into another.
///
/// The UI depends only on this protocol. The default implementation is chosen
/// by ``TranslationServiceFactory``.
protocol TranslationService: Sendable {
    /// Translates `text` from `source` into `target`.
    /// - Parameters:
    ///   - text: The text to translate.
    ///   - source: Source language code (e.g. `"de"`), or `"auto"` to detect.
    ///   - target: Target language code (e.g. `"en"`).
    /// - Returns: The translated text plus any detected source language.
    func translate(_ text: String, from source: String, to target: String) async throws -> TranslationResult
}

enum TranslationServiceFactory {
    static func makeDefault() -> any TranslationService {
        let key = ProcessInfo.processInfo.environment["NOVI_DEEPL_API_KEY"] ?? ""
        return key.isEmpty ? LibreTranslateService() : DeepLTranslationService(apiKey: key)
    }
}
