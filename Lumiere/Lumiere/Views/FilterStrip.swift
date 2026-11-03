//
//  FilterStrip.swift
//  Lumiere
//

import SwiftUI

struct FilterStrip: View {
    let looks: [FilmLook]
    @Binding var selection: FilmLook

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(looks) { look in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = look
                        }
                        Haptics.selection()
                    } label: {
                        VStack(spacing: 7) {
                            swatch(for: look)
                            Text(look.name)
                                .font(.rounded(9, weight: .medium))
                                .foregroundStyle(isSelected(look) ? Theme.accent : Theme.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
        }
    }

    private func isSelected(_ look: FilmLook) -> Bool {
        look.id == selection.id
    }

    private func swatch(for look: FilmLook) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: look.swatch,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )

            if look.isIdentity {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.85))
            }

            if isSelected(look) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 1.6)
                    .frame(width: 66, height: 66)
            }
        }
        .frame(width: 66, height: 66)
    }
}
