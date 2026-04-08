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

float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

// Gradient noise (-1 ~ 1)
float gnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic

    float a = dot(hash2(i),               f);
    float b = dot(hash2(i + float2(1,0)), f - float2(1,0));
    float c = dot(hash2(i + float2(0,1)), f - float2(0,1));
    float d = dot(hash2(i + float2(1,1)), f - float2(1,1));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Layered FBM
float fbm(float2 p, int oct) {
    float v = 0.0, a = 0.5, freq = 1.0;
    for (int i = 0; i < oct; i++) {
        v += a * gnoise(p * freq);
        freq *= 2.1;
        a *= 0.48;
    }
    return v;
}

// Domain-warped FBM (핵심 — 출력이 입력 좌표를 왜곡)
float warpFbm(float2 p, float t, int oct) {
    float2 q = float2(
        fbm(p + float2(0.0,  0.0) + float2(t * 0.07, t * 0.05), oct),
        fbm(p + float2(5.2,  1.3) + float2(t * 0.06, t * 0.04), oct)
    );
    float2 r = float2(
        fbm(p + 4.0 * q + float2(1.7, 9.2) + float2(t * 0.04, 0.0), oct),
        fbm(p + 4.0 * q + float2(8.3, 2.8) + float2(0.0, t * 0.03), oct)
    );
    return fbm(p + 4.0 * r, oct);
}

// HSL → RGB
float3 hsl2rgb(float h, float s, float l) {
    float3 rgb = clamp(abs(fmod(h * 6.0 + float3(0,4,2), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return l + s * (rgb - 0.5) * (1.0 - abs(2.0 * l - 1.0));
}

// ─── Preset: Fluid ────────────────────────────────────────────────────────────
// 잉크가 물에 천천히 번지는 느낌. 도메인 워핑 3단계.

fragment float4 fragment_fluid(VertexOut in [[stage_in]],
                               constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    uv.x *= u.resolution.x / u.resolution.y;
    float t = u.time * 0.18;

    float n = warpFbm(uv * 1.8, t, 7);

    // 색상: 딥 블루-퍼플-틸 팔레트
    float hue  = 0.58 + n * 0.15 + t * 0.012;
    float sat  = 0.6 + n * 0.3;
    float lum  = 0.08 + smoothstep(-0.6, 0.8, n) * 0.28;

    float3 col = hsl2rgb(hue, sat, lum);

    // 미세 표면 노이즈 (질감)
    float detail = gnoise(uv * 12.0 + t * 0.3) * 0.03;
    col += detail;

    // 비네팅
    float2 vc = in.uv - 0.5;
    col *= 1.0 - dot(vc, vc) * 1.2;

    return float4(saturate(col), 1.0);
}

// ─── Preset: Smoke ────────────────────────────────────────────────────────────
// 바닥에서 올라오는 연기. 수직 속도장 + 온도 기반 굴절.

fragment float4 fragment_smoke(VertexOut in [[stage_in]],
                               constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / u.resolution.y;
    uv.x *= aspect;
    float t = u.time * 0.12;

    // 수직 상승 흐름 — y축으로 시간 오프셋
    float2 p = uv + float2(0.0, -t * 0.4);

    // 난류 도메인 워핑
    float2 warp = float2(
        fbm(p * 1.5 + float2(t * 0.05, 0.0), 5),
        fbm(p * 1.5 + float2(3.1, t * 0.04), 5)
    );
    float2 warped = p + warp * 0.5;

    float density = fbm(warped * 2.0, 6);
    density = smoothstep(-0.2, 0.7, density);

    // 높이에 따라 옅어짐 (연기 확산)
    float rise = smoothstep(0.0, 0.8, in.uv.y);
    density *= (1.0 - rise * 0.6);

    // 연기 색상: 차가운 회색-청회색
    float3 smokeCol  = mix(float3(0.55, 0.58, 0.65), float3(0.85, 0.87, 0.90), density);
    float3 bgCol     = float3(0.04, 0.04, 0.07);

    // 내부 발광 (열기 느낌)
    float heat = fbm(warped * 3.0 + float2(0.0, -t * 0.6), 4);
    heat = smoothstep(0.3, 0.8, heat) * (1.0 - rise);
    float3 heatCol = mix(float3(0.6, 0.25, 0.05), float3(1.0, 0.65, 0.2), heat);

    float3 col = mix(bgCol, smokeCol, density * 0.75);
    col += heatCol * heat * 0.4;

    // 비네팅
    float2 vc = in.uv - 0.5;
    col *= 1.0 - dot(vc, vc) * 0.8;

    return float4(saturate(col), 1.0);
}

// ─── Preset: Flow ─────────────────────────────────────────────────────────────
// 컬 노이즈 기반 흐름선. 바람의 궤적, 자기장 필드 시각화.

fragment float4 fragment_flow(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    uv.x *= u.resolution.x / u.resolution.y;
    float t = u.time * 0.15;

    // 컬 노이즈로 방향장 생성
    float eps = 0.001;
    float2 p = uv * 2.5;
    float n0 = fbm(p + float2(t * 0.08, 0.0), 5);
    float nx = fbm(p + float2(eps, 0.0) + float2(t * 0.08, 0.0), 5);
    float ny = fbm(p + float2(0.0, eps) + float2(t * 0.08, 0.0), 5);
    float2 curl = float2(ny - n0, -(nx - n0)) / eps * 0.002;

    // 흐름선: 좌표를 벡터 필드로 이동시켜 샘플
    float2 advected = p;
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float2 step_p = advected + float2(fi * 0.3, fi * 0.17);
        float2 v = float2(
            fbm(step_p + float2(t * 0.06,  0.0), 4),
            fbm(step_p + float2(0.0, t * 0.05), 4)
        );
        advected += normalize(v + 0.001) * 0.03;
    }

    float field = fbm(advected + curl * 20.0, 5);

    // 흐름선 강조 (등고선 효과)
    float lines = abs(fract(field * 6.0 + t * 0.05) - 0.5);
    lines = smoothstep(0.45, 0.5, lines);

    // 색상: 딥 그린-청록
    float hue = 0.45 + field * 0.12 + t * 0.008;
    float lum = 0.05 + field * 0.2 + lines * 0.35;
    float sat = 0.55 + lines * 0.2;
    float3 col = hsl2rgb(hue, sat, lum);

    // 흐름선 발광
    col += float3(0.1, 0.9, 0.7) * lines * 0.3;

    float2 vc = in.uv - 0.5;
    col *= 1.0 - dot(vc, vc) * 1.0;

    return float4(saturate(col), 1.0);
}

// ─── Preset: Lava ─────────────────────────────────────────────────────────────
// 마그마 대류. 느리고 점성 강한 유체, 균열 사이 발광.

fragment float4 fragment_lava(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    uv.x *= u.resolution.x / u.resolution.y;
    float t = u.time * 0.07; // 매우 느린 흐름

    // 3단계 도메인 워핑 — 마그마 특유의 무거운 대류
    float2 q = float2(
        fbm(uv * 1.2 + float2(t, 0.0), 6),
        fbm(uv * 1.2 + float2(0.0, t), 6)
    );
    float2 r = float2(
        fbm(uv * 1.2 + 3.5 * q + float2(1.7, 9.2), 6),
        fbm(uv * 1.2 + 3.5 * q + float2(8.3, 2.8), 6)
    );
    float f = fbm(uv * 1.2 + 3.5 * r, 6);

    // 균열 라인 (어두운 경계)
    float crack = abs(gnoise(uv * 3.0 + float2(t * 0.2, 0.0)));
    crack = smoothstep(0.3, 0.0, crack);

    // 마그마 팔레트: 검정 → 다크레드 → 오렌지 → 옐로우
    float heat = smoothstep(-0.4, 0.8, f);
    float3 col = mix(float3(0.02, 0.0, 0.0), float3(0.5, 0.02, 0.0), heat);
    col = mix(col, float3(0.9, 0.2, 0.0), smoothstep(0.3, 0.7, heat));
    col = mix(col, float3(1.0, 0.7, 0.1), smoothstep(0.6, 1.0, heat));

    // 균열 발광
    float3 crackGlow = float3(1.0, 0.4, 0.0) * crack * 1.2;
    col = mix(col, float3(0.0), crack * 0.7);
    col += crackGlow;

    // 표면 반사 질감
    float gloss = gnoise(uv * 8.0 + float2(t * 0.3, 0.0)) * 0.05;
    col += gloss * heat;

    float2 vc = in.uv - 0.5;
    col *= 1.0 - dot(vc, vc) * 0.6;

    return float4(saturate(col), 1.0);
}
