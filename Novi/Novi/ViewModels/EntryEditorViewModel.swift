//
//  EntryEditorViewModel.swift
//  Novi
//
//  Drives editing of a single saved JournalEntryRecord: auto-saves changes,
//  keeps the live translation in sync, generates lessons and titles.
//

import Foundation
import NaturalLanguage
import Observation
import SwiftData

/// View model for the journal editor, operating on one ``JournalEntryRecord``.
///
/// The record *is* the document: views bind to its properties and this model
/// auto-saves changes (notes-app style), drives Tier-1 live translation, runs
/// AI lesson generation, fills in a title when the user leaves it empty, and
/// updates the source-language picker to whatever language was detected.
@MainActor
@Observable
final class EntryEditorViewModel {

    let entry: JournalEntryRecord

    // MARK: Transient UI state

    private(set) var isGenerating = false
    private(set) var generationError: String?
    private(set) var isTranslating = false
    private(set) var isTranslationPreparing = false
    private(set) var translationError: String?
    private(set) var detectedSourceLanguage: String?
    private(set) var isGeneratingTitle = false
    /// Timestamp of the last successful save — shown as "last saved".
    private(set) var lastSavedAt: Date

    // MARK: Dependencies & config

    private let modelContext: ModelContext
    private let lessonService: LessonGenerating
    private let translationService: any TranslationService
    private let titleService: TitleGenerating
    private let wordLibrary = WordLibraryService()

    private let translationDebounce: Duration = .seconds(2)
    private let autosaveDebounce: Duration = .milliseconds(800)
    private let autoDetectMinimumWords = 4
    private let autoDetectMinimumCharacters = 18
    private static let sentenceTerminators: Set<Character> = [
        ".", "!", "?", "。", "！", "？", "…"
    ]

    private var translationTask: Task<Void, Never>?
    private var autosaveTask: Task<Void, Never>?
    private var lastTranslationKey: String?
    /// True once a title exists (typed or generated), to avoid re-generating.
    private var hasResolvedTitle: Bool

    convenience init(entry: JournalEntryRecord, modelContext: ModelContext) {
        self.init(
            entry: entry,
            modelContext: modelContext,
            lessonService: AILessonService(),
            translationService: TranslationServiceFactory.makeDefault(),
            titleService: AILessonService()
        )
    }

    init(
        entry: JournalEntryRecord,
        modelContext: ModelContext,
        lessonService: LessonGenerating,
        translationService: any TranslationService,
        titleService: TitleGenerating
    ) {
        self.entry = entry
        self.modelContext = modelContext
        self.lessonService = lessonService
        self.translationService = translationService
        self.titleService = titleService
        self.lastSavedAt = entry.updatedAt
        self.hasResolvedTitle = !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Don't immediately re-translate text that was already translated.
        if !entry.liveTranslation.isEmpty {
            self.lastTranslationKey = Self.key(
                source: entry.sourceLanguage, target: entry.targetLanguage, text: trimmedText
            )
        }
    }

    // MARK: - Edit handlers (called from the view on change)

    /// The journal text changed: persist, translate, maybe title.
    func handleTextEdit() {
        entry.updatedAt = Date()
        scheduleAutosave()
        scheduleLiveTranslation()
    }

    /// The title changed: persist. A non-empty title stops auto-generation.
    func handleTitleEdit() {
        entry.updatedAt = Date()
        hasResolvedTitle = !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        scheduleAutosave()
    }

    /// A language picker changed: persist and re-translate.
    func handleLanguageChange() {
        entry.updatedAt = Date()
        scheduleAutosave()
        scheduleLiveTranslation()
    }

    /// The user-facing journal date changed: persist, but don't affect text processing.
    func handleJournalDateChange() {
        entry.updatedAt = Date()
        scheduleAutosave()
    }

    /// Final save when leaving the editor.
    func flush() {
        translationTask?.cancel()
        isTranslationPreparing = false
        isTranslating = false
        autosaveTask?.cancel()
        save()
    }

    // MARK: - Lesson generation

    var canGenerate: Bool { !isGenerating && !trimmedText.isEmpty }

    func generateLesson() async {
        guard canGenerate else { return }
        isGenerating = true
        generationError = nil

        do {
            let lesson = try await lessonService.generateLesson(from: entry.sourceText)
            entry.apply(lesson) { modelContext.delete($0) }
            entry.lessonSourceText = trimmedText
            entry.updatedAt = Date()
            save()

            // Grow the long-term Word Library and track usage.
            wordLibrary.registerLesson(
                vocabulary: lesson.vocabulary,
                entryText: entry.sourceText,
                entry: entry,
                sourceLanguage: entry.sourceLanguage,
                targetLanguage: entry.targetLanguage,
                in: modelContext
            )

            await generateTitleIfNeeded()
        } catch {
            generationError = (error as? LocalizedError)?.errorDescription
                ?? "Could not generate a lesson: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    // MARK: - Real-time translation (Tier 1)

    func scheduleLiveTranslation() {
        translationTask?.cancel()

        let text = trimmedText
        refreshDetectedSourceLanguage(from: text)
        guard !text.isEmpty else {
            entry.liveTranslation = ""
            translationError = nil
            isTranslating = false
            isTranslationPreparing = false
            detectedSourceLanguage = nil
            lastTranslationKey = nil
            return
        }

        guard shouldTranslate(text) else {
            entry.liveTranslation = ""
            lastTranslationKey = nil
            isTranslating = false
            isTranslationPreparing = false
            detectedSourceLanguage = nil
            translationError = nil
            return
        }

        let key = Self.key(source: entry.sourceLanguage, target: entry.targetLanguage, text: text)
        guard key != lastTranslationKey else {
            isTranslating = false
            isTranslationPreparing = false
            translationError = nil
            return
        }

        let endsSentence = text.last.map(Self.sentenceTerminators.contains) ?? false
        let delay: Duration = endsSentence ? .zero : translationDebounce
        isTranslationPreparing = delay > .zero
        isTranslating = false
        translationError = nil

        translationTask = Task { [weak self] in
            guard let self else { return }
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self.performLiveTranslation(of: text)
        }
    }

    private func performLiveTranslation(of text: String) async {
        let key = Self.key(source: entry.sourceLanguage, target: entry.targetLanguage, text: text)
        guard key != lastTranslationKey else {
            isTranslationPreparing = false
            isTranslating = false
            return
        }

        isTranslationPreparing = false
        isTranslating = true
        translationError = nil

        do {
            let result = try await translationService.translate(
                text, from: entry.sourceLanguage, to: entry.targetLanguage
            )
            guard !Task.isCancelled else { return }
            entry.liveTranslation = result.text
            detectedSourceLanguage = entry.sourceLanguage == "auto"
                ? result.detectedLanguageCode
                : entry.sourceLanguage
            lastTranslationKey = key

            entry.updatedAt = Date()
            save()
        } catch is CancellationError {
            // Superseded by newer input — ignore without clobbering newer UI state.
            return
        } catch {
            guard !Task.isCancelled else { return }
            translationError = error.localizedDescription
        }

        isTranslationPreparing = false
        isTranslating = false
    }

    // MARK: - Title generation

    private func generateTitleIfNeeded() async {
        guard !hasResolvedTitle, !isGeneratingTitle,
              entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = trimmedText
        guard wordCount(text) >= 3 else { return }

        hasResolvedTitle = true // optimistic, prevents duplicate requests
        isGeneratingTitle = true
        defer { isGeneratingTitle = false }

        do {
            let title = try await titleService.generateTitle(from: text)
            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                hasResolvedTitle = false
            } else {
                entry.title = cleaned
                entry.updatedAt = Date()
                save()
            }
        } catch {
            hasResolvedTitle = false // allow a later retry
        }
    }

    // MARK: - Persistence

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.autosaveDebounce)
            guard !Task.isCancelled else { return }
            self.save()
            await self.generateTitleIfNeeded()
        }
    }

    private func save() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
            lastSavedAt = Date()
        } catch {
            // Keep the in-memory edits; surface as a translation-style note.
            translationError = "Could not save: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private var trimmedText: String {
        entry.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldTranslate(_ text: String) -> Bool {
        guard entry.sourceLanguage == "auto" else { return true }
        return text.count >= autoDetectMinimumCharacters || wordCount(text) >= autoDetectMinimumWords
    }

    private func refreshDetectedSourceLanguage(from text: String) {
        guard entry.sourceLanguage == "auto" else {
            detectedSourceLanguage = entry.sourceLanguage
            return
        }

        guard text.count >= 8 else {
            detectedSourceLanguage = nil
            return
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        detectedSourceLanguage = recognizer.dominantLanguage?.rawValue
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private static func key(source: String, target: String, text: String) -> String {
        "\(source)|\(target)|\(text)"
    }
}
