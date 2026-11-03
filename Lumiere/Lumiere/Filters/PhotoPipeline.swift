//
//  PhotoPipeline.swift
//  Lumiere
//
//  Pure, synchronous image work. Deliberately free of UI state so it can run
//  on a background queue at full resolution.
//

import CoreImage
import UIKit

enum PhotoPipeline {

    /// Decodes a captured JPEG and bakes in its orientation, so every
    /// downstream filter works in an upright coordinate space.
    static func orientedImage(from data: Data) -> CIImage? {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return nil
        }
        return image
    }

    static func image(from data: Data, look: FilmLook, maxDimension: CGFloat) -> UIImage? {
        guard let source = orientedImage(from: data) else { return nil }
        let longest = max(source.extent.width, source.extent.height)
        guard longest > 0 else { return nil }

        let scale = min(1, maxDimension / longest)
        let scaled = scale < 1
            ? source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : source

        let processed = FilmEngine.shared.apply(look, to: scaled)
        return FilmEngine.shared.uiImage(from: processed)
    }

    static func renderJPEG(from data: Data, look: FilmLook, quality: CGFloat = 0.94) -> Data? {
        guard let source = orientedImage(from: data) else { return nil }
        let processed = FilmEngine.shared.apply(look, to: source)
        return FilmEngine.shared.jpeg(from: processed, quality: quality)
    }

    static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
