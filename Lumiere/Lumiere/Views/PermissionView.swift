//
//  PermissionView.swift
//  Lumiere
//

import SwiftUI
import UIKit

struct PermissionView: View {

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accentDim)
                    .frame(width: 78, height: 78)

                Image(systemName: "camera.aperture")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 8) {
                Text("需要相机权限")
                    .font(.rounded(16, weight: .semibold))
                    .foregroundStyle(Theme.primary)

                Text("Lumière 需要访问相机来取景与拍摄。\n照片只会保存在本机与你的相册。")
                    .font(.rounded(11, weight: .regular))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("前往系统设置")
                    .font(.rounded(12, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.primary))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(32)
    }
}
