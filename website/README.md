# Tahow documentation

Static Astro + MDX documentation, built with Bun. Portuguese and English pages live in `src/pages/pt-BR` and `src/pages/en-US`.

From the repository root:

```sh
bun install --frozen-lockfile
bun run docs:dev
bun run docs:build
bun run docs:preview
```

The development URL is `http://127.0.0.1:4321/`. Production uses `https://tahow.eduardoaugusto.work/`.

## Publishing and domain

GitHub Pages uses GitHub Actions. `.github/workflows/docs.yml` installs the root Bun workspace, builds the static pages and deploys pushes to main. Pull requests only build. Manual deployment is available through workflow_dispatch.

The custom domain is configured in repository Pages settings, `astro.config.mjs` (`site`, with no repository base path), and `public/CNAME`. In the Cloudflare DNS zone `eduardoaugusto.work`, the required record is:

| Type | Name | Target | Proxy | TTL |
| --- | --- | --- | --- | --- |
| CNAME | tahow | eduardoaugustolb.github.io | DNS only | Auto |

After DNS propagates and GitHub provisions the certificate, enable Enforce HTTPS in repository Pages settings. DNS credentials are not stored in the repository.

## Visual source and provenance

The conventional documentation layout has a sticky full-width header, left navigation, central article and right table of contents. It follows the shell's light/dark colors, accent, typography and original glyphs without a desktop-window frame. CSS adapts the glass material for the browser; it does not implement desktop capture or QML refraction shaders. Browser appearance follows the OS initially, then the persisted manual selection.

Six original glyphs are copied from `shell/icons/regular`, under the project's AGPL-3.0 license. The approved glass logo is generated artwork; its source and provenance are in `docs/brand/tahow-logo-concept-v3.provenance.json`. The landing pages feature the approved animated banner: the original generated glass-orbit background, approved logo and bundled Sacramento signature are rendered with the reload screen shaders. MP4 plays automatically, muted and on an infinite loop, without player controls; reduced-motion visitors see a static poster. Rebuild with `bun tools/build-shaders.ts` followed by `bun tools/animate-banner.ts`; the renderer updates both repository artifacts and website copies. Provenance is in `docs/brand/tahow-banner-v2.provenance.json`. The system font stack follows the shell without distributing proprietary fonts. No desktop screenshots or third-party wallpapers are bundled.

The search filters page titles in the current language. Language switching preserves the current page. Pages and navigation remain available without JavaScript; theme switching, search, the mobile menu toggle and the generated on-page index need JavaScript.
