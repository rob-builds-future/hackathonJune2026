//
//  WordLibraryView.swift
//  Novi
//
//  A personal, card-based collection of the words the user's life has taught
//  them — not a table. Search and filter, then open a word for its story.
//

import SwiftUI
import SwiftData

struct WordLibraryView: View {
    /// Opens a related journal entry (memory) by id.
    var onOpenEntry: (UUID) -> Void = { _ in }

    @Query(sort: \WordRecord.lastSuggestedAt, order: .reverse)
    private var words: [WordRecord]

    @State private var search = ""
    @State private var statusFilter: LearningStatus?

    private var filtered: [WordRecord] {
        words.filter { word in
            let matchesStatus = statusFilter == nil || word.learningStatus == statusFilter
            let matchesSearch = search.isEmpty
                || word.term.localizedCaseInsensitiveContains(search)
                || word.translation.localizedCaseInsensitiveContains(search)
            return matchesStatus && matchesSearch
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                content
            }
            .navigationTitle("Word Library")
            .navigationSubtitle(subtitle)
            .navigationDestination(for: WordRecord.self) { word in
                WordDetailView(word: word, onOpenEntry: onOpenEntry)
            }
        }
        .searchable(text: $search, prompt: "Search your words")
    }

    private var subtitle: String {
        words.isEmpty ? "" : "\(words.count) word\(words.count == 1 ? "" : "s") collected from your life"
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", color: .accentColor,
                           isSelected: statusFilter == nil) { statusFilter = nil }
                ForEach(LearningStatus.allCases) { status in
                    FilterChip(title: status.label, color: status.color,
                               isSelected: statusFilter == status) {
                        statusFilter = (statusFilter == status) ? nil : status
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if words.isEmpty {
            ContentUnavailableView(
                "Your collection is empty",
                systemImage: "leaf",
                description: Text("As you journal and generate lessons, the words your life teaches you gather here.")
            )
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filtered) { word in
                        NavigationLink(value: word) {
                            WordCard(word: word)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Word card

private struct WordCard: View {
    let word: WordRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.term)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(word.translation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack {
                StatusBadge(status: word.learningStatus)
                Spacer()
                Text("\(word.timesSuggested)×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Suggested \(word.timesSuggested) times")
            }

            ProgressView(value: word.confidenceScore)
                .tint(word.learningStatus.color)
        }
        .padding(16)
        .frame(height: 150, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(word.learningStatus.color.opacity(0.6))
                .frame(height: 4)
                .padding(.horizontal, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(.quaternary, lineWidth: 1)
        )
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? color.opacity(0.20) : Color.secondary.opacity(0.10),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared status styling

/// A small colored badge for a learning status.
struct StatusBadge: View {
    let status: LearningStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.18), in: Capsule())
            .foregroundStyle(status.color)
    }
}

extension LearningStatus {
    var color: Color {
        switch self {
        case .new: return .secondary
        case .learning: return .orange
        case .practicing: return .yellow
        case .familiar: return .blue
        case .mastered: return .green
        }
    }
}

#Preview {
    WordLibraryView()
        .modelContainer(for: [JournalEntryRecord.self, VocabularyItemRecord.self, WordRecord.self],
                        inMemory: true)
}
