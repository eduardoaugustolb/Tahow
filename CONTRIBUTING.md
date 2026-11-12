# Contributing to Tahow

Open an issue describing the problem or submit a focused pull request with the resulting behavior and relevant validation. Include compositor, Quickshell/Qt versions, and reproducible steps for runtime bugs. Remove personal information from logs and screenshots.

Use Bun exclusively for JavaScript/TypeScript scripts and dependencies. Keep shell components modular: configuration owns preference persistence, theme resolves appearance, and host adapters isolate desktop integration. Preserve compatibility IDs and the existing settings schema unless a migration is included.

## Checks

```sh
bun run check
bun test
```

Rebuild shader artifacts after changing shader sources:

```sh
bun tools/build-shaders.ts
```

Keep user-facing text in the `en-US` and `pt-BR` catalogues, then run `bun tools/sync-i18n.ts`. Include appropriate tests for logic changes. For visual or lifecycle changes, describe desktop verification, reduced-motion behavior, and capture fallback behavior. Do not claim compositor support from static checks alone: Hyprland has runtime coverage; niri still needs validation.

Edit this repository's sources, not installed Ryoku files. Export integration changes into a separate catalogue checkout with `bun tools/export-ryostore.ts --to /path/to/ryostore` and review the diff before publishing. Commit generated artifacts with the source changes that produce them.

## Authentication and privacy

Preserve qylock/PAM/fingerprint boundaries. Use simulated authentication for automated tests. Never request, record, print, or commit real passwords or keystrokes. A real lock/unlock test is voluntary, manual, and performed by the machine's user with a recovery path available.

Report vulnerabilities using [SECURITY.md](SECURITY.md). Retain third-party notices and document the source, revision, license, and modifications of imported material. Contributions are distributed under the project's applicable licenses.
