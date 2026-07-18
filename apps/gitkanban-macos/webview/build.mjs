// Bundles the Nizel renderer + styles into ONE self-contained HTML file that
// GitKanban ships in its app bundle and loads in a WKWebView. No network, no
// external files — the app is sandboxed and must render offline.
import { build } from "esbuild";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const outFile = resolve(here, "../GitKanban/Resources/markdown-renderer.html");

const bundle = await build({
  entryPoints: [resolve(here, "src/renderer.ts")],
  bundle: true,
  format: "iife",
  platform: "browser",
  target: ["safari15"],
  minify: true,
  write: false,
});

const js = bundle.outputFiles[0].text;
const css = readFileSync(resolve(here, "src/style.css"), "utf8");

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>GitKanban card</title>
<style>${css}</style>
</head>
<body>
<div id="content" class="markdown"></div>
<script>${js}</script>
</body>
</html>
`;

mkdirSync(dirname(outFile), { recursive: true });
writeFileSync(outFile, html);
console.log(`markdown-renderer.html written (${html.length} bytes) → ${outFile}`);
