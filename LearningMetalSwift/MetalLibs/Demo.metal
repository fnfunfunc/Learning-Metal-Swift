//
//  Demo.metal
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/15.
//

#include <metal_stdlib>
using namespace metal;

vertex float4 vertex_main(device float2 const* positions [[buffer(0)]], uint vertexId [[vertex_id]]) {
    float2 position = positions[vertexId];
    return float4(position, 0.0, 1.0);
}

fragment float4 fragment_main(float4 position [[stage_in]]) {
    return float4(1.0, 0.0, 0.0, 1.0);
}
