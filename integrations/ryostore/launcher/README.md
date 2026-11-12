# Tahow launcher bridge

Requires the `tahoe-shell` subshell active. Opens its palette through IPC; all preferences belong to `tahow-shell/settings.json` (`~/.config/tahow-shell/settings.json`, with the legacy `~/.config/tahoe-shell/settings.json` as a read-only fallback).

The bridge refuses an open request and logs the activation requirement when
another subshell is selected. It does not launch a second Tahow runtime.

`settings.json` explicitly leaves Ryoku's shared launcher controls disabled.
Those controls write `~/.config/ryoku/launcher.json`; Tahow instead owns its
General settings and palette overrides in its shared preferences file. Open
the palette's preferences button for those controls, or use the existing
configuration entry point:

```sh
qs -c shell ipc call tahoe settingsTab glass
```

The stable IPC configuration target is `tahoe`, and the Glass page ID is
`glass`. The adapter also accepts Ryoku's generic `settings` surface request.
These are runtime entry points, not extra registry fields. The documented
Ryostore launcher settings contract supports only `capabilities` and
`sections`; it does not declare an external settings action.
