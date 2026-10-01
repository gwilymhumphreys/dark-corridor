shader_type canvas_item;
// The paper burn effect (docs/systems/paper_burn.md): a ragged hole spreading from an ignition point,
// with a glowing ember line at its edge, a charred band behind the line and a dithered scorch ahead of
// it. `PaperBurn` makes this the material of the burning Control and sets the Control to clip its
// children. Godot then draws the children into a buffer and draws the Control with this shader over
// them, the way a CanvasGroup works: the shader reads the children's pixels from the screen texture,
// cuts the hole and colours the bands on the children's own pixels. All distances are in pixels of the
// Control's own space. The hole and the bands are in paper_burn.gdshaderinc, shared with the enemy
// sprite burn; `rect_size` is the burning Control's size.

// The hole, the bands and their uniforms; this also includes print_noise.gdshaderinc.
#include "res://src/shaders/paper_burn.gdshaderinc"
// The palette colours, matching and dither pattern, copied from the combat effects' material by
// `PaperBurn` when a burn starts.
#include "res://src/shaders/palette_clamp.gdshaderinc"

uniform sampler2D children_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform bool dither = true;
// Snap the bands to the palette, then brighten the glowing parts, and make the hole's edge solid or
// empty by the dither pattern. The token's untouched pixels are left alone: its pictures are already
// snapped to their own palette.
uniform bool snap = false;

varying vec2 local;


void vertex() {
  local = VERTEX;
}


// The palette clamp's dither threshold for this screen pixel, so the scorch's dots and the palette's
// dots line up.
float pixel_threshold(vec2 frag) {
  return dither_threshold(frag / max(dither_size, 1.0));
}


void fragment() {
  // The children's pixels, as CanvasGroup's own shader reads them.
  vec4 children = textureLod(children_texture, SCREEN_UV, 0.0);
  if (children.a > 0.0001) {
    children.rgb /= children.a;
  }
  // The Control draws a larger rectangle than its size (for its drop shadow and anything hanging off
  // its edge); outside the size, the hole takes its value from the nearest point on the edge and no
  // bands are drawn.
  vec2 inside = clamp(local, vec2(0.0), rect_size);
  bool on_rect = local == inside;
  float depth = burn_depth(inside);
  // A pixel wide soft edge, so the hole is not jagged.
  float soft = max(fwidth(depth), 0.5);
  float remaining = 1.0 - smoothstep(-soft, soft, depth);
  if (snap) {
    remaining = remaining > pixel_threshold(FRAGCOORD.xy) ? 1.0 : 0.0;
  }
  vec3 colour = children.rgb;
  // Whether a band coloured this pixel, and how far above white it goes, applied after the snap.
  bool banded = false;
  float glow = 1.0;
  if (on_rect) {
    float threshold = dither ? pixel_threshold(FRAGCOORD.xy) : -1.0;
    colour = burn_colour(children.rgb, inside, depth, threshold, TIME, glow, banded);
  }
  if (snap && banded) {
    colour = clamp_to_palette(clamp(colour, 0.0, 1.0), FRAGCOORD.xy);
  }
  colour *= glow;
  COLOR = vec4(colour, children.a * remaining);
}
