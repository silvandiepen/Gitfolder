import SwiftUI
import WebKit

/// Renders markdown via the bundled Nizel renderer (`markdown-renderer.html`) in a
/// WKWebView. Shows a loader and keeps the web view hidden until the first render so
/// there is no white flash.
struct MarkdownWebView: View {
    let markdown: String
    @State private var isReady = false

    var body: some View {
        ZStack {
            Representable(markdown: markdown, onReady: { isReady = true })
                .opacity(isReady ? 1 : 0)
            if !isReady {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isReady)
    }

    private struct Representable: UIViewRepresentable {
        let markdown: String
        let onReady: () -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onReady: onReady) }

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            context.coordinator.webView = webView
            if let url = Bundle.main.url(forResource: "markdown-renderer", withExtension: "html") {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            }
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            context.coordinator.onReady = onReady
            context.coordinator.render(markdown)
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
            weak var webView: WKWebView?
            var onReady: () -> Void
            private var isLoaded = false
            private var didSignalReady = false
            private var pending: String?

            init(onReady: @escaping () -> Void) { self.onReady = onReady }

            func render(_ markdown: String) {
                pending = markdown
                if isLoaded { flush() }
            }

            private func flush() {
                guard let markdown = pending, let webView else { return }
                pending = nil
                let json = (try? JSONEncoder().encode(markdown))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
                webView.evaluateJavaScript("window.setMarkdown(\(json))") { [weak self] _, _ in
                    self?.signalReady()
                }
            }

            private func signalReady() {
                guard !didSignalReady else { return }
                didSignalReady = true
                let callback = onReady
                DispatchQueue.main.async { callback() }
            }

            func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                isLoaded = true
                flush()
            }
        }
    }
}

/// Renders SVG source (text) in a WKWebView, scaled to fit, on a checkerboard
/// background so transparent/black artwork stays visible.
struct SVGWebView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=4">
        <style>
        html,body{margin:0;height:100%}
        body{
          background-color:#fff;
          background-image:
            linear-gradient(45deg,#d0d0d0 25%,transparent 25%),
            linear-gradient(-45deg,#d0d0d0 25%,transparent 25%),
            linear-gradient(45deg,transparent 75%,#d0d0d0 75%),
            linear-gradient(-45deg,transparent 75%,#d0d0d0 75%);
          background-size:20px 20px;
          background-position:0 0,0 10px,10px -10px,-10px 0px;
        }
        .wrap{display:flex;align-items:center;justify-content:center;height:100vh;padding:12px;box-sizing:border-box}
        svg,img{max-width:100%;max-height:100%;height:auto}
        </style></head>
        <body><div class="wrap">\(svg)</div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
