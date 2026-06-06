//
//  AILessonService.swift
//  Novi
//
//  Real, AI-backed LessonGenerating implementation (OpenAI Chat Completions).
//

import Foundation

/// A ``LessonGenerating`` implementation that asks an AI model to turn a
/// journal entry into a structured language lesson.
///
/// It talks to an OpenAI-compatible Chat Completions endpoint, requests a
/// JSON-only response, decodes it into a transport DTO and maps that onto the
/// app's ``Lesson`` model. No lesson content is hardcoded here — everything
/// comes from the model's response.
///
/// Endpoint, model and target language are injectable so the same type works
/// against OpenAI or any compatible self-hosted server.
struct AILessonService: LessonGenerating {

    // MARK: Configuration

    /// OpenAI API key, read from the `NOVI_OPENAI_API_KEY` environment variable.
    ///
    /// Set it in Xcode under Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments ▸
    /// Environment Variables. This keeps the key out of source control: scheme
    /// env vars live in user-specific data, never in the committed code.
    var apiKey: String = ProcessInfo.processInfo.environment["NOVI_OPENAI_API_KEY"] ?? ""

    /// Base URL of the OpenAI-compatible API.
    var baseURL: URL = URL(string: "https://api.openai.com/v1")!

    /// Chat model to use.
    var model: String = "gpt-5.4-mini"

    /// The language the lesson should teach / translate into.
    var targetLanguage: String = "English"

    var session: URLSession = .shared

    // MARK: - LessonGenerating

    func generateLesson(from entry: String) async throws -> Lesson {
        let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AILessonError.emptyInput }
        guard !apiKey.isEmpty else { throw AILessonError.notConfigured }

        // Scale the lesson's depth to the length of the entry: more text → more
        // input. Roughly 10% of the words become vocabulary, 2% grammar notes.
        let words = Self.wordCount(of: trimmed)
        let vocabularyCount = max(1, Int((Double(words) * 0.10).rounded()))
        let grammarCount = max(1, Int((Double(words) * 0.02).rounded()))

        let request = try makeRequest(
            for: trimmed, vocabularyCount: vocabularyCount, grammarCount: grammarCount
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AILessonError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AILessonError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error.message
            throw AILessonError.server(status: http.statusCode, message: message)
        }

        let content = try decodeChatContent(from: data)
        let dto = try decodeLesson(from: content)
        return dto.toLesson(fallbackSourceText: trimmed)
    }

    // MARK: - Request building

    private func makeRequest(
        for entry: String, vocabularyCount: Int, grammarCount: Int
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: model,
            temperature: 0.4,
            responseFormat: .init(type: "json_object"),
            messages: [
                .init(role: "system", content: Self.systemPrompt(
                    targetLanguage: targetLanguage,
                    vocabularyCount: vocabularyCount,
                    grammarCount: grammarCount
                )),
                .init(role: "user", content: Self.userPrompt(entry: entry))
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Counts whitespace-separated words in `text`.
    private static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    // MARK: - Decoding

    private func decodeChatContent(from data: Data) throws -> String {
        guard let content = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let message = content.choices.first?.message.content,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AILessonError.emptyResponse
        }
        return message
    }

    private func decodeLesson(from content: String) throws -> AILessonDTO {
        // Models occasionally wrap JSON in ```json fences despite instructions.
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw AILessonError.invalidJSON
        }
        do {
            return try JSONDecoder().decode(AILessonDTO.self, from: jsonData)
        } catch {
            throw AILessonError.invalidJSON
        }
    }

    // MARK: - Prompts

    private static func systemPrompt(
        targetLanguage: String, vocabularyCount: Int, grammarCount: Int
    ) -> String {
        """
        You are a friendly language tutor for absolute beginners who cannot yet \
        speak or understand the target language. The target language is \
        \(targetLanguage).

        Given the user's journal entry, create one short, practical, \
        beginner-friendly lesson. Do NOT translate the whole entry.

        Rules:
        - Extract about \(vocabularyCount) useful vocabulary item(s) taken from the \
        user's own text. Pick the most useful words.
        - Explain about \(grammarCount) relevant grammar point(s), briefly and simply.
        - Create exactly one short writing challenge based on the entry.
        - Keep everything concise and beginner-friendly.
        - Respond with VALID JSON ONLY. No markdown, no code fences, no commentary.

        Respond using exactly this JSON shape:
        {
          "sourceText": "the user's original text, unchanged",
          "vocabulary": [
            { "term": "word/phrase", "translation": "its meaning in \(targetLanguage)", "example": "short example sentence" }
          ],
          "grammarNotes": ["one short grammar note", "an optional second note"],
          "writingChallenge": "one short writing prompt"
        }
        """
    }

    private static func userPrompt(entry: String) -> String {
        "Journal entry:\n\"\"\"\n\(entry)\n\"\"\""
    }
}

// MARK: - OpenAI wire format

private struct ChatRequest: Encodable {
    let model: String
    let temperature: Double
    let responseFormat: ResponseFormat
    let messages: [Message]

    struct ResponseFormat: Encodable { let type: String }
    struct Message: Encodable { let role: String; let content: String }

    enum CodingKeys: String, CodingKey {
        case model, temperature, messages
        case responseFormat = "response_format"
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String }
}

private struct APIErrorResponse: Decodable {
    let error: APIError
    struct APIError: Decodable { let message: String }
}

// MARK: - Lesson transport DTO

/// Decodes the AI's JSON response and maps it onto the app's ``Lesson`` model,
/// keeping the wire format decoupled from the domain model.
private struct AILessonDTO: Decodable {
    let sourceText: String?
    let translation: String?
    let vocabulary: [Vocab]
    let grammarNotes: FlexibleStringArray
    let writingChallenge: String

    struct Vocab: Decodable {
        let term: String
        let translation: String
        let example: String?
    }

    func toLesson(fallbackSourceText: String) -> Lesson {
        Lesson(
            sourceText: sourceText?.isEmpty == false ? sourceText! : fallbackSourceText,
            translation: translation ?? "",
            vocabulary: vocabulary.map {
                VocabularyItem(term: $0.term, translation: $0.translation, example: $0.example)
            },
            grammarNotes: grammarNotes.values,
            writingChallenge: writingChallenge
        )
    }
}

/// Decodes a value that may be either a JSON string or an array of strings into
/// `[String]`, so the service tolerates both shapes of `grammarNotes`.
private struct FlexibleStringArray: Decodable {
    let values: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            values = array
        } else if let single = try? container.decode(String.self) {
            values = single.isEmpty ? [] : [single]
        } else {
            values = []
        }
    }
}

// MARK: - Errors

/// Errors surfaced by ``AILessonService``, each with a readable description.
enum AILessonError: LocalizedError {
    case emptyInput
    case notConfigured
    case network(Error)
    case invalidResponse
    case server(status: Int, message: String?)
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Please write a journal entry first."
        case .notConfigured:
            return "AI is not configured: add your OpenAI API key in AILessonService."
        case let .network(error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "The AI server returned an unexpected response."
        case let .server(status, message):
            return message ?? "The AI request failed (HTTP \(status))."
        case .emptyResponse:
            return "The AI returned an empty response. Please try again."
        case .invalidJSON:
            return "The AI response was not valid JSON. Please try again."
        }
    }
}
