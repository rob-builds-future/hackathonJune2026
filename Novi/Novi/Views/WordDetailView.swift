//
//  WordDetailView.swift
//  Novi
//
//  A word's story: translation, progress, stats, example and — most
//  importantly — the journal entries where it appeared in the user's life.
//

import SwiftUI

struct WordDetailView: View {
    let word: WordRecord
    var onOpenEntry: (UUID) -> Void = { _ in }

    private var relatedEntries: [JournalEntryRecord] {
        word.entries.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                progressSection
                statisticsSection
                if !word.example.isEmpty { exampleSection }
                relatedMemoriesSection
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(word.term)
    }

    // MARK: - Header (highest emphasis)

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(word.term)
                .font(.system(size: 40, weight: .bold))
                .textSelection(.enabled)
            Text(word.translation)
                .font(.title2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Progress (medium emphasis)

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusBadge(status: word.learningStatus)
                Spacer()
                Text("\(Int(word.confidenceScore * 100))%")
                    .font(.headline)
                    .foregroundStyle(word.learningStatus.color)
            }
            ProgressView(value: word.confidenceScore)
                .tint(word.learningStatus.color)
        }
    }

    // MARK: - Statistics (lower emphasis)

    private var statisticsSection: some View {
        let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(label: "Times Suggested", value: "\(word.timesSuggested)", icon: "sparkles")
            StatTile(label: "Times Used", value: "\(word.timesUsedByUser)", icon: "pencil")
            StatTile(label: "First Learned", value: Self.date(word.firstSuggestedAt), icon: "calendar")
            StatTile(label: "Last Seen", value: Self.date(lastSeen), icon: "clock")
        }
    }

    private var lastSeen: Date {
        max(word.lastSuggestedAt, word.lastUsedAt ?? .distantPast)
    }

    private static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Example

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Example Sentence")
            Text(word.example)
                .font(.body)
                .italic()
                .textSelection(.enabled)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Related memories (special emphasis)

    private var relatedMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(.tint)
                Text("Related Memories")
                    .font(.title3.weight(.semibold))
            }

            Text("Where this word showed up in your life")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if relatedEntries.isEmpty {
                Text("No linked journal entries yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(relatedEntries) { entry in
                        MemoryRow(entry: entry) { onOpenEntry(entry.id) }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
    }
}

// MARK: - Pieces

private struct StatTile: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct MemoryRow: View {
    let entry: JournalEntryRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayTitle)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
