//
//  HoverTranslatableText.swift
//  Novi
//
//  Renders text as individually hoverable words. Hovering a word shows its
//  meaning in an info tooltip, using known vocabulary first and Apple's
//  on-device Translation framework for everything else.
//

import SwiftUI
import Translation

/// A read-only text view whose words can be hovered to reveal their meaning.
///
/// - `text` is shown to the user (in `wordsLanguage`).
/// - Hovering a word shows its translation into `explanationLanguage`.
/// - `glossary` provides instant, offline lookups (e.g. the lesson's vocabulary);
///   anything missing is translated on-device via ``TranslationSession``.
struct HoverTranslatableText: View {
    let text: String
    /// BCP-47 code of the language `text` is written in.
    let wordsLanguage: String
    /// BCP-47 code of the language hovered words are translated into.
    let explanationLanguage: String
    /// Instant lookups keyed by lowercased word.
    var glossary: [String: String] = [:]

    @State private var cache: [String: String] = [:]
    @State private var attempted: Set<String> = []
    @State private var configuration: TranslationSession.Configuration?

    private var tokens: [TextToken] { TextToken.tokens(from: text) }

    private var uniqueWords: [String] {
        Array(Set(tokens.compactMap { $0.word?.lowercased() })).filter { !$0.isEmpty }
    }

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: 5) {
            ForEach(tokens) { token in
                if let word = token.word {
                    HoverWord(
                        word: word,
                        display: token.display,
                        meaning: meaning(for: word),
                        isUnavailable: meaning(for: word) == nil && attempted.contains(word.lowercased())
                    )
                } else {
                    Text(token.display)
                }
            }
        }
        .translationTask(configuration) { session in
            await translatePending(using: session)
        }
        .onAppear { refreshConfiguration() }
        .onChange(of: text) { refreshConfiguration() }
        .onChange(of: wordsLanguage) { cache = [:]; attempted = []; refreshConfiguration() }
        .onChange(of: explanationLanguage) { cache = [:]; attempted = []; refreshConfiguration() }
    }

    // MARK: - Lookups

    private func meaning(for word: String) -> String? {
        let key = word.lowercased()
        return glossary[key] ?? cache[key]
    }

    // MARK: - Translation

    private func refreshConfiguration() {
        guard !uniqueWords.isEmpty,
              !wordsLanguage.isEmpty, wordsLanguage != "auto",
              !explanationLanguage.isEmpty, explanationLanguage != "auto",
              wordsLanguage != explanationLanguage else { return }

        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: wordsLanguage),
                target: Locale.Language(identifier: explanationLanguage)
            )
        } else {
            configuration?.invalidate()
        }
    }

    private func translatePending(using session: TranslationSession) async {
        let pending = uniqueWords.filter { meaning(for: $0) == nil && !attempted.contains($0) }
        guard !pending.isEmpty else { return }

        // Warm up / ensure the language pair is ready once. If this fails the
        // pair is unavailable — mark everything attempted so the UI shows
        // "No translation available" instead of spinning forever.
        do {
            try await session.prepareTranslation()
        } catch {
            attempted.formUnion(pending)
            return
        }

        // Translate word by word and publish each result immediately, so words
        // light up as they finish instead of waiting for the whole batch.
        for word in pending {
            if Task.isCancelled { return }
            do {
                let response = try await session.translate(word)
                cache[word] = response.targetText
            } catch {
                // Leave this word unavailable; keep going with the rest.
            }
            attempted.insert(word)
        }
    }
}

// MARK: - Word view

/// A single hoverable word; highlights on hover and shows its meaning in a
/// popover info window.
private struct HoverWord: View {
    let word: String
    let display: String
    let meaning: String?
    /// True when translation was attempted but produced no result.
    let isUnavailable: Bool

    @State private var isHovered = false

    var body: some View {
        Text(display)
            .padding(.horizontal, 1)
            .background(
                isHovered ? Color.accentColor.opacity(0.20) : .clear,
                in: RoundedRectangle(cornerRadius: 3)
            )
            .onHover { isHovered = $0 }
            .popover(isPresented: $isHovered, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word)
                        .font(.headline)
                    if let meaning, !meaning.isEmpty {
                        Text(meaning)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    } else if isUnavailable {
                        Text("No translation available")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Translating…").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .frame(minWidth: 130, alignment: .leading)
            }
    }
}

// MARK: - Tokenizer

/// A run of characters from the source text: either a `word` (letters/digits)
/// or a separator (spaces, punctuation) where `word` is nil.
struct TextToken: Identifiable {
    let id: Int
    let display: String
    let word: String?

    static func tokens(from text: String) -> [TextToken] {
        var tokens: [TextToken] = []
        var current = ""
        var currentIsWord = false
        var id = 0

        func flush() {
            guard !current.isEmpty else { return }
            tokens.append(TextToken(id: id, display: current, word: currentIsWord ? current : nil))
            id += 1
            current = ""
        }

        for character in text {
            let isWordCharacter = character.isLetter || character.isNumber
            if current.isEmpty {
                current.append(character)
                currentIsWord = isWordCharacter
            } else if isWordCharacter == currentIsWord {
                current.append(character)
            } else {
                flush()
                current.append(character)
                currentIsWord = isWordCharacter
            }
        }
        flush()
        return tokens
    }
}

// MARK: - Flow layout

/// A simple left-to-right wrapping layout for the word views.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x)
        }
        let width = maxWidth.isFinite ? maxWidth : widest
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
