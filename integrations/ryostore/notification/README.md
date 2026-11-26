# Tahow Banner

A liquid-glass notification card for Ryoku, in the Tahow visual language: a
translucent dark surface with a soft top highlight, an accent-tinted app icon,
and glass action buttons. It is the notification half of the Tahow design
system, so a banner matches the Tahow palette, island and palette surfaces.

The card is self-contained and sandbox-compliant: it runs from its own installed
copy, reaches only global modules (`shell.services` for `Notifs`,
`Ryoku.Ui.Singletons` for tokens/icons/i18n), and never creates a window —
Ryoku's notification host owns position, spacing, arrival/dismiss transitions,
timers, DND and history.

## What it draws

- App name, accent icon tile, summary and body (styled text).
- An optional image when the user enables notification images.
- Action buttons: each invokes once and then dismisses; the default action fires
  on a body tap; the close button dismisses.

## Install and enable

1. Install from **RyoStore → Notifications → Tahow Banner**.
2. Pick it in **Settings → Overlays → Notification design** (`designs.notification
   = "tahoe-shell"`). Installing never switches the active design by itself.
3. Send a test: `notify-send "Tahow" "Glass banner"`.

The card renders under any barStyle and does not require the Tahow subshell.

## Files

- `Card.qml` — the popup card (the whole design).
- `LICENSE`, `README.md`, `PROVENANCE.txt`.

The authoring contract, allowed imports and checklist live in the catalogue's
`notifications/AUTHORING.md`.
