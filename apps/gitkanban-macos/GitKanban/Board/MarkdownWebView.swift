import SwiftUI
import WebKit

/// Renders a card's markdown via Nizel in a WKWebView. Shows a loader and keeps
/// the web view hidden until the first render is done, so there's no white flash.
struct MarkdownWebView: View {
    let markdown: String
    @State private var isReady = false

    var body: some View {
        ZStack {
            Representable(markdown: markdown, onReady: { isReady = true })
                .opacity(isReady ? 1 : 0)
            if !isReady {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isReady)
    }

    private struct Representable: NSViewRepresentable {
        let markdown: String
        let onReady: () -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onReady: onReady) }

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
