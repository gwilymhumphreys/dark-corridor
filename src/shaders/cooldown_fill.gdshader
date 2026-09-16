shader_type canvas_item;
// The cooldown fill on a board item cell (docs/systems/run_screen.md): a semi-transparent fill rising
// from the bottom of the cell as the item recharges, with a solid line along its top edge. The edge is
// torn like the paper edges elsewhere in the print look — it wanders along the cell and breaks into
// specks — using the same noise as the print border and the background wear (print_noise.gdshaderinc).
// Drawn at full resolution, like the print border and panel wear. The pattern is in the cell's local
// pixels, so it stays fixed to the cell while the cell scales on hover and recoil.
// Drawn by `ItemCell` on a rectangle over the item icon, so it reads on top of the art rather than
// behind it. Each cell has its own material, because the progress differs per item.

#include "res://src/shaders/print_noise.gdshaderinc"

// How far the item has recharged: 0 just fired, 1 ready to fire.
uniform float cooldown_progress : hint_range(0.0, 1.0) = 0.0;
// The cell's size in local pixels, set by ItemCell.
uniform vec2 rect_size = vec2(120.0, 120.0);
// A different seed gives each cell its own tear.
uniform float cell_seed = 0.0;

uniform vec4 fill_colour : source_color = vec4(0.95, 0.95, 0.95, 0.25);
uniform vec4 line_colour : source_color = vec4(0.95, 0.95, 0.95, 1.0);

// Thickness of the solid line along the top of the fill, in pixels.
uniform float line_width : hint_range(1.0, 20.0, 0.5) = 5.0;
// How far the underside of the line wanders, in pixels.
uniform float line_roughness : hint_range(0.0, 8.0, 0.1) = 1.5;
// How far the torn edge wanders up and down, in pixels.
uniform float tear_depth : hint_range(0.0, 40.0, 0.5) = 7.0;
// Length of one wander along the cell, in pixels; small values give a busier tear.
uniform float tear_scale : hint_range(2.0, 120.0, 0.5) = 22.0;
// How far specks of the line scatter into the empty part above it, in pixels.
uniform float tear_specks : hint_range(0.0, 30.0, 0.5) = 9.0;
// Size of the specks, in pixels.
uniform float speck_scale : hint_range(1.0, 12.0, 0.5) = 2.5;


void fragment() {
  vec2 local = UV * rect_size;
  float top = rect_size.y * (1.0 - cooldown_progress);
  top += (fbm(vec2(local.x / tear_scale, cell_seed * 13.7)) - 0.5) * 2.0 * tear_depth;
  float below = local.y - top;   // below the edge is the recharged part
  float line_bottom = line_width + (value_noise(vec2(local.x / speck_scale, cell_seed * 5.3 + 4.1)) - 0.5) * 2.0 * line_roughness;
  if (below < 0.0) {
    // Above the line, specks of it scatter off into the empty part and thin out with distance, so
    // the edge looks torn rather than cut.
    float reach = -below / max(tear_specks, 0.001);
    float speck = value_noise(local / speck_scale + cell_seed * 7.3) * 0.8 + hash12(floor(local) + cell_seed) * 0.2;
    COLOR = vec4(0.0);
    if (reach < 1.0 && speck > 0.4 + reach * 0.6) {
      COLOR = line_colour;
    }
  } else if (below < line_bottom) {
    COLOR = line_colour;
  } else {
    COLOR = fill_colour;
  }
}
