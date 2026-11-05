import react from "@vitejs/plugin-react";
import { defineConfig, type PluginOption } from "vite";
import { visualizer } from "rollup-plugin-visualizer";

const plugins: PluginOption[] = [react()];
if (process.env["ANALYZE"] === "true") {
  plugins.push(
    visualizer({
      open: true,
      filename: "dist/stats.html",
      gzipSize: true,
      brotliSize: true,
    }),
  );
}

export default defineConfig({ plugins });
