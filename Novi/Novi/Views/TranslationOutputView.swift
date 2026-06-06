//
//  TranslationOutputView.swift
//  Novi
//
//  Right pane: live (Tier-1) translation plus the generated lesson sections.
//

import SwiftUI

/// The output side of the screen: shows the real-time translation and, once
/// generated, the full lesson.
struct TranslationOutputView: View {
    let viewModel: LessonViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                liveTranslationSection
                generateButton
                lessonSections
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Live translation (Tier 1)

    private var liveTranslationSection: some View {
        LessonSectionView(title: "Live Translation") {
            VStack(alignment: .leading, spacing: 8) {
                if let error = viewModel.translationErrorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                } else if let translation = viewModel.liveTranslation, !translation.isEmpty {
                    Text(translation)
                        .textSelection(.enabled)
                } else {
                    Text("Start typing — a translation appears after a short pause.")
                        .foregroundStyle(.secondary)
                }

                if viewModel.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Translating…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Generate action

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

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Lesson

    @ViewBuilder
    private var lessonSections: some View {
        if let lesson = viewModel.lesson {
            LessonSectionView(title: "Vocabulary") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(lesson.vocabulary) { VocabularyRow(item: $0) }
                }
            }

            LessonSectionView(title: "Grammar Notes") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lesson.grammarNotes.enumerated()), id: \.offset) { _, note in
                        Label(note, systemImage: "circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.callout)
                    }
                }
            }

            LessonSectionView(title: "Writing Challenge") {
                Text(lesson.writingChallenge).textSelection(.enabled)
            }
        } else {
            Text("Tap “Generate Lesson” to see vocabulary, grammar notes and a writing challenge.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
