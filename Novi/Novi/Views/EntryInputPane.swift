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
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $entry.title)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)

            Text(savedStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            TextEditor(text: $entry.sourceText)
                .font(.body)
                .frame(maxHeight: .infinity)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                )

            languagePickers
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var savedStatus: String {
        if viewModel.isGeneratingTitle {
            return "Generating title…"
        }
        return "Last saved \(viewModel.lastSavedAt.formatted(date: .omitted, time: .standard))"
    }

    private var languagePickers: some View {
        HStack(spacing: 12) {
            Picker("From", selection: $entry.sourceLanguage) {
                Text("Auto-detect").tag("auto")
                ForEach(Self.languages, id: \.code) { Text($0.name).tag($0.code) }
            }
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
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
