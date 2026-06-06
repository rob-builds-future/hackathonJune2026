//
//  EntryOutputPane.swift
//  Novi
//
//  Right pane of the editor: live translation and the generated lesson.
//

import SwiftUI
import NaturalLanguage

/// The output side of the editor: real-time translation plus the lesson, read
/// from the persisted record so saved entries render identically.
struct EntryOutputPane: View {
    let entry: JournalEntryRecord
    let viewModel: EntryEditorViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var resultGlowOpacity = 0.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                liveTranslationSection
                generateButton
                lessonSections
            }
            .padding(Spacing.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(DesignColors.glassStroke, lineWidth: 1)
        )
        .shadow(color: DesignColors.cardShadowStrong.opacity(0.45), radius: 18, x: 0, y: 12)
    }

    // MARK: - Live translation (Tier 1)

    private var liveTranslationSection: some View {
        LessonSectionView(title: "Live Translation", icon: "bubble.left.and.text.bubble.right", accent: DesignColors.accentPrimary) {
            VStack(alignment: .leading, spacing: 10) {
                if let error = viewModel.translationError {
                    Text(error).font(.callout).foregroundStyle(DesignColors.error)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(liveTranslationHighlight)
                            .opacity(entry.liveTranslation.isEmpty ? 0.18 : 0.34)
                            .allowsHitTesting(false)

                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        DesignColors.brandTeal.opacity(entry.liveTranslation.isEmpty ? 0.42 : 0.88),
                                        DesignColors.brandViolet.opacity(entry.liveTranslation.isEmpty ? 0.36 : 0.78),
                                        DesignColors.brandCoral.opacity(entry.liveTranslation.isEmpty ? 0.34 : 0.72)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: entry.liveTranslation.isEmpty ? 1 : 1.45
                            )
                            .shadow(color: DesignColors.brandTeal.opacity(0.10 + resultGlowOpacity * 0.46), radius: 14, x: 0, y: 0)
                            .shadow(color: DesignColors.brandViolet.opacity(0.08 + resultGlowOpacity * 0.34), radius: 24, x: 0, y: 8)
                            .opacity(entry.liveTranslation.isEmpty ? 0.55 : 1)
                            .padding(2)
                            .allowsHitTesting(false)

                        Group {
                            if !entry.liveTranslation.isEmpty {
                                TranslationRevealContainer(
                                    trigger: entry.liveTranslation,
                                    reduceMotion: reduceMotion,
                                    onReveal: playResultGlow
                                ) { highlightedSuffix, highlightOpacity in
                                    HoverTranslatableText(
                                        text: entry.liveTranslation,
                                        wordsLanguage: entry.targetLanguage,
                                        explanationLanguage: explanationLanguage,
                                        glossary: glossary,
                                        highlightedSuffix: highlightedSuffix,
                                        highlightOpacity: highlightOpacity,
                                        fontSize: 18
                                    )
                                }
                            } else {
                                Text("Start typing — a translation appears after a short pause.")
                                    .font(Typography.bodyEmphasized)
                                    .foregroundStyle(DesignColors.textSecondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)

                    VStack(alignment: .leading, spacing: 7) {
                        if isTranslationMotionActive {
                            TranslationProgressBeam(isActive: isTranslationMotionActive, reduceMotion: reduceMotion)
                            TranslationStatusRow(isTranslating: viewModel.isTranslating)
                        } else if !entry.liveTranslation.isEmpty {
                            Text("Click a word to see its meaning.")
                                .font(.caption2)
                                .foregroundStyle(DesignColors.textMuted)
                        } else {
                            Color.clear.frame(height: 18)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .animation(.easeInOut(duration: AnimationDuration.standard), value: viewModel.isTranslationPreparing)
                    .animation(.easeInOut(duration: AnimationDuration.standard), value: viewModel.isTranslating)
                }
            }
        }
    }

    private var isTranslationMotionActive: Bool {
        viewModel.isTranslationPreparing || viewModel.isTranslating
    }

    private var liveTranslationHighlight: LinearGradient {
        LinearGradient(
            colors: [
                DesignColors.brandTeal.opacity(0.18),
                DesignColors.brandViolet.opacity(0.14),
                DesignColors.brandCoral.opacity(0.12),
                DesignColors.surfaceElevated.opacity(0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func playResultGlow() {
        guard !reduceMotion else {
            resultGlowOpacity = 0
            return
        }

        resultGlowOpacity = 0
        withAnimation(.easeOut(duration: 0.16)) {
            resultGlowOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.82).delay(0.08)) {
            resultGlowOpacity = 0
        }
    }

    /// Language hovered words are explained in: the user's source language, or
    /// the device language when the source is still set to auto-detect.
    private var explanationLanguage: String {
        if entry.sourceLanguage != "auto" {
            return entry.sourceLanguage
        }

        if let detected = viewModel.detectedSourceLanguage, detected != entry.targetLanguage {
            return detected
        }

        if let inferred = inferredSourceLanguage, inferred != entry.targetLanguage {
            return inferred
        }

        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        return deviceLanguage == entry.targetLanguage ? "" : deviceLanguage
    }

    private var inferredSourceLanguage: String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(entry.sourceText)
        guard let language = recognizer.dominantLanguage else { return nil }
        return language.rawValue
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
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowGenerateButton {
                Button {
                    Task { await viewModel.generateLesson() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isGenerating {
                            ProgressView().controlSize(.small)
                        }

                        Text(generateButtonTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .disabled(!viewModel.canGenerate)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(viewModel.canGenerate ? DesignColors.accentPrimary : DesignColors.textMuted)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DesignColors.accentPrimary)

                    Text("Lesson ready")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(DesignColors.surfaceInset.opacity(0.34), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(DesignColors.glassStroke.opacity(0.62), lineWidth: 1)
                )
                .transition(.opacity)
            }

            if let error = viewModel.generationError {
                Text(error).font(.callout).foregroundStyle(DesignColors.error)
            }
        }
        .animation(.easeInOut(duration: AnimationDuration.standard), value: shouldShowGenerateButton)
    }

    private var shouldShowGenerateButton: Bool {
        viewModel.isGenerating || !hasLesson || isLessonStale
    }

    private var isLessonStale: Bool {
        entry.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) != entry.lessonSourceText
    }

    private var generateButtonTitle: String {
        if viewModel.isGenerating { return "Generating Lesson..." }
        return hasLesson ? "Update Lesson" : "Generate Lesson"
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

private struct TranslationProgressBeam: View {
    let isActive: Bool
    let reduceMotion: Bool
    @State private var brightSweep = false
    @State private var glowSweep = false
    @State private var breathe = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignColors.surfaceInset.opacity(0.58))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                DesignColors.brandTeal.opacity(0.24),
                                DesignColors.brandViolet.opacity(0.22),
                                DesignColors.brandCoral.opacity(0.20),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: reduceMotion ? width : width * 0.72)
                    .offset(x: reduceMotion ? 0 : (glowSweep ? width : -width * 0.72))
                    .blur(radius: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                DesignColors.brandTeal.opacity(0.94),
                                DesignColors.brandViolet.opacity(0.88),
                                DesignColors.brandCoral.opacity(0.82),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: reduceMotion ? width : width * 0.34)
                    .offset(x: reduceMotion ? 0 : (brightSweep ? width : -width * 0.34))
                    .shadow(color: DesignColors.brandTeal.opacity(0.30), radius: 5, x: 0, y: 0)
                    .shadow(color: DesignColors.brandViolet.opacity(0.22), radius: 8, x: 0, y: 0)
            }
            .clipShape(Capsule())
            .opacity(isActive ? (breathe ? 1 : 0.72) : 0)
            .onAppear { updateSweep(active: isActive) }
            .onChange(of: isActive) { _, active in updateSweep(active: active) }
            .onChange(of: reduceMotion) { _, _ in updateSweep(active: isActive) }
        }
        .frame(height: 4)
    }

    private func updateSweep(active: Bool) {
        guard active, !reduceMotion else {
            brightSweep = false
            glowSweep = false
            breathe = active && reduceMotion
            return
        }

        brightSweep = false
        glowSweep = false
        breathe = false
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                brightSweep = true
            }
            withAnimation(.linear(duration: 1.85).repeatForever(autoreverses: false)) {
                glowSweep = true
            }
            withAnimation(.easeInOut(duration: 0.92).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

private struct TranslationStatusRow: View {
    let isTranslating: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isTranslating {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignColors.accentPrimary)
            }

            Text(isTranslating ? "Translating..." : "Preparing translation...")
                .font(.caption)
                .foregroundStyle(DesignColors.textMuted)
        }
    }
}

private struct TranslationRevealContainer<Content: View>: View {
    let trigger: String
    let reduceMotion: Bool
    var onReveal: () -> Void = {}
    @ViewBuilder let content: (_ highlightedSuffix: String, _ highlightOpacity: Double) -> Content

    @State private var highlightedSuffix = ""
    @State private var flashOpacity = 0.0

    var body: some View {
        content(highlightedSuffix, flashOpacity)
        .onChange(of: trigger) { oldValue, newValue in playReveal(from: oldValue, to: newValue) }
    }

    private func playReveal(from oldValue: String, to newValue: String) {
        highlightedSuffix = appendedSuffix(from: oldValue, to: newValue)

        guard !reduceMotion else {
            flashOpacity = 0
            return
        }

        onReveal()
        flashOpacity = 0.86

        withAnimation(.easeOut(duration: 0.70)) {
            flashOpacity = 0
        }
    }

    private func appendedSuffix(from oldValue: String, to newValue: String) -> String {
        guard !oldValue.isEmpty, newValue.hasPrefix(oldValue), newValue.count > oldValue.count else {
            return newValue
        }

        return String(newValue.dropFirst(oldValue.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
