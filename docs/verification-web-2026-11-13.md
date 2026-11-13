# Web documentation verification — 2026-11-13

Created an Astro/MDX static documentation workspace under website/, with six pages per language (pt-BR and en-US), plus a language entry page. The layout derives its colors, 258 px sidebar, 24 px window corners and compact groups from the shell sources. Original project glyphs and the OFL Sacramento font are bundled with notices. Browser glass is a CSS approximation; no desktop capture or QML shader is used.

Environment: Linux x64, Bun 1.4.4. `bun install --frozen-lockfile` passed. `bun run docs:build` generated 13 pages. A static output scan verified 226 local links/assets and confirmed MDX class conversion. `bun run check` passed (133 QML files and current generated translations). `bun test` passed: 40 tests, 0 failures.

The CUA browser host was unavailable, so interactive, screenshot and mobile browser verification could not be performed. Responsive CSS and accessible control labels were inspected in source; they are not claimed as visually validated. No shell runtime, installed desktop, real authentication or niri validation was performed for this documentation change.

Existing local shell, locale, integration and login-wallpaper changes were preserved and excluded from the documentation publication.
