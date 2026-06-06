//
//  HoverTranslatableText.swift
//  Novi
//
//  Renders text as individually hoverable words. Hovering a word shows its
//  meaning in a popover, using known vocabulary first and Novi's own
//  LibreTranslate instance for everything else.
//

import SwiftUI

/// A read-only text view whose words can be hovered to reveal their meaning.
///
/// - `text` is shown to the user (in `wordsLanguage`).
/// - Hovering a word translates it into `explanationLanguage` on demand via the
///   `translationService` and caches the result.
/// - `glossary` provides instant, offline lookups (e.g. the lesson's vocabulary).
struct HoverTranslatableText: View {
    let text: String
    /// BCP-47 code of the language `text` is written in.
    let wordsLanguage: String
    /// BCP-47 code of the language hovered words are translated into.
    let explanationLanguage: String
    /// Instant lookups keyed by lowercased word.
    var glossary: [String: String] = [:]
    /// Translation backend (Novi's own LibreTranslate by default).
    var translationService: any TranslationService = TranslationServiceFactory.makeDefault()

    @State private var cache: [String: String] = [:]
    @State private var failed: Set<String> = []
    @State private var inFlight: Set<String> = []

    private var tokens: [TextToken] { TextToken.tokens(from: text) }

    private var languagesValid: Bool {
        !wordsLanguage.isEmpty && !explanationLanguage.isEmpty
            && explanationLanguage != "auto" && wordsLanguage != explanationLanguage
    }

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: 5) {
            ForEach(tokens) { token in
                if let word = token.word {
                    HoverWord(
                        word: word,
                        display: token.display,
                        meaning: meaning(for: word),
                        isUnavailable: failed.contains(word.lowercased()),
                        onHover: { requestTranslation(word) }
                    )
                } else {
                    Text(token.display)
                        .foregroundStyle(DesignColors.textPrimary)
                }
            }
        }
    }

    private func meaning(for word: String) -> String? {
        let key = word.lowercased()
        return glossary[key] ?? cache[key]
    }

    /// Translates a single word on demand and caches the result.
    private func requestTranslation(_ word: String) {
        let key = word.lowercased()
        guard meaning(for: word) == nil, !inFlight.contains(key), !failed.contains(key) else { return }
        guard languagesValid else { failed.insert(key); return }

        inFlight.insert(key)
        let service = translationService
        let from = wordsLanguage
        let to = explanationLanguage

        Task {
            let result = try? await service.translate(key, from: from, to: to)
            let translated = result?.text.trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                inFlight.remove(key)
                if let translated, !translated.isEmpty {
                    cache[key] = translated
                } else {
                    failed.insert(key)
                }
            }
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
    /// Called when the pointer enters the word (triggers translation).
    let onHover: () -> Void

    @State private var isHovered = false

    var body: some View {
        Text(display)
            .padding(.horizontal, 1)
            .background(
                isHovered ? DesignColors.accentPrimary.opacity(0.18) : .clear,
                in: RoundedRectangle(cornerRadius: 3)
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering { onHover() }
            }
            .popover(isPresented: $isHovered, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word)
                        .font(.headline)
                    if let meaning, !meaning.isEmpty {
                        Text(meaning)
                            .foregroundStyle(DesignColors.textSecondary)
                            .textSelection(.enabled)
                    } else if isUnavailable {
                        Text("No translation available")
                            .font(.callout)
                            .foregroundStyle(DesignColors.textSecondary)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Translating…").foregroundStyle(DesignColors.textSecondary)
                        }
                    }
                }
                .padding(12)
                .frame(minWidth: 130, alignment: .leading)
                .background(DesignColors.surfacePrimary)
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
