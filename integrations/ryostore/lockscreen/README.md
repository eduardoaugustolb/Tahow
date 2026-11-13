# Tahow lockscreen

Companion qylock theme for Tahow. Host-owned authentication is retained; shared preferences are read from `~/.config/tahow-shell/settings.json` (with the legacy `~/.config/tahoe-shell/settings.json` as a read-only fallback) without writing them.

The boot login runs in SDDM's plain Qt engine, with no session wallpaper socket
or access to your home. `Main.qml` reads `config.background` there. Session-only
Quickshell imports stay in `LiveData.qml`; the translation singleton is plain Qt.

To opt into the boot integration, run from the Tahow checkout:

```sh
sudo bun tools/install-login.ts --user YOUR_LOGIN
```

This installs the theme as `/usr/share/sddm/themes/tahoe-shell`, selects it in
`/etc/sddm.conf.d/zz-tahow.conf`, and provisions
`/var/lib/tahow/wallpapers/<uid>` for the specified user. It backs up a previous
Tahow theme/selection and never restarts SDDM. This is an explicit system install,
separate from installing the session companion through Ryostore.

In Tahow Settings → Lockscreen, upload a PNG, JPEG, WebP or BMP, or enable
**Follow Ryoku wallpaper** (on by default). Requires Bun and ImageMagick's
`magick` on PATH. The upload converts the first image frame to a bounded PNG,
strips metadata and atomically replaces a world-readable boot image outside the
home directory. Uploading manually turns off following; its image persists
across reboot. Following listens to Ryogami's `subscribe wallpaper` publications,
including repeated paths with new content, and reconnects after daemon restarts.
Video wallpapers are unsupported and leave the last valid login image intact.
One selected desktop user's directory supplies the system-wide login image.

To restore the previous SDDM selection, remove `zz-tahow.conf`; the installer does
not change the existing Ryoku selection file. No PAM/fingerprint code or policy
is changed. Actual boot remains a manual check on the target system.
