shader_type canvas_item;
// The printed border around the combat corridor (docs/systems/print_frame.md): a solid line in the
// background wear's colour, with rough edges and rubbed spots. PrintFrame draws it on a rectangle
// behind the corridor, sized to the corridor plus the gap, the line width and the roughness. Pixels
// off the line are fully transparent, so nothing is blended.

#include "res://src/shaders/print_noise.gdshaderinc"

// Set by PrintFrame from Colours: the background wear's dark colour for the line and its light colour
// for the rubbed spots, so the border is printed in the same ink as the wear on the paper.
uniform vec3 border_colour : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 border_wear_colour : source_color = vec3(0.48, 0.47, 0.47);
// The rectangle's size in screen pixels, set by PrintFrame.
uniform vec2 rect_size = vec2(1.0);

group_uniforms print_border;
uniform bool print_border_on = false;
// Line width, in screen pixels.
uniform float print_border_width : hint_range(1.0, 60.0, 1.0) = 10.0;
// Space between the line and the corridor, in screen pixels.
uniform float print_border_gap : hint_range(0.0, 60.0, 1.0) = 10.0;
// How far the line's edges wander, in screen pixels.
uniform float print_border_roughness : hint_range(0.0, 8.0, 0.1) = 2.0;
// How much of the line is rubbed away: rubbed spots show the background, with the wear colour around
// them.
uniform float print_border_wear : hint_range(0.0, 1.0, 0.01) = 0.3;
// Size of the rough edges and rubbed spots, in screen pixels.
uniform float print_border_scale : hint_range(1.0, 64.0, 0.5) = 6.0;
group_uniforms;


void fragment() {
  vec2 local = UV * rect_size;
  vec2 edge = min(local, rect_size - local);
  float from_outside = min(edge.x, edge.y);
  float roughness = print_border_roughness;
  float outer = roughness + (value_noise(FRAGCOORD.xy / print_border_scale) - 0.5) * 2.0 * roughness;
  float inner = roughness + print_border_width + (value_noise(FRAGCOORD.yx / print_border_scale + 9.1) - 0.5) * 2.0 * roughness;
  float alpha = 0.0;
  vec3 colour = border_colour;
  if (print_border_on && from_outside >= outer && from_outside < inner) {
    alpha = 1.0;
    float rub = fbm(FRAGCOORD.xy / (print_border_scale * 2.0)) * 0.7 + hash12(FRAGCOORD.xy + 1.7) * 0.3;
    float threshold = 1.0 - print_border_wear * 0.6;
    if (rub > threshold) {
      alpha = 0.0;
    } else if (rub > threshold - 0.06) {
      colour = border_wear_colour;
    }
  }
  COLOR = vec4(colour, alpha);
}
