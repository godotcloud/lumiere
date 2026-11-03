//
//  FilmLibrary.swift
//  Lumiere
//
//  Seven stocks, hand-tuned. Values are deliberately restrained: a film look
//  should be felt, not seen.
//

import SwiftUI

enum FilmLibrary {

    static let original = FilmLook(
        id: "original",
        name: "原片",
        subtitle: "Neutral scan",
        swatch: [Color(hex: 0x3A3F45), Color(hex: 0x6E747C), Color(hex: 0xB9BEC4)],
        isIdentity: true
    )

    static let portra400 = FilmLook(
        id: "portra400",
        name: "Portra",
        subtitle: "Kodak · 400",
        swatch: [Color(hex: 0x7A5A45), Color(hex: 0xC9A183), Color(hex: 0xF1DFC9)],
        exposure: 0.15,
        contrast: 0.96,
        saturation: 0.94,
        red: ChannelCurve(lift: 0.020, gain: 1.035, curve: -0.030),
        green: ChannelCurve(lift: 0.012, gain: 1.000, curve: -0.022),
        blue: ChannelCurve(lift: 0.030, gain: 0.958, curve: -0.018),
        halation: 0.14,
        grain: 0.20,
        vignette: 0.22
    )

    static let cinestill800T = FilmLook(
        id: "cinestill800t",
        name: "CineStill",
        subtitle: "Tungsten · 800T",
        swatch: [Color(hex: 0x0F2E3A), Color(hex: 0x2C6E7A), Color(hex: 0xD8E3E0)],
        exposure: 0.08,
        contrast: 1.02,
        saturation: 1.02,
        red: ChannelCurve(lift: -0.008, gain: 1.030, curve: -0.045),
        green: ChannelCurve(lift: 0.006, gain: 0.985, curve: -0.035),
        blue: ChannelCurve(lift: 0.052, gain: 1.070, curve: -0.025),
        halation: 0.42,
        halationTint: .bloodRed,
        grain: 0.28,
        vignette: 0.28
    )

    static let gold200 = FilmLook(
        id: "gold200",
        name: "Gold",
        subtitle: "Kodak · 200",
        swatch: [Color(hex: 0x6B3F13), Color(hex: 0xC9903C), Color(hex: 0xF6E3B4)],
        exposure: 0.05,
        contrast: 1.06,
        saturation: 1.12,
        red: ChannelCurve(lift: 0.016, gain: 1.062, curve: -0.052),
        green: ChannelCurve(lift: 0.000, gain: 1.005, curve: -0.045),
        blue: ChannelCurve(lift: 0.010, gain: 0.918, curve: -0.048),
        halation: 0.16,
        grain: 0.24,
        vignette: 0.26
    )

    static let superia = FilmLook(
        id: "superia",
        name: "Superia",
        subtitle: "Fujifilm · 400",
        swatch: [Color(hex: 0x1F4A38), Color(hex: 0x5E9070), Color(hex: 0xE2EADC)],
        exposure: 0.00,
        contrast: 1.04,
        saturation: 1.05,
        red: ChannelCurve(lift: -0.004, gain: 0.978, curve: -0.040),
        green: ChannelCurve(lift: 0.020, gain: 1.024, curve: -0.050),
        blue: ChannelCurve(lift: 0.032, gain: 1.018, curve: -0.030),
        halation: 0.10,
        halationTint: Tint(r: 0.78, g: 1.0, b: 0.84),
        grain: 0.26,
        vignette: 0.28
    )

    static let velvia = FilmLook(
        id: "velvia",
        name: "Velvia",
        subtitle: "Fujifilm · 50",
        swatch: [Color(hex: 0x4A1230), Color(hex: 0x9E2A55), Color(hex: 0xF0C7A0)],
        exposure: -0.05,
        contrast: 1.12,
        saturation: 1.24,
        red: ChannelCurve(lift: -0.010, gain: 1.080, curve: -0.060),
        green: ChannelCurve(lift: -0.010, gain: 1.020, curve: -0.060),
        blue: ChannelCurve(lift: 0.000, gain: 0.980, curve: -0.070),
        halation: 0.08,
        grain: 0.10,
        vignette: 0.20
    )

    static let hp5 = FilmLook(
        id: "hp5",
        name: "HP5",
        subtitle: "Ilford · 400",
        swatch: [Color(hex: 0x101010), Color(hex: 0x5C5C5C), Color(hex: 0xE8E6E1)],
        exposure: 0.06,
        contrast: 1.14,
        saturation: 0,
        red: ChannelCurve(lift: 0.000, gain: 1.020, curve: -0.075),
        green: ChannelCurve(lift: 0.000, gain: 1.020, curve: -0.075),
        blue: ChannelCurve(lift: -0.010, gain: 0.985, curve: -0.065),
        halation: 0.00,
        grain: 0.42,
        grainSize: 1.15,
        vignette: 0.32
    )

    static let looks: [FilmLook] = [
        original,
        portra400,
        cinestill800T,
        gold200,
        superia,
        velvia,
        hp5
    ]

    static func look(withID id: String) -> FilmLook {
        looks.first(where: { $0.id == id }) ?? original
    }
}
