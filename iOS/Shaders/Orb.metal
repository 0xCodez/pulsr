#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The "Halo" recovery orb. Mirrors the WebGL prototype in docs/design/lumen-iris.html.
// The view this is applied to is 1.8x the sphere's diameter so the glow can spread into the screen.

static float orbBand(float2 q, float t, float amp, float fr, float sp, float ph, float th) {
    float x = q.x;
    float env = pow(clamp(1.0 - x * x, 0.0, 1.0), 1.35);
    float y0 = env * (amp * sin(fr * x + t * sp + ph) + amp * 0.38 * sin(fr * 2.1 * x - t * sp * 1.35 + ph * 1.7));
    float h = th * (0.6 + 0.4 * sin(1.3 * x + t * 0.75 + ph)) * env + 0.012;
    float d = (q.y - y0) / h;
    float crest = exp(-d * d * 1.5);
    float under = q.y < y0 ? exp((q.y - y0) / (h * 3.2 + 0.03)) * 0.42 : 0.0;
    return (crest + under) * env;
}

[[ stitchable ]] half4 haloOrb(float2 position, half4 color, float2 size, float time, float beat,
                               float lightMode, float spread, half4 c0, half4 c1, half4 c2, half4 c3) {
    const float scale = 1.8;
    float2 p = (position / size * 2.0 - 1.0) * scale;
    p.y = -p.y;
    float t = time;
    float r = length(p);
    float rc = min(r, 1.0);
    float2 q = p * (1.0 + 0.22 * rc * rc);

    float3 C0 = float3(c0.rgb), C1 = float3(c1.rgb), C2 = float3(c2.rgb), C3 = float3(c3.rgb);
    float amp = 0.24 * (0.75 + 0.3 * beat);
    float3 L = C0 * orbBand(q, t, amp, 2.3, 0.85, 0.0, 0.15)
             + C1 * orbBand(q, t, amp * 0.85, 2.9, -0.7, 1.9, 0.13)
             + C2 * orbBand(q, t, amp * 1.1, 1.9, 0.52, 3.7, 0.11)
             + C3 * orbBand(q, t, amp * 0.65, 3.4, 1.05, 5.2, 0.075) * 0.7;

    // drifting colour clouds
    float3 F = float3(0.0);
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float2 c = float2(0.42 * sin(t * 0.29 + fk * 2.1), 0.26 * cos(t * 0.25 + fk * 1.7) - 0.04);
        float3 ck = k == 0 ? C0 : (k == 1 ? C1 : C2);
        F += ck * exp(-dot(q - c, q - c) * 2.2);
    }
    L += F * 0.08;

    float lum = dot(L, float3(0.3333));
    L += float3(1.0) * smoothstep(1.15, 2.6, lum) * 0.55;
    L *= 0.78 + 0.36 * beat;

    // the sphere exists only as light: a luminous volume and a soft coloured edge glow, no outline
    float m = 1.0 - smoothstep(0.8075, 1.35, r);
    float3 tint = (C0 + C1 + C2) * 0.3333;
    float ang = atan2(p.y, p.x);
    float3 spectral = 0.55 + 0.45 * cos(6.2831 * (float3(0.0, 0.33, 0.67) + ang * 0.32 + t * 0.03));
    float side = exp(-pow(p.y * 2.2, 2.0));
    float vol = pow(clamp(1.0 - r / 1.1225, 0.0, 1.0), 1.15) * (0.75 - 0.25 * p.y);
    L += mix(tint, float3(1.0), 0.15) * vol * 0.22;
    L += mix(spectral, tint, 0.4) * exp(-pow((r - 0.96) / 0.11, 2.0)) * 0.38 * (0.35 + 0.65 * side) * (0.8 + 0.4 * beat);

    float glow = exp(-pow(max(r - 0.15, 0.0) / spread, 1.6)) * (1.0 - smoothstep(1.4, 1.8, r));
    float gA = glow * mix(0.30, 0.22, lightMode) * (0.7 + 0.5 * beat);

    float3 light = L * m;
    float lA = clamp(max(max(light.r, light.g), light.b), 0.0, 1.0);
    if (lightMode > 0.5) { light *= 1.05; lA = clamp(lA * 1.1, 0.0, 1.0); }

    // premultiplied: light over glow
    float3 col = light + tint * gA * (1.0 - lA);
    float a = lA + gA * (1.0 - lA);
    return half4(half3(min(col, float3(1.0))), half(clamp(a, 0.0, 1.0)));
}

// Fine film grain for screen backgrounds.
[[ stitchable ]] half4 filmGrain(float2 position, half4 color, float strength) {
    float n = fract(sin(dot(floor(position), float2(12.9898, 78.233))) * 43758.5453);
    return half4(half3(n), 1.0h) * half(strength);
}
