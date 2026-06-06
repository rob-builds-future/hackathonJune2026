//
//  EntryInputPane.swift
//  Novi
//
//  Left pane of the editor: title, journal text, languages, last-saved status.
//

import SwiftUI

/// The input side of the editor. Binds directly to the record so edits
/// auto-save through the view model.
struct EntryInputPane: View {
    @Bindable var entry: JournalEntryRecord
    let viewModel: EntryEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            TextField("Title", text: $entry.title)
                .font(Typography.title)
                .textFieldStyle(.plain)
                .foregroundStyle(DesignColors.textPrimary)

            Text(savedStatus)
                .font(Typography.caption)
                .foregroundStyle(DesignColors.textMuted)

            Divider()
                .overlay(DesignColors.separator)

            TextEditor(text: $entry.sourceText)
                .font(Typography.body)
                .foregroundStyle(DesignColors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DesignColors.surfaceInset)
                .frame(maxHeight: .infinity)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(DesignColors.separator, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(DesignColors.focusRing.opacity(0.18), lineWidth: 1)
                        .padding(2)
                )

            languagePickers
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignColors.backgroundPrimary)
    }

    private var savedStatus: String {
        if viewModel.isGeneratingTitle {
            return "Generating title…"
        }
        return "Last saved \(viewModel.lastSavedAt.formatted(date: .omitted, time: .standard))"
    }

    private var languagePickers: some View {
        HStack(spacing: 12) {
            Text("From")
                .font(Typography.caption)
                .foregroundStyle(DesignColors.textMuted)
            Picker("From", selection: $entry.sourceLanguage) {
                Text("Auto-detect").tag("auto")
                ForEach(Self.languages, id: \.code) { Text($0.name).tag($0.code) }
            }
            Image(systemName: "arrow.right")
                .foregroundStyle(DesignColors.textMuted)
            Text("To")
                .font(Typography.caption)
                .foregroundStyle(DesignColors.textMuted)
            Picker("To", selection: $entry.targetLanguage) {
                ForEach(Self.languages, id: \.code) { Text($0.name).tag($0.code) }
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }

    /// A small set of languages offered in the UI. Codes match LibreTranslate.
    private static let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("de", "German"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("ru", "Russian"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ar", "Arabic")
    ]
}
