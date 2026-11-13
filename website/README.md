# Tahow documentation

Static Astro + MDX documentation, built with Bun. Portuguese and English pages live in `src/pages/pt-BR` and `src/pages/en-US`.

From the repository root:

```sh
bun install --frozen-lockfile
bun run docs:dev
bun run docs:build
bun run docs:preview
```

The development URL is `http://127.0.0.1:4321/Tahow/`. Production uses `https://eduardoaugustolb.github.io/Tahow/`.

## Publishing

In repository Settings → Pages, select GitHub Actions as the build source. `.github/workflows/docs.yml` installs the root Bun workspace, builds the static pages and deploys pushes to main. Pull requests only build. Manual deployment is also available through workflow_dispatch. If changing repository or owner, update `site` and `base` in `astro.config.mjs`. All internal paths must retain the configured base.

## Visual source and provenance

The 258 px navigation, 24 px window corners, compact groups, general light/dark colors and accent-tinted sidebar follow `shell/SettingsWindow.qml`. Foreground and glass colors follow `shell/Theme.qml` and `shell/lib/material.js`. CSS approximates the material for the browser; it does not implement desktop capture or the shell's refraction shaders. Browser appearance follows the OS initially, then the persisted manual selection.

Six original glyphs are copied from `shell/icons/regular`, under the project's AGPL-3.0 license. Sacramento is copied from `shell/reload/fonts`; the SIL OFL is included in `public/fonts/OFL.txt`. The system font stack follows the shell without distributing proprietary fonts. No desktop screenshots or third-party wallpapers are bundled.

The search filters page titles in the current language. Language switching preserves the current page. Pages are static and work without JavaScript; theme switching, search, mobile navigation and the generated on-page index need JavaScript.
