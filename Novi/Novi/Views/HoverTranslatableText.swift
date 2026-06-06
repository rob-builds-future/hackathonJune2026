//
//  HoverTranslatableText.swift
//  Novi
//
//  Renders translated text as one AppKit text view. Clicking a word shows its
//  meaning in one lightweight popover, using known vocabulary first and Novi's
//  configured translation backend for everything else.
//

import AppKit
import SwiftUI

/// A read-only text view whose words can be clicked to reveal their meaning.
///
/// - `text` is shown to the user (in `wordsLanguage`).
/// - Clicking a word translates it into `explanationLanguage` on demand via the
///   `translationService` and caches the result.
/// - `glossary` provides instant, offline lookups (e.g. the lesson's vocabulary).
struct HoverTranslatableText: View {
    let text: String
    /// BCP-47 code of the language `text` is written in.
    let wordsLanguage: String
    /// BCP-47 code of the language clicked words are translated into.
    let explanationLanguage: String
    /// Instant lookups keyed by lowercased word.
    var glossary: [String: String] = [:]
    /// Optional trailing text to flash without re-animating the whole paragraph.
    var highlightedSuffix: String = ""
    var highlightOpacity: Double = 0
    var fontSize: CGFloat = 15
    /// Translation backend (DeepL when configured, LibreTranslate fallback).
    var translationService: any TranslationService = TranslationServiceFactory.makeDefault()

    var body: some View {
        ClickTranslatableTextView(
            text: text,
            wordsLanguage: wordsLanguage,
            explanationLanguage: explanationLanguage,
            glossary: glossary,
            highlightedSuffix: highlightedSuffix,
            highlightOpacity: highlightOpacity,
            fontSize: fontSize,
            translationService: translationService
        )
    }
}

// MARK: - AppKit text renderer

private struct ClickTranslatableTextView: NSViewRepresentable {
    let text: String
    let wordsLanguage: String
    let explanationLanguage: String
    let glossary: [String: String]
    let highlightedSuffix: String
    let highlightOpacity: Double
    let fontSize: CGFloat
    let translationService: any TranslationService

    func makeCoordinator() -> Coordinator {
        Coordinator(
            wordsLanguage: wordsLanguage,
            explanationLanguage: explanationLanguage,
            glossary: glossary,
            translationService: translationService
        )
    }

    func makeNSView(context: Context) -> ClickableWrappingTextView {
        let view = ClickableWrappingTextView()
        view.onWordClick = { [weak coordinator = context.coordinator] word, rect, sourceView in
            coordinator?.showMeaning(for: word, anchorRect: rect, in: sourceView)
        }
        return view
    }

    func updateNSView(_ nsView: ClickableWrappingTextView, context: Context) {
        context.coordinator.update(
            wordsLanguage: wordsLanguage,
            explanationLanguage: explanationLanguage,
            glossary: glossary,
            translationService: translationService
        )
        nsView.update(text: text, highlightedSuffix: highlightedSuffix, highlightOpacity: highlightOpacity, fontSize: fontSize)
    }

    final class Coordinator: NSObject {
        private var wordsLanguage: String
        private var explanationLanguage: String
        private var glossary: [String: String]
        private var translationService: any TranslationService

        private var cache: [String: String] = [:]
        private var inFlight: Set<String> = []
        private var selectedWord: String?
        private var selectedAnchorRect: NSRect?
        private weak var selectedSourceView: NSView?
        private var popover: NSPopover?

        init(
            wordsLanguage: String,
            explanationLanguage: String,
            glossary: [String: String],
            translationService: any TranslationService
        ) {
            self.wordsLanguage = wordsLanguage
            self.explanationLanguage = explanationLanguage
            self.glossary = glossary
            self.translationService = translationService
        }

        func update(
            wordsLanguage: String,
            explanationLanguage: String,
            glossary: [String: String],
            translationService: any TranslationService
        ) {
            let languageChanged = self.wordsLanguage != wordsLanguage
                || self.explanationLanguage != explanationLanguage
            self.wordsLanguage = wordsLanguage
            self.explanationLanguage = explanationLanguage
            self.glossary = glossary
            self.translationService = translationService
            if languageChanged {
                cache.removeAll()
                inFlight.removeAll()
                closePopover()
            }
        }

        func showMeaning(for word: String, anchorRect: NSRect, in sourceView: NSView) {
            let cleanedWord = Self.cleanedWord(word)
            guard !cleanedWord.isEmpty else { return }

            let key = cacheKey(for: cleanedWord)
            selectedWord = word
            selectedAnchorRect = anchorRect
            selectedSourceView = sourceView

            showPopover(word: word, meaning: meaning(for: key), isUnavailable: false, inFlight: inFlight.contains(key))

            guard meaning(for: key) == nil, !inFlight.contains(key) else { return }
            guard languagesValid else {
                showPopover(word: word, meaning: nil, isUnavailable: true, inFlight: false)
                return
            }

            inFlight.insert(key)
            showPopover(word: word, meaning: nil, isUnavailable: false, inFlight: true)

            let service = translationService
            let from = normalizedLanguage(wordsLanguage)
            let to = normalizedLanguage(explanationLanguage)

            Task {
                let result = try? await service.translate(cleanedWord, from: from, to: to)
                let translated = result?.text.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    self.inFlight.remove(key)
                    if let translated, !translated.isEmpty {
                        self.cache[key] = translated
                    }
                    guard self.selectedWord.map(Self.cleanedWord).map(self.cacheKey(for:)) == key else { return }
                    self.showPopover(
                        word: word,
                        meaning: self.meaning(for: key),
                        isUnavailable: translated == nil || translated?.isEmpty == true,
                        inFlight: false
                    )
                }
            }
        }

        private var languagesValid: Bool {
            let from = normalizedLanguage(wordsLanguage)
            let to = normalizedLanguage(explanationLanguage)
            return !from.isEmpty && !to.isEmpty && to != "auto" && from != to
        }

        private func meaning(for key: String) -> String? {
            cache[key] ?? glossary[glossaryKey(from: key)]
        }

        private func cacheKey(for word: String) -> String {
            "\(normalizedLanguage(wordsLanguage))|\(normalizedLanguage(explanationLanguage))|\(word.lowercased())"
        }

        private func glossaryKey(from cacheKey: String) -> String {
            cacheKey.components(separatedBy: "|").last ?? cacheKey
        }

        private func normalizedLanguage(_ language: String) -> String {
            language
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .components(separatedBy: "-")
                .first ?? ""
        }

        private static func cleanedWord(_ word: String) -> String {
            word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        }

        private func showPopover(word: String, meaning: String?, isUnavailable: Bool, inFlight: Bool) {
            guard let selectedAnchorRect, let selectedSourceView else { return }

            let content = WordMeaningPopoverContent(
                word: word,
                meaning: meaning,
                isUnavailable: isUnavailable,
                inFlight: inFlight
            )
            .padding(12)

            let controller = NSHostingController(rootView: content)
            controller.sizingOptions = [.intrinsicContentSize]

            if popover == nil {
                let popover = NSPopover()
                popover.behavior = .transient
                popover.animates = false
                self.popover = popover
            }

            popover?.contentViewController = controller
            if popover?.isShown == true {
                popover?.positioningRect = selectedAnchorRect
            } else {
                popover?.show(relativeTo: selectedAnchorRect, of: selectedSourceView, preferredEdge: .maxY)
            }
        }

        private func closePopover() {
            popover?.close()
            popover = nil
            selectedWord = nil
            selectedAnchorRect = nil
            selectedSourceView = nil
        }
    }
}

private final class ClickableWrappingTextView: NSView {
    var onWordClick: ((String, NSRect, NSView) -> Void)?

    private let textView = NSTextView()
    private var heightConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: heightConstraint?.constant ?? 20)
    }

    override func layout() {
        super.layout()
        textView.textContainer?.containerSize = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        updateHeight()
    }

    func update(text: String, highlightedSuffix: String = "", highlightOpacity: Double = 0, fontSize: CGFloat = 15) {
        if textView.string != text {
            textView.string = text
        }
        applyTextStyle(highlightedSuffix: highlightedSuffix, highlightOpacity: highlightOpacity, fontSize: fontSize)
        updateHeight()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(textView)
        heightConstraint = heightAnchor.constraint(equalToConstant: 20)
        heightConstraint?.isActive = true
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        textView.addGestureRecognizer(clickGesture)
    }

    private func applyTextStyle(highlightedSuffix: String, highlightOpacity: Double, fontSize: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let textColor = NSColor(named: "TextPrimary") ?? .labelColor
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = textColor
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        textView.textStorage?.setAttributes(textView.typingAttributes, range: NSRange(location: 0, length: textView.string.utf16.count))

        let suffix = highlightedSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard highlightOpacity > 0, !suffix.isEmpty else { return }

        let nsString = textView.string as NSString
        let range = nsString.range(of: suffix, options: [.backwards, .caseInsensitive])
        guard range.location != NSNotFound else { return }

        let teal = NSColor(named: "AccentPrimary") ?? .systemTeal
        let highlight = teal.withAlphaComponent(max(0, min(1, highlightOpacity * 0.28)))
        textView.textStorage?.addAttributes(
            [
                .backgroundColor: highlight,
                .foregroundColor: textColor
            ],
            range: range
        )
    }

    private func updateHeight() {
        guard bounds.width > 0,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let height = ceil(layoutManager.usedRect(for: textContainer).height)
        heightConstraint?.constant = max(20, height)
        invalidateIntrinsicContentSize()
    }

    @objc private func handleClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended,
              let wordHit = word(at: recognizer.location(in: textView)) else { return }
        onWordClick?(wordHit.word, wordHit.rect, textView)
    }

    private func word(at point: NSPoint) -> (word: String, rect: NSRect)? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        let containerOrigin = textView.textContainerOrigin
        let containerPoint = NSPoint(x: point.x - containerOrigin.x, y: point.y - containerOrigin.y)
        let glyphIndex = layoutManager.glyphIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        var characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let nsString = textView.string as NSString
        guard characterIndex < nsString.length else { return nil }

        if !Self.isWordCharacter(in: nsString, at: characterIndex) {
            guard let nearby = Self.nearbyWordIndex(in: nsString, around: characterIndex) else { return nil }
            characterIndex = nearby
        }

        let wordRange = Self.wordRange(in: nsString, at: characterIndex)
        guard wordRange.length > 0 else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: wordRange, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect = rect.insetBy(dx: -2, dy: -2)
        guard rect.insetBy(dx: -10, dy: -8).contains(containerPoint) else { return nil }
        rect.origin.x += containerOrigin.x
        rect.origin.y += containerOrigin.y

        return (nsString.substring(with: wordRange), rect)
    }

    private static func nearbyWordIndex(in string: NSString, around index: Int) -> Int? {
        for distance in 1...2 {
            let previous = index - distance
            if isWordCharacter(in: string, at: previous) { return previous }

            let next = index + distance
            if isWordCharacter(in: string, at: next) { return next }
        }
        return nil
    }

    private static func isWordCharacter(in string: NSString, at index: Int) -> Bool {
        let wordCharacters = CharacterSet.letters.union(.decimalDigits)
        guard index >= 0,
              index < string.length,
              let scalar = UnicodeScalar(string.character(at: index)) else { return false }
        return wordCharacters.contains(scalar)
    }

    private static func wordRange(in string: NSString, at index: Int) -> NSRange {
        guard isWordCharacter(in: string, at: index) else {
            return NSRange(location: index, length: 0)
        }

        var start = index
        while isWordCharacter(in: string, at: start - 1) {
            start -= 1
        }

        var end = index
        while isWordCharacter(in: string, at: end) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }
}

private struct WordMeaningPopoverContent: View {
    let word: String
    let meaning: String?
    let isUnavailable: Bool
    let inFlight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(word)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(DesignColors.textPrimary)

            if let meaning, !meaning.isEmpty {
                Text(meaning)
                    .font(Typography.caption)
                    .foregroundStyle(DesignColors.textSecondary)
            } else if isUnavailable {
                Text("No translation available")
                    .font(Typography.caption)
                    .foregroundStyle(DesignColors.textSecondary)
            } else if inFlight {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating...")
                        .font(Typography.caption)
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }
        }
        .frame(minWidth: 130, alignment: .leading)
        .fixedSize()
        .background(DesignColors.surfaceElevated)
    }
}
