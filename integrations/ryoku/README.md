# Ryoku catalogue and configuration contract

Tahow is distributed through the `barstyles/tahoe-shell` product, with the
`subshell` tag and the existing `barStyle` activation ID. The Ryostore
contribution guide says subshells share barstyle activation; it does not
define a separate subshell registry or package format.

The own-preferences entry point is the stable IPC target `tahoe`; the Glass
page is `settingsTab glass`. Ryoku's generic `settings` surface is also
handled by the adapter. The launcher companion's `settings.json` follows
the [documented launcher contract](https://github.com/Ryoku-dev/ryostore/blob/main/launchers/AUTHORING.md).
It advertises no shared controls because those would write the host's
`launcher.json`, while Tahow reads its own General/palette preferences.
The contract offers `capabilities` and `sections`, not a custom settings
command or configuration target field.

## Visibility compatibility

Inspection on 2026-11-12 found that the installed Hub's
`barstudio/Subshells.js` filters that page by a fixed ID list. The
[current upstream module](https://github.com/Ryoku-dev/ryoku/blob/main/ryoku/hub/quickshell/barstudio/Subshells.js)
also uses a fixed list. Neither consumes the registry's `subshell` tag or a
configuration identifier. Therefore a catalogue tag alone cannot currently
make Tahow appear in that filtered Hub page. No host source or installed
file is modified by this project, and no speculative registry field is
advertised as supported. Tahow remains selectable as an installed barstyle.

## Catalogue migration

`bun tools/export-ryostore.ts --to /path/to/ryostore` updates the three existing
`tahoe-shell` registrations and removes the legacy `launchers/tahoe` listing.
This leaves a single discoverable Tahow Palette entry. The exporter keeps the
old launcher directory and manifest for existing installation receipts; it
does not uninstall anything, rewrite a user's selected launcher, publish the
catalogue, or update the installed desktop. Existing users of the old palette
must select Tahow Palette after installing and activating the Tahow subshell.

Review the catalogue diff before publishing. Exporting does not alter the
installed Hub's filtering behavior.
