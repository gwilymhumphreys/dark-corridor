shader_type canvas_item;
// The paper burn effect (docs/systems/paper_burn.md): a ragged hole spreading from an ignition point,
// with a glowing ember line at its edge, a charred band behind the line and a dithered scorch ahead of
// it. `PaperBurn` makes this the material of the burning Control and sets the Control to clip its
// children. Godot then draws the children into a buffer and draws the Control with this shader over
// them, the way a CanvasGroup works: the shader reads the children's pixels from the screen texture,
// cuts the hole and colours the bands on the children's own pixels. All distances are in pixels of the
// Control's own space.

#include "res://src/shaders/print_noise.gdshaderinc"

uniform sampler2D children_texture : hint_screen_texture, repeat_disable, filter_nearest;

// 0 before the first mark, 1 when nothing is left.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// The burning Control's size. The Control draws a larger rectangle (for its drop shadow and anything
// hanging off its edge); outside the size, the hole takes its value from the nearest point on the edge
// and no bands are drawn.
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
// How far above white the ember line goes. Above 1 the screen glow blooms it.
uniform float brightness = 2.5;
uniform bool dither = true;
uniform vec3 ember_colour : source_color = vec3(1.0, 0.67, 0.31);
uniform vec3 char_colour : source_color = vec3(0.05, 0.03, 0.02);
uniform vec3 scorch_colour : source_color = vec3(0.35, 0.2, 0.08);

varying vec2 local;


void vertex() {
  local = VERTEX;
}


// Ordered dithering threshold for this screen pixel: a 4 by 4 Bayer matrix, built from the 2 by 2 one.
float bayer2(vec2 p) {
  p = floor(p);
  return fract(p.x / 2.0 + p.y * p.y * 0.75);
}


float bayer4(vec2 frag) {
  return bayer2(frag * 0.5) * 0.25 + bayer2(frag) + 0.03125;
}


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


void fragment() {
  // The children's pixels, as CanvasGroup's own shader reads them.
  vec4 children = textureLod(children_texture, SCREEN_UV, 0.0);
  if (children.a > 0.0001) {
    children.rgb /= children.a;
  }
  vec2 inside = clamp(local, vec2(0.0), rect_size);
  // No bands on what lies outside the Control's rectangle, such as its drop shadow.
  float on_rect = local == inside ? 1.0 : 0.0;
  float depth = burn_depth(inside);
  // A pixel wide soft edge, so the hole is not jagged.
  float soft = max(fwidth(depth), 0.5);
  float remaining = 1.0 - smoothstep(-soft, soft, depth);
  vec3 colour = children.rgb;
  // How far ahead of the hole's edge this point is, and the bands, which vary in width along the edge.
  float behind = -depth;
  float wobble = 0.6 + 0.8 * value_noise(inside / (detail * 0.6) + seed * 5.0);
  float ember_end = ember_width * wobble;
  float char_end = ember_end + char_width * wobble;
  if (on_rect > 0.0) {
    if (behind < ember_end) {
      // The ember line: hottest at the hole, cooling into the char, flickering along its length.
      float t = clamp(behind / max(ember_end, 0.001), 0.0, 1.0);
      float flicker = 0.7 + 0.6 * value_noise(inside / 5.0 + vec2(TIME * 2.3, -TIME * 4.1) + seed * 3.0);
      // From a thin hot core at the hole, through orange and a deep red, into the char.
      vec3 hot = mix(ember_colour, vec3(1.0, 0.9, 0.7), 0.3);
      vec3 deep = ember_colour * vec3(0.75, 0.32, 0.12);
      vec3 ember = mix(hot, ember_colour, smoothstep(0.0, 0.3, t));
      ember = mix(ember, deep, smoothstep(0.3, 0.7, t));
      ember = mix(ember, char_colour, smoothstep(0.7, 1.0, t));
      colour = ember * mix(brightness * flicker, 1.0, smoothstep(0.1, 0.7, t));
    } else if (behind < char_end) {
      // The char, with a few specks still glowing in it.
      float speck = step(0.86, value_noise(inside / 2.5 + seed * 11.0));
      float pulse = 0.5 + 0.5 * sin(TIME * 7.0 + hash12(floor(inside / 2.5)) * 6.28);
      colour = mix(char_colour, ember_colour * brightness, speck * pulse);
    } else {
      // The scorch: the card browns and darkens towards the char, dithered like the pictures. It
      // multiplies, so a light icon browns while the dark card stays dark.
      float s = 1.0 - clamp((behind - char_end) / max(scorch_width, 0.001), 0.0, 1.0);
      s = s * s;
      float amount = dither ? step(bayer4(FRAGCOORD.xy), s) : s;
      vec3 browned = children.rgb * scorch_colour / max(max(scorch_colour.r, scorch_colour.g), 0.001);
      colour = mix(children.rgb, browned * 0.8, amount);
    }
  }
  COLOR = vec4(colour, children.a * remaining);
}
