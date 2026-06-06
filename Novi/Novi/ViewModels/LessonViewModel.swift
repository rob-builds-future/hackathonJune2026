//
//  LessonViewModel.swift
//  Novi
//
//  Drives the single screen: holds input, requests lessons, exposes state,
//  and provides Tier-1 real-time translation of the journal entry.
//

import Foundation
import Observation

/// View model backing the main screen.
///
/// It owns the journal text, talks to a ``LessonGenerating`` service to produce
/// a lesson, and exposes the result plus loading/error state. The view binds to
/// this object and never constructs a ``Lesson`` itself.
///
/// It also drives **Tier-1 real-time translation**: for learners who cannot yet
/// speak or understand the language, the entry is translated automatically after
/// a short pause in typing, via an injected ``TranslationService``.
///
/// Both services are injected, so tests (or future real backends) can supply
/// different implementations without touching this class.
@MainActor
@Observable
final class LessonViewModel {

    /// The user's current journal entry.
    var journalEntry: String = ""

    // MARK: Lesson state

    /// The most recently generated lesson, if any.
    private(set) var lesson: Lesson?
    /// Whether a lesson is currently being generated.
    private(set) var isGenerating: Bool = false
    /// A user-facing error message, if generation failed.
    private(set) var errorMessage: String?

    // MARK: Real-time translation state (Tier 1)

    /// Source language code for live translation (`"auto"` detects it).
    var sourceLanguage: String = "auto"
    /// Target language code for live translation.
    var targetLanguage: String = "en"

    /// The live translation of the current entry, if any.
    private(set) var liveTranslation: String?
    /// Whether a live translation request is in flight.
    private(set) var isTranslating: Bool = false
    /// A user-facing error message, if live translation failed.
    private(set) var translationErrorMessage: String?

    /// Seconds of typing inactivity before a live translation is triggered.
    private let translationDebounce: Duration = .seconds(2)

    private let lessonService: LessonGenerating
    private let translationService: TranslationService
    private var translationTask: Task<Void, Never>?
    /// Identifies the last successful translation (text + language pair) so the
    /// same request is not sent twice in a row.
    private var lastTranslationKey: String?

    /// Creates the view model.
    ///
    /// Swap the lesson generator here to switch between the real AI backend and
    /// the offline development fallback:
    /// - `AILessonService()` — real AI-powered lessons (default).
    /// - `MockLessonService()` — hardcoded data, no network, for development.
    init(
        lessonService: LessonGenerating = AILessonService(),
        translationService: TranslationService = LibreTranslateService()
    ) {
        self.lessonService = lessonService
        self.translationService = translationService
    }

    // MARK: - Lesson generation

    /// Whether the "Generate Lesson" action should be available.
    var canGenerate: Bool {
        !isGenerating && !trimmedEntry.isEmpty
    }

    /// Requests a lesson for the current journal entry from the service.
    func generateLesson() async {
        guard canGenerate else { return }

        isGenerating = true
        errorMessage = nil

        do {
            lesson = try await lessonService.generateLesson(from: journalEntry)
        } catch {
            // Typed errors (AILessonError, …) already carry readable messages.
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not generate a lesson: \(error.localizedDescription)"
            lesson = nil
        }

        isGenerating = false
    }

    // MARK: - Real-time translation (Tier 1)

    /// Schedules a live translation after the debounce interval.
    ///
    /// Call this whenever the journal entry changes. Each call cancels any
    /// pending translation and restarts the timer, so the request only fires
    /// once the user has paused typing for ``translationDebounce`` seconds.
    func scheduleLiveTranslation() {
        translationTask?.cancel()

        let text = trimmedEntry
        guard !text.isEmpty else {
            liveTranslation = nil
            translationErrorMessage = nil
            isTranslating = false
            lastTranslationKey = nil
            return
        }

        // A finished sentence (entry ends with a full stop) translates
        // immediately; otherwise we wait for a pause in typing.
        let endsSentence = text.last.map(Self.sentenceTerminators.contains) ?? false
        let delay: Duration = endsSentence ? .zero : translationDebounce

        translationTask = Task { [weak self] in
            guard let self else { return }
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self.performLiveTranslation(of: text)
        }
    }

    /// Characters that mark the end of a sentence and trigger an immediate
    /// translation (Latin plus common CJK full stops).
    private static let sentenceTerminators: Set<Character> = [
        ".", "!", "?", "。", "！", "？", "…"
    ]

    /// Cancels any pending or in-flight live translation.
    func cancelLiveTranslation() {
        translationTask?.cancel()
        translationTask = nil
    }

    private func performLiveTranslation(of text: String) async {
        // Skip if we already translated this exact text for this language pair.
        let key = "\(sourceLanguage)|\(targetLanguage)|\(text)"
        guard key != lastTranslationKey else { return }

        isTranslating = true
        translationErrorMessage = nil

        do {
            let result = try await translationService.translate(
                text, from: sourceLanguage, to: targetLanguage
            )
            guard !Task.isCancelled else { return }
            liveTranslation = result
            lastTranslationKey = key
        } catch is CancellationError {
            // Superseded by newer input — ignore.
        } catch {
            guard !Task.isCancelled else { return }
            translationErrorMessage = error.localizedDescription
        }

        isTranslating = false
    }

    // MARK: - Helpers

    private var trimmedEntry: String {
        journalEntry.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
