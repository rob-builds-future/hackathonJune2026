//
//  Typography.swift
//  Novi
//
//  Central typography scale for the Novi design system.
//

import SwiftUI

enum Typography {
    static let hero = Font.system(size: 34, weight: .bold, design: .default)
    static let title = Font.system(size: 24, weight: .semibold, design: .default)
    static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .default)
    static let cardTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyEmphasized = Font.system(size: 15, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let metadata = Font.system(size: 11, weight: .regular, design: .default)
}
