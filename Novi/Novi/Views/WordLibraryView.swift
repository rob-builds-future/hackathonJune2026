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
                libraryHeader
                filterBar
                Divider().overlay(DesignColors.separator)
                content
            }
            .background(DesignColors.auroraBackground)
            .navigationDestination(for: WordRecord.self) { word in
                WordDetailView(word: word, onOpenEntry: onOpenEntry)
            }
        }
        .searchable(text: $search, prompt: "Search your words")
        .toolbar(.hidden)
    }

    private var subtitle: String {
        words.isEmpty ? "" : "\(words.count) word\(words.count == 1 ? "" : "s") collected from your life"
    }

    // MARK: - Filters

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignColors.memoryGradient)
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(DesignColors.brandGold)
            }
            .frame(width: 56, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignColors.glassStroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("Word Library")
                    .font(Typography.title)
                    .foregroundStyle(DesignColors.textPrimary)
                Text(subtitle.isEmpty ? "words collected from your life" : subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(DesignColors.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.top, Spacing.medium)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignColors.glassStroke)
                .frame(height: 1)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", color: DesignColors.accentPrimary,
                           isSelected: statusFilter == nil) { statusFilter = nil }
                ForEach(LearningStatus.allCases) { status in
                    FilterChip(title: status.label, color: status.color,
                               isSelected: statusFilter == status) {
                        statusFilter = (statusFilter == status) ? nil : status
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
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
            .foregroundStyle(DesignColors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignColors.auroraBackground)
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: search)
                .foregroundStyle(DesignColors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignColors.auroraBackground)
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
                .padding(Spacing.medium)
            }
            .background(DesignColors.auroraBackground)
        }
    }
}

// MARK: - Word card

private struct WordCard: View {
    let word: WordRecord

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.term)
                    .font(Typography.cardTitle)
                    .foregroundStyle(DesignColors.textPrimary)
                    .lineLimit(1)
            Text(word.translation)
                .font(.callout)
                .foregroundStyle(DesignColors.textSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack {
                StatusBadge(status: word.learningStatus)
                Spacer()
                Text("\(word.timesSuggested)×")
                    .font(.caption)
                    .foregroundStyle(DesignColors.textMuted)
                    .help("Suggested \(word.timesSuggested) times")
            }

            ProgressView(value: word.confidenceScore)
                .tint(word.learningStatus.color)
        }
        .padding(Spacing.small)
        .frame(height: 142, alignment: .topLeading)
        .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(DesignColors.glassStroke, lineWidth: 1)
        )
        .shadow(color: DesignColors.shadow, radius: 16, x: 0, y: 9)
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
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? color.opacity(0.22) : DesignColors.surfaceElevated.opacity(0.74),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? color : DesignColors.textSecondary)
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
        case .new: return DesignColors.textMuted
        case .learning: return DesignColors.warning
        case .practicing: return DesignColors.vocabularyAccent
        case .familiar: return DesignColors.accentPrimary
        case .mastered: return DesignColors.success
        }
    }
}

#Preview {
    WordLibraryView()
        .modelContainer(for: [JournalEntryRecord.self, VocabularyItemRecord.self, WordRecord.self],
                        inMemory: true)
}
