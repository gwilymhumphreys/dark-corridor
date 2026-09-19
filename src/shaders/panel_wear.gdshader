shader_type canvas_item;
// Print wear on a UI panel (docs/systems/panel_wear.md): the same faded areas, specks, rubbed edges and
// creases as the screen background (background_wear.gdshader), but panel-local and with no folds
// (folds are laid out for a whole screen, not a panel). Drawn by `WornStyleBox` into a canvas item
// behind the control, so the wear covers only the panel's own style, not its text or children.
// `panel_rect` and `panel_seed` are per-control instance uniforms, set by `PrintLook`, so one material
// serves every worn panel with a different pattern arrangement each. The control highlight is drawn
// here too, over the wear, from its own per-control instance uniforms (control_highlight.gdshaderinc).

#include "res://src/shaders/print_wear.gdshaderinc"
#include "res://src/shaders/control_highlight.gdshaderinc"

// Set from Colours, so they are not look settings.
uniform vec3 wear_dark_colour : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 wear_light_colour : source_color = vec3(0.48, 0.47, 0.47);

// The panel's rectangle in the parent canvas item's local pixels (x, y, width, height), set by
// `PrintLook` from the rect passed to `StyleBox.draw()`.
instance uniform vec4 panel_rect = vec4(0.0, 0.0, 64.0, 64.0);
// A different seed gives a different arrangement of marks, so same-size panels do not look identical.
instance uniform float panel_seed = 0.0;

group_uniforms panel_pattern;
// Pixels per pattern pixel: 1 for full resolution, 4 for the interface pixel grid.
uniform float panel_pattern_pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
group_uniforms;

group_uniforms panel_faded_areas;
uniform bool panel_faded_areas_on = true;
// How much of the panel fades: 0 gives almost none, 1 fades most of it.
uniform float panel_faded_areas_coverage : hint_range(0.0, 1.0, 0.01) = 0.22;
// How far the middle of a patch blends towards the dark mark colour: 1 reaches it.
uniform float panel_faded_areas_amount : hint_range(0.0, 1.0, 0.005) = 0.1;
// Size of the patches, in pattern pixels.
uniform float panel_faded_areas_size : hint_range(20.0, 800.0, 5.0) = 90.0;
// How gradually a patch fades out at its edge.
uniform float panel_faded_areas_softness : hint_range(0.01, 0.5, 0.01) = 0.18;
// 1 keeps patches round; higher stretches them upright.
uniform float panel_faded_areas_stretch : hint_range(1.0, 4.0, 0.1) = 2.0;
// Fine pixel noise inside the fade, so it looks worn rather than airbrushed.
uniform float panel_faded_areas_grain : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms panel_specks;
uniform bool panel_specks_on = true;
// The average chance that each cell holds a speck.
uniform float panel_specks_density : hint_range(0.0, 1.0, 0.01) = 0.012;
// Cell size in pattern pixels; specks are spaced at roughly this distance where they are densest.
uniform float panel_specks_cell : hint_range(2.0, 64.0, 1.0) = 10.0;
// Largest speck radius in pattern pixels.
uniform float panel_specks_size : hint_range(0.5, 6.0, 0.1) = 1.3;
// 0 keeps every speck near the largest size; 1 makes most specks tiny with a few large ones.
uniform float panel_specks_size_variation : hint_range(0.0, 1.0, 0.01) = 0.69;
// 0 spreads specks evenly; 1 gathers them into clumps with clear areas between.
uniform float panel_specks_clumping : hint_range(0.0, 1.0, 0.01) = 0.6;
// Size of the clumps and clear areas, in pattern pixels.
uniform float panel_specks_clump_size : hint_range(20.0, 1000.0, 1.0) = 90.0;
// Mixed makes the larger specks and about a third of the rest light, and the others dark.
uniform int panel_specks_colour : hint_enum("Dark", "Light", "Mixed") = 2;
group_uniforms;

group_uniforms panel_edge_wear;
uniform bool panel_edge_wear_on = true;
// How far in from the panel's edges the wear reaches, in pattern pixels.
uniform float panel_edge_wear_width : hint_range(1.0, 100.0, 1.0) = 12.0;
uniform float panel_edge_wear_amount : hint_range(0.0, 1.0, 0.01) = 0.45;
// Size of the worn patches, in pattern pixels.
uniform float panel_edge_wear_scale : hint_range(1.0, 64.0, 0.5) = 5.0;
// Extra wear where two edges meet.
uniform float panel_edge_wear_corners : hint_range(0.0, 4.0, 0.05) = 1.5;
group_uniforms;

group_uniforms panel_creases;
uniform bool panel_creases_on = true;
uniform float panel_creases_count : hint_range(1.0, 4.0, 1.0) = 1.0;
// Half the width of a crease, in pattern pixels.
uniform float panel_creases_width : hint_range(1.0, 30.0, 1.0) = 4.0;
uniform float panel_creases_amount : hint_range(0.0, 1.0, 0.01) = 0.22;
// Degrees; 90 is vertical. Each crease turns by up to 10 degrees either way.
uniform float panel_creases_angle : hint_range(0.0, 180.0, 1.0) = 91.0;
group_uniforms;

varying vec2 local_position;


void vertex() {
  local_position = VERTEX;
}


PrintWearSettings _panel_wear_settings() {
  PrintWearSettings settings;
  settings.pattern_pixel_size = panel_pattern_pixel_size;
  settings.pattern_seed = panel_seed;
  settings.faded_areas_on = panel_faded_areas_on;
  settings.faded_areas_coverage = panel_faded_areas_coverage;
  settings.faded_areas_amount = panel_faded_areas_amount;
  settings.faded_areas_size = panel_faded_areas_size;
  settings.faded_areas_softness = panel_faded_areas_softness;
  settings.faded_areas_stretch = panel_faded_areas_stretch;
  settings.faded_areas_grain = panel_faded_areas_grain;
  settings.specks_on = panel_specks_on;
  settings.specks_density = panel_specks_density;
  settings.specks_cell = panel_specks_cell;
  settings.specks_size = panel_specks_size;
  settings.specks_size_variation = panel_specks_size_variation;
  settings.specks_clumping = panel_specks_clumping;
  settings.specks_clump_size = panel_specks_clump_size;
  settings.specks_colour = panel_specks_colour;
  settings.edge_wear_on = panel_edge_wear_on;
  settings.edge_wear_width = panel_edge_wear_width;
  settings.edge_wear_amount = panel_edge_wear_amount;
  settings.edge_wear_scale = panel_edge_wear_scale;
  settings.edge_wear_corners = panel_edge_wear_corners;
  settings.creases_on = panel_creases_on;
  settings.creases_count = panel_creases_count;
  settings.creases_width = panel_creases_width;
  settings.creases_amount = panel_creases_amount;
  settings.creases_angle = panel_creases_angle;
  settings.folds_on = false;
  settings.folds_across = 0.0;
  settings.folds_down = 0.0;
  settings.folds_follow_layout = false;
  settings.folds_line_width = 0.0;
  settings.folds_wear_width = 0.0;
  settings.folds_wear_amount = 0.0;
  settings.folds_crossings = 0.0;
  settings.folds_shading = 0.0;
  return settings;
}


void fragment() {
  vec2 local = local_position - panel_rect.xy;
  vec3 colour = print_panel_wear(COLOR.rgb, _panel_wear_settings(), local, panel_rect.zw, wear_dark_colour, wear_light_colour);
  // The pointer feedback goes on last, over the worn panel (docs/systems/control_feedback.md).
  colour = control_highlight(colour, local, panel_rect.zw, FRAGCOORD.xy);
  COLOR = vec4(colour, COLOR.a);
}
