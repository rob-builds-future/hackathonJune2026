//
//  MockLessonService.swift
//  Novi
//
//  A hardcoded LessonGenerating implementation used for the prototype.
//

import Foundation

/// A ``LessonGenerating`` implementation that returns hardcoded example data.
///
/// No network, no AI, no persistence — it simply demonstrates the
/// journal-entry-to-lesson workflow end to end. A small artificial delay is
/// included so the UI's loading state is exercised the same way it will be
/// once a real backend is wired in.
struct MockLessonService: LessonGenerating, TitleGenerating {

    /// Optional simulated latency, in nanoseconds. Defaults to ~0.6s.
    var simulatedDelay: UInt64 = 600_000_000

    func generateTitle(from entry: String) async throws -> String {
        let words = entry
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(5)
        return words.isEmpty ? "Journal Entry" : words.joined(separator: " ")
    }

    func generateLesson(from entry: String) async throws -> Lesson {
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: simulatedDelay)
        }

        let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? "Heute war ein schöner Tag." : trimmed

        return Lesson(
            sourceText: source,
            translation: "Today was a beautiful day. I went for a walk in the park "
                + "and met a friend.",
            vocabulary: [
                VocabularyItem(
                    term: "der Tag",
                    translation: "the day",
                    example: "Heute war ein schöner Tag."
                ),
                VocabularyItem(
                    term: "spazieren gehen",
                    translation: "to go for a walk",
                    example: "Ich gehe im Park spazieren."
                ),
                VocabularyItem(
                    term: "der Freund",
                    translation: "the friend",
                    example: "Ich habe einen Freund getroffen."
                )
            ],
            grammarNotes: [
                "“war” is the simple past (Präteritum) of “sein” (to be).",
                "Separable verbs like “spazieren gehen” split in main clauses: "
                    + "“Ich gehe spazieren.”",
                "Masculine nouns take the article “der”: der Tag, der Freund."
            ],
            writingChallenge: "Write three sentences about what you did yesterday "
                + "using the simple past tense."
        )
    }
}
