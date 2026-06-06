//
//  EntryOutputPane.swift
//  Novi
//
//  Right pane of the editor: live translation and the generated lesson.
//

import SwiftUI

/// The output side of the editor: real-time translation plus the lesson, read
/// from the persisted record so saved entries render identically.
struct EntryOutputPane: View {
    let entry: JournalEntryRecord
    let viewModel: EntryEditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                liveTranslationSection
                generateButton
                lessonSections
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColors.auroraBackground)
    }

    // MARK: - Live translation (Tier 1)

    private var liveTranslationSection: some View {
        LessonSectionView(title: "Live Translation", icon: "bubble.left.and.text.bubble.right", accent: DesignColors.accentPrimary) {
            VStack(alignment: .leading, spacing: 8) {
                if let error = viewModel.translationError {
                    Text(error).font(.callout).foregroundStyle(DesignColors.error)
                } else if !entry.liveTranslation.isEmpty {
                    HoverTranslatableText(
                        text: entry.liveTranslation,
                        wordsLanguage: entry.targetLanguage,
                        explanationLanguage: explanationLanguage,
                        glossary: glossary
                    )
                    Text("Click a word to see its meaning.")
                        .font(.caption2)
                        .foregroundStyle(DesignColors.textMuted)
                } else {
                    Text("Start typing — a translation appears after a short pause.")
                        .foregroundStyle(DesignColors.textSecondary)
                }

                if viewModel.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Translating…").font(.caption).foregroundStyle(DesignColors.textMuted)
                    }
                }
            }
        }
    }

    /// Language hovered words are explained in: the user's source language, or
    /// the device language when the source is still set to auto-detect.
    private var explanationLanguage: String {
        entry.sourceLanguage == "auto"
            ? (Locale.current.language.languageCode?.identifier ?? "en")
            : entry.sourceLanguage
    }

    /// Instant word lookups from the lesson's vocabulary (term → meaning).
    private var glossary: [String: String] {
        Dictionary(
            entry.vocabulary.map { ($0.term.lowercased(), $0.translation) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - Generate action

    @ViewBuilder
    private var generateButton: some View {
        HStack {
            Button {
                Task { await viewModel.generateLesson() }
            } label: {
                if viewModel.isGenerating {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Generate Lesson")
                }
            }
            .disabled(!viewModel.canGenerate)
            .buttonStyle(.borderedProminent)
            .tint(viewModel.canGenerate ? DesignColors.accentPrimary : DesignColors.textMuted)
        }

        if let error = viewModel.generationError {
            Text(error).font(.callout).foregroundStyle(DesignColors.error)
        }
    }

    // MARK: - Lesson

    @ViewBuilder
    private var lessonSections: some View {
        if hasLesson {
            if !entry.vocabulary.isEmpty {
                LessonSectionView(title: "Vocabulary", icon: "character.book.closed", accent: DesignColors.vocabularyAccent) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entry.vocabulary) { VocabularyRow(item: $0.asVocabularyItem) }
                    }
                }
            }

            if !entry.grammarNotes.isEmpty {
                LessonSectionView(title: "Grammar Notes", icon: "textformat", accent: DesignColors.grammarAccent) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entry.grammarNotes.enumerated()), id: \.offset) { _, note in
                            Label(note, systemImage: "circle.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.callout)
                                .foregroundStyle(DesignColors.textPrimary, DesignColors.grammarAccent)
                        }
                    }
                }
            }

            if !entry.writingChallenge.isEmpty {
                LessonSectionView(title: "Writing Challenge", icon: "pencil.and.outline", accent: DesignColors.challengeAccent) {
                    Text(entry.writingChallenge)
                        .font(Typography.body)
                        .foregroundStyle(DesignColors.textPrimary)
                        .textSelection(.enabled)
                }
            }
        } else {
            Text("Tap “Generate Lesson” to see vocabulary, grammar notes and a writing challenge.")
                .foregroundStyle(DesignColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasLesson: Bool {
        !entry.vocabulary.isEmpty || !entry.grammarNotes.isEmpty || !entry.writingChallenge.isEmpty
    }
}
