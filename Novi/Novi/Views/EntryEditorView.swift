//
//  EntryEditorView.swift
//  Novi
//
//  Two-pane editor for one journal entry. Used for both new and saved entries
//  — editing a saved entry behaves exactly like the writing workspace.
//

import SwiftUI
import SwiftData

struct EntryEditorView: View {
    let entry: JournalEntryRecord
    @State private var viewModel: EntryEditorViewModel

    init(entry: JournalEntryRecord, modelContext: ModelContext) {
        self.entry = entry
        _viewModel = State(initialValue: EntryEditorViewModel(entry: entry, modelContext: modelContext))
    }

    var body: some View {
        HSplitView {
            EntryInputPane(entry: entry, viewModel: viewModel)
                .frame(minWidth: 420, idealWidth: 620)

            EntryOutputPane(entry: entry, viewModel: viewModel)
                .frame(minWidth: 360, idealWidth: 480)
        }
        .frame(minWidth: 860, minHeight: 560)
        .background(DesignColors.auroraBackground)
        .onChange(of: entry.sourceText) { viewModel.handleTextEdit() }
        .onChange(of: entry.title) { viewModel.handleTitleEdit() }
        .onChange(of: entry.sourceLanguage) { viewModel.handleLanguageChange() }
        .onChange(of: entry.targetLanguage) { viewModel.handleLanguageChange() }
        .onDisappear { viewModel.flush() }
    }
}
