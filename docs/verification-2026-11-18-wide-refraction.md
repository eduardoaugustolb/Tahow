# Wider optical edge

- Increased the snapshot shader lens band from `bezel * 2.6` to `bezel * 3.9` (50%). Its existing curvature and warp falloffs now extend farther inward.
- Increased the compositor adapter's bulb mapping from `bezel * 1.45` to `bezel * 2.175`, retaining bounds and user preferences.
- Rebuilt Qt shaders and generated widget packages with Bun.
- `bun run check`: passed (147 QML files).
- `bun test`: 52 passed, 0 failed.
- Visual/runtime comparison was not performed; niri is not validated. No installed desktop files were changed.
