//
//  LessonSectionView.swift
//  Novi
//
//  Small reusable building blocks for displaying a lesson.
//

import SwiftUI

/// A titled container for one section of the lesson output.
///
/// Generic over its content so every output section (translation, grammar,
/// challenge, …) shares the same look without duplicating layout code.
struct LessonSectionView<Content: View>: View {
    let title: String
    var icon: String?
    var accent: Color = DesignColors.accentPrimary
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
                Text(title)
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(DesignColors.textPrimary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.small)
        .background(DesignColors.cardGradient, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [accent, DesignColors.brandCoral.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.vertical, Spacing.small)
        }
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(DesignColors.glassStroke, lineWidth: 1)
        )
        .shadow(color: DesignColors.shadow, radius: 14, x: 0, y: 8)
    }
}

/// Displays a single vocabulary item: term, translation and optional example.
struct VocabularyRow: View {
    let item: VocabularyItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(item.term).fontWeight(.semibold)
                    .foregroundStyle(DesignColors.textPrimary)
                Text("—")
                    .foregroundStyle(DesignColors.textMuted)
                Text(item.translation).foregroundStyle(DesignColors.textSecondary)
            }
            .font(Typography.body)
            if let example = item.example {
                Text(example)
                    .font(Typography.caption)
                    .italic()
                    .foregroundStyle(DesignColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
