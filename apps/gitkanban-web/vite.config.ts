import { fileURLToPath, URL } from "node:url";
import vue from "@vitejs/plugin-vue";
import { ui } from "@sil/ui/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [vue(), ui()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
});

