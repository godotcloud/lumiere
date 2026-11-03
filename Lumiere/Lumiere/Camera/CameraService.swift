//
//  CameraService.swift
//  Lumiere
//
//  Owns the AVCaptureSession and exposes a small, typed surface for manual
//  control. Nothing in here knows about SwiftUI.
//

import AVFoundation
import UIKit

enum FlashMode: String, CaseIterable, Identifiable {
    case off, auto, on

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .off: return "bolt.slash"
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        }
    }

    var label: String {
        switch self {
        case .off: return "关闭"
        case .auto: return "自动"
        case .on: return "开启"
        }
    }

    var deviceMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .auto: return .auto
        case .on: return .on
        }
    }

    var next: FlashMode {
        switch self {
        case .off: return .auto
        case .auto: return .on
        case .on: return .off
        }
    }
}

struct ManualCapabilities: Equatable {
    var minISO: Float = 34
    var maxISO: Float = 1600
    var minShutter: Double = 1.0 / 8000
    var maxShutter: Double = 0.5
    var minKelvin: Float = 2000
    var maxKelvin: Float = 8000
    var maxZoom: CGFloat = 6
    var hasUltraWide = false
}

final class CameraService: NSObject {

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "app.lumiere.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    private weak var previewSink: AVCaptureVideoDataOutputSampleBufferDelegate?
    private var processors: [Int64: PhotoCaptureProcessor] = [:]
    private var isConfigured = false

    private(set) var device: AVCaptureDevice?

    var isFrontCamera: Bool { device?.position == .front }

    // MARK: - Wiring

    /// The preview view calls this as soon as it exists. Order of attachment
    /// relative to `configure` does not matter.
    func attachPreview(_ sink: AVCaptureVideoDataOutputSampleBufferDelegate) {
        previewSink = sink
        if session.outputs.contains(videoOutput) {
            videoOutput.setSampleBufferDelegate(sink, queue: .main)
        }
    }

    func configure(position: AVCaptureDevice.Position) -> Bool {
        if isConfigured { return true }
        guard let device = Self.device(for: position) else { return false }

        session.beginConfiguration()
        session.sessionPreset = .photo

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return false
            }
            session.addInput(input)
        } catch {
            session.commitConfiguration()
            return false
        }

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            session.addOutput(videoOutput)
            if let sink = previewSink {
                videoOutput.setSampleBufferDelegate(sink, queue: .main)
            }
        }

        session.commitConfiguration()

        self.device = device
        isConfigured = true
        return true
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func switchCamera(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self,
                  let currentInput = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first
            else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let target: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            guard let newDevice = Self.device(for: target),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice)
            else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)

            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.device = newDevice
            } else {
                self.session.addInput(currentInput)
            }

            self.session.commitConfiguration()
            DispatchQueue.main.async { completion(true) }
        }
    }

    // MARK: - Capture

    func capture(flash: FlashMode, completion: @escaping (Data?) -> Void) {
        guard let device else {
            completion(nil)
            return
        }

        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.photoQualityPrioritization = .quality

        if device.hasFlash, device.isFlashModeSupported(flash.deviceMode) {
            settings.flashMode = flash.deviceMode
        }

        let identifier = settings.uniqueID
        let processor = PhotoCaptureProcessor { [weak self] data in
            self?.processors.removeValue(forKey: identifier)
            completion(data)
        }
        processors[identifier] = processor
        photoOutput.capturePhoto(with: settings, delegate: processor)
    }

    // MARK: - Manual control

    func focus(at point: CGPoint, autoExpose: Bool) {
        guard let device else { return }
        do { try device.lockForConfiguration() } catch { return }
        defer { device.unlockForConfiguration() }

        if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
        }

        if autoExpose,
           device.isExposurePointOfInterestSupported,
           device.isExposureModeSupported(.autoExpose) {
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
        }
    }

    func setExposure(iso: Float?, duration: Double?) {
        guard let device else { return }
        do { try device.lockForConfiguration() } catch { return }
        defer { device.unlockForConfiguration() }

        guard device.isExposureModeSupported(.custom) else { return }
        let format = device.activeFormat

        let targetISO = min(max(iso ?? device.iso, format.minISO), format.maxISO)

        var seconds = duration ?? device.exposureDuration.seconds
        let minSeconds = format.minExposureDuration.seconds
        let maxSeconds = format.maxExposureDuration.seconds
        seconds = min(max(seconds, minSeconds), maxSeconds)

        let targetDuration = CMTime(seconds: seconds, preferredTimescale: 1_000_000)
        device.setExposureModeCustom(duration: targetDuration, iso: targetISO, completionHandler: nil)
    }

    func setWhiteBalance(kelvin: Float) {
        guard let device, device.isWhiteBalanceModeSupported(.locked) else { return }
        do { try device.lockForConfiguration() } catch { return }
        defer { device.unlockForConfiguration() }

        let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: kelvin, tint: 0)
        var gains = device.deviceWhiteBalanceGains(for: values)

        let ceiling = device.maxWhiteBalanceGain
        gains.redGain = min(max(gains.redGain, 1), ceiling)
        gains.greenGain = min(max(gains.greenGain, 1), ceiling)
        gains.blueGain = min(max(gains.blueGain, 1), ceiling)

        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
    }

    func setExposureBias(_ bias: Float) {
        guard let device else { return }
        do { try device.lockForConfiguration() } catch { return }
        defer { device.unlockForConfiguration() }
        let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
        device.setExposureTargetBias(clamped, completionHandler: nil)
    }

    func setZoom(_ factor: CGFloat, animated: Bool) {
        guard let device else { return }
        let upper = min(device.maxAvailableVideoZoomFactor, 8)
        let lower = max(device.minAvailableVideoZoomFactor, 0.5)
        let clamped = min(max(factor, lower), upper)

        do { try device.lockForConfiguration() } catch { return }
        defer { device.unlockForConfiguration() }

        if animated {
            device.ramp(toVideoZoomFactor: clamped, withRate: 10)
        } else {
            device.videoZoomFactor = clamped
        }
    }

    /// Freeze exposure and white balance at their current values so the dials
    /// take over without a visible jump.
    func enterManualMode() {
        guard let device else { return }
        do { try device.lockForConfiguration() } catch { return }
        defer { device.unlockForConfiguration() }

        if device.isExposureModeSupported(.custom) {
            let format = device.activeFormat
            let iso = min(max(device.iso, format.minISO), format.maxISO)
            let seconds = min(
                max(device.exposureDuration.seconds, format.minExposureDuration.seconds),
                format.maxExposureDuration.seconds
            )
            device.setExposureModeCustom(
                duration: CMTime(seconds: seconds, preferredTimescale: 1_000_000),
                iso: iso,
                completionHandler: nil
            )
        }

        if device.isWhiteBalanceModeSupported(.locked) {
            device.whiteBalanceMode = .locked
        }
    }

    func restoreAutoMode() {
        guard let device else { return }
        do { try device.lockForConfiguration() } catch { return }
        defer { device.unlockForConfiguration() }

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        device.setExposureTargetBias(0, completionHandler: nil)
    }

    // MARK: - Capabilities

    var capabilities: ManualCapabilities {
        guard let device else { return ManualCapabilities() }
        let format = device.activeFormat

        var caps = ManualCapabilities()
        caps.minISO = format.minISO
        caps.maxISO = max(format.maxISO, format.minISO + 1)
        caps.minShutter = max(format.minExposureDuration.seconds, 1.0 / 8000)
        caps.maxShutter = max(min(format.maxExposureDuration.seconds, 1.0), caps.minShutter * 2)
        caps.maxZoom = min(device.maxAvailableVideoZoomFactor, 8)
        caps.hasUltraWide = device.minAvailableVideoZoomFactor < 0.99
        return caps
    }

    private static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
    }
}

// MARK: - Photo delegate

final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {

    private let completion: (Data?) -> Void
    private var payload: Data?

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        payload = photo.fileDataRepresentation()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        let data = payload
        DispatchQueue.main.async { [completion] in
            completion(data)
        }
    }
}
