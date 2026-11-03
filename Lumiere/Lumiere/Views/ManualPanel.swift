//
//  ManualPanel.swift
//  Lumiere
//
//  Three dials, no menus. ISO, shutter and Kelvin — the only controls that
//  actually change a photograph.
//

import SwiftUI

struct ManualPanel: View {
    @ObservedObject var model: CameraViewModel

    var body: some View {
        VStack(spacing: 12) {
            control(
                title: "ISO",
                value: "\(Int(model.iso))",
                slider: Binding(
                    get: { model.isoSliderValue },
                    set: { model.isoSliderValue = $0 }
                ),
                range: model.isoRange
            )

            control(
                title: "快门",
                value: model.shutterLabel,
                slider: Binding(
                    get: { model.shutterNormalized },
                    set: { model.setShutterNormalized($0) }
                ),
                range: 0...1
            )

            control(
                title: "色温",
                value: "\(Int(model.kelvin))K",
                slider: Binding(
                    get: { model.kelvinSliderValue },
                    set: { model.kelvinSliderValue = $0 }
                ),
                range: model.kelvinRange
            )

            HStack {
                Text("锁定曝光后，画面不再随光线变化")
                    .font(.rounded(9, weight: .medium))
                    .foregroundStyle(Theme.tertiary)

                Spacer()

                Button {
                    model.resetToAuto()
                } label: {
                    Text("AUTO")
                        .font(.rounded(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accentDim))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func control(
        title: String,
        value: String,
        slider: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.rounded(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondary)

                Spacer()

                Text(value)
                    .font(.mono(12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }

            Slider(value: slider, in: range)
                .tint(Theme.accent)
                .controlSize(.small)
        }
    }
}
