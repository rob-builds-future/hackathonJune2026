//
//  WordLibraryService.swift
//  Novi
//
//  Maintains the persistent Word Library: merges lesson vocabulary, tracks
//  usage, derives learning progress, and provides data for adaptive lessons
//  and future quizzes.
//

import Foundation
import SwiftData

/// Operations on the personal Word Library.
///
/// Stateless — every method takes the ``ModelContext`` it should work in, so it
/// composes cleanly with SwiftData and stays easy to test.
struct WordLibraryService {

    // MARK: - Merging a lesson

    /// Merges a lesson's vocabulary into the library and records word usage.
    ///
    /// - New words are inserted; existing ones get `timesSuggested` incremented
    ///   and `lastSuggestedAt`/example refreshed.
    /// - Any library word whose term appears in `entryText` is counted as used
    ///   by the learner.
    func registerLesson(
        vocabulary: [VocabularyItem],
        entryText: String,
        entry: JournalEntryRecord,
        sourceLanguage: String,
        targetLanguage: String,
        in context: ModelContext
    ) {
        let now = Date()

        // Existing words for this target language, indexed by normalized term.
        let descriptor = FetchDescriptor<WordRecord>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        var index = Dictionary(existing.map { ($0.normalizedTerm, $0) }, uniquingKeysWith: { a, _ in a })

        // Words touched in this lesson — linked to the entry as "memories".
        var touched: [WordRecord] = []

        // 1. Usage detection: any known word the learner wrote counts as used.
        let writtenWords = Self.wordSet(in: entryText)
        for record in existing where writtenWords.contains(record.normalizedTerm) {
            record.timesUsedByUser += 1
            record.lastUsedAt = now
            Self.recomputeProgress(record)
            touched.append(record)
        }

        // 2. Merge the suggested vocabulary.
        for item in vocabulary {
            let key = item.term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }

            if let record = index[key] {
                record.timesSuggested += 1
                record.lastSuggestedAt = now
                if !item.translation.isEmpty { record.translation = item.translation }
                if let example = item.example, !example.isEmpty { record.example = example }
                Self.recomputeProgress(record)
                touched.append(record)
            } else {
                let record = WordRecord(
                    term: item.term,
                    translation: item.translation,
                    example: item.example ?? "",
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    firstSuggestedAt: now,
                    lastSuggestedAt: now,
                    timesSuggested: 1
                )
                Self.recomputeProgress(record)
                context.insert(record)
                index[key] = record
                touched.append(record)
            }
        }

        // 3. Link touched words to this entry (the "related memory").
        for record in touched where !record.entries.contains(where: { $0.id == entry.id }) {
            record.entries.append(entry)
        }

        try? context.save()
    }

    // MARK: - Progress logic

    /// Recomputes `confidenceScore` and `learningStatus` from the counters.
    static func recomputeProgress(_ record: WordRecord) {
        record.confidenceScore = confidence(
            timesSuggested: record.timesSuggested,
            timesUsedByUser: record.timesUsedByUser
        )
        record.learningStatus = status(
            timesSuggested: record.timesSuggested,
            timesUsedByUser: record.timesUsedByUser,
            confidence: record.confidenceScore
        )
    }

    /// A 0...1 confidence estimate. Usage weighs more than mere suggestion.
    static func confidence(timesSuggested: Int, timesUsedByUser: Int) -> Double {
        let suggested = Double(timesSuggested) * 0.08
        let used = Double(timesUsedByUser) * 0.25
        return min(1.0, suggested + used)
    }

    /// Maps counters to a learning status (see the project's progress rules).
    static func status(timesSuggested: Int, timesUsedByUser: Int, confidence: Double) -> LearningStatus {
        if confidence >= 0.9 { return .mastered }
        if timesSuggested >= 6 && timesUsedByUser > 0 { return .familiar }
        if timesSuggested >= 4 { return .practicing }
        if timesSuggested >= 2 { return .learning }
        return .new
    }

    // MARK: - Quiz-ready queries (no quiz UI yet)

    /// Words the learner is still struggling with (low status / confidence).
    func weakWords(in context: ModelContext, limit: Int = 50) -> [WordRecord] {
        allWords(in: context)
            .filter { $0.learningStatus.rank <= LearningStatus.learning.rank }
            .sorted { $0.confidenceScore < $1.confidenceScore }
            .prefix(limit)
            .map { $0 }
    }

    /// Older words due for review — not seen for `days`, not yet mastered.
    func wordsDueForReview(olderThanDays days: Int = 7, in context: ModelContext, limit: Int = 50) -> [WordRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allWords(in: context)
            .filter { $0.learningStatus != .mastered && $0.lastSuggestedAt < cutoff }
            .sorted { $0.lastSuggestedAt < $1.lastSuggestedAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Words the learner has mastered.
    func masteredWords(in context: ModelContext, limit: Int = 100) -> [WordRecord] {
        allWords(in: context)
            .filter { $0.learningStatus == .mastered }
            .prefix(limit)
            .map { $0 }
    }

    /// Most recently suggested words, newest first.
    func recentlySuggestedWords(in context: ModelContext, limit: Int = 20) -> [WordRecord] {
        allWords(in: context)
            .sorted { $0.lastSuggestedAt > $1.lastSuggestedAt }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - AI context helper

    /// Vocabulary guidance the lesson generator can use to stay adaptive and
    /// avoid repetition. (Wiring into the AI prompt is a future step.)
    func vocabularyGuidance(in context: ModelContext) -> VocabularyGuidance {
        let words = allWords(in: context)
        let avoid = words
            .filter { $0.learningStatus.rank >= LearningStatus.familiar.rank || $0.timesSuggested >= 5 }
            .map(\.term)
        let reinforce = words
            .filter { $0.learningStatus.rank <= LearningStatus.learning.rank }
            .sorted { $0.confidenceScore < $1.confidenceScore }
            .map(\.term)
        let recent = words
            .sorted { $0.lastSuggestedAt > $1.lastSuggestedAt }
            .prefix(15)
            .map(\.term)
        let mastered = words
            .filter { $0.learningStatus == .mastered }
            .map(\.term)

        return VocabularyGuidance(
            avoidRepeating: Array(avoid.prefix(30)),
            reinforce: Array(reinforce.prefix(15)),
            recentlySuggested: Array(recent),
            mastered: Array(mastered.prefix(30))
        )
    }

    // MARK: - Helpers

    private func allWords(in context: ModelContext) -> [WordRecord] {
        (try? context.fetch(FetchDescriptor<WordRecord>())) ?? []
    }

    /// Lowercased set of word tokens in `text`.
    static func wordSet(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
                .map(String.init)
        )
    }
}

/// Guidance for adaptive lesson generation, derived from the Word Library.
struct VocabularyGuidance {
    /// Words the learner already knows — avoid re-teaching these.
    let avoidRepeating: [String]
    /// Weak words worth reinforcing.
    let reinforce: [String]
    /// Recently suggested words (avoid immediate repetition).
    let recentlySuggested: [String]
    /// Mastered words.
    let mastered: [String]

    /// A compact, prompt-ready summary for injecting into a future AI request.
    var promptSnippet: String {
        var lines: [String] = []
        if !avoidRepeating.isEmpty {
            lines.append("Avoid re-teaching these already-known words: \(avoidRepeating.joined(separator: ", ")).")
        }
        if !reinforce.isEmpty {
            lines.append("Gently reinforce these weak words when relevant: \(reinforce.joined(separator: ", ")).")
        }
        if !recentlySuggested.isEmpty {
            lines.append("Recently suggested (don't repeat right away): \(recentlySuggested.joined(separator: ", ")).")
        }
        return lines.joined(separator: "\n")
    }
}
