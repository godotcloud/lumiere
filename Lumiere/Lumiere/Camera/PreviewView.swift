//
//  PreviewView.swift
//  Lumiere
//
//  Metal-backed viewfinder. Video frames arrive as CVPixelBuffers, get graded
//  by FilmEngine, and are blitted straight into the drawable — 30 fps of live
//  film emulation with no detour through UIImage.
//

import AVFoundation
import MetalKit
import SwiftUI
import UIKit

final class PreviewView: MTKView, AVCaptureVideoDataOutputSampleBufferDelegate {

    // Written on the main thread only: the sample-buffer delegate queue is main.
    var look: FilmLook = FilmLibrary.original
    var mirrored = false
    var isFront = false

    var onFocusPoint: ((CGPoint) -> Void)?
    var onPinchBegan: (() -> Void)?
    var onPinch: ((CGFloat) -> Void)?
    var onPinchEnded: (() -> Void)?

    private let ciContext: CIContext
    private let commandQueue: MTLCommandQueue?
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)

    /// Geometry of the last rendered frame, kept so a tap can be mapped back
    /// into sensor coordinates.
    private var display: (size: CGSize, scale: CGFloat, origin: CGPoint)?

    private var focusLayer: CAShapeLayer?

    // MARK: - Lifecycle

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        let metalDevice = device ?? MTLCreateSystemDefaultDevice()
        if let metalDevice {
            ciContext = CIContext(mtlDevice: metalDevice, options: [.cacheIntermediates: false])
        } else {
            ciContext = CIContext(options: [.cacheIntermediates: false])
        }
        commandQueue = metalDevice?.makeCommandQueue()

        super.init(frame: frameRect, device: metalDevice)

        colorPixelFormat = .bgra8Unorm
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = false
        autoResizeDrawable = true
        isOpaque = true
        backgroundColor = .black
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Frame rendering

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let drawable = currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer()
        else { return }

        let bounds = self.bounds
        guard bounds.width > 1, bounds.height > 1 else { return }

        var image = CIImage(cvPixelBuffer: pixelBuffer)

        // The sensor delivers landscape buffers; rotate to portrait.
        image = image.oriented(isFront ? .left : .right)

        if mirrored {
            let width = image.extent.width
            image = image.transformed(
                by: CGAffineTransform(scaleX: -1, y: 1)
                    .concatenating(CGAffineTransform(translationX: width, y: 0))
            )
        }

        // Grade a downscaled copy: the viewfinder only needs screen resolution,
        // and this keeps the filter graph cheap enough for 30 fps.
        let sourceExtent = image.extent
        let longest = max(sourceExtent.width, sourceExtent.height)
        let processingScale = longest > 1440 ? 1440 / longest : 1
        if processingScale < 1 {
            image = image.transformed(by: CGAffineTransform(scaleX: processingScale, y: processingScale))
        }

        let processed = FilmEngine.shared.apply(look, to: image)

        // Aspect-fill into the drawable.
        let target = CGSize(width: CGFloat(drawable.texture.width), height: CGFloat(drawable.texture.height))
        guard target.width > 0, target.height > 0 else { return }

        let extent = processed.extent
        let fill = max(bounds.width / extent.width, bounds.height / extent.height)
        let offsetX = (bounds.width - extent.width * fill) / 2
        let offsetY = (bounds.height - extent.height * fill) / 2

        let pointScale = bounds.width > 0 ? target.width / bounds.width : 1
        let transform = CGAffineTransform(scaleX: fill * pointScale, y: fill * pointScale)
            .concatenating(
                CGAffineTransform(
                    translationX: (offsetX * pointScale) - extent.minX * fill * pointScale,
                    y: (offsetY * pointScale) - extent.minY * fill * pointScale
                )
            )

        let positioned = processed.transformed(by: transform)
        let canvas = CGRect(origin: .zero, size: target)
        let clipped = positioned.cropped(to: canvas)

        display = (extent.size, fill, CGPoint(x: offsetX, y: offsetY))

        ciContext.render(
            clipped,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: canvas,
            colorSpace: colorSpace ?? CGColorSpaceCreateDeviceRGB()
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Gestures

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        showReticle(at: location)
        guard let point = devicePoint(for: location) else { return }
        onFocusPoint?(point)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            onPinchBegan?()
        case .changed:
            onPinch?(recognizer.scale)
        case .ended, .cancelled, .failed:
            onPinchEnded?()
        default:
            break
        }
    }

    /// Maps a touch in view coordinates to normalised sensor coordinates.
    private func devicePoint(for location: CGPoint) -> CGPoint? {
        guard let display, display.size.width > 0, display.size.height > 0 else { return nil }

        let x = (location.x - display.origin.x) / display.scale
        let y = (location.y - display.origin.y) / display.scale

        var u = min(max(x / display.size.width, 0), 1)
        let v = min(max(y / display.size.height, 0), 1)
        if mirrored { u = 1 - u }

        // Undo the 90° rotation that produced the portrait image.
        return CGPoint(x: v, y: 1 - u)
    }

    private func showReticle(at point: CGPoint) {
        focusLayer?.removeFromSuperlayer()

        let side: CGFloat = 74
        let rect = CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)

        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor(red: 0.906, green: 0.71, blue: 0.388, alpha: 1).cgColor
        layer.lineWidth = 1.2
        self.layer.addSublayer(layer)
        focusLayer = layer

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.45
        scale.toValue = 1.0
        scale.duration = 0.28
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.beginTime = CACurrentMediaTime() + 0.75
        fade.duration = 0.45
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        layer.add(scale, forKey: "pop")
        layer.add(fade, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak layer] in
            layer?.removeFromSuperlayer()
        }
    }
}

// MARK: - SwiftUI bridge

struct CameraPreview: UIViewRepresentable {

    let camera: CameraService
    let look: FilmLook
    let mirrored: Bool
    let isFront: Bool
    let onFocus: (CGPoint) -> Void
    let onPinchBegan: () -> Void
    let onPinch: (CGFloat) -> Void
    let onPinchEnded: () -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.look = look
        view.mirrored = mirrored
        view.isFront = isFront
        view.onFocusPoint = onFocus
        view.onPinchBegan = onPinchBegan
        view.onPinch = onPinch
        view.onPinchEnded = onPinchEnded
        camera.attachPreview(view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.look = look
        uiView.mirrored = mirrored
        uiView.isFront = isFront
    }
}
