// Nearest palette colour matching (docs/systems/palette_clamp.md), used by corridor_look.gdshader
// (the corridor image).
// The palette arrives as one-row textures plus a count, so switching palettes does not recompile
// the shader.

const int MAX_COLOURS = 64;   // must match DebugPanelsAutoload.MAX_COLOURS

// Palette colours in sRGB, one texel each.
uniform sampler2D palette_rgb : filter_nearest;
// The same colours in OKLab (float texture), filled by PaletteLoader.to_oklab.
uniform sampler2D palette_lab : filter_nearest;
uniform int colour_count = 0;
// false = nearest in RGB, true = nearest in OKLab.
uniform bool perceptual = false;
// A dot pattern mixing the two nearest colours.
uniform bool dithering = false;
// The dot pattern. Blue noise reads `dither_noise`; the others are calculated.
uniform int dither_pattern : hint_enum("Bayer 4x4", "Bayer 8x8", "Blue noise", "Interleaved gradient noise") = 0;
// Screen pixels per pattern cell, on top of any pixelate block size.
uniform float dither_size : hint_range(1.0, 8.0, 1.0) = 1.0;
// Dither at twice the resolution and average each 2x2 back to one pixel (Obra Dinn's fix for
// moire). The result mixes palette colours, so it is no longer strictly on the palette.
uniform bool dither_supersample = false;
// A tileable blue noise texture whose red channel is each pixel's rank; set by DebugPanels.
uniform sampler2D dither_noise : filter_nearest;

const float BAYER[16] = float[16](
  0.0, 8.0, 2.0, 10.0,
  12.0, 4.0, 14.0, 6.0,
  3.0, 11.0, 1.0, 9.0,
  15.0, 7.0, 13.0, 5.0
);


vec3 srgb_to_linear(vec3 c) {
  return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}


// Keep in step with PaletteLoader.to_oklab.
vec3 to_oklab(vec3 srgb) {
  vec3 c = srgb_to_linear(srgb);
  float l = pow(max(0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b, 0.0), 1.0 / 3.0);
  float m = pow(max(0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b, 0.0), 1.0 / 3.0);
  float s = pow(max(0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b, 0.0), 1.0 / 3.0);
  return vec3(
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  );
}


// The Bayer value (0 to 63) of an 8x8 cell: each bit pair of the position adds the 2x2 Bayer value,
// with the lowest bits weighted most.
int bayer8(ivec2 cell) {
  int value = 0;
  for (int bit = 0; bit < 3; bit++) {
    int x = (cell.x >> bit) & 1;
    int y = (cell.y >> bit) & 1;
    value += (2 * (x ^ y) + y) << (2 * (2 - bit));
  }
  return value;
}


// The dither threshold (0 to 1) for pattern cell `cell`.
float dither_threshold(vec2 cell) {
  ivec2 whole = ivec2(floor(cell));
  if (dither_pattern == 1) {
    return (float(bayer8(whole & ivec2(7))) + 0.5) / 64.0;
  }
  if (dither_pattern == 2) {
    ivec2 size = textureSize(dither_noise, 0);
    if (size.x <= 1) {
      return 0.5;
    }
    return texelFetch(dither_noise, ((whole % size) + size) % size, 0).r;
  }
  if (dither_pattern == 3) {
    // Interleaved gradient noise (Jimenez 2014).
    return fract(52.9829189 * fract(dot(floor(cell), vec2(0.06711056, 0.00583715))));
  }
  ivec2 small = whole & ivec2(3);
  return (BAYER[small.y * 4 + small.x] + 0.5) / 16.0;
}


// `colour` replaced by the nearest palette colour, or unchanged when no palette is set.
// `frag_coord` (window pixels) places the dithering pattern.
vec3 clamp_to_palette(vec3 colour, vec2 frag_coord) {
  if (colour_count <= 0) {
    return colour;
  }
  vec3 point = perceptual ? to_oklab(colour) : colour;
  int best = 0;
  int second = 0;
  float best_distance = 1e9;
  float second_distance = 1e9;
  for (int i = 0; i < MAX_COLOURS; i++) {
    if (i >= colour_count) {
      break;
    }
    vec3 candidate = perceptual
      ? texelFetch(palette_lab, ivec2(i, 0), 0).rgb
      : texelFetch(palette_rgb, ivec2(i, 0), 0).rgb;
    vec3 offset = point - candidate;
    float distance_squared = dot(offset, offset);
    if (distance_squared < best_distance) {
      second = best;
      second_distance = best_distance;
      best = i;
      best_distance = distance_squared;
    } else if (distance_squared < second_distance) {
      second = i;
      second_distance = distance_squared;
    }
  }
  vec3 best_rgb = texelFetch(palette_rgb, ivec2(best, 0), 0).rgb;
  if (!dithering || colour_count <= 1) {
    return best_rgb;
  }
  vec3 second_rgb = texelFetch(palette_rgb, ivec2(second, 0), 0).rgb;
  vec3 near_colour = perceptual ? texelFetch(palette_lab, ivec2(best, 0), 0).rgb : best_rgb;
  vec3 far_colour = perceptual ? texelFetch(palette_lab, ivec2(second, 0), 0).rgb : second_rgb;
  // How far the pixel sits along the line from the nearest colour to the second nearest.
  vec3 span = far_colour - near_colour;
  float along = clamp(dot(point - near_colour, span) / max(dot(span, span), 1e-6), 0.0, 1.0);
  vec2 cell = frag_coord / max(dither_size, 1.0);
  if (!dither_supersample) {
    return along > dither_threshold(cell) ? second_rgb : best_rgb;
  }
  // Four pattern cells at twice the resolution, averaged.
  vec2 fine = floor(cell * 2.0 - 0.5);
  float share = 0.0;
  for (int i = 0; i < 4; i++) {
    share += along > dither_threshold(fine + vec2(float(i % 2), float(i / 2))) ? 0.25 : 0.0;
  }
  return mix(best_rgb, second_rgb, share);
}
