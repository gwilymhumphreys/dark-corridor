shader_type canvas_item;
// Drawn on a rectangle over the combat corridor image, under the enemy HUDs
// (docs/systems/print_frame.md). It reads the corridor from the screen and draws over it: the
// background's print wear at the same screen positions, so marks carry on across the corridor's edge,
// and a rubbed edge that wears the corridor image away into the background colour. PrintFrame copies
// the background wear settings and colours into this material.

#include "res://src/shaders/print_wear.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Set by PrintFrame: the background colour, and the rectangle's size in screen pixels.
uniform vec3 paper_colour : source_color = vec3(0.04, 0.04, 0.05);
uniform vec2 rect_size = vec2(1.0);

group_uniforms corridor_wear;
// The background wear, with its settings, drawn over the corridor too.
uniform bool corridor_wear_on = true;
group_uniforms;

group_uniforms corridor_worn_edge;
uniform bool corridor_worn_edge_on = true;
// How far in from the corridor's edges the wear reaches, in screen pixels.
uniform float corridor_worn_edge_width : hint_range(1.0, 200.0, 1.0) = 24.0;
uniform float corridor_worn_edge_amount : hint_range(0.0, 1.0, 0.01) = 0.6;
// Size of the worn patches, in screen pixels.
uniform float corridor_worn_edge_scale : hint_range(1.0, 64.0, 0.5) = 6.0;
// Extra wear where two edges meet.
uniform float corridor_worn_edge_corners : hint_range(0.0, 4.0, 0.05) = 1.5;
group_uniforms;


void fragment() {
  vec3 colour = texture(screen_texture, SCREEN_UV).rgb;
  if (corridor_wear_on) {
    colour = print_wear(colour, FRAGCOORD.xy, 1.0 / SCREEN_PIXEL_SIZE);
  }
  if (corridor_worn_edge_on) {
    vec2 local = UV * rect_size;
    vec2 near = 1.0 - clamp(min(local, rect_size - local) / corridor_worn_edge_width, 0.0, 1.0);
    float wear = max(near.x, near.y);
    wear = wear * wear + near.x * near.y * corridor_worn_edge_corners;
    float strength = wear * corridor_worn_edge_amount;
    float noise = fbm(FRAGCOORD.xy / corridor_worn_edge_scale) * 0.8 + hash12(FRAGCOORD.xy + 8.3) * 0.2;
    float threshold = 1.0 - strength;
    if (strength > 0.0 && noise > threshold + 0.12) {
      colour = paper_colour;
    } else if (strength > 0.0 && noise > threshold) {
      colour = wear_dark_colour;
    }
  }
  COLOR = vec4(colour, 1.0);
}
