//
//  JournalInputView.swift
//  Novi
//
//  Left pane: the journal entry editor, language selection and lesson action.
//

import SwiftUI

/// The input side of the screen: where the user writes and chooses languages.
struct JournalInputView: View {
    @Bindable var viewModel: LessonViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Journal Entry")
                    .font(.headline)
                TextEditor(text: $viewModel.journalEntry)
                    .font(.body)
                    .frame(maxHeight: .infinity)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )
            }

            languagePickers
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var languagePickers: some View {
        HStack(spacing: 12) {
            Picker("From", selection: $viewModel.sourceLanguage) {
                Text("Auto-detect").tag("auto")
                ForEach(Self.languages, id: \.code) { Text($0.name).tag($0.code) }
            }
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Picker("To", selection: $viewModel.targetLanguage) {
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
