//
//  VocabularyItemRecord.swift
//  Novi
//
//  SwiftData-persisted counterpart of VocabularyItem.
//

import Foundation
import SwiftData

/// A persisted vocabulary item belonging to a saved ``JournalEntryRecord``.
///
/// SwiftData needs its own model class for stored relationships, so this mirrors
/// the runtime ``VocabularyItem`` value type. Mapping helpers live in
/// `LessonPersistence.swift`.
@Model
final class VocabularyItemRecord {
    var term: String
    var translation: String
    var example: String?

    /// The saved entry this item belongs to (inverse of the relationship).
    var entry: JournalEntryRecord?

    init(
        term: String,
        translation: String,
        example: String? = nil,
        entry: JournalEntryRecord? = nil
    ) {
        self.term = term
        self.translation = translation
        self.example = example
        self.entry = entry
    }
}
