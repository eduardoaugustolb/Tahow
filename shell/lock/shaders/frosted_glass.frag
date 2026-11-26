#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 radii;
    vec4 tintColor;
    float bezel;
    float thickness;
    float ior;
    float dispersion;
    float frost;
    float rim;
    float saturation;
    float tintAmount;
    vec4 srcRect;
    float clear;
    float glassPad;
    float shadowAmt;
    float energy;
    vec4 fillet;
    vec4 box;
    float filletInset;
    vec4 sampleBounds;
    float unpremul;
    float innerShadow;
    float prism;
};

layout(binding = 1) uniform sampler2D src;

float sdRoundBox(vec2 p, vec2 b, vec4 r) {
    float rad = p.x > 0.0 ? (p.y > 0.0 ? r.z : r.y) : (p.y > 0.0 ? r.w : r.x);
    rad = min(rad, min(b.x, b.y));
    vec2 q = abs(p) - b + rad;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rad;
}

vec2 boxHalf() {
    return box.z > 0.0 ? box.zw : itemSize * 0.5;
}

float sdfCard(vec2 p) {
    return sdRoundBox(p - box.xy, boxHalf() - glassPad, radii);
}

float sdfPlane(vec2 p) {
    vec2 h = boxHalf();
    return abs(fillet.x) * h.x + abs(fillet.y) * h.y - dot(p - box.xy, fillet.xy) - filletInset;
}

float sdf(vec2 p) {
    float a = sdfCard(p);
    if (fillet.z <= 0.0) return a;
    float b = sdfPlane(p);
    float r = fillet.z;
    vec2 u = max(vec2(r - a, r - b), vec2(0.0));
    return max(r, min(a, b)) - length(u);
}

vec4 fetchBackdrop(vec2 p, float lod) {
    vec2 uv = clamp((p + itemSize * 0.5) / itemSize, max(vec2(0.001), sampleBounds.xy), min(vec2(0.999), sampleBounds.zw));
    vec4 c = textureLod(src, srcRect.xy + uv * srcRect.zw, lod);
    return unpremul > 0.5 ? c : vec4(c.rgb, 1.0);
}

vec3 blurredBackdrop(vec2 p, float radius) {
    float lod = clamp(log2(max(radius * 0.5, 1.0)), 0.0, 5.0);
    vec4 sum = fetchBackdrop(p, lod) * 4.0;
    for (int i = 0; i < 8; ++i) {
        float angle = float(i) * 0.78539816;
        sum += fetchBackdrop(p + vec2(cos(angle), sin(angle)) * radius, lod);
    }
    return sum.a > 0.001 ? sum.rgb / sum.a : tintColor.rgb;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    float distance = sdf(p);
    if (fillet.w > 0.5 && (sdfCard(p) < 0.0 || sdfPlane(p) < 0.0)) {
        fragColor = vec4(0.0);
        return;
    }
    float coverage = clamp(0.5 - distance, 0.0, 1.0);
    float shadow = 0.16 * shadowAmt * (1.0 - smoothstep(-1.0, 9.0, sdf(p - vec2(0.0, 3.0))));
    if (coverage <= 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, shadow * qt_Opacity);
        return;
    }

    float depth = max(-distance, 0.0);
    const vec2 stepPx = vec2(0.75, 0.0);
    vec2 gradient = vec2(sdf(p + stepPx.xy) - sdf(p - stepPx.xy),
                         sdf(p + stepPx.yx) - sdf(p - stepPx.yx));
    vec2 outward = gradient / max(length(gradient), 0.001);
    float halfSize = max(1.0, min(boxHalf().x, boxHalf().y) - glassPad);
    float width = clamp(bezel * mix(2.0, 3.3, prism), 1.0, halfSize);
    float edge = mix(1.0 - clamp(depth / width, 0.0, 1.0), 1.0 - smoothstep(0.0, width, depth), prism);
    float bend = min(width * mix(0.94, 0.87, prism), thickness * mix(9.0, 1.5, prism) * max(ior - 1.0, 0.0));
    vec2 shift = outward * bend * edge * mix(-1.0, 1.0, prism);

    float blur = frost * mix(3.0, 1.0, prism) * mix(mix(0.42, 0.62, prism), 1.0, 1.0 - edge);
    vec3 color = blurredBackdrop(p + shift, blur);
    if (prism > 0.5 && dispersion > 0.0 && edge > 0.0) {
        vec2 split = shift * dispersion;
        color.r = blurredBackdrop(p + shift + split, blur).r;
        color.b = blurredBackdrop(p + shift - split, blur).b;
    } else if (prism <= 0.5 && dot(shift, shift) > 0.01) {
        vec2 split = shift * dispersion;
        vec4 red = fetchBackdrop(p + shift + split, 0.0);
        vec4 green = fetchBackdrop(p + shift, 0.0);
        vec4 blue = fetchBackdrop(p + shift - split, 0.0);
        vec3 alpha = vec3(red.a, green.a, blue.a);
        vec3 detail = vec3(red.r, green.g, blue.b) / max(alpha, vec3(0.001));
        color = mix(color, detail, edge * min(min(alpha.r, alpha.g), alpha.b));
    }

    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luminance), color, saturation);
    color *= 1.0 - 0.07 * smoothstep(0.22, 0.9, luminance) * (1.0 - clear);
    color = mix(color, tintColor.rgb, clamp(tintAmount, 0.0, 1.0));
    color *= 1.0 - 0.18 * innerShadow * exp(-depth / 4.0) * max(outward.y, 0.0);
    float facing = dot(outward, vec2(-0.45, -0.89));
    float highlight = exp(-depth / 0.85) * (0.06 + 0.36 * max(facing, 0.0));
    highlight += exp(-depth / 1.6) * 0.16 * max(-facing, 0.0);
    color += vec3(highlight * rim * (1.0 + 0.25 * energy));
    float alpha = mix(1.0, max(tintAmount, edge), clear);
    fragColor = vec4(clamp(color, 0.0, 1.0) * alpha * coverage,
                     alpha * coverage + shadow * (1.0 - coverage)) * qt_Opacity;
}
