//
//  WordDetailView.swift
//  Novi
//
//  A word's story: translation, progress, stats, example and — most
//  importantly — the journal entries where it appeared in the user's life.
//

import SwiftUI

struct WordDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let word: WordRecord
    var onOpenEntry: (UUID, UUID) -> Void = { _, _ in }

    private var relatedEntries: [JournalEntryRecord] {
        word.entries.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                backButton
                header
                progressSection
                statisticsSection
                if !word.example.isEmpty { exampleSection }
                relatedMemoriesSection
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.xLarge)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DesignColors.auroraBackground)
        .toolbar(.hidden)
    }

    // MARK: - Header (highest emphasis)

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Label("Library", systemImage: "chevron.left")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(DesignColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DesignColors.cardGradient, in: Capsule())
                .overlay(Capsule().stroke(DesignColors.glassStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(word.term)
                .font(Typography.hero)
                .foregroundStyle(DesignColors.textPrimary)
                .textSelection(.enabled)
            Text(word.translation)
                .font(Typography.title)
                .foregroundStyle(DesignColors.textSecondary)
                .textSelection(.enabled)
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColors.memoryGradient, in: RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(DesignColors.glassStroke, lineWidth: 1)
        )
        .shadow(color: DesignColors.shadow, radius: 18, x: 0, y: 10)
    }

    // MARK: - Progress (medium emphasis)

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack {
                StatusBadge(status: word.learningStatus)
                Spacer()
                Text("\(Int(word.confidenceScore * 100))%")
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(word.learningStatus.color)
            }
            ProgressView(value: word.confidenceScore)
                .tint(word.learningStatus.color)
        }
    }

    // MARK: - Statistics (lower emphasis)

    private var statisticsSection: some View {
        let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: Spacing.small) {
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
                .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(DesignColors.glassStroke, lineWidth: 1)
                )
        }
    }

    // MARK: - Related memories (special emphasis)

    private var relatedMemoriesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(DesignColors.accentPrimary)
                Text("Related Memories")
                    .font(Typography.sectionTitle)
                    .foregroundStyle(DesignColors.textPrimary)
            }

            Text("Where this word showed up in your life")
                .font(.subheadline)
                .foregroundStyle(DesignColors.textSecondary)

            if relatedEntries.isEmpty {
                Text("No linked journal entries yet.")
                    .font(.callout)
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: Spacing.xSmall) {
                    ForEach(relatedEntries) { entry in
                        MemoryRow(entry: entry) {
                            dismiss()
                            DispatchQueue.main.async {
                                onOpenEntry(entry.id, word.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .font(Typography.sectionTitle)
            .foregroundStyle(DesignColors.textPrimary)
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
                .font(Typography.caption)
                .foregroundStyle(DesignColors.textMuted)
            Text(value)
                .font(Typography.cardTitle)
                .foregroundStyle(DesignColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.small)
        .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(DesignColors.glassStroke, lineWidth: 1)
        )
    }
}

private struct MemoryRow: View {
    let entry: JournalEntryRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(DesignColors.accentPrimary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayTitle)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignColors.textPrimary)
                        .lineLimit(1)
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(DesignColors.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignColors.textMuted)
            }
            .padding(Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(DesignColors.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
