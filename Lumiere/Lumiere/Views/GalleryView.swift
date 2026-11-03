//
//  GalleryView.swift
//  Lumiere
//

import SwiftUI

struct GalleryView: View {

    @ObservedObject var store: CaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotoAsset?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if store.photos.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(store.photos) { asset in
                                Button {
                                    selection = asset
                                } label: {
                                    cell(for: asset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .navigationTitle("胶片库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $selection) { asset in
            PhotoDetailView(asset: asset, store: store)
        }
    }

    private func cell(for asset: PhotoAsset) -> some View {
        Rectangle()
            .fill(Theme.surfaceRaised)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumbnail = asset.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                        .tint(Theme.tertiary)
                }
            }
            .clipped()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(Theme.tertiary)

            Text("还没有照片")
                .font(.rounded(13, weight: .semibold))
                .foregroundStyle(Theme.secondary)

            Text("按一次快门，第一张胶片就会出现在这里。")
                .font(.rounded(11, weight: .regular))
                .foregroundStyle(Theme.tertiary)
        }
    }
}
