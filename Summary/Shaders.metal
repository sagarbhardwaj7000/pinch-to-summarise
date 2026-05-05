//
//  Shaders.metal
//  Summary
//
//  Two stitchable shaders for the reading state:
//   - rippleShimmer: a diagonal cyan→blue→white ripple that travels across the text.
//   - textRipple:    a water-surface displacement so the text floats and gets lifted
//                    by the ripple front as it passes.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Color: diagonal ripple shimmer (cyan / blue / white)

[[ stitchable ]] half4 rippleShimmer(
    float2 position,
    half4  color,
    float  time,
    float2 size
) {
    // If this pixel isn't part of the text shape, leave it transparent.
    if (color.a <= 0.001h) {
        return color;
    }

    // Diagonal axis: top-right (location 0) → bottom-left (location 1).
    float2 startCorner = float2(size.x, 0.0);
    float2 endCorner   = float2(0.0, size.y);
    float2 axis        = endCorner - startCorner;
    float  axisLen     = max(length(axis), 1.0);
    float2 axisDir     = axis / axisLen;
    float  along       = clamp(dot(position - startCorner, axisDir) / axisLen, 0.0, 1.0);

    // Animated band position. Pad the cycle to [-0.4, 1.4] so the bright spot
    // is fully off-screen at both ends — the wraparound is invisible.
    float cycleDur = 1.4;
    float raw      = fract(time / cycleDur);
    float bandPos  = raw * 1.8 - 0.4;

    float edgeFade = 1.0;
    if (bandPos < 0.0)      edgeFade = max(0.0, 1.0 + bandPos / 0.4);
    else if (bandPos > 1.0) edgeFade = max(0.0, 1.0 - (bandPos - 1.0) / 0.4);

    float p = clamp(bandPos, 0.0, 1.0);
    float d = abs(along - p);

    // Layer widths (white core → blue → cyan → dim).
    float wWhite = 0.04;
    float wBlue  = 0.06;
    float wCyan  = 0.12;

    half3 dim   = color.rgb * 0.32h;
    half3 cyan  = half3(0.32, 0.86, 0.97);
    half3 blue  = half3(0.30, 0.55, 0.99);
    half3 white = half3(1.0,  1.0,  1.0);

    half3 outRGB = dim;
    if (d < wWhite) {
        float t = d / wWhite;
        half3 c = mix(white, blue, half(t));
        outRGB = mix(dim, c, half(edgeFade));
    } else if (d < (wWhite + wBlue)) {
        float t = (d - wWhite) / wBlue;
        half3 c = mix(blue, cyan, half(t));
        outRGB = mix(dim, c, half(edgeFade * 0.92));
    } else if (d < (wWhite + wBlue + wCyan)) {
        float t = (d - wWhite - wBlue) / wCyan;
        half3 c = mix(cyan, dim, half(t));
        outRGB = mix(dim, c, half(edgeFade * 0.55));
    }

    // Pre-multiplied alpha out — preserves the text glyph shape.
    return half4(outRGB * color.a, color.a);
}

// MARK: - Distortion: a soft force wave that lifts the text as it passes

[[ stitchable ]] float2 textRipple(
    float2 position,
    float  time,
    float2 size
) {
    // Diagonal axis matched to the colour shader (top-right → bottom-left).
    float2 startCorner = float2(size.x, 0.0);
    float2 axis        = float2(-size.x, size.y);
    float  axisLen     = max(length(axis), 1.0);
    float2 axisDir     = axis / axisLen;
    float  along       = dot(position - startCorner, axisDir) / axisLen;

    float cycleDur = 1.4;
    float raw      = fract(time / cycleDur);
    float bandPos  = raw * 1.8 - 0.4;

    // Signed distance from the wavefront. The crest is wide enough that the
    // ramp-up and ramp-down feel like a single smooth lift, not a flick.
    float d = along - bandPos;

    float crestWidth = 0.11;
    float crest      = exp(-(d * d) / (crestWidth * crestWidth));

    // Gentle wake — low-frequency, quickly decaying.
    float wake = 0.0;
    if (d > 0.0) {
        float decay = exp(-d * 8.5);
        wake = sin(d * 22.0) * decay * 0.18;
    }

    // Taper while the wave is off-screen at either end of the cycle.
    float onScreen = 1.0;
    if (bandPos < 0.0)      onScreen = max(0.0, 1.0 + bandPos / 0.4);
    else if (bandPos > 1.0) onScreen = max(0.0, 1.0 - (bandPos - 1.0) / 0.4);

    // Push perpendicular to the wave direction — text rises as the front
    // sweeps through, settles after.
    float2 perp = float2(-axisDir.y, axisDir.x);
    float  perpAmp = (crest + wake) * 6.0 * onScreen;

    return position + perp * perpAmp;
}
