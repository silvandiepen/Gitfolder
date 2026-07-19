import SwiftUI
import UIKit

/// A small in-memory cache of decoded image thumbnails, keyed by repo + path.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
}

/// A lazily-loaded thumbnail for a raster image file, fetched over the provider API and
/// cached. Shows a placeholder icon until it loads.
struct RepoThumbnail: View {
    @Environment(AppModel.self) private var model
    let entry: RepoEntry
    let side: CGFloat
    @State private var image: UIImage?

    private var key: String { "\(model.activeRepo?.id ?? "")/\(entry.path)" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.12))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").font(.system(size: side * 0.32)).foregroundStyle(.secondary)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: key) { await load() }
    }

    private func load() async {
        if image != nil { return }
        if let cached = ImageCache.shared.image(for: key) { image = cached; return }
        guard let data = try? await model.readData(entry.path), let full = UIImage(data: data) else { return }
        let thumb = full.preparingThumbnail(of: CGSize(width: side * 3, height: side * 3)) ?? full
        ImageCache.shared.set(thumb, for: key)
        image = thumb
    }
}

/// A large square tile: a thumbnail (for images) or a big type icon, with the name below.
struct TileCell: View {
    let entry: RepoEntry
    private let side: CGFloat = 104

    var body: some View {
        VStack(spacing: 8) {
            if entry.isDirectory {
                iconTile("folder.fill", AnyShapeStyle(.tint))
            } else if FileKind.isRasterImage(entry.name) {
                RepoThumbnail(entry: entry, side: side)
            } else {
                iconTile(FileKind.icon(entry.name, isDirectory: false), AnyShapeStyle(.secondary))
            }
            Text(entry.name)
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: side)
        }
    }

    private func iconTile(_ symbol: String, _ style: AnyShapeStyle) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.10))
            Image(systemName: symbol).font(.system(size: side * 0.4)).foregroundStyle(style)
        }
        .frame(width: side, height: side)
    }
}

