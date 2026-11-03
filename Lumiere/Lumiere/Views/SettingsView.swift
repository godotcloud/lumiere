//
//  SettingsView.swift
//  Lumiere
//

import SwiftUI

struct SettingsView: View {

    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        group("拍摄") {
                            toggleRow("保存到系统相册", "square.and.arrow.down", $settings.saveToLibrary)
                            divider
                            toggleRow("前置镜头镜像", "flip.horizontal", $settings.mirrorFrontCamera)
                            divider
                            toggleRow("触感反馈", "hand.tap", $settings.haptics)
                        }

                        group("取景") {
                            toggleRow("三分构图网格", "square.grid.3x3", $settings.showGrid)
                            divider
                            toggleRow("水平仪", "level", $settings.showLevel)
                        }

                        footer
                    }
                    .padding(16)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.rounded(12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
            .padding(.leading, 34)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("LUMIÈRE  1.0")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(3)
                .foregroundStyle(Theme.tertiary)

            Text("七种胶片配方 · 手动曝光 · 非破坏性调色")
                .font(.rounded(10, weight: .regular))
                .foregroundStyle(Theme.tertiary.opacity(0.8))
        }
        .padding(.top, 6)
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.rounded(10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.tertiary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private func toggleRow(_ title: String, _ symbol: String, _ isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.secondary)
                .frame(width: 20)

            Text(title)
                .font(.rounded(12, weight: .medium))
                .foregroundStyle(Theme.primary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
