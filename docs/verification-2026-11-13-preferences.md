# Preference loss on startup and shutdown

Environment: Quickshell 0.3.2, Qt 6.12.0, Bun 1.4.4. Integration tests ran
Quickshell offscreen with the software backend and isolated XDG_CONFIG_HOME
stores. The available desktop provider is Hyprland v0.57.2. No niri runtime
validation or installed-shell reload was performed. User preferences were
read for diagnosis but were not modified by the tests or this fix.

## Reproduction

A minimal harness imported Config lazily, with canonical preferences containing
`topMargin: 11` and `overrides.palette.columns: 9`, plus a legacy file containing
`topMargin: 99`. The original Config returned defaults on first access, then the
legacy FileView completed before the independent canonical existence probe.
`migrateLegacy()` consequently overwrote the canonical file with legacy values,
erasing its overrides. Instrumentation showed legacy loading before the probe.
A pending 120 ms persistence timer also left the most recent UI edit unsaved
when the process quit immediately afterward.

## Change

Startup now explicitly completes the canonical read before considering the
legacy source. There is one JsonAdapter; legacy migration copies only known
preferences and component overrides once. Missing files permit migration or
fresh defaults, but malformed/unreadable files do not. No live legacy watcher
can overwrite migrated settings.

Preference writes now complete atomically before returning. This removes the
pending-save shutdown window and prevents a self-watch reload from overtaking
an unfinished write. Small JSON writes briefly block the UI thread; rapid-edit
integration tests exercise that path. Save failures are logged and exposed as
Config.persistenceError. External edits still reload.

## Verification

- `bun run check`: passed; 133 QML files and generated translations verified.
- `bun test`: passed; 49 tests, including nine actual-Quickshell persistence tests.
- `bun tools/verify-glass-settings.ts`: passed; actual slider, exact numeric input,
  scope inheritance, partial reset and disk readback verified offscreen.
- Persistence regressions cover canonical priority over legacy across restarts,
  immediate quit after editing, one-time migration, fresh directories, malformed
  canonical data, rapid edits plus self-watch notifications, external edits,
  unreadable canonical paths and reported write failures.

No settings UI screenshots or compositor-specific rendering claims are made.
