shader_type canvas_item;
// The grid behind the player's items (docs/systems/print_frame.md): grid paper drawn in pencil, with
// lines that drift off straight, vary in pressure along their length, skip in places and show the
// paper's grain. The combat view sizes the rectangle to the board and sets the square size so each
// item sits in one square. Pixels off the lines are fully transparent.

#include "res://src/shaders/print_noise.gdshaderinc"

// Set by CombatViewFramed: the pencil colour from Colours, and the distance between the lines at the
// item cells' edges in canvas pixels. The board grid and the potion grid share this material; each
// reads its own rectangle's pixels, so neither needs its size set.
uniform vec3 pencil_colour : source_color = vec3(0.48, 0.47, 0.47);
uniform float square_size = 144.0;

group_uniforms board_grid;
uniform bool board_grid_on = true;
// Lines per item cell: 1 draws a line only at the cells' edges, more draws finer paper.
uniform int board_grid_squares_per_cell : hint_range(1, 8) = 1;
// Line width, in canvas pixels.
uniform float board_grid_line_width : hint_range(0.5, 8.0, 0.1) = 2.0;
// How strongly the lines show over the background.
uniform float board_grid_darkness : hint_range(0.0, 1.0, 0.01) = 0.35;
// How far a line drifts from straight, in canvas pixels, and over what length it changes direction.
uniform float board_grid_wobble : hint_range(0.0, 8.0, 0.1) = 1.2;
uniform float board_grid_wobble_length : hint_range(10.0, 600.0, 1.0) = 120.0;
// How much the pencil's pressure, and so the line's darkness, varies along a line.
uniform float board_grid_pressure : hint_range(0.0, 1.0, 0.01) = 0.5;
// How much of the paper's grain shows through the graphite.
uniform float board_grid_grain : hint_range(0.0, 1.0, 0.01) = 0.5;
// How much of each line the pencil skips.
uniform float board_grid_gaps : hint_range(0.0, 1.0, 0.01) = 0.1;
group_uniforms;


// How much pencil covers this point for the lines running along `along`, spaced `spacing` apart
// across `across`. `seed` keeps the vertical and horizontal lines different.
float pencil_lines(float across, float along, float spacing, float seed) {
  float index = floor(across / spacing + 0.5);
  float drift = (value_noise(vec2(along / board_grid_wobble_length, index * 7.31 + seed)) - 0.5) * 2.0 * board_grid_wobble;
  float distance_to_line = abs(across - index * spacing - drift);
  float half_width = board_grid_line_width * 0.5;
  float cover = 1.0 - smoothstep(half_width - 0.5, half_width + 0.5, distance_to_line);
  float pressure = value_noise(vec2(along / (board_grid_wobble_length * 0.6), index * 3.17 + seed + 11.0));
  cover *= mix(1.0, pressure, board_grid_pressure);
  float skip = value_noise(vec2(along / 18.0, index * 5.53 + seed + 23.0));
  if (skip < board_grid_gaps * 0.6) {
    cover = 0.0;
  }
  return cover;
}


varying vec2 local_position;


void vertex() {
  local_position = VERTEX;
}


void fragment() {
  vec2 local = local_position;
  float spacing = square_size / float(max(board_grid_squares_per_cell, 1));
  float vertical = pencil_lines(local.x, local.y, spacing, 0.0);
  float horizontal = pencil_lines(local.y, local.x, spacing, 41.0);
  float cover = 1.0 - (1.0 - vertical) * (1.0 - horizontal);   // crossings are darker, as in pencil
  float grain = hash12(FRAGCOORD.xy) * 0.5 + value_noise(FRAGCOORD.xy / 2.5) * 0.5;
  cover *= mix(1.0, grain, board_grid_grain);
  float alpha = board_grid_on ? cover * board_grid_darkness : 0.0;
  COLOR = vec4(pencil_colour, alpha);
}
