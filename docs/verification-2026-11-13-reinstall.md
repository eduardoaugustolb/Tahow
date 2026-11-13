# Reinstall and live reload

The user explicitly requested reinstall and push after the hover and preference
fixes. Exported the three companions with `bun tools/export-ryostore.ts --to
/home/eduardoaugustolb/Documents/www/third-party/ryostore` and inspected the
registry diff. The existing local catalogue checkout already contained uncommitted
Tahow registrations; it was used for installation, not committed or pushed.

Ryostore initially reused cached catalogue data. Ran `ryostore catalog --refresh`
and reinstalled barstyles, launchers and lockscreens `tahoe-shell` through
`ryostore install`. The installed Config.qml and Island.qml SHA-256 hashes
exactly match the repository sources.

Backed up canonical and legacy settings to `/tmp/tahow-pre-reinstall-20261113/`
before installation. The canonical settings SHA-256 remained identical before
installation and after `ryoku reload`:
`6e0d73725f993c7d0d34f9131ba5cdaf9460c023d49a447257d37749a13beae7`.

The reloaded Hyprland shell answered `tahoe state` IPC with the island idle,
opacity 1, surface opacity 1, captureCount 0 and acquiringBackdrop false. No
real authentication, locking or unlocking was automated. SDDM's separate
system installer was not run. No niri validation is claimed.

Required checks before installation: `bun run check` and `bun test` (49 passed),
plus `bun tools/verify-glass-settings.ts` with isolated preferences. This live
verification confirms installation and reload; it is not visual hover QA.
