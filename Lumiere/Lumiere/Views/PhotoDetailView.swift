//
//  PhotoDetailView.swift
//  Lumiere
//
//  Non-destructive re-grading: the original JPEG is re-rendered with whatever
//  stock you pick, and the choice is persisted in the sidecar metadata.
//

import SwiftUI
import UIKit

struct PhotoDetailView: View {

    let asset: PhotoAsset
    @ObservedObject var store: CaptureStore

    @Environment(\.dismiss) private var dismiss

    @State private var selectedLook: FilmLook
    @State private var image: UIImage?
    @State private var isRendering = true
    @State private var isSaving = false
    @State private var share: ShareItem?
    @State private var toast: String?

    init(asset: PhotoAsset, store: CaptureStore) {
        self.asset = asset
        self._store = ObservedObject(wrappedValue: store)
        self._selectedLook = State(initialValue: FilmLibrary.look(withID: asset.lookID))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
                    .overlay(alignment: .center) {
                        if isRendering {
                            ProgressView().tint(Theme.accent)
                        }
                    }
            } else if isRendering {
                ProgressView().tint(Theme.accent)
            }

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                controls
            }

            if let toast {
                VStack {
                    Text(toast)
                        .font(.rounded(11, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
                .padding(.top, 68)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .statusBarHidden(true)
        .task(id: selectedLook.id) {
            await render()
        }
        .sheet(item: $share) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(selectedLook.name)
                    .font(.rounded(12, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text(dateLabel)
                    .font(.mono(9, weight: .regular))
                    .foregroundStyle(Theme.tertiary)
            }

            Spacer()

            Menu {
                Button {
                    saveToLibrary()
                } label: {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    store.delete(asset)
                    dismiss()
                } label: {
                    Label("删除照片", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd  HH:mm"
        return formatter.string(from: asset.createdAt)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            FilterStrip(looks: FilmLibrary.looks, selection: $selectedLook)

            HStack(spacing: 12) {
                actionButton(title: "分享", systemName: "square.and.arrow.up") {
                    prepareShare()
                }

                actionButton(
                    title: isSaving ? "保存中" : "保存到相册",
                    systemName: "arrow.down.to.line"
                ) {
                    saveToLibrary()
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func actionButton(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.rounded(11, weight: .semibold))
            }
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    // MARK: - Work

    private func render() async {
        isRendering = true
        let look = selectedLook
        let url = asset.url

        let result: UIImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let data = try? Data(contentsOf: url)
                let rendered = data.flatMap {
                    PhotoPipeline.image(from: $0, look: look, maxDimension: 1800)
                }
                continuation.resume(returning: rendered)
            }
        }

        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.18)) {
            image = result
            isRendering = false
        }

        // Persist the choice so the gallery thumbnail stays in sync.
        if look.id != asset.lookID, let result {
            let thumb = PhotoPipeline.downsample(result, maxDimension: 360)
            store.updateLook(asset, look: look, thumbnail: thumb)
        }
    }

    private func saveToLibrary() {
        guard !isSaving else { return }
        isSaving = true
        let look = selectedLook
        let url = asset.url

        DispatchQueue.global(qos: .userInitiated).async {
            let data = (try? Data(contentsOf: url)).flatMap {
                PhotoPipeline.renderJPEG(from: $0, look: look)
            }

            guard let data else {
                DispatchQueue.main.async {
                    isSaving = false
                    show("导出失败")
                }
                return
            }

            PhotoLibrary.save(data) { success in
                isSaving = false
                show(success ? "已保存到相册" : "没有相册权限")
            }
        }
    }

    private func prepareShare() {
        let look = selectedLook
        let url = asset.url

        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = (try? Data(contentsOf: url)).flatMap({
                PhotoPipeline.renderJPEG(from: $0, look: look)
            }) else { return }

            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("lumiere-\(UUID().uuidString)")
                .appendingPathExtension("jpg")
            try? data.write(to: temporary, options: .atomic)

            DispatchQueue.main.async {
                share = ShareItem(url: temporary)
            }
        }
    }

    private func show(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.25)) { toast = nil }
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
