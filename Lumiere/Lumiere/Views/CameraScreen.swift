//
//  CameraScreen.swift
//  Lumiere
//
//  The viewfinder. Everything is layered over a single full-bleed preview so
//  the photograph is never framed inside a box.
//

import SwiftUI

struct CameraScreen: View {

    @ObservedObject var store: CaptureStore
    @ObservedObject private var settings = AppSettings.shared

    @StateObject private var model: CameraViewModel
    @StateObject private var level = MotionLevel()

    @State private var showGallery = false
    @State private var showSettings = false
    @State private var flashOpacity: Double = 0
    @Environment(\.scenePhase) private var scenePhase

    init(store: CaptureStore) {
        self._store = ObservedObject(wrappedValue: store)
        _model = StateObject(wrappedValue: CameraViewModel(store: store))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            preview
                .ignoresSafeArea()

            if settings.showGrid {
                GridOverlay()
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                Spacer(minLength: 0)

                if settings.showLevel {
                    LevelIndicator(roll: level.roll)
                        .padding(.bottom, 14)
                }

                zoomRow
                    .padding(.bottom, 12)

                bottomPanel
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if let toast = model.toast {
                toastView(toast)
            }

            if let error = model.cameraError {
                errorView(error)
            }
        }
        .task {
            model.start()
            level.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.start()
                level.start()
            case .inactive, .background:
                model.stop()
                level.stop()
            @unknown default:
                break
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView(store: store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
    }

    // MARK: - Viewfinder

    private var preview: some View {
        CameraPreview(
            camera: model.camera,
            look: model.look,
            mirrored: settings.mirrorFrontCamera && model.isFrontCamera,
            isFront: model.isFrontCamera,
            onFocus: { point in model.focus(at: point) },
            onPinchBegan: { model.beginPinch() },
            onPinch: { scale in model.updatePinch(scale) },
            onPinchEnded: { model.endPinch() }
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            GlassIconButton(
                systemName: model.flash.symbolName,
                active: model.flash != .off
            ) {
                model.cycleFlash()
            }

            Spacer()

            VStack(spacing: 3) {
                Text("LUMIÈRE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(Theme.primary)

                Text(model.look.subtitle.uppercased())
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Theme.accent.opacity(0.9))
            }

            Spacer()

            HStack(spacing: 9) {
                GlassIconButton(
                    systemName: "square.grid.3x3",
                    active: settings.showGrid
                ) {
                    settings.showGrid.toggle()
                }

                GlassIconButton(
                    systemName: "level",
                    active: settings.showLevel
                ) {
                    settings.showLevel.toggle()
                }

                GlassIconButton(systemName: "slider.horizontal.3") {
                    showSettings = true
                }
            }
        }
    }

    // MARK: - Zoom

    private var zoomRow: some View {
        HStack(spacing: 10) {
            ForEach(model.zoomPresets, id: \.self) { preset in
                ZoomChip(
                    label: zoomLabel(preset),
                    isActive: abs(model.zoom - preset) < 0.08
                ) {
                    model.setZoom(preset)
                }
            }
        }
    }

    private func zoomLabel(_ value: CGFloat) -> String {
        if value < 1 { return String(format: "%.1f×", value) }
        return "\(Int(value))×"
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 3) {
                PanelTab(title: "滤镜", isActive: model.panel == .filters) {
                    model.selectPanel(.filters)
                }
                PanelTab(title: "手动", isActive: model.panel == .manual) {
                    model.selectPanel(.manual)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.06)))

            Group {
                switch model.panel {
                case .filters:
                    FilterStrip(looks: FilmLibrary.looks, selection: $model.look)
                case .manual:
                    ManualPanel(model: model)
                }
            }
            .frame(height: model.panel == .manual ? 196 : 88)

            captureRow
                .padding(.bottom, 4)
        }
        .padding(.top, 14)
        .padding(.bottom, 14)
        .glassPanel()
    }

    private var captureRow: some View {
        HStack {
            galleryButton
                .frame(width: 56, alignment: .leading)

            Spacer()

            ShutterButton(isBusy: model.isCapturing) {
                capture()
            }

            Spacer()

            GlassIconButton(
                systemName: "arrow.triangle.2.circlepath.camera",
                size: 44
            ) {
                model.switchCamera()
            }
            .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 20)
    }

    private var galleryButton: some View {
        Button {
            showGallery = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)

                if let thumbnail = model.lastAsset?.thumbnail ?? store.photos.first?.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overlays

    private func toastView(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.rounded(11, weight: .medium))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
                .padding(.top, 76)

            Spacer()
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.secondary)

            Text(message)
                .font(.rounded(12, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Actions

    private func capture() {
        model.capture()
        flashOpacity = 0.85
        withAnimation(.easeOut(duration: 0.3)) {
            flashOpacity = 0
        }
    }
}
