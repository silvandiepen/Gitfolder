// Runs inside GitKanban's WKWebView. Swift calls window.setMarkdown(md) with a
// card's markdown body; Nizel turns it into HTML that we drop into #content.
import { markdownToHtml } from "nizel/browser";

declare global {
  interface Window {
    setMarkdown: (markdown: string) => void;
  }
}

const content = document.getElementById("content");

// Serialize renders so a burst of calls ends on the last value, in order.
let queue: Promise<void> = Promise.resolve();

window.setMarkdown = (markdown: string): void => {
  queue = queue.then(async () => {
    if (!content) return;
    try {
      content.innerHTML = await markdownToHtml(markdown ?? "");
    } catch (error) {
      content.textContent = String(error);
    }
  });
};
