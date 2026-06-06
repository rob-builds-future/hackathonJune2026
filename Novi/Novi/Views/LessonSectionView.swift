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
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Displays a single vocabulary item: term, translation and optional example.
struct VocabularyRow: View {
    let item: VocabularyItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(item.term).fontWeight(.semibold)
                Text("—")
                Text(item.translation).foregroundStyle(.secondary)
            }
            if let example = item.example {
                Text(example)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
