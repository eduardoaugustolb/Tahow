#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 sourceRect;
    float strength;
};
layout(binding = 1) uniform sampler2D backdrop;
layout(binding = 2) uniform sampler2D glyphs;
float field(vec2 uv) {
    vec2 p = 1.0 / itemSize;
    float a = texture(glyphs, uv).a * 0.2;
    for (int i = 1; i <= 4; ++i) {
        vec2 d = p * float(i) * 1.7;
        a += (texture(glyphs, uv + vec2(d.x, 0)).a
            + texture(glyphs, uv - vec2(d.x, 0)).a
            + texture(glyphs, uv + vec2(0, d.y)).a
            + texture(glyphs, uv - vec2(0, d.y)).a) * 0.05;
    }
    return a;
}
void main() {
    vec2 uv = qt_TexCoord0;
    float coverage = texture(glyphs, uv).a;
    if (coverage < 0.005) { fragColor = vec4(0); return; }
    vec2 px = 1.0 / itemSize;
    vec2 gradient = vec2(field(uv + vec2(px.x, 0)) - field(uv - vec2(px.x, 0)),
                         field(uv + vec2(0, px.y)) - field(uv - vec2(0, px.y)));
    vec3 normal = normalize(vec3(-gradient * 9.0, 1.0));
    vec3 ray = refract(vec3(0, 0, -1), normal, 1.0 / 1.65);
    vec2 offset = ray.xy / max(0.2, -ray.z) * strength * px;
    // UVs remain in full-wallpaper coordinates, so every numeral acts as a lens.
    vec2 sampleUv = sourceRect.xy + (vec2(0.5) + (uv - vec2(0.5)) * 0.90 + offset) * sourceRect.zw;
    vec2 split = offset * sourceRect.zw * 0.08;
    vec3 col = vec3(texture(backdrop, clamp(sampleUv + split, 0.0, 1.0)).r,
                    texture(backdrop, clamp(sampleUv, 0.0, 1.0)).g,
                    texture(backdrop, clamp(sampleUv - split, 0.0, 1.0)).b);
    // Clear glass: wallpaper carries the material, without directional bevel lighting.
    col = mix(col, vec3(0.67, 0.88, 1.0), 0.20);
    col = min(col * 1.10 + vec3(0.035), vec3(1.0));
    float edge = clamp(length(gradient) * 3.0, 0.0, 1.0);
    col = mix(col, vec3(0.82, 0.95, 1.0), edge * 0.22);
    fragColor = vec4(col * coverage, coverage) * qt_Opacity;
}
