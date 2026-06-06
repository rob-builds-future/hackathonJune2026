//
//  LessonPersistence.swift
//  Novi
//
//  Mapping helpers between the runtime models (Lesson, VocabularyItem) and
//  their SwiftData persistence records.
//

import Foundation

extension VocabularyItemRecord {
    /// Creates a persistence record from a runtime ``VocabularyItem``.
    convenience init(from item: VocabularyItem) {
        self.init(term: item.term, translation: item.translation, example: item.example)
    }

    /// Maps this record back to a runtime ``VocabularyItem`` (used for display).
    var asVocabularyItem: VocabularyItem {
        VocabularyItem(term: term, translation: translation, example: example)
    }
}

extension JournalEntryRecord {
    /// Applies a generated ``Lesson`` onto this record, replacing any previous
    /// lesson content. The single mapping point from `Lesson` → record fields.
    func apply(_ lesson: Lesson, deletingOldVocabulary delete: (VocabularyItemRecord) -> Void) {
        lessonTranslation = lesson.translation
        grammarNotes = lesson.grammarNotes
        writingChallenge = lesson.writingChallenge
        for old in vocabulary { delete(old) }
        vocabulary = lesson.vocabulary.map { VocabularyItemRecord(from: $0) }
    }
}
