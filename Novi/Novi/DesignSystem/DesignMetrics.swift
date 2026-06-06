//
//  DesignMetrics.swift
//  Novi
//
//  Shared spacing, radius, and motion constants for the Novi design system.
//

import Foundation

enum Spacing {
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 32
    static let xLarge: CGFloat = 48
    static let xxLarge: CGFloat = 64
}

enum CornerRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

enum AnimationDuration {
    static let fast: TimeInterval = 0.15
    static let standard: TimeInterval = 0.25
    static let slow: TimeInterval = 0.40
}
