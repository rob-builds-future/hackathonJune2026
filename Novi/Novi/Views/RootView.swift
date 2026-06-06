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
    @Query(sort: \JournalEntryRecord.journalDate, order: .reverse)
    private var entries: [JournalEntryRecord]

    @State private var selection: SidebarItem?
    @State private var wordReturnID: UUID?
    @State private var pendingWordOpenID: UUID?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 290)
        } detail: {
            detail
        }
        .onChange(of: selection) { oldValue, _ in
            if case let .entry(oldID) = oldValue {
                pruneIfEmpty(id: oldID)
            }
        }
        .onAppear {
            openDraftIfNeeded()
        }
        .toolbar(.hidden)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            brandHeader

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    pinnedLibraryCard

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(Typography.metadata.weight(.semibold))
                                .foregroundStyle(DesignColors.textMuted)
                                .textCase(.uppercase)
                                .padding(.horizontal, 6)

                            ForEach(section.entries) { entry in
                                Button {
                                    wordReturnID = nil
                                    pendingWordOpenID = nil
                                    selection = .entry(entry.id)
                                } label: {
                                    EntrySidebarRow(
                                        entry: entry,
                                        isSelected: selection == .entry(entry.id)
                                    )
                                }
                                .buttonStyle(.plain)
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
                .padding(12)
            }
            .scrollContentBackground(.hidden)
        }
        .background(DesignColors.sidebarGradient)
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignColors.accentGradient)
                Text("N")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            .shadow(color: DesignColors.cardShadowStrong, radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text("Novi")
                    .font(Typography.cardTitle)
                    .foregroundStyle(DesignColors.textPrimary)
                Text("future-self journal")
                    .font(Typography.metadata)
                    .foregroundStyle(DesignColors.textMuted)
            }

            Spacer()

            Button(action: newEntry) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignColors.selectionText)
                    .frame(width: 34, height: 34)
                    .background(DesignColors.accentGradient, in: RoundedRectangle(cornerRadius: CornerRadius.small))
                    .shadow(color: DesignColors.cardShadowStrong, radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .help("New Entry")
        }
        .padding(.horizontal, 14)
        .padding(.top, Spacing.medium)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignColors.glassStroke)
                .frame(height: 1)
        }
    }

    private var pinnedLibraryCard: some View {
        Button {
            wordReturnID = nil
            pendingWordOpenID = nil
            selection = .wordLibrary
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignColors.brandGold)
                    .frame(width: 32, height: 32)
                    .background(DesignColors.brandGold.opacity(0.14), in: RoundedRectangle(cornerRadius: CornerRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Word Library")
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(selection == .wordLibrary ? DesignColors.selectionText : DesignColors.textPrimary)
                    Text("words from your life")
                        .font(Typography.metadata)
                        .foregroundStyle(selection == .wordLibrary ? DesignColors.selectionText.opacity(0.72) : DesignColors.textMuted)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sidebarCardFill(isSelected: selection == .wordLibrary), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(sidebarCardStroke(isSelected: selection == .wordLibrary))
            .shadow(color: DesignColors.shadow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .wordLibrary:
            WordLibraryView(openWordID: $pendingWordOpenID) { entryID, wordID in
                wordReturnID = wordID
                selection = nil
                DispatchQueue.main.async {
                    selection = .entry(entryID)
                }
            }
        case let .entry(id):
            if let entry = entries.first(where: { $0.id == id }) {
                if wordReturnID != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        returnToWordButton
                            .padding(.horizontal, Spacing.medium)
                            .padding(.top, 10)

                        EntryEditorView(entry: entry, modelContext: modelContext) {
                            delete(entry)
                        }
                            .id(entry.id)
                    }
                    .background(DesignColors.auroraBackground)
                } else {
                    EntryEditorView(entry: entry, modelContext: modelContext) {
                        delete(entry)
                    }
                        .id(entry.id)
                }
            } else {
                placeholder
            }
        case nil:
            Color.clear
                .background(DesignColors.auroraBackground)
        }
    }

    private var placeholder: some View {
        ContentUnavailableView(
            "No entry selected",
            systemImage: "book.closed",
            description: Text("Pick an entry from the sidebar or create a new one.")
        )
        .foregroundStyle(DesignColors.textSecondary)
        .background(DesignColors.auroraBackground)
    }

    // MARK: - Derived data

    private var sections: [DaySection] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: visibleEntries) { calendar.startOfDay(for: $0.journalDate) }
        return groups
            .map { day, entries in
                DaySection(
                    day: day,
                    entries: entries.sorted {
                        if $0.journalDate == $1.journalDate { return $0.updatedAt > $1.updatedAt }
                        return $0.journalDate > $1.journalDate
                    }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private var visibleEntries: [JournalEntryRecord] {
        entries.filter { !$0.isEmpty }
    }

    // MARK: - Actions

    private func openDraftIfNeeded() {
        pruneEmptyEntries()
        guard selection == nil else { return }
        newEntry()
    }

    private func newEntry() {
        wordReturnID = nil
        pendingWordOpenID = nil
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

    private var returnToWordButton: some View {
        Button {
            pendingWordOpenID = wordReturnID
            wordReturnID = nil
            selection = .wordLibrary
        } label: {
            Label("Back to Word", systemImage: "chevron.left")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(DesignColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DesignColors.cardGradient, in: Capsule())
                .overlay(Capsule().stroke(DesignColors.glassStroke, lineWidth: 1))
                .shadow(color: DesignColors.shadow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    /// Removes an entry the user left completely empty.
    private func pruneIfEmpty(id: UUID) {
        guard selection != .entry(id),
              let previous = entries.first(where: { $0.id == id }),
              previous.isEmpty else { return }
        modelContext.delete(previous)
        try? modelContext.save()
    }

    private func pruneEmptyEntries() {
        for entry in entries where entry.isEmpty && selection != .entry(entry.id) {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func sidebarCardFill(isSelected: Bool) -> some ShapeStyle {
        isSelected ? AnyShapeStyle(DesignColors.accentGradient) : AnyShapeStyle(DesignColors.cardGradient)
    }

    private func sidebarCardStroke(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .stroke(isSelected ? DesignColors.glassStroke : DesignColors.separator.opacity(0.65), lineWidth: isSelected ? 1.4 : 1)
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
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? DesignColors.selectionText.opacity(0.85) : DesignColors.brandTeal.opacity(0.55))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayTitle)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(isSelected ? DesignColors.selectionText : DesignColors.textPrimary)
                        .lineLimit(2)
                    Text(entry.journalDate, format: .dateTime.hour().minute())
                        .font(Typography.metadata)
                        .foregroundStyle(isSelected ? DesignColors.selectionText.opacity(0.74) : DesignColors.textMuted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? AnyShapeStyle(DesignColors.accentGradient) : AnyShapeStyle(DesignColors.cardGradient),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(isSelected ? DesignColors.glassStroke : DesignColors.separator.opacity(0.55), lineWidth: isSelected ? 1.3 : 1)
        )
        .shadow(color: isSelected ? DesignColors.cardShadowStrong : DesignColors.shadow, radius: isSelected ? 14 : 8, x: 0, y: isSelected ? 7 : 3)
        .contentShape(Rectangle())
    }
}

#Preview {
    RootView()
        .modelContainer(for: [JournalEntryRecord.self, VocabularyItemRecord.self, WordRecord.self],
                        inMemory: true)
}
