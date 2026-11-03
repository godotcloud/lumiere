//
//  RootView.swift
//  Lumiere
//
//  Camera permission gate. Nothing is shown until we know whether the session
//  can actually run.
//

import AVFoundation
import SwiftUI

enum CameraPermission {
    case checking
    case granted
    case denied
}

struct RootView: View {

    @StateObject private var store = CaptureStore()
    @State private var permission: CameraPermission = .checking

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch permission {
            case .checking:
                ProgressView()
                    .tint(Theme.accent)
            case .granted:
                CameraScreen(store: store)
            case .denied:
                PermissionView()
            }
        }
        .statusBarHidden(permission != .denied)
        .task {
            await requestCameraAccess()
        }
    }

    private func requestCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .granted
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            permission = granted ? .granted : .denied
        default:
            permission = .denied
        }
    }
}
