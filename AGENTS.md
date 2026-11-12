# Working on Tahow

- Use Bun as the runtime and package manager. Do not introduce npm lockfiles.
- Work in this repository. Never patch installed Ryoku, Quickshell, or catalogue files as a substitute for changing source.
- Keep configuration, theme, runtime, and host adapters separate. Desktop-specific imports belong in adapters; `shell/shell.qml` remains independently runnable.
- Keep user-facing strings in both `en-US` and `pt-BR` catalogues. Run `bun tools/sync-i18n.ts` after changing strings.
- Preserve `tahoe-shell` installation IDs and IPC names for compatibility unless an explicit migration is requested. The preferences home is `~/.config/tahow-shell`; the legacy `~/.config/tahoe-shell` directory stays a readable fallback until the canonical file exists. Preferences use General fields plus `overrides.island`, `overrides.palette`, and `overrides.lockscreen`.
- Settings follows General dark/light appearance and desktop accent. Do not introduce an independent light-only settings theme.
- The collapsed island uses simulated glass without capture or a refraction shader. Expanded capture excludes owned surfaces and precedes animation. Do not imply frozen snapshots are live window tracking.
- Edit shader sources, rebuild with `bun tools/build-shaders.ts`, and include the generated `.qsb` artifacts. Treat generated translation/export outputs similarly: use their generator and inspect the diff.
- Preserve qylock/PAM/fingerprint authentication. Automated tests must use simulated authentication. Never capture, log, request, or store passwords or raw keystrokes; never automate unlocking a real session.
- Run `bun run check` and `bun test` for relevant changes, plus targeted visual/runtime verification where needed. Record the actual environment and limitations. Hyprland has runtime testing; niri must not be advertised as validated without evidence.
- Export companions using `bun tools/export-ryostore.ts --to <catalogue-checkout>` and inspect changes before publishing. Do not silently mutate the user's installed desktop.
- Retain attribution and license notices. Add provenance for imported assets or source; do not add proprietary Apple/Icons8 assets.
