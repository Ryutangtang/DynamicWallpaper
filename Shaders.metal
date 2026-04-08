#include <metal_stdlib>
using namespace metal;

// ─── Shared ───────────────────────────────────────────────────────────────────

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float  time;
    float2 resolution;
};

// Fullscreen triangle strip vertex shader
vertex VertexOut vertex_fullscreen(uint vid [[vertex_id]]) {
    float2 pos[4] = {
        float2(-1, -1), float2( 1, -1),
        float2(-1,  1), float2( 1,  1)
    };
    VertexOut out;
    out.position = float4(pos[vid], 0, 1);
    out.uv = pos[vid] * 0.5 + 0.5;
    return out;
}

// ─── Utilities ────────────────────────────────────────────────────────────────

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float2 hash2(float2 p) {
    float2 q = float2(dot(p, float2(127.1, 311.7)),
                      dot(p, float2(269.5, 183.3)));
    return fract(sin(q) * 43758.5453);
}

float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + float2(1, 0));
    float c = hash(i + float2(0, 1));
    float d = hash(i + float2(1, 1));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 6; i++) {
        v += a * smoothNoise(p);
        p = p * 2.0 + float2(3.2, 1.7);
        a *= 0.5;
    }
    return v;
}

// ─── Preset: Particles ────────────────────────────────────────────────────────

fragment float4 fragment_particles(VertexOut in [[stage_in]],
                                   constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time;

    float3 col = float3(0.02, 0.02, 0.08);
    float2 aspect = float2(u.resolution.x / u.resolution.y, 1.0);

    // 80 virtual particles via grid hash
    for (int i = 0; i < 80; i++) {
        float fi = float(i);
        float2 seed = float2(fi * 0.3713, fi * 0.7823);
        float2 origin = hash2(seed);

        float speed = 0.05 + hash(seed + 0.5) * 0.1;
        float angle = hash(seed + 1.3) * 6.283 + t * speed;
        float radius = 0.1 + hash(seed + 2.1) * 0.3;

        float2 pos = origin + float2(cos(angle), sin(angle)) * radius;
        pos = fract(pos);

        float2 diff = (uv - pos) * aspect;
        float dist = length(diff);

        float3 hue = float3(
            0.5 + 0.5 * sin(fi * 0.4 + t * 0.2),
            0.4 + 0.4 * sin(fi * 0.7 + 1.0),
            0.8 + 0.2 * sin(fi * 1.1 + 2.0)
        );

        float glow = exp(-dist * 80.0) * 0.8;
        float core = exp(-dist * 400.0) * 1.5;
        col += hue * (glow + core);
    }

    // Subtle nebula bg
    float n = fbm(uv * 3.0 + t * 0.02);
    col += float3(0.0, 0.02, 0.08) * n;

    return float4(col, 1.0);
}

// ─── Preset: Aurora ───────────────────────────────────────────────────────────

fragment float4 fragment_aurora(VertexOut in [[stage_in]],
                                constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time * 0.3;

    float3 col = float3(0.0, 0.01, 0.03);

    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float speed = 0.1 + fi * 0.07;
        float2 p = float2(uv.x + sin(t * speed + fi * 1.3) * 0.1,
                          uv.y + cos(t * speed * 0.7 + fi * 0.9) * 0.05);

        float band = fbm(float2(p.x * 2.0 + t * 0.1 + fi, p.y * 0.8));
        float mask = exp(-pow(uv.y - 0.4 - sin(uv.x * 2.0 + t * 0.2 + fi) * 0.15, 2.0) * 20.0);

        float3 c = mix(
            float3(0.0, 0.8, 0.5),
            float3(0.3, 0.2, 1.0),
            fract(fi * 0.37 + t * 0.05)
        );
        col += c * band * mask * 0.5;
    }

    // Stars
    float2 starGrid = uv * float2(u.resolution.x, u.resolution.y) / 4.0;
    float2 si = floor(starGrid);
    float2 sf = fract(starGrid);
    float s = hash(si);
    if (s > 0.95) {
        float b = exp(-length(sf - 0.5) * 20.0) * s * 0.6;
        col += float3(b);
    }

    return float4(saturate(col), 1.0);
}

// ─── Preset: Nebula ───────────────────────────────────────────────────────────

fragment float4 fragment_nebula(VertexOut in [[stage_in]],
                                constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    uv.x *= u.resolution.x / u.resolution.y;
    float t = u.time * 0.05;

    float2 p = uv;
    float3 col = float3(0.0);

    // Layered fbm clouds
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float2 offset = float2(cos(t + fi * 1.3), sin(t * 0.7 + fi * 0.9)) * 0.2;
        float n = fbm(p * (1.5 + fi * 0.3) + offset);

        float3 layerCol = mix(
            float3(0.4, 0.0, 0.6),
            float3(0.0, 0.3, 0.8),
            fract(fi * 0.25 + t * 0.1)
        );
        layerCol = mix(layerCol, float3(1.0, 0.4, 0.1), n * 0.5);

        col += layerCol * pow(n, 2.0) * 0.6;
    }

    // Bright core
    float r = length(p);
    col += float3(1.0, 0.8, 0.4) * exp(-r * r * 2.0) * 0.4;

    // Stars
    float2 sg = in.uv * float2(u.resolution.x, u.resolution.y) / 3.0;
    float2 si = floor(sg), sf = fract(sg);
    float s = hash(si);
    if (s > 0.96) {
        col += float3(exp(-length(sf - 0.5) * 25.0) * s);
    }

    return float4(saturate(col), 1.0);
}

// ─── Preset: Wave ─────────────────────────────────────────────────────────────

fragment float4 fragment_wave(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time;
    float aspect = u.resolution.x / u.resolution.y;

    float3 col = float3(0.0, 0.02, 0.06);

    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float freq = 2.0 + fi * 1.5;
        float speed = 0.3 + fi * 0.1;
        float amp = 0.04 - fi * 0.005;
        float yOff = 0.2 + fi * 0.12;

        float wave = sin(uv.x * freq * 3.14159 * 2.0 * aspect - t * speed + fi * 0.8) * amp;
        float dist = abs(uv.y - yOff - wave);
        float line = exp(-dist * 80.0);

        float3 c = mix(
            float3(0.0, 0.6, 1.0),
            float3(0.5, 0.1, 1.0),
            fi / 6.0
        );
        col += c * line * (0.6 + 0.4 * sin(t * 0.5 + fi));
    }

    // Reflective sheen at bottom
    float sheen = smoothstep(0.7, 1.0, uv.y) * 0.3;
    col += float3(0.0, 0.3, 0.6) * sheen;

    return float4(saturate(col), 1.0);
}
