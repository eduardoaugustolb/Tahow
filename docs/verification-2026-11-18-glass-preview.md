# Glass settings preview consistency

- Removed the opaque preview underlay and duplicate glass tint; regular surfaces now use one material veil.
- Preview optics respect capture being disabled and black material selection.
- Lockscreen preview uses the lockscreen shader and shader tint, without another veil.
- Palette fallback now applies tint once, accepts zero frost and follows configured rim strength/toggle.
- `bun tools/verify-glass-settings.ts`: passed with isolated preferences and Qt offscreen/software backend, including preview bindings, capture/material switching and lock shader selection.
- `bun run check`: passed (147 QML files).
- `bun test`: 52 passed, 0 failed.
- The software backend verifies controls and bindings, not GPU shader pixels. Live compositor appearance and niri were not visually validated. Installed desktop files were not modified.
