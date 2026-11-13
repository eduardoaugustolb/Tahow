#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
};
layout(binding=1) uniform sampler2D logo;
void main() {
    vec2 uv = qt_TexCoord0;
    float t = phase * 6.2831853;
    // The same periodic silhouette field as the reload signature: individual
    // parts stretch and relax while the overall composition stays anchored.
    vec2 p = uv + vec2(sin(uv.x*13.0+uv.y*5.0-t)*.006 + sin(uv.y*11.0+t)*.003,
                       sin(uv.x*16.0-t)*.012 + cos(uv.x*8.0+uv.y*6.0+t)*.005);
    vec4 c = texture(logo, p);
    float light = pow(max(0., .5+.5*sin(uv.x*8.-uv.y*3.+t)),12.);
    c.rgb = min(c.rgb * (1.0 + .08*light), vec3(c.a));
    fragColor = c * qt_Opacity;
}
