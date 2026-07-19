import SwiftUI
import UIKit
import WebKit

/// Views an image file from the repository. Raster formats render with `UIImage`; SVGs
/// render in a `WKWebView`. Offers Share and, when ImageKid is installed, "Edit in
/// ImageKid" — handing the image off through the system open-in sheet.
struct ImageViewerView: View {
    @Environment(AppModel.self) private var model
    let path: String
    let name: String

    @State private var data: Data?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var shareItem: ShareItem?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let loadError {
                ContentUnavailableView("Couldn't open image", systemImage: "photo.badge.exclamationmark", description: Text(loadError))
            } else if let data {
                if FileKind.isSVG(name) {
                    SVGWebView(data: data)
                } else if let image = UIImage(data: data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                } else {
                    ContentUnavailableView("Unsupported image", systemImage: "photo", description: Text("Couldn't decode \(name)."))
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if data != nil, ImageKidBridge.isInstalled {
                    Button {
                        if let url = writeTempFile() { shareItem = ShareItem(url: url) }
                    } label: { Label("Edit in ImageKid", systemImage: "wand.and.stars") }
                }
                if data != nil {
                    Button {
                        if let url = writeTempFile() { shareItem = ShareItem(url: url) }
                    } label: { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            data = try await model.readData(path)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    /// Write the image to a temp file (keeping its name/extension) so another app can
    /// open it via the share/open-in sheet.
    private func writeTempFile() -> URL? {
        guard let data else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: url); return url } catch { return nil }
    }
}

/// Detects whether ImageKid is installed (it registers the `imagekid` URL scheme).
enum ImageKidBridge {
    static var isInstalled: Bool {
        guard let url = URL(string: "imagekid://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

/// Renders SVG data in a WKWebView, scaled to fit.
private struct SVGWebView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let svg = String(data: data, encoding: .utf8) ?? ""
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=4">
        <style>html,body{margin:0;height:100%;background:transparent}
        .wrap{display:flex;align-items:center;justify-content:center;height:100vh;padding:12px;box-sizing:border-box}
        svg,img{max-width:100%;max-height:100%;height:auto}</style></head>
        <body><div class="wrap">\(svg)</div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
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
