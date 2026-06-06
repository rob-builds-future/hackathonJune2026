//
//  Lesson.swift
//  Novi
//
//  The full lesson generated from a journal entry.
//

import Foundation

/// A complete language lesson derived from a single journal entry.
///
/// This is the central output model of the app. Each section of the UI maps
/// directly onto one property here, which keeps the view layer dumb and makes
/// the model easy to populate from any source (mock data today, an AI backend
/// tomorrow).
struct Lesson: Identifiable, Hashable {
    let id: UUID
    /// The original text the user wrote.
    let sourceText: String
    /// A translation of the source text.
    let translation: String
    /// Vocabulary worth studying from the entry.
    let vocabulary: [VocabularyItem]
    /// Bite-sized grammar observations about the entry.
    let grammarNotes: [String]
    /// A short prompt encouraging the user to write more.
    let writingChallenge: String

    init(
        id: UUID = UUID(),
        sourceText: String,
        translation: String,
        vocabulary: [VocabularyItem],
        grammarNotes: [String],
        writingChallenge: String
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translation = translation
        self.vocabulary = vocabulary
        self.grammarNotes = grammarNotes
        self.writingChallenge = writingChallenge
    }
}
