//
//  RootView.swift
//  Novi
//
//  Notes-app shell: a sidebar with the Word Library and saved entries grouped
//  by day, and the editor / library in the detail pane.
//

import SwiftUI
import SwiftData

/// What the sidebar can select.
enum SidebarItem: Hashable {
    case wordLibrary
    case entry(UUID)
}

/// The app's root. The sidebar holds the Word Library plus saved journal
/// entries grouped into daily sections, newest first.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntryRecord.updatedAt, order: .reverse)
    private var entries: [JournalEntryRecord]

    @State private var selection: SidebarItem?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label("Word Library", systemImage: "character.book.closed")
                        .tag(SidebarItem.wordLibrary)
                }

                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.entries) { entry in
                            EntrySidebarRow(entry: entry)
                                .tag(SidebarItem.entry(entry.id))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        delete(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .navigationTitle("Novi")
            .toolbar {
                ToolbarItem {
                    Button(action: newEntry) {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
                }
            }
        } detail: {
            detail
        }
        .onChange(of: selection) { oldValue, _ in
            if case let .entry(oldID) = oldValue {
                pruneIfEmpty(id: oldID)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .wordLibrary:
            WordLibraryView { entryID in
                selection = .entry(entryID)
            }
        case let .entry(id):
            if let entry = entries.first(where: { $0.id == id }) {
                EntryEditorView(entry: entry, modelContext: modelContext)
                    .id(entry.id)
            } else {
                placeholder
            }
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        ContentUnavailableView(
            "No entry selected",
            systemImage: "book.closed",
            description: Text("Pick an entry from the sidebar or create a new one.")
        )
    }

    // MARK: - Derived data

    private var sections: [DaySection] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.updatedAt) }
        return groups
            .map { DaySection(day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }

    // MARK: - Actions

    private func newEntry() {
        let entry = JournalEntryRecord()
        modelContext.insert(entry)
        try? modelContext.save()
        selection = .entry(entry.id)
    }

    private func delete(_ entry: JournalEntryRecord) {
        if selection == .entry(entry.id) { selection = nil }
        modelContext.delete(entry)
        try? modelContext.save()
    }

    /// Removes an entry the user left completely empty.
    private func pruneIfEmpty(id: UUID) {
        guard selection != .entry(id),
              let previous = entries.first(where: { $0.id == id }),
              previous.isEmpty else { return }
        modelContext.delete(previous)
        try? modelContext.save()
    }
}

/// A day's worth of entries in the sidebar.
private struct DaySection: Identifiable {
    let day: Date
    let entries: [JournalEntryRecord]

    var id: Date { day }

    var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month().year())
    }
}

/// One entry row in the sidebar.
private struct EntrySidebarRow: View {
    let entry: JournalEntryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.displayTitle)
                .lineLimit(1)
            Text(entry.updatedAt, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [JournalEntryRecord.self, VocabularyItemRecord.self, WordRecord.self],
                        inMemory: true)
}
