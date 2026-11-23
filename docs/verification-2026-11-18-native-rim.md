# Native rim control

- The native acrylic highlight previously ignored the configured specular rim toggle and strength.
- Added a bounded per-region rim uniform to the Tahow-owned shader variant. Refraction, aberration and shadow retain separate controls.
- Island and palette forward their effective rim settings; the settings sidebar disables its highlight.
- Rebuilt native library, exported/reinstalled the local barstyle through Ryostore and reloaded the plugin and shell on Hyprland.
- User preferences now disable glass rim and lock rim; stronger optical settings remain intact. Previous settings and library backed up under `/tmp`.
- `bun run check` passed; `bun test`: 52 passed. Native C++ build passed. After reconnection, live IPC reports compositor-live ready, liquidMix 1 and island/surface opacity 1.
- Live startup exercises native shader compilation. No pixel comparison or niri validation was performed.

## Settings control

- Renamed the existing `rimStrength` slider to “Rim intensity” / “Intensidade da borda”; reused existing persistence, scope overrides and reset handling.
- Isolated Qt software-backend settings verification passed, including intensity reaching the preview and the toggle disabling it. `bun run check` passed; all 52 tests passed.
- Regenerated translations, exported and reinstalled the local barstyle through Ryostore, then reloaded the shell. No new width control or visual pixel comparison was added.
