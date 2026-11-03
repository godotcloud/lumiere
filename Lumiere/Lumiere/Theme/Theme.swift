//
//  Theme.swift
//  Lumiere
//
//  Design tokens: a dark, warm, editorial palette built around a single
//  amber accent so the interface never competes with the photograph.
//

import SwiftUI

enum Theme {
    static let background = Color(hex: 0x08080A)
    static let surface = Color(hex: 0x141417)
    static let surfaceRaised = Color(hex: 0x1E1E23)

    static let hairline = Color.white.opacity(0.09)

    static let primary = Color.white.opacity(0.95)
    static let secondary = Color.white.opacity(0.52)
    static let tertiary = Color.white.opacity(0.28)

    static let accent = Color(hex: 0xE7B563)
    static let accentDim = Color(hex: 0xE7B563).opacity(0.18)

    static let danger = Color(hex: 0xE06C5A)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// Frosted, hairline-bordered container used by the control surfaces.
    func glassPanel(cornerRadius: CGFloat = 26) -> some View {
        self
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}
