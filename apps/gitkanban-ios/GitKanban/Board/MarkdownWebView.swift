import SwiftUI
import WebKit

/// Renders markdown via the bundled Nizel renderer (`markdown-renderer.html`) in a
/// WKWebView, matching the macOS app. Self-sizing so it fits inside a ScrollView; shows
/// a loader until the first render so there's no white flash.
struct MarkdownWebView: View {
    let markdown: String
    @State private var isReady = false
    @State private var height: CGFloat = 60

    var body: some View {
        ZStack {
            Representable(markdown: markdown, onReady: { isReady = true }, onHeight: { height = max($0, 20) })
                .frame(height: height)
                .opacity(isReady ? 1 : 0)
            if !isReady {
                ProgressView().frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isReady)
    }

    private struct Representable: UIViewRepresentable {
        let markdown: String
        let onReady: () -> Void
        let onHeight: (CGFloat) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onReady: onReady, onHeight: onHeight) }

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.scrollView.isScrollEnabled = false
            context.coordinator.webView = webView
            if let url = Bundle.main.url(forResource: "markdown-renderer", withExtension: "html") {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            }
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            context.coordinator.onReady = onReady
            context.coordinator.onHeight = onHeight
            context.coordinator.render(markdown)
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
            weak var webView: WKWebView?
            var onReady: () -> Void
            var onHeight: (CGFloat) -> Void
            private var isLoaded = false
            private var didSignalReady = false
            private var pending: String?

            init(onReady: @escaping () -> Void, onHeight: @escaping (CGFloat) -> Void) {
                self.onReady = onReady
                self.onHeight = onHeight
            }

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
                    self?.measureHeight()
                }
            }

            private func measureHeight() {
                webView?.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                    if let number = result as? NSNumber { self?.onHeight(CGFloat(number.doubleValue)) }
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
