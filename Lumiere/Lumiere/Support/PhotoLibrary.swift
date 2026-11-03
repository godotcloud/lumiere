//
//  PhotoLibrary.swift
//  Lumiere
//
//  Thin wrappers for the two system touchpoints: saving to Photos and haptics.
//

import Photos
import UIKit

enum PhotoLibrary {

    static func save(_ jpeg: Data, completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = "public.jpeg"
                request.addResource(with: .photo, data: jpeg, options: options)
            } completionHandler: { success, _ in
                DispatchQueue.main.async { completion?(success) }
            }
        }
    }
}

enum Haptics {

    static func shutter() {
        guard AppSettings.shared.haptics else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
    }

    static func selection() {
        guard AppSettings.shared.haptics else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
