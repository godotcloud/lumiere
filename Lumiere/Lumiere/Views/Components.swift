//
//  Components.swift
//  Lumiere
//
//  Shared bits of chrome: glass buttons, framing guides, the level line and
//  the shutter.
//

import SwiftUI

// MARK: - Buttons

struct GlassIconButton: View {
    let systemName: String
    var active: Bool = false
    var size: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(active ? Theme.accent : Theme.primary)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().strokeBorder(
                        Color.white.opacity(active ? 0.22 : 0.10),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(isBusy ? 0.35 : 0.95), lineWidth: 3)
                    .frame(width: 76, height: 76)

                Circle()
                    .fill(Color.white.opacity(isBusy ? 0.6 : 1))
                    .frame(width: 62, height: 62)

                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.black)
                }
            }
        }
        .buttonStyle(ShutterButtonStyle())
        .disabled(isBusy)
    }
}

struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Framing

struct GridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                for index in 1...2 {
                    let x = width * CGFloat(index) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))

                    let y = height * CGFloat(index) / 3
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

struct LevelIndicator: View {
    let roll: Double

    private var isLevel: Bool { abs(roll) < 1.2 }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isLevel ? Theme.accent : Color.white.opacity(0.55))
                .frame(width: 108, height: 1)
                .rotationEffect(.degrees(-roll))
                .opacity(isLevel ? 1 : 0.7)

            Rectangle()
                .fill(isLevel ? Theme.accent : Color.white.opacity(0.55))
                .frame(width: 1.5, height: 9)
        }
        .frame(height: 22)
        .animation(.easeOut(duration: 0.12), value: isLevel)
        .allowsHitTesting(false)
    }
}

// MARK: - Chips

struct PanelTab: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(isActive ? Theme.background : Theme.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? Theme.primary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ZoomChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.rounded(11, weight: .semibold))
                .foregroundStyle(isActive ? Theme.background : Theme.primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isActive ? Theme.primary : Color.black.opacity(0.35))
                )
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(isActive ? 0 : 0.14), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
