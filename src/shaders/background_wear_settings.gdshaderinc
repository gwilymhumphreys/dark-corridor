// The background wear uniforms (docs/systems/background_wear.md), shared by background_wear.gdshader
// and corridor_overlay.gdshader so both keep identical names; PrintFrame copies them by name onto the
// overlay material. Also builds a PrintWearSettings struct (print_wear.gdshaderinc) from them, so both
// shaders fill the struct the same way.

#include "res://src/shaders/print_wear.gdshaderinc"

// Set from Colours, so they are not look settings.
uniform vec3 wear_dark_colour : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 wear_light_colour : source_color = vec3(0.48, 0.47, 0.47);
// The corridor's rectangle on screen in screen pixels (x, y, width, height), set by PrintFrame while a
// fight is on screen; zero width when there is none. Folds can line up with it.
uniform vec4 print_corridor_rect = vec4(0.0);
// False on menu screens, so folds are only drawn during a run. Set by ScreenBackground.
uniform bool folds_shown = true;

group_uniforms background_pattern;
// Screen pixels per pattern pixel: 1 for full resolution, 4 for the interface pixel grid.
uniform float background_pattern_pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
// A different seed gives a different arrangement of marks.
uniform float background_pattern_seed : hint_range(0.0, 100.0, 1.0) = 0.0;
group_uniforms;

group_uniforms background_faded_areas;
uniform bool background_faded_areas_on = true;
// How much of the screen fades: 0 gives almost none, 1 fades most of it.
uniform float background_faded_areas_coverage : hint_range(0.0, 1.0, 0.01) = 0.18;
// How far the middle of a patch blends towards the dark mark colour: 1 reaches it.
uniform float background_faded_areas_amount : hint_range(0.0, 1.0, 0.005) = 0.13;
// Size of the patches, in pattern pixels.
uniform float background_faded_areas_size : hint_range(50.0, 2000.0, 10.0) = 370.0;
// How gradually a patch fades out at its edge.
uniform float background_faded_areas_softness : hint_range(0.01, 0.5, 0.01) = 0.18;
// 1 keeps patches round; higher stretches them upright.
uniform float background_faded_areas_stretch : hint_range(1.0, 4.0, 0.1) = 2.2;
// Fine pixel noise inside the fade, so it looks worn rather than airbrushed.
uniform float background_faded_areas_grain : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms background_specks;
uniform bool background_specks_on = true;
// The average chance that each cell holds a speck.
uniform float background_specks_density : hint_range(0.0, 1.0, 0.01) = 0.01;
// Cell size in pattern pixels; specks are spaced at roughly this distance where they are densest.
uniform float background_specks_cell : hint_range(2.0, 64.0, 1.0) = 15.0;
// Largest speck radius in pattern pixels.
uniform float background_specks_size : hint_range(0.5, 6.0, 0.1) = 2.0;
// 0 keeps every speck near the largest size; 1 makes most specks tiny with a few large ones.
uniform float background_specks_size_variation : hint_range(0.0, 1.0, 0.01) = 0.69;
// 0 spreads specks evenly; 1 gathers them into clumps with clear areas between.
uniform float background_specks_clumping : hint_range(0.0, 1.0, 0.01) = 0.74;
// Size of the clumps and clear areas, in pattern pixels.
uniform float background_specks_clump_size : hint_range(20.0, 1000.0, 1.0) = 260.0;
// Mixed makes the larger specks and about a third of the rest light, and the others dark.
uniform int background_specks_colour : hint_enum("Dark", "Light", "Mixed") = 2;
group_uniforms;

group_uniforms background_edge_wear;
uniform bool background_edge_wear_on = true;
// How far in from the screen edges the wear reaches, in pattern pixels.
uniform float background_edge_wear_width : hint_range(1.0, 300.0, 1.0) = 40.0;
uniform float background_edge_wear_amount : hint_range(0.0, 1.0, 0.01) = 0.5;
// Size of the worn patches, in pattern pixels.
uniform float background_edge_wear_scale : hint_range(1.0, 64.0, 0.5) = 7.5;
// Extra wear where two edges meet.
uniform float background_edge_wear_corners : hint_range(0.0, 4.0, 0.05) = 1.55;
group_uniforms;

group_uniforms background_creases;
uniform bool background_creases_on = true;
uniform float background_creases_count : hint_range(1.0, 4.0, 1.0) = 4.0;
// Half the width of a crease, in pattern pixels.
uniform float background_creases_width : hint_range(1.0, 60.0, 1.0) = 9.0;
uniform float background_creases_amount : hint_range(0.0, 1.0, 0.01) = 0.34;
// Degrees; 90 is vertical. Each crease turns by up to 10 degrees either way.
uniform float background_creases_angle : hint_range(0.0, 180.0, 1.0) = 91.0;
group_uniforms;

group_uniforms background_folds;
uniform bool background_folds_on = true;
// Folds running top to bottom.
uniform float background_folds_across : hint_range(0.0, 4.0, 1.0) = 1.0;
// Folds running side to side.
uniform float background_folds_down : hint_range(0.0, 3.0, 1.0) = 1.0;
// On a fight screen, the last fold across sits past the corridor's right edge by the corridor's
// distance from the left of the screen, with the others spaced evenly to its left, and the last fold
// down sits past its bottom edge by its distance from the top, so the corridor has the same margin on
// every side. Otherwise folds are spaced evenly over the screen.
uniform bool background_folds_follow_layout = true;
// Width of the raised line along each fold, in pattern pixels.
uniform float background_folds_line_width : hint_range(1.0, 8.0, 1.0) = 1.0;
// How far rubbed wear reaches from a fold, in pattern pixels.
uniform float background_folds_wear_width : hint_range(0.0, 80.0, 1.0) = 30.0;
uniform float background_folds_wear_amount : hint_range(0.0, 1.0, 0.01) = 0.55;
// Extra wear where two folds cross.
uniform float background_folds_crossings : hint_range(0.0, 4.0, 0.05) = 0.7;
// How much lighter or darker each section between folds is: lighter blends towards the dark mark
// colour, darker towards black.
uniform float background_folds_shading : hint_range(0.0, 0.5, 0.01) = 0.0;
group_uniforms;


// The wear settings for the screen background and the corridor overlay, from the uniforms above.
PrintWearSettings background_wear_settings() {
  PrintWearSettings settings;
  settings.pattern_pixel_size = background_pattern_pixel_size;
  settings.pattern_seed = background_pattern_seed;
  settings.faded_areas_on = background_faded_areas_on;
  settings.faded_areas_coverage = background_faded_areas_coverage;
  settings.faded_areas_amount = background_faded_areas_amount;
  settings.faded_areas_size = background_faded_areas_size;
  settings.faded_areas_softness = background_faded_areas_softness;
  settings.faded_areas_stretch = background_faded_areas_stretch;
  settings.faded_areas_grain = background_faded_areas_grain;
  settings.specks_on = background_specks_on;
  settings.specks_density = background_specks_density;
  settings.specks_cell = background_specks_cell;
  settings.specks_size = background_specks_size;
  settings.specks_size_variation = background_specks_size_variation;
  settings.specks_clumping = background_specks_clumping;
  settings.specks_clump_size = background_specks_clump_size;
  settings.specks_colour = background_specks_colour;
  settings.edge_wear_on = background_edge_wear_on;
  settings.edge_wear_width = background_edge_wear_width;
  settings.edge_wear_amount = background_edge_wear_amount;
  settings.edge_wear_scale = background_edge_wear_scale;
  settings.edge_wear_corners = background_edge_wear_corners;
  settings.creases_on = background_creases_on;
  settings.creases_count = background_creases_count;
  settings.creases_width = background_creases_width;
  settings.creases_amount = background_creases_amount;
  settings.creases_angle = background_creases_angle;
  settings.folds_on = background_folds_on;
  settings.folds_across = background_folds_across;
  settings.folds_down = background_folds_down;
  settings.folds_follow_layout = background_folds_follow_layout;
  settings.folds_line_width = background_folds_line_width;
  settings.folds_wear_width = background_folds_wear_width;
  settings.folds_wear_amount = background_folds_wear_amount;
  settings.folds_crossings = background_folds_crossings;
  settings.folds_shading = background_folds_shading;
  return settings;
}
