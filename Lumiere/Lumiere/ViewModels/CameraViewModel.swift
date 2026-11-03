//
//  CameraViewModel.swift
//  Lumiere
//
//  All mutable camera UI state lives here. The view stays declarative; the
//  service stays dumb.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

enum CapturePanel {
    case filters
    case manual
}

final class CameraViewModel: ObservableObject {

    let camera = CameraService()
    private let store: CaptureStore

    // Look & panel
    @Published var look: FilmLook = FilmLibrary.original
    @Published var panel: CapturePanel = .filters

    // Capture
    @Published var flash: FlashMode = .off
    @Published var isCapturing = false
    @Published var lastAsset: PhotoAsset?

    // Session
    @Published var isReady = false
    @Published var cameraError: String?
    @Published var isFrontCamera = false
    @Published var capabilities = ManualCapabilities()

    // zoom
    @Published var zoom: CGFloat = 1
    private var pinchAnchor: CGFloat = 1

    // Manual exposure
    @Published var iso: Float = 100
    @Published var shutterSeconds: Double = 1.0 / 120
    @Published var kelvin: Float = 5200
    @Published var exposureBias: Float = 0

    // Overlays
    @Published var toast: String?

    init(store: CaptureStore) {
        self.store = store
    }

    // MARK: - Session

    func start() {
        if !isReady {
            guard camera.configure(position: isFrontCamera ? .front : .back) else {
                cameraError = "无法启动相机。请改用真机运行，或检查相机权限。"
                return
            }
            isReady = true
            refreshCapabilities()
        }
        camera.start()
    }

    func stop() {
        camera.stop()
    }

    private func refreshCapabilities() {
        capabilities = camera.capabilities
        guard let device = camera.device else { return }

        let deviceISO = device.iso > 0 ? device.iso : capabilities.minISO
        iso = min(max(deviceISO, capabilities.minISO), capabilities.maxISO)

        let seconds = device.exposureDuration.seconds
        if seconds.isFinite, seconds > 0 {
            shutterSeconds = min(max(seconds, capabilities.minShutter), capabilities.maxShutter)
        }

        let gains = device.deviceWhiteBalanceGains
        let values = device.temperatureAndTintValues(for: gains)
        if values.temperature.isFinite, values.temperature > 0 {
            kelvin = min(max(values.temperature, capabilities.minKelvin), capabilities.maxKelvin)
        }
    }

    func cycleFlash() {
        flash = flash.next
        Haptics.selection()
    }

    func switchCamera() {
        camera.switchCamera { [weak self] success in
            guard let self, success else { return }
            self.isFrontCamera = self.camera.isFrontCamera
            self.zoom = 1
            self.camera.setZoom(1, animated: false)
            self.refreshCapabilities()
        }
    }

    // MARK: - Zoom

    var zoomPresets: [CGFloat] {
        var presets: [CGFloat] = []
        if capabilities.hasUltraWide { presets.append(0.5) }
        presets.append(1)
        if capabilities.maxZoom >= 2 { presets.append(2) }
        if capabilities.maxZoom >= 3 { presets.append(3) }
        return presets
    }

    func setZoom(_ value: CGFloat, animated: Bool = true) {
        let upper = max(capabilities.maxZoom, 1)
        let clamped = min(max(value, capabilities.hasUltraWide ? 0.5 : 1), upper)
        zoom = clamped
        camera.setZoom(clamped, animated: animated)
    }

    func beginPinch() {
        pinchAnchor = zoom
    }

    func updatePinch(_ scale: CGFloat) {
        setZoom(pinchAnchor * scale, animated: false)
    }

    func endPinch() {
        pinchAnchor = zoom
    }

    // MARK: - Focus

    func focus(at devicePoint: CGPoint) {
        camera.focus(at: devicePoint, autoExpose: panel != .manual)
        Haptics.selection()
    }

    // MARK: - Panel

    func selectPanel(_ newPanel: CapturePanel) {
        guard newPanel != panel else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            panel = newPanel
        }
        Haptics.selection()

        if newPanel == .manual {
            camera.enterManualMode()
            refreshCapabilities()
        } else {
            camera.restoreAutoMode()
        }
    }

    // MARK: - Manual exposure

    var isoRange: ClosedRange<Double> {
        let lower = Double(capabilities.minISO)
        let upper = Double(max(capabilities.maxISO, capabilities.minISO + 1))
        return lower...upper
    }

    var isoSliderValue: Double {
        get { Double(iso) }
        set { setISO(Float(newValue)) }
    }

    func setISO(_ value: Float) {
        iso = min(max(value, capabilities.minISO), capabilities.maxISO)
        guard panel == .manual else { return }
        camera.setExposure(iso: iso, duration: nil)
    }

    var shutterNormalized: Double {
        let lower = log(max(capabilities.minShutter, 1.0 / 20000))
        let upper = log(max(capabilities.maxShutter, capabilities.minShutter * 2))
        guard upper > lower, shutterSeconds > 0 else { return 0 }
        return min(max((log(shutterSeconds) - lower) / (upper - lower), 0), 1)
    }

    func setShutterNormalized(_ value: Double) {
        let lower = log(max(capabilities.minShutter, 1.0 / 20000))
        let upper = log(max(capabilities.maxShutter, capabilities.minShutter * 2))
        let seconds = exp(lower + (upper - lower) * min(max(value, 0), 1))
        shutterSeconds = min(max(seconds, capabilities.minShutter), capabilities.maxShutter)
        guard panel == .manual else { return }
        camera.setExposure(iso: nil, duration: shutterSeconds)
    }

    var shutterLabel: String {
        guard shutterSeconds > 0 else { return "—" }
        if shutterSeconds >= 0.35 {
            return String(format: "%.1fs", shutterSeconds)
        }
        return "1/\(Int((1 / shutterSeconds).rounded()))"
    }

    var kelvinRange: ClosedRange<Double> {
        let lower = Double(capabilities.minKelvin)
        let upper = Double(max(capabilities.maxKelvin, capabilities.minKelvin + 500))
        return lower...upper
    }

    var kelvinSliderValue: Double {
        get { Double(kelvin) }
        set { setKelvin(Float(newValue)) }
    }

    func setKelvin(_ value: Float) {
        kelvin = min(max(value, capabilities.minKelvin), capabilities.maxKelvin)
        guard panel == .manual else { return }
        camera.setWhiteBalance(kelvin: kelvin)
    }

    func resetToAuto() {
        camera.restoreAutoMode()
        refreshCapabilities()
        exposureBias = 0
        withAnimation { panel = .filters }
        showToast("已恢复自动曝光")
    }

    // MARK: - Capture

    func capture() {
        guard isReady, !isCapturing else { return }
        isCapturing = true
        Haptics.shutter()

        camera.capture(flash: flash) { [weak self] data in
            guard let self else { return }
            guard let data else {
                self.isCapturing = false
                self.showToast("拍摄失败，请重试")
                return
            }

            let look = self.look
            let shouldSave = AppSettings.shared.saveToLibrary

            DispatchQueue.global(qos: .userInitiated).async {
                let thumbnail = PhotoPipeline.image(from: data, look: look, maxDimension: 420)
                let rendered = shouldSave ? PhotoPipeline.renderJPEG(from: data, look: look) : nil

                DispatchQueue.main.async {
                    let asset = self.store.add(originalData: data, look: look, thumbnail: thumbnail)
                    self.lastAsset = asset
                    self.isCapturing = false

                    if let rendered {
                        PhotoLibrary.save(rendered)
                    }
                }
            }
        }
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.toast == message else { return }
            withAnimation(.easeIn(duration: 0.25)) { self.toast = nil }
        }
    }
}
