#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 sourceRect;
    float phase;
};
layout(binding=1) uniform sampler2D backdrop;
layout(binding=2) uniform sampler2D glyphs;
vec2 liquidUv(vec2 uv) {
    float t = phase * 6.2831853;
    // Warp the glyph silhouette itself. Different parts of each joined stroke
    // stretch and relax, rather than moving the word as a rigid object.
    return uv + vec2(sin(uv.x*13.0 + uv.y*5.0 - t)*.006
                   + sin(uv.y*11.0 + t)*.003,
                     sin(uv.x*16.0 - t)*.012
                   + cos(uv.x*8.0 + uv.y*6.0 + t)*.005);
}
float coverage(vec2 uv) { return texture(glyphs, liquidUv(uv)).a; }
float field(vec2 uv) {
    vec2 p = 1.0 / itemSize;
    float a = coverage(uv) * .2;
    for (int i=1; i<=4; i++) {
        vec2 d = p * float(i) * 1.5;
        a += .05 * (coverage(uv+vec2(d.x,0)) + coverage(uv-vec2(d.x,0))
                  + coverage(uv+vec2(0,d.y)) + coverage(uv-vec2(0,d.y)));
    }
    return a;
}
void main() {
    vec2 uv = qt_TexCoord0;
    float a = coverage(uv);
    if (a < .005) { fragColor=vec4(0); return; }
    vec2 px = 1.0 / itemSize;
    vec2 g = vec2(field(uv+vec2(px.x,0))-field(uv-vec2(px.x,0)), field(uv+vec2(0,px.y))-field(uv-vec2(0,px.y)));
    float t = phase * 6.2831853;
    vec2 bend = g * .12 + vec2(sin(uv.y*8.+t), cos(uv.x*7.+t)) * .008;
    vec2 p = sourceRect.xy + (vec2(.5)+(uv-.5)*.92+bend)*sourceRect.zw;
    vec2 split = g * sourceRect.zw * .012;
    vec3 c = vec3(texture(backdrop,clamp(p+split,0.,1.)).r,texture(backdrop,clamp(p,0.,1.)).g,texture(backdrop,clamp(p-split,0.,1.)).b);
    float edge = clamp(length(g)*3.5,0.,1.);
    float light = pow(max(0., .5+.5*sin(uv.x*8.-uv.y*3.+t)),12.);
    c = mix(c,vec3(.86,.94,1.),.18) + edge*(.18+.32*max(0.,dot(normalize(g+vec2(.0001)),normalize(vec2(-.6,-1.))))) + light*.19;
    fragColor=vec4(clamp(c,0.,1.)*a,a)*qt_Opacity;
}
