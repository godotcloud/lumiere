//
//  FilmEngine.swift
//  Lumiere
//
//  The renderer. One Core Image graph shared by the live viewfinder, the
//  gallery thumbnails and the full-resolution export, so what you see is
//  exactly what you get.
//

import CoreImage
import Metal
import UIKit

final class FilmEngine {

    static let shared = FilmEngine()

    let context: CIContext

    /// A fixed tile of monochrome noise, reused for every frame. Regenerating
    /// noise per frame would cost more than the entire colour grade.
    private let noiseTile: CIImage

    private init() {
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        } else {
            context = CIContext(options: [.cacheIntermediates: false])
        }

        let random = CIFilter(name: "CIRandomGenerator")?.outputImage
            ?? CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        noiseTile = random.cropped(to: CGRect(x: 0, y: 0, width: 512, height: 512))
    }

    // MARK: - Grading

    func apply(_ look: FilmLook, to input: CIImage) -> CIImage {
        guard !look.isIdentity else { return input }

        let extent = input.extent
        guard extent.width > 0, extent.height > 0 else { return input }

        var image = input

        // 1 — Exposure trim.
        if abs(look.exposure) > 0.001 {
            image = image.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: look.exposure
            ])
        }

        // 2 — Per-channel film curve: the actual "stock".
        image = image.applyingFilter("CIColorPolynomial", parameters: [
            "inputRedCoefficients": vector(look.red),
            "inputGreenCoefficients": vector(look.green),
            "inputBlueCoefficients": vector(look.blue),
            "inputAlphaCoefficients": CIVector(x: 0, y: 0, z: 1, w: 0)
        ])

        // 3 — Global contrast and saturation.
        if abs(look.contrast - 1) > 0.001 || abs(look.saturation - 1) > 0.001 {
            image = image.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: look.contrast,
                kCIInputSaturationKey: look.saturation,
                kCIInputBrightnessKey: 0.0
            ])
        }

        // 4 — Halation: light scattering inside the emulsion, strongest in red.
        if look.halation > 0.01 {
            let bloom = image.applyingFilter("CIBloom", parameters: [
                kCIInputRadiusKey: 16.0,
                kCIInputIntensityKey: 0.6
            ])
            let tinted = bloom.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: look.halationTint.r, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: look.halationTint.g, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: look.halationTint.b, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(look.halation))
            ])
            image = tinted.applyingFilter("CIScreenBlendMode", parameters: [
                kCIInputBackgroundImageKey: image
            ])
        }

        // 5 — Grain.
        if look.grain > 0.01 {
            image = applyGrain(to: image, strength: look.grain, size: look.grainSize, extent: extent)
        }

        // 6 — Vignette.
        if look.vignette > 0.01 {
            image = image.applyingFilter("CIVignetteEffect", parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputRadiusKey: min(extent.width, extent.height) * 0.62,
                kCIInputIntensityKey: look.vignette,
                "inputFalloff": 0.55
            ])
        }

        return image.cropped(to: extent)
    }

    private func applyGrain(to image: CIImage, strength: Float, size: CGFloat, extent: CGRect) -> CIImage {
        let tileSize = noiseTile.extent.width
        let scale = max(extent.width / tileSize, extent.height / tileSize) * size

        let grain = noiseTile
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(strength) * 0.55)
            ])

        return grain.applyingFilter("CISoftLightBlendMode", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    private func vector(_ curve: ChannelCurve) -> CIVector {
        CIVector(x: curve.a, y: curve.b, z: curve.c, w: curve.d)
    }

    // MARK: - Output

    func uiImage(from image: CIImage) -> UIImage? {
        let rect = image.extent.integral
        guard !rect.isEmpty, rect.width.isFinite, rect.height.isFinite else { return nil }
        guard let cgImage = context.createCGImage(image, from: rect) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func jpeg(from image: CIImage, quality: CGFloat = 0.95) -> Data? {
        uiImage(from: image)?.jpegData(compressionQuality: quality)
    }
}
