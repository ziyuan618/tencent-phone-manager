#include <metal_stdlib>
using namespace metal;

// ============================================
// 腾讯手机管家 - Metal Shaders
// ESP 人物绘制 + 物资显示 + 科技风 UI
// ============================================

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float  pointSize [[point_size]];
};

// 线条顶点着色器
vertex VertexOut line_vertex(uint vertexID [[vertex_id]],
                              constant float2* vertices [[buffer(0)]],
                              constant float4& color [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.color = color;
    out.pointSize = 2.0;
    return out;
}

// 线条片段着色器
fragment float4 line_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// 方框顶点 (四边形 → 线段)
vertex VertexOut box_vertex(uint vertexID [[vertex_id]],
                             constant float2* vertices [[buffer(0)]],
                             constant float4& color [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.color = color;
    return out;
}

fragment float4 box_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// 血量条顶点
struct HealthVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex HealthVertexOut health_vertex(uint vertexID [[vertex_id]],
                                      constant float2* vertices [[buffer(0)]],
                                      constant float4& color [[buffer(1)]]) {
    HealthVertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.color = color;
    return out;
}

fragment float4 health_fragment(HealthVertexOut in [[stage_in]]) {
    return in.color;
}

// 圆点（用于骨骼关节 + 物资标记）
vertex VertexOut point_vertex(uint vertexID [[vertex_id]],
                               constant float2* vertices [[buffer(0)]],
                               constant float4& color [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.color = color;
    out.pointSize = 6.0;
    return out;
}

fragment float4 point_fragment(VertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    // 圆形点
    float dist = length(pointCoord - float2(0.5));
    if (dist > 0.5) discard_fragment();
    
    // 发光效果
    float glow = 1.0 - dist * 2.0;
    return float4(in.color.rgb, in.color.a * glow);
}

// 科技风菜单背景（圆角矩形 + 青色边框光晕）
vertex VertexOut menu_vertex(uint vertexID [[vertex_id]],
                              constant float2* vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    return out;
}

fragment float4 menu_fragment(VertexOut in [[stage_in]]) {
    // 暗色渐变背景
    float4 bgTop    = float4(0.04, 0.04, 0.10, 0.94);
    float4 bgBottom = float4(0.06, 0.06, 0.14, 0.94);
    float t = in.position.y / 900.0; // 屏幕高度归一化
    return mix(bgTop, bgBottom, t);
}

// 文字渲染（通过纹理atlas）
struct TextVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex TextVertexOut text_vertex(uint vertexID [[vertex_id]],
                                  constant float4* vertices [[buffer(0)]],
                                  constant float4& color [[buffer(1)]]) {
    TextVertexOut out;
    float4 v = vertices[vertexID];
    out.position = float4(v.xy, 0, 1);
    out.texCoord = v.zw;
    out.color = color;
    return out;
}

fragment float4 text_fragment(TextVertexOut in [[stage_in]],
                               texture2d<float> fontTexture [[texture(0)]],
                               sampler fontSampler [[sampler(0)]]) {
    float alpha = fontTexture.sample(fontSampler, in.texCoord).r;
    return float4(in.color.rgb, in.color.a * alpha);
}

// 物资图标着色器
fragment float4 loot_fragment(VertexOut in [[stage_in]],
                               texture2d<float> iconTexture [[texture(0)]],
                               sampler iconSampler [[sampler(0)]]) {
    float4 tex = iconTexture.sample(iconSampler, in.texCoord);
    return float4(tex.rgb * in.color.rgb, tex.a * in.color.a);
}

// 发光效果 (用于敌人高亮)
fragment float4 glow_fragment(VertexOut in [[stage_in]]) {
    float dist = length(in.position.xy - float2(0.5));
    float glow = exp(-dist * 5.0);
    return float4(in.color.rgb, in.color.a * glow);
}
