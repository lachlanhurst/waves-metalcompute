//
//  waveComputeShader.metal
//  water-shader
//
//  Created by Lachlan Hurst on 1/10/2015.
//  Copyright © 2015 Lachlan Hurst. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void waveShader(texture2d<float, access::read> inPrevTexture [[texture(0)]],
                       texture2d<float, access::read> inTexture [[texture(1)]],
                       texture2d<float, access::write> outTexture [[texture(2)]],
                       uint2 gid [[thread_position_in_grid]])
{
    const uint2 centerIndex(gid.x, gid.y);
    const uint2 northIndex(gid.x, gid.y - 1);
    const uint2 eastIndex(gid.x + 1, gid.y);
    const uint2 southIndex(gid.x, gid.y + 1);
    const uint2 westIndex(gid.x - 1, gid.y);
    
    const float centerColor = inPrevTexture.read(centerIndex).r;
    const float northColor = inTexture.read(northIndex).r;
    const float southColor = inTexture.read(southIndex).r;
    const float westColor = inTexture.read(westIndex).r;
    const float eastColor = inTexture.read(eastIndex).r;

    const float res = ((northColor + southColor + westColor + eastColor) / 2.0 - centerColor) * 0.9999;
    
    //const float4 outColor(res, step(0.11,res), step(0.13,res), 1);
    const float4 outColor(res, res, res, 1);
    outTexture.write(outColor, gid);
}