# Tahow translations

`en-US.json` and `pt-BR.json` are the canonical catalogs. Keys are English source strings; unknown strings pass through unchanged. Edit both catalogs together, then run `bun tools/sync-i18n.ts`. CI or local checks can use `bun tools/sync-i18n.ts --check`.

Portuguese translations combine original Tahow translations and matching entries from Ryoku's installed `/usr/share/ryoku/i18n/pt_BR.json` and `pt.json` catalogs (Ryoku, AGPL-3.0; see the project's license and upstream attribution). English technical names, commands, device names, and font names remain unchanged where appropriate. No build step reads the host's Ryoku files: the checked-in JSON is self-contained.

The language policy defaults to `auto`: inherit Ryoku's language when available, otherwise use the system locale. Explicit Tahow selection takes priority. Portuguese variants normalize to `pt-BR`; unsupported languages fall back to `en-US`. Missing translated keys fall back to English, then the original source string. Dates use the selected Qt locale.
