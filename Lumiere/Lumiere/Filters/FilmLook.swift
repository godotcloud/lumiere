//
//  FilmLook.swift
//  Lumiere
//
//  A look is a small, declarative recipe. Everything the renderer needs to
//  reproduce a stock lives here — no LUT files, no per-device tuning.
//

import SwiftUI

/// Cubic polynomial applied per colour channel: `a·x³ + b·x² + c·x + d`.
///
/// This one primitive gives us shadow lift (`d`), channel gain (`c`) and
/// highlight roll-off (`b`, negative) — i.e. the three moves that make a
/// digital capture read as film.
struct ChannelCurve: Equatable {
    var a: CGFloat = 0
    var b: CGFloat = 0
    var c: CGFloat = 1
    var d: CGFloat = 0

    init(a: CGFloat = 0, b: CGFloat = 0, c: CGFloat = 1, d: CGFloat = 0) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }

    /// Convenience for authoring: lift the toe, set the gain, bend the shoulder.
    init(lift: CGFloat, gain: CGFloat, curve: CGFloat) {
        self.a = 0
        self.b = curve
        self.c = gain
        self.d = lift
    }
}

struct Tint: Equatable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat

    static let warmHighlights = Tint(r: 1.0, g: 0.62, b: 0.46)
    static let bloodRed = Tint(r: 1.0, g: 0.22, b: 0.16)
    static let neutral = Tint(r: 1, g: 1, b: 1)
}

struct FilmLook: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let swatch: [Color]

    var isIdentity: Bool = false

    var exposure: Float = 0
    var contrast: Float = 1
    var saturation: Float = 1

    var red = ChannelCurve()
    var green = ChannelCurve()
    var blue = ChannelCurve()

    /// Strength of the glow that bleeds out of clipped highlights.
    var halation: Float = 0
    var halationTint: Tint = .warmHighlights

    var grain: Float = 0
    var grainSize: CGFloat = 1
    var vignette: Float = 0
}
