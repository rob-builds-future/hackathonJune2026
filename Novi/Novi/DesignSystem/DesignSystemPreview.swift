//
//  DesignSystemPreview.swift
//  Novi
//
//  Development-only preview surface for Novi design tokens.
//

import SwiftUI

struct DesignSystemPreview: View {
    private let colorTokens: [(String, Color)] = [
        ("backgroundPrimary", DesignColors.backgroundPrimary),
        ("backgroundSecondary", DesignColors.backgroundSecondary),
        ("surfacePrimary", DesignColors.surfacePrimary),
        ("surfaceSecondary", DesignColors.surfaceSecondary),
        ("textPrimary", DesignColors.textPrimary),
        ("textSecondary", DesignColors.textSecondary),
        ("textMuted", DesignColors.textMuted),
        ("accentPrimary", DesignColors.accentPrimary),
        ("success", DesignColors.success),
        ("warning", DesignColors.warning),
        ("error", DesignColors.error),
        ("vocabularyAccent", DesignColors.vocabularyAccent),
        ("grammarAccent", DesignColors.grammarAccent),
        ("challengeAccent", DesignColors.challengeAccent),
        ("separator", DesignColors.separator)
    ]

    private let typographyTokens: [(String, Font)] = [
        ("Hero", Typography.hero),
        ("Title", Typography.title),
        ("Section Title", Typography.sectionTitle),
        ("Card Title", Typography.cardTitle),
        ("Body", Typography.body),
        ("Body Emphasized", Typography.bodyEmphasized),
        ("Caption", Typography.caption),
        ("Metadata", Typography.metadata)
    ]

    private let spacingTokens: [(String, CGFloat)] = [
        ("8", Spacing.xSmall),
        ("16", Spacing.small),
        ("24", Spacing.medium),
        ("32", Spacing.large),
        ("48", Spacing.xLarge),
        ("64", Spacing.xxLarge)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                section("Colors") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: Spacing.small)], spacing: Spacing.small) {
                        ForEach(colorTokens, id: \.0) { name, color in
                            ColorTokenCard(name: name, color: color)
                        }
                    }
                }

                section("Typography") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        ForEach(typographyTokens, id: \.0) { name, font in
                            Text(name)
                                .font(font)
                                .foregroundStyle(DesignColors.textPrimary)
                        }
                    }
                }

                section("Spacing") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        ForEach(spacingTokens, id: \.0) { name, value in
                            HStack(spacing: Spacing.small) {
                                Text(name)
                                    .font(Typography.metadata)
                                    .foregroundStyle(DesignColors.textMuted)
                                    .frame(width: 28, alignment: .leading)

                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .fill(DesignColors.accentPrimary)
                                    .frame(width: value, height: Spacing.xSmall)
                            }
                        }
                    }
                }

                section("Radius") {
                    HStack(spacing: Spacing.small) {
                        RadiusTokenCard(name: "Small", radius: CornerRadius.small)
                        RadiusTokenCard(name: "Medium", radius: CornerRadius.medium)
                        RadiusTokenCard(name: "Large", radius: CornerRadius.large)
                    }
                }
            }
            .padding(Spacing.large)
        }
        .background(DesignColors.backgroundPrimary)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(Typography.sectionTitle)
                .foregroundStyle(DesignColors.textPrimary)
            content()
        }
    }
}

private struct ColorTokenCard: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(color)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(DesignColors.separator, lineWidth: 1)
                )

            Text(name)
                .font(Typography.caption)
                .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(Spacing.small)
        .background(DesignColors.surfacePrimary, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

private struct RadiusTokenCard: View {
    let name: String
    let radius: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            RoundedRectangle(cornerRadius: radius)
                .fill(DesignColors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(DesignColors.accentPrimary, lineWidth: 1)
                )
                .frame(width: 96, height: 64)

            Text(name)
                .font(Typography.caption)
                .foregroundStyle(DesignColors.textSecondary)
        }
    }
}

struct DesignSystemPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DesignSystemPreview()
                .preferredColorScheme(.light)
                .previewDisplayName("Design System - Light")

            DesignSystemPreview()
                .preferredColorScheme(.dark)
                .previewDisplayName("Design System - Dark")
        }
        .frame(width: 900, height: 900)
    }
}
