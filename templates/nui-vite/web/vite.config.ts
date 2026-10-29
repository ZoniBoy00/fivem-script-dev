import { defineConfig } from 'vite';

export default defineConfig({
  // NUI loads files from nui://<resource>/web/build/, so asset URLs must be relative
  base: './',
  build: {
    outDir: 'build',
    emptyOutDir: true,
    // FiveM's CEF is a recent Chromium; no legacy transpiling needed
    target: 'es2022',
  },
});
