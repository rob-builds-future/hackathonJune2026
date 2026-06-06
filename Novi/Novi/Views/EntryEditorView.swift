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
    let onDelete: () -> Void
    @State private var viewModel: EntryEditorViewModel

    init(entry: JournalEntryRecord, modelContext: ModelContext, onDelete: @escaping () -> Void = {}) {
        self.entry = entry
        self.onDelete = onDelete
        _viewModel = State(initialValue: EntryEditorViewModel(entry: entry, modelContext: modelContext))
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 980
            let lessonWidth = max(360, min(proxy.size.width * 0.38, 560))

            HStack(alignment: .top, spacing: isCompact ? Spacing.medium : Spacing.large) {
                EntryInputPane(entry: entry, viewModel: viewModel, onDelete: onDelete)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                EntryOutputPane(entry: entry, viewModel: viewModel)
                    .frame(width: lessonWidth)
                    .frame(maxHeight: .infinity)
            }
            .padding(Spacing.medium)
        }
        .frame(minWidth: 860, minHeight: 560)
        .background(DesignColors.auroraBackground)
        .onChange(of: entry.sourceText) { viewModel.handleTextEdit() }
        .onChange(of: entry.title) { viewModel.handleTitleEdit() }
        .onChange(of: entry.journalDate) { viewModel.handleJournalDateChange() }
        .onChange(of: entry.sourceLanguage) { viewModel.handleLanguageChange() }
        .onChange(of: entry.targetLanguage) { viewModel.handleLanguageChange() }
        .onDisappear { viewModel.flush() }
    }
}
