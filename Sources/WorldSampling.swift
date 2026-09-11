// SPDX-License-Identifier: GPL-2.0-or-later
enum WorldSampling {
    static let shader="""
    float3 paletteLinear(float3 c) {
        return select(c/12.92,pow((c+0.055)/1.055,float3(2.4)),c>0.04045);
    }
    float3 litPalette(float3 color,float shade,float3 added) {
        float3 base=color*shade;
        if (all(added<=0.0)) return base;
        // Accumulate light energy in linear space, preserving the classic ambient base.
        float3 linear=paletteLinear(base)+paletteLinear(color)*max(added,0.0)*0.5;
        return select(linear*12.92,1.055*pow(linear,float3(1.0/2.4))-0.055,linear>0.0031308);
    }
    float4 sampleWorld(texture2d<float> tex,float2 pixelUV,float4 power) {
        float2 uv=pixelUV/float2(tex.get_width(),tex.get_height());
        constexpr sampler classic(coord::normalized,address::repeat,filter::nearest,mip_filter::none);
        float4 original=tex.sample(classic,uv);
        if (power.w<=0 || power.x>0 || power.y>0) return original;
        constexpr sampler smooth(coord::normalized,address::repeat,filter::linear,mip_filter::linear,max_anisotropy(4));
        float4 filtered=tex.sample(smooth,uv);
        // Keep the original binary cutout silhouette and matching ray alpha mask.
        // Transparent map texels are black, so unpremultiply filtered edge colors.
        return float4(filtered.rgb/max(filtered.a,0.001),original.a);
    }
    """
}
