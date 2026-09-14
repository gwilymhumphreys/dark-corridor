// Nearest palette colour matching (docs/systems/palette_clamp.md), shared by
// palette_clamp.gdshader (the whole screen) and world_clamp.gdshader (the corridor viewport).
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
// Ordered 4x4 dot pattern mixing the two nearest colours.
uniform bool dithering = false;

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
  int chosen = best;
  if (dithering && colour_count > 1) {
    vec3 near_colour = perceptual
      ? texelFetch(palette_lab, ivec2(best, 0), 0).rgb
      : texelFetch(palette_rgb, ivec2(best, 0), 0).rgb;
    vec3 far_colour = perceptual
      ? texelFetch(palette_lab, ivec2(second, 0), 0).rgb
      : texelFetch(palette_rgb, ivec2(second, 0), 0).rgb;
    // How far the pixel sits along the line from the nearest colour to the second nearest.
    vec3 span = far_colour - near_colour;
    float along = clamp(dot(point - near_colour, span) / max(dot(span, span), 1e-6), 0.0, 1.0);
    ivec2 cell = ivec2(frag_coord) % 4;
    float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
    if (along > threshold) {
      chosen = second;
    }
  }
  return texelFetch(palette_rgb, ivec2(chosen, 0), 0).rgb;
}
