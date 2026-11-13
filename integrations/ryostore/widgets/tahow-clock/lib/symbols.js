.pragma library

// Original Tahoe glyphs, Eduardo Augusto and contributors, 2026. AGPL-3.0.
var paths = {
  "settings": "<path d=\"M9.5 3.5h5l.7 2.4 2 .9 2.2-.6 2.5 4.3-1.6 1.9v2.2l1.6 1.9-2.5 4.3-2.2-.6-2 .9-.7 2.4h-5l-.7-2.4-2-.9-2.2.6-2.5-4.3 1.6-1.9v-2.2l-1.6-1.9 2.5-4.3 2.2.6 2-.9z\" transform=\"translate(0 -1) scale(1 .95)\"/><circle cx=\"12\" cy=\"12\" r=\"3.1\"/>",
  "home": "<path d=\"m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z\"/>",
  "island": "<rect x=\"2.5\" y=\"7\" width=\"19\" height=\"10\" rx=\"5\"/><circle cx=\"7.5\" cy=\"12\" r=\"1.3\"/><path d=\"M12 10h5m-5 4h3\"/>",
  "keyboard": "<rect x=\"2.5\" y=\"5.5\" width=\"19\" height=\"13\" rx=\"3\"/><path d=\"M6 9h.01M10 9h.01M14 9h.01M18 9h.01M6 12h.01M10 12h.01M14 12h.01M18 12h.01M7 15h10\"/>",
  "lock": "<rect x=\"5.5\" y=\"10\" width=\"13\" height=\"11\" rx=\"3\"/><path d=\"M8 10V7a4 4 0 0 1 8 0v3m-4 5v2\"/>",
  "search": "<circle cx=\"10.5\" cy=\"10.5\" r=\"6.5\"/><path d=\"m15.5 15.5 5 5\"/>",
  "apps": "<rect x=\"3.5\" y=\"3.5\" width=\"6\" height=\"6\" rx=\"1.8\"/><rect x=\"14.5\" y=\"3.5\" width=\"6\" height=\"6\" rx=\"1.8\"/><rect x=\"3.5\" y=\"14.5\" width=\"6\" height=\"6\" rx=\"1.8\"/><rect x=\"14.5\" y=\"14.5\" width=\"6\" height=\"6\" rx=\"1.8\"/>",
  "music_note": "<path d=\"M9 17V5l11-2v12M9 8l11-2\"/><ellipse cx=\"6\" cy=\"18\" rx=\"3\" ry=\"2.5\"/><ellipse cx=\"17\" cy=\"16\" rx=\"3\" ry=\"2.5\"/>",
  "tune": "<path d=\"M4 6h5m5 0h6M4 12h10m5 0h1M4 18h2m5 0h9\"/><circle cx=\"11.5\" cy=\"6\" r=\"2.5\"/><circle cx=\"16.5\" cy=\"12\" r=\"2.5\"/><circle cx=\"8.5\" cy=\"18\" r=\"2.5\"/>",
  "timer": "<circle cx=\"12\" cy=\"13.5\" r=\"7.5\"/><path d=\"M9 2h6m-3 0v4m6.5 1 2-2M12 9v5l3 2\"/>",
  "notifications": "<path d=\"M6 9a6 6 0 0 1 12 0v5l2 3H4l2-3zM9.5 20a3 3 0 0 0 5 0\"/>",
  "info": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 11v6m0-10v.01\"/>",
  "wifi": "<path d=\"M2 8a15 15 0 0 1 20 0M5.5 12a10 10 0 0 1 13 0M9 16a5 5 0 0 1 6 0M12 20h.01\"/>",
  "bluetooth": "<path d=\"m7 7 10 10-5 4V3l5 4L7 17\"/>",
  "monitor": "<rect x=\"2.5\" y=\"3.5\" width=\"19\" height=\"13\" rx=\"2.5\"/><path d=\"M12 17v4m-5 0h10\"/>",
  "nightlight": "<path d=\"M20.5 14.5A9 9 0 0 1 9.5 3.5a9 9 0 1 0 11 11z\"/>",
  "play_arrow": "<path d=\"M7 4.5v15l12-7.5z\"/>",
  "pause": "<path d=\"M7 4v16m10-16v16\" stroke-width=\"4\"/>",
  "skip_next": "<path d=\"m4 5 11 7-11 7zM19 5v14\"/>",
  "skip_previous": "<path d=\"m20 5-11 7 11 7zM5 5v14\"/>",
  "close": "<path d=\"m6 6 12 12M18 6 6 18\"/>",
  "chevron_left": "<path d=\"m15 5-7 7 7 7\"/>",
  "chevron_right": "<path d=\"m9 5 7 7-7 7\"/>",
  "palette": "<path d=\"M21 11a9 9 0 1 0-9 10c2 0 3-1 2-3s0-3 2-3h2c2 0 3-2 3-4z\"/><path d=\"M7 8h.01M11 5h.01M16 7h.01M5 13h.01\" stroke-width=\"2.8\"/>",
  "account_circle": "<circle cx=\"12\" cy=\"8\" r=\"3.5\"/><path d=\"M4 21v-2a8 6 0 0 1 16 0v2\"/>",
  "bedtime": "<path d=\"M20.5 14.5A9 9 0 0 1 9.5 3.5a9 9 0 1 0 11 11z\"/>",
  "volume_up": "<path d=\"M3 9h4l5-5v16l-5-5H3zM16 8a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14\"/>",
  "mic": "<rect x=\"9\" y=\"2.5\" width=\"6\" height=\"12\" rx=\"3\"/><path d=\"M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3m-3 0h6\"/>",
  "power_settings_new": "<path d=\"M12 2v10m-5-7a9 9 0 1 0 10 0\"/>",
  "check": "<path d=\"m4 12 5 5L20 6\"/>",
  "logout": "<path d=\"M9 3H4v18h5m-1-9h13m-5-5 5 5-5 5\"/>",
  "refresh": "<path d=\"M20 9a8 8 0 1 0 .2 6M20 3v6h-6\"/>",
  "light_mode": "<circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 1v2m0 18v2M1 12h2m18 0h2M4 4l1.5 1.5m13 13L20 20M4 20l1.5-1.5m13-13L20 4\"/>"
};
var aliases = {"smart_button":"island","dashboard":"island","grid_view":"apps","control_camera":"tune","dark_mode":"nightlight","person":"account_circle","arrow_back":"chevron_left","arrow_forward":"chevron_right","graphic_eq":"music_note","stopwatch":"timer","settings_suggest":"settings"};
function has(name) { return !!paths[aliases[name] || name]; }
function image(name, filled, color) { const path = paths[aliases[name] || name]; if (!path) return ""; return "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="'+(filled?color:"none")+'" fill-opacity="'+(filled?".14":"1")+'" stroke="'+color+'" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">'+path+'</svg>'); }
