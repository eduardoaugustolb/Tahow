# Local installation

- User requested local installation of the wider refraction and preview fixes.
- Exported to the configured local Ryostore checkout, reviewed registry scope, refreshed catalogue and reinstalled `barstyles`, `launchers` and `lockscreens` / `tahoe-shell` through Ryostore.
- Active installed view matches repository `GlassSettings.qml`, `Sheet.qml` and compiled glass shader byte for byte.
- Backed up preferences and previous native plugin to `/tmp/tahow-local-install-20261118-1795014634617`.
- Atomically replaced the repository build output with the compiled native plugin, unloaded/reloaded it successfully, then ran `ryoku reload`.
- Hyprland IPC reports `compositor-live`, ready, island opacity 1 and capture count 0. Plugin is loaded.
- Canonical preferences hash remained `f19b2b446f5c658225c5054ce25982e41a273401c43a02370020f2acd3950b39` across reload.
- No real lock/authentication or SDDM installation was performed. No niri validation or visual preview comparison is claimed.
