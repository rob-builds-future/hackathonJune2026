//
//  WordRecord.swift
//  Novi
//
//  Persistent personal-vocabulary entry with learning statistics.
//

import Foundation
import SwiftData

/// How well the learner knows a word, driven by how often it has been
/// suggested and used.
enum LearningStatus: String, Codable, CaseIterable, Identifiable {
    case new
    case learning
    case practicing
    case familiar
    case mastered

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Ordering from least to most known (handy for sorting / quiz selection).
    var rank: Int {
        switch self {
        case .new: return 0
        case .learning: return 1
        case .practicing: return 2
        case .familiar: return 3
        case .mastered: return 4
        }
    }
}

/// A single vocabulary word in the user's long-term Word Library.
///
/// Aggregated across all lessons: it remembers how often a word was suggested,
/// how often the user actually used it, and a derived learning status — the
/// foundation for adaptive lessons and future quizzes.
@Model
final class WordRecord {
    @Attribute(.unique) var id: UUID

    var term: String = ""
    var translation: String = ""
    var example: String = ""
    var sourceLanguage: String = ""
    var targetLanguage: String = ""

    var firstSuggestedAt: Date
    var lastSuggestedAt: Date
    var lastUsedAt: Date?

    var timesSuggested: Int = 0
    var timesUsedByUser: Int = 0
    /// 0...1 estimate of how well the word is known.
    var confidenceScore: Double = 0
    var learningStatus: LearningStatus = LearningStatus.new

    /// Journal entries this word appeared in — the word's "related memories".
    /// Inverse declared on ``JournalEntryRecord/words``.
    var entries: [JournalEntryRecord] = []

    init(
        id: UUID = UUID(),
        term: String,
        translation: String,
        example: String = "",
        sourceLanguage: String,
        targetLanguage: String,
        firstSuggestedAt: Date = Date(),
        lastSuggestedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        timesSuggested: Int = 1,
        timesUsedByUser: Int = 0,
        confidenceScore: Double = 0,
        learningStatus: LearningStatus = .new
    ) {
        self.id = id
        self.term = term
        self.translation = translation
        self.example = example
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.firstSuggestedAt = firstSuggestedAt
        self.lastSuggestedAt = lastSuggestedAt
        self.lastUsedAt = lastUsedAt
        self.timesSuggested = timesSuggested
        self.timesUsedByUser = timesUsedByUser
        self.confidenceScore = confidenceScore
        self.learningStatus = learningStatus
    }

    /// Lowercased term, used for case-insensitive matching when merging.
    var normalizedTerm: String {
        term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
