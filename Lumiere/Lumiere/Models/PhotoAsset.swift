//
//  PhotoAsset.swift
//  Lumiere
//
//  The on-disk model is non-destructive: a capture stores the untouched JPEG
//  plus a tiny sidecar describing which stock was chosen. Re-grading later
//  re-renders from the original, so nothing is ever baked in twice.
//

import Foundation
import UIKit

struct PhotoAsset: Identifiable, Equatable {
    let id: String
    let url: URL
    let lookID: String
    let createdAt: Date
    var thumbnail: UIImage?

    func updated(lookID: String, thumbnail: UIImage?) -> PhotoAsset {
        PhotoAsset(
            id: id,
            url: url,
            lookID: lookID,
            createdAt: createdAt,
            thumbnail: thumbnail ?? self.thumbnail
        )
    }

    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }
}

struct PhotoMeta: Codable {
    let id: String
    let lookID: String
    let createdAt: Date
}
