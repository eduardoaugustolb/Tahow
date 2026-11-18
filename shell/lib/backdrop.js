.pragma library

// Physical texel budget, independent of output scale. Keep logical coordinates
// for sampling; only the intermediate backing texture is reduced.
function size(width, height) {
    width = Number.isFinite(width) && width > 0 ? width : 1;
    height = Number.isFinite(height) && height > 0 ? height : 1;
    const scale = Math.min(1, 2048 / Math.max(width, height), Math.sqrt(2073600 / (width * height)));
    return {width: Math.max(1, Math.floor(width * scale)), height: Math.max(1, Math.floor(height * scale))};
}
