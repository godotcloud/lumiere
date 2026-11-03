//
//  CaptureStore.swift
//  Lumiere
//
//  File-backed library. Everything lives in Documents/Captures so the gallery
//  survives relaunches without touching the system photo library.
//

import Combine
import Foundation
import UIKit

final class CaptureStore: ObservableObject {

    @Published private(set) var photos: [PhotoAsset] = []

    private let root: URL
    private let work = DispatchQueue(label: "app.lumiere.store", qos: .utility)

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = documents.appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        reload()
    }

    // MARK: - Reading

    func reload() {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return
        }

        let metas: [PhotoMeta] = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(PhotoMeta.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }

        photos = metas.map { meta in
            PhotoAsset(
                id: meta.id,
                url: root.appendingPathComponent(meta.id).appendingPathExtension("jpg"),
                lookID: meta.lookID,
                createdAt: meta.createdAt,
                thumbnail: nil
            )
        }

        loadThumbnails(for: photos)
    }

    private func loadThumbnails(for assets: [PhotoAsset]) {
        for asset in assets {
            work.async { [weak self] in
                guard let self,
                      let data = try? Data(contentsOf: asset.url),
                      let thumbnail = PhotoPipeline.image(
                          from: data,
                          look: FilmLibrary.look(withID: asset.lookID),
                          maxDimension: 360
                      )
                else { return }

                DispatchQueue.main.async {
                    guard let index = self.photos.firstIndex(where: { $0.id == asset.id }) else { return }
                    self.photos[index].thumbnail = thumbnail
                }
            }
        }
    }

    // MARK: - Writing

    @discardableResult
    func add(originalData: Data, look: FilmLook, thumbnail: UIImage?) -> PhotoAsset {
        let id = UUID().uuidString
        let url = root.appendingPathComponent(id).appendingPathExtension("jpg")
        try? originalData.write(to: url, options: .atomic)

        let meta = PhotoMeta(id: id, lookID: look.id, createdAt: Date())
        write(meta)

        let asset = PhotoAsset(
            id: id,
            url: url,
            lookID: look.id,
            createdAt: meta.createdAt,
            thumbnail: thumbnail
        )
        photos.insert(asset, at: 0)
        return asset
    }

    func updateLook(_ asset: PhotoAsset, look: FilmLook, thumbnail: UIImage?) {
        write(PhotoMeta(id: asset.id, lookID: look.id, createdAt: asset.createdAt))
        guard let index = photos.firstIndex(where: { $0.id == asset.id }) else { return }
        photos[index] = asset.updated(lookID: look.id, thumbnail: thumbnail)
    }

    func delete(_ asset: PhotoAsset) {
        let manager = FileManager.default
        try? manager.removeItem(at: asset.url)
        try? manager.removeItem(at: root.appendingPathComponent(asset.id).appendingPathExtension("json"))
        photos.removeAll { $0.id == asset.id }
    }

    private func write(_ meta: PhotoMeta) {
        guard let data = try? JSONEncoder().encode(meta) else { return }
        let url = root.appendingPathComponent(meta.id).appendingPathExtension("json")
        try? data.write(to: url, options: .atomic)
    }
}
