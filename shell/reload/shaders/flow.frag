#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
};
layout(binding=1) uniform sampler2D wallpaper;
void main() {
    vec2 uv = qt_TexCoord0;
    float t = phase * 6.2831853;
    // A periodic flow field bends the glass contours locally, never pans the image.
    vec2 flow = vec2(
        sin(uv.y * 7.0 + t) * .017 + sin(uv.x * 9.0 - uv.y * 4.0 - t) * .008,
        sin(uv.x * 6.0 - t) * .020 + cos(uv.y * 8.0 + uv.x * 3.0 + t) * .009);
    vec2 envelope = sin(uv * 3.14159265);
    vec2 p = uv + flow * envelope;
    vec2 dispersion = flow * .025;
    vec3 c = vec3(texture(wallpaper, clamp(p + dispersion, 0., 1.)).r,
                  texture(wallpaper, clamp(p, 0., 1.)).g,
                  texture(wallpaper, clamp(p - dispersion, 0., 1.)).b);
    // Traveling caustic illumination follows the same flowing surface.
    float light = sin(uv.x * 5.0 + uv.y * 4.0 - t) * .025;
    c *= 1.0 + light;
    fragColor = vec4(c, 1.) * qt_Opacity;
}
