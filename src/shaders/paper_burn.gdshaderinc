// The paper burn's hole and bands (docs/systems/paper_burn.md), shared by the interface burn
// (`paper_burn.gdshader`, a Control) and the enemy sprite burn (`paper_burn_sprite.gdshader`, a
// Sprite3D in the corridor). All distances are in screen pixels of the burning rectangle. This file
// includes print_noise.gdshaderinc, so a shader including it must not include that as well.

#include "res://src/shaders/print_noise.gdshaderinc"

// 0 before the first mark, 1 when nothing is left.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// The size of the burning rectangle.
uniform vec2 rect_size = vec2(80.0);
// Where the fire starts, in pixels; usually on the edge.
uniform vec2 origin = vec2(40.0, 80.0);
// Moves the noise, so every burn has a different edge.
uniform float seed = 0.0;
// How far the noise pushes the edge in and out, and the size of its bumps, in pixels.
uniform float raggedness = 10.0;
uniform float detail = 12.0;
// The bands, in pixels: the glowing line at the hole's edge, the black behind it, the brown ahead.
uniform float ember_width = 5.0;
uniform float char_width = 4.0;
uniform float scorch_width = 14.0;
// How far above white the ember line goes.
uniform float brightness = 2.5;
uniform vec3 ember_colour : source_color = vec3(1.0, 0.67, 0.31);
uniform vec3 char_colour : source_color = vec3(0.05, 0.03, 0.02);
uniform vec3 scorch_colour : source_color = vec3(0.35, 0.2, 0.08);


// How far the fire's front has passed this point, in pixels: above 0 the point is burnt away, and
// below 0 it is that far ahead of the hole's edge.
float burn_depth(vec2 p) {
  // The corner farthest from the origin is the last point to burn.
  float reach = length(max(origin, rect_size - origin));
  // Domain warp: the noise is read at a point pushed by another noise, so the edge has tongues and
  // bays rather than even bumps.
  vec2 q = p / detail + vec2(seed * 17.0, seed * 31.0);
  vec2 warp = vec2(fbm(q + vec2(3.1, 7.7)), fbm(q + vec2(8.3, 2.8))) - 0.5;
  float n = fbm(q + warp * 1.6) - 0.5;
  float distance_from_origin = length(p - origin) + n * raggedness * 2.0;
  float bands = ember_width + char_width + scorch_width;
  // At progress 0 even the scorch is short of the nearest point; at 1 the farthest point is gone.
  float front = mix(-bands - raggedness, reach + raggedness, progress);
  return front - distance_from_origin;
}


// The colour of a point `depth` from the hole's edge (from burn_depth) whose own colour is `base`.
// `glow` is set to how far above white it goes, and `banded` to whether a band coloured it.
// `threshold` is the dither threshold for the scorch at this pixel, or below 0 for a smooth scorch.
// `time` is TIME, which a helper function cannot read.
vec3 burn_colour(vec3 base, vec2 inside, float depth, float threshold, float time, out float glow, out bool banded) {
  glow = 1.0;
  banded = false;
  // How far ahead of the hole's edge this point is, and the bands, which vary in width along the edge.
  float behind = -depth;
  float wobble = 0.6 + 0.8 * value_noise(inside / (detail * 0.6) + seed * 5.0);
  float ember_end = ember_width * wobble;
  float char_end = ember_end + char_width * wobble;
  if (behind < ember_end) {
    // The ember line: hottest at the hole, cooling into the char, flickering along its length.
    float t = clamp(behind / max(ember_end, 0.001), 0.0, 1.0);
    float flicker = 0.7 + 0.6 * value_noise(inside / 5.0 + vec2(time * 2.3, -time * 4.1) + seed * 3.0);
    // From a thin hot core at the hole, through orange and a deep red, into the char.
    vec3 hot = mix(ember_colour, vec3(1.0, 0.9, 0.7), 0.3);
    vec3 deep = ember_colour * vec3(0.75, 0.32, 0.12);
    vec3 ember = mix(hot, ember_colour, smoothstep(0.0, 0.3, t));
    ember = mix(ember, deep, smoothstep(0.3, 0.7, t));
    ember = mix(ember, char_colour, smoothstep(0.7, 1.0, t));
    glow = mix(brightness * flicker, 1.0, smoothstep(0.1, 0.7, t));
    banded = true;
    return ember;
  }
  if (behind < char_end) {
    // The char, with a few specks still glowing in it.
    float speck = step(0.86, value_noise(inside / 2.5 + seed * 11.0));
    float pulse = 0.5 + 0.5 * sin(time * 7.0 + hash12(floor(inside / 2.5)) * 6.28);
    glow = mix(1.0, brightness, speck * pulse);
    banded = true;
    return mix(char_colour, ember_colour, speck * pulse);
  }
  // The scorch: the picture browns and darkens towards the char. It multiplies, so a light icon
  // browns while a dark card stays dark.
  float s = 1.0 - clamp((behind - char_end) / max(scorch_width, 0.001), 0.0, 1.0);
  s = s * s;
  float amount = threshold >= 0.0 ? step(threshold, s) : s;
  vec3 browned = base * scorch_colour / max(max(scorch_colour.r, scorch_colour.g), 0.001);
  banded = amount > 0.0;
  return mix(base, browned * 0.8, amount);
}
