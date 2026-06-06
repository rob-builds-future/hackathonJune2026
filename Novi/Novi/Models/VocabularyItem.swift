//
//  VocabularyItem.swift
//  Novi
//
//  A single vocabulary entry surfaced from a journal entry.
//

import Foundation

/// One vocabulary item extracted from the user's journal entry.
///
/// Kept deliberately small and value-typed so it is trivial to map
/// from a future AI response (OpenAI, a local LLM, etc.) or to persist
/// with SwiftData later on.
struct VocabularyItem: Identifiable, Hashable {
    let id: UUID
    /// The word or phrase in the language the user is learning.
    let term: String
    /// The translation in the user's native language.
    let translation: String
    /// An optional example sentence showing the term in context.
    let example: String?

    init(id: UUID = UUID(), term: String, translation: String, example: String? = nil) {
        self.id = id
        self.term = term
        self.translation = translation
        self.example = example
    }
}
