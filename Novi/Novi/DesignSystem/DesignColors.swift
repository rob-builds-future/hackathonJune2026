//
//  DesignColors.swift
//  Novi
//
//  Central semantic color tokens for the Novi design system.
//

import SwiftUI

enum DesignColors {
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")

    static let surfacePrimary = Color("SurfacePrimary")
    static let surfaceSecondary = Color("SurfaceSecondary")
    static let surfaceElevated = Color("SurfaceElevated")
    static let surfaceInset = Color("SurfaceInset")

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textMuted = Color("TextMuted")

    static let accentPrimary = Color("AccentPrimary")
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let error = Color("Error")

    static let vocabularyAccent = Color("VocabularyAccent")
    static let grammarAccent = Color("GrammarAccent")
    static let challengeAccent = Color("ChallengeAccent")

    static let separator = Color("Separator")
    static let selection = Color("Selection")
    static let selectionText = Color("SelectionText")
    static let shadow = Color("Shadow")
    static let focusRing = Color("FocusRing")

    static let brandCoral = Color(red: 1.00, green: 0.45, blue: 0.42)
    static let brandTeal = Color(red: 0.16, green: 0.78, blue: 0.68)
    static let brandViolet = Color(red: 0.55, green: 0.36, blue: 1.00)
    static let brandGold = Color(red: 0.96, green: 0.68, blue: 0.24)
    static let glassStroke = Color.white.opacity(0.22)
    static let cardShadowStrong = Color.black.opacity(0.22)

    static let auroraBackground = LinearGradient(
        colors: [
            backgroundPrimary,
            brandViolet.opacity(0.14),
            brandTeal.opacity(0.10),
            backgroundPrimary
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarGradient = LinearGradient(
        colors: [
            brandViolet.opacity(0.24),
            backgroundSecondary,
            brandTeal.opacity(0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            surfaceElevated.opacity(0.96),
            brandViolet.opacity(0.10),
            brandTeal.opacity(0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [brandCoral, brandViolet, accentPrimary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let memoryGradient = LinearGradient(
        colors: [brandGold.opacity(0.22), brandCoral.opacity(0.18), brandViolet.opacity(0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
