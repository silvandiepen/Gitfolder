import SwiftUI
import WebKit

/// Renders a card's markdown by handing it to Nizel inside a WKWebView. The web
/// asset (`markdown-renderer.html`) is bundled and fully self-contained, so this
/// works offline in the sandbox. Swift only passes the markdown string across.
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.underPageBackgroundColor = .clear
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "markdown-renderer", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.render(markdown)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var isLoaded = false
        private var pending: String?

        func render(_ markdown: String) {
            pending = markdown
            if isLoaded { flush() }
        }

        private func flush() {
            guard let markdown = pending, let webView else { return }
            pending = nil
            // JSON-encode the string so any quotes/newlines/backslashes are safe.
            let json = (try? JSONEncoder().encode(markdown))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
            webView.evaluateJavaScript("window.setMarkdown(\(json))")
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            isLoaded = true
            flush()
        }
    }
}
