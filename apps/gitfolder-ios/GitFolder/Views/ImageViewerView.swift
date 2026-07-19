import SwiftUI
import UIKit

/// Views an image, fit to the screen by default, with pinch-to-zoom and double-tap to
/// reset. Swipe left/right to page through the other images in the same folder. Offers
/// Share and, when ImageKid is installed, "Edit in ImageKid".
struct ImageViewerView: View {
    @Environment(AppModel.self) private var model
    let path: String
    let name: String

    @State private var siblings: [RepoEntry] = []
    @State private var selection: String = ""
    @State private var loaded = false
    @State private var shareItem: ShareItem?

    private var current: RepoEntry? { siblings.first { $0.path == selection } }

    var body: some View {
        Group {
            if siblings.isEmpty {
                ProgressView()
            } else {
                TabView(selection: $selection) {
                    ForEach(siblings) { entry in
                        ZoomableImage(entry: entry).tag(entry.path)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: siblings.count > 1 ? .automatic : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            }
        }
        .navigationTitle(current?.name ?? name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSiblings() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if ImageKidBridge.isInstalled {
                    Button {
                        Task { await share() }
                    } label: { Label("Edit in ImageKid", systemImage: "wand.and.stars") }
                }
                Button {
                    Task { await share() }
                } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    /// List the folder and gather its images so the viewer can page through them.
    private func loadSiblings() async {
        guard !loaded else { return }
        loaded = true
        let parent = (path as NSString).deletingLastPathComponent
        let entries = (try? await model.list(parent)) ?? []
        let images = entries.filter { !$0.isDirectory && FileKind.isRasterImage($0.name) }
        siblings = images.isEmpty ? [RepoEntry(name: name, path: path, isDirectory: false)] : images
        selection = path
    }

    /// Write the current image to a temp file and present the share / open-in sheet.
    private func share() async {
        guard let entry = current, let data = try? await model.readData(entry.path) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(entry.name)
        guard (try? data.write(to: url)) != nil else { return }
        shareItem = ShareItem(url: url)
    }
}

/// One image page: fit to screen by default, pinch to zoom (1–5×), double-tap to reset.
struct ZoomableImage: View {
    @Environment(AppModel.self) private var model
    let entry: RepoEntry

    @State private var image: UIImage?
    @State private var loadError = false
    @State private var steady: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    private var key: String { "full/\(model.activeRepo?.id ?? "")/\(entry.path)" }
    private var scale: CGFloat { min(max(steady * pinch, 1), 5) }

    var body: some View {
        ZStack {
            if image != nil { Checkerboard().ignoresSafeArea() }
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .updating($pinch) { value, state, _ in state = value }
                            .onEnded { value in steady = min(max(steady * value, 1), 5) }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeOut(duration: 0.2)) { steady = steady > 1 ? 1 : 2.5 }
                    }
            } else if loadError {
                ContentUnavailableView("Couldn't open image", systemImage: "photo.badge.exclamationmark")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: entry.path) { await load() }
    }

    private func load() async {
        if image != nil { return }
        if let cached = ImageCache.shared.image(for: key) { image = cached; return }
        do {
            let data = try await model.readData(entry.path)
            if let ui = UIImage(data: data) {
                ImageCache.shared.set(ui, for: key)
                image = ui
            } else {
                loadError = true
            }
        } catch {
            loadError = true
        }
    }
}

/// A transparency checkerboard, so transparent/black artwork stays visible.
struct Checkerboard: View {
    var square: CGFloat = 14
    var body: some View {
        Canvas { ctx, size in
            let cols = Int(ceil(size.width / square))
            let rows = Int(ceil(size.height / square))
            for r in 0...rows {
                for c in 0...cols where (r + c).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(c) * square, y: CGFloat(r) * square, width: square, height: square)
                    ctx.fill(Path(rect), with: .color(Color(white: 0.82)))
                }
            }
        }
        .background(Color(white: 0.97))
    }
}

/// Detects whether ImageKid is installed (it registers the `imagekid` URL scheme).
enum ImageKidBridge {
    static var isInstalled: Bool {
        guard let url = URL(string: "imagekid://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

/// A SwiftUI wrapper for the system share / open-in sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so a temp file URL can drive a `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
