#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float4x4 projectionMatrix;
    float4x4 modelMatrix;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.modelMatrix * float4(in.position, 0, 1);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return texture.sample(textureSampler, in.texCoord);
}
