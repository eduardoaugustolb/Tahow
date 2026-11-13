# Login wallpaper, launcher and crash investigation

Environment: Hyprland (reported by `ryoku wm status`), Quickshell 0.3.2,
Qt 6.12.0, Bun 1.4.4. niri was not tested.

The supplied crash `0c3lovfot` is SIGSEGV in the main Ryoku shell, inside
`QQuickItemViewFxItem::itemX`, through item-view extent calculation and width
updates. The trace does not identify which QML view owns the invalid item.
It is not sufficient evidence to attribute the crash to Tahow or the wallpaper.
No fix for that native crash is claimed.

Boot wallpaper previously had an empty source whenever session `LiveData` was
inactive. It now reads SDDM's `config.background`, which the explicit installer
points at a public PNG outside the home directory. The lock translation singleton
also previously imported Quickshell in plain SDDM; session preference reads now
remain in `LiveData`. Authentication handlers are unchanged.

Validation:

- `bun run check`: QML syntax and generated translations passed.
- `bun test`: existing suite plus conversion/publication tests passed.
- Settings → Lockscreen loaded with a temporary config in offscreen Quickshell.
- Plain Qt `qml` loaded the boot theme with a simulated `config.background`;
  `/tmp/tahow-login-qa/boot.png` confirmed the configured image was displayed.
  Offscreen rendering does not validate the shader clock's hardware appearance.
- A fake Ryogami socket received two subscriptions after an intentional
  disconnect; both frames emitted `wallpaperPublished`, including the same path.
- `Shell.AppLaunch.run` was called in a short-lived Quickshell instance on the
  live Wayland session, with a harmless `touch` command. The expected temporary
  marker was created. The previous adapter used an unqualified `AppLaunch`,
  although the service is imported under the `Shell` namespace.
- A full Ryoku adapter cannot be validated offscreen: loading its desktop
  services produced `std::bad_function_call`. This isolated harness failure is
  distinct from the supplied SIGSEGV. The individual launcher service was then
  verified on Wayland instead.

The installed settings have `screenCapture: true`. Palette opening calls
`Host.beginCapture`; previously, `IslandWindow` bound its content opacity to zero
whenever another window was capturing. This caused the visible blink. That global
opacity binding has now been removed: a window may hide only itself during its
own capture. The Island's local fade-out/acquire/fade-in now targets only the
Island item, preserving banners and other content sharing its overlay window.
Notification Center stays hidden until its own capture completes, leaving the
Island visible. Palette and Settings retain their own capture readiness gates.
Other components remain visible, including in the acquired frozen backdrop. The
shared capture counter remains solely for focus/hover guards and diagnostics.

An isolated Wayland/Hyprland harness using source components confirmed:

- During an unrelated capture and Palette opening, Island opacity stayed at 1;
  Palette acquired a valid frame (`frameReady` and `captureHasContent` true).
- During Island acquisition, its own opacity reached 0 and returned to 1 while
  the overlay window's content opacity remained 1.
- During Notification Center acquisition, both Island and overlay opacity
  remained 1; its backdrop was acquired successfully.

The harness used temporary preferences and no lock/authentication component.

## Authorized local installation

At the user's request, exported to the existing local Ryostore checkout and
installed `barstyles/tahoe-shell`, `launchers/tahoe-shell` and
`lockscreens/tahoe-shell` through `ryostore install`. The previous catalogue
products/registries were copied to `/tmp/tahow-local-backup` before export.
No catalogue publication was performed.

Installed the explicit SDDM integration with the system's graphical administrative
authentication. No SDDM restart or session termination was requested. Confirmed
`zz-tahow.conf` selects `tahoe-shell`, and the selected theme points to
`/var/lib/tahow/wallpapers/1000/wallpaper.png`.

Live installation exposed that systemd's shell PATH lacks the interactive mise
Bun installation. The uploader command now retains PATH and adds conventional
Bun/mise runtime directories. Re-exported/reinstalled the barstyle and reloaded
with `ryoku reload`; the normal Ryogami publication then produced the 1.4 MiB
world-readable PNG without an administrative write. The installer now also
accepts an already-provisioned wallpaper directory on subsequent updates.

Final live IPC confirms `captureCount: 0`, Island and overlay opacity both 1,
and the Palette closed. `bun run check`, all 37 tests and `git diff --check`
passed. Actual next-boot SDDM display remains a manual check.

No real authentication, unlock, SDDM restart, catalogue publication or installation
is part of the automated checks. Source changes still require export/install
through the documented routes before affecting the installed desktop.
