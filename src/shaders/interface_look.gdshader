shader_type canvas_item;
render_mode unshaded;
// Interface look (docs/systems/interface_look.md): the corridor look's effects on interface images
// (icons, character portraits, HP bars, item value pills), set as the material of those nodes only, so
// other text is not affected. The settings and effect functions are shared with the corridor look
// (look_effects.gdshaderinc); warp, bloom and vignette are not used here.
//
// Each node is drawn on its own, so the effects work within the node's own rectangle. Distances are in
// screen pixels, as in the corridor look. Dot, line and speck patterns are laid out from the node's
// corner, so they move with a node that is animated.
//
// Picture wear draws the same print wear as panel wear (panel_wear.gdshader) on the image itself. It is
// laid out in the node's own pixels, as panel wear is, so the same settings give marks of the same size.
// Its settings are separate from panel wear's and start at panel wear's defaults.
//
// The interface palette clamp replaces each pixel with the nearest colour in the interface palette file
// (docs/systems/interface_palette.md#images). DebugPanels sets its palette and matching; with no interface
// palette its colour count is 0 and colours pass through.

#include "res://src/shaders/look_effects.gdshaderinc"
#include "res://src/shaders/print_wear.gdshaderinc"
#include "res://src/shaders/palette_clamp.gdshaderinc"

// Set from Colours by InterfaceLook, so they are not look settings.
uniform vec3 picture_wear_dark_colour : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 picture_wear_light_colour : source_color = vec3(0.48, 0.47, 0.47);

group_uniforms picture_wear;
uniform bool picture_wear_on = false;
// Pixels per pattern pixel: 1 for full resolution, 4 for the interface pixel grid.
uniform float picture_wear_pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
group_uniforms;

group_uniforms picture_faded_areas;
uniform bool picture_faded_areas_on = true;
uniform float picture_faded_areas_coverage : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float picture_faded_areas_amount : hint_range(0.0, 1.0, 0.005) = 0.1;
uniform float picture_faded_areas_size : hint_range(20.0, 800.0, 5.0) = 90.0;
uniform float picture_faded_areas_softness : hint_range(0.01, 0.5, 0.01) = 0.18;
uniform float picture_faded_areas_stretch : hint_range(1.0, 4.0, 0.1) = 2.0;
uniform float picture_faded_areas_grain : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms picture_specks;
uniform bool picture_specks_on = true;
uniform float picture_specks_density : hint_range(0.0, 1.0, 0.01) = 0.012;
uniform float picture_specks_cell : hint_range(2.0, 64.0, 1.0) = 10.0;
uniform float picture_specks_size : hint_range(0.5, 6.0, 0.1) = 1.3;
uniform float picture_specks_size_variation : hint_range(0.0, 1.0, 0.01) = 0.69;
uniform float picture_specks_clumping : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float picture_specks_clump_size : hint_range(20.0, 1000.0, 1.0) = 90.0;
uniform int picture_specks_colour : hint_enum("Dark", "Light", "Mixed") = 2;
group_uniforms;

group_uniforms picture_edge_wear;
uniform bool picture_edge_wear_on = true;
uniform float picture_edge_wear_width : hint_range(1.0, 100.0, 1.0) = 12.0;
uniform float picture_edge_wear_amount : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float picture_edge_wear_scale : hint_range(1.0, 64.0, 0.5) = 5.0;
uniform float picture_edge_wear_corners : hint_range(0.0, 4.0, 0.05) = 1.5;
group_uniforms;

group_uniforms picture_creases;
uniform bool picture_creases_on = true;
uniform float picture_creases_count : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform float picture_creases_width : hint_range(1.0, 30.0, 1.0) = 4.0;
uniform float picture_creases_amount : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float picture_creases_angle : hint_range(0.0, 180.0, 1.0) = 91.0;
group_uniforms;

// The node's colour (its ColorRect colour and modulate), kept from the vertex stage.
varying vec4 node_colour;
// Position in the node's own pixels, before screen scaling, as panel wear measures it.
varying vec2 node_position;


void vertex() {
  node_colour = COLOR;
  node_position = VERTEX;
}


PrintWearSettings _picture_wear_settings(float seed) {
  PrintWearSettings settings;
  settings.pattern_pixel_size = picture_wear_pixel_size;
  settings.pattern_seed = seed;
  settings.faded_areas_on = picture_faded_areas_on;
  settings.faded_areas_coverage = picture_faded_areas_coverage;
  settings.faded_areas_amount = picture_faded_areas_amount;
  settings.faded_areas_size = picture_faded_areas_size;
  settings.faded_areas_softness = picture_faded_areas_softness;
  settings.faded_areas_stretch = picture_faded_areas_stretch;
  settings.faded_areas_grain = picture_faded_areas_grain;
  settings.specks_on = picture_specks_on;
  settings.specks_density = picture_specks_density;
  settings.specks_cell = picture_specks_cell;
  settings.specks_size = picture_specks_size;
  settings.specks_size_variation = picture_specks_size_variation;
  settings.specks_clumping = picture_specks_clumping;
  settings.specks_clump_size = picture_specks_clump_size;
  settings.specks_colour = picture_specks_colour;
  settings.edge_wear_on = picture_edge_wear_on;
  settings.edge_wear_width = picture_edge_wear_width;
  settings.edge_wear_amount = picture_edge_wear_amount;
  settings.edge_wear_scale = picture_edge_wear_scale;
  settings.edge_wear_corners = picture_edge_wear_corners;
  settings.creases_on = picture_creases_on;
  settings.creases_count = picture_creases_count;
  settings.creases_width = picture_creases_width;
  settings.creases_amount = picture_creases_amount;
  settings.creases_angle = picture_creases_angle;
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
  // UV change across one screen pixel, so distances can be given in screen pixels.
  vec2 uv_per_pixel = max(fwidth(UV), vec2(0.000001));
  vec2 uv = UV;
  // Position in screen pixels from the node's corner.
  vec2 local = UV / uv_per_pixel;
  float block = 1.0;

  if (pixelate_on) {
    block = max(pixelate_size, 1.0);
    vec2 cell = uv_per_pixel * block;
    uv = (floor(uv / cell) + 0.5) * cell;
  }
  vec2 pixel = floor(local / block) * block;

  vec4 source = texture(TEXTURE, uv);
  vec3 colour = source.rgb;
  if (colour_fringe_on) {
    vec2 offset = (uv - 0.5) * 2.0 * colour_fringe_amount * uv_per_pixel;
    colour = vec3(texture(TEXTURE, uv + offset).r, colour.g, texture(TEXTURE, uv - offset).b);
  }
  // A modulate brighter than white makes the node glow (docs/systems/interface_glow.md). The effects run
  // on the colour up to white, and the extra brightness is put back at the end.
  float glow_brightness = max(max(node_colour.r, node_colour.g), max(node_colour.b, 1.0));
  colour *= node_colour.rgb / glow_brightness;

  if (grade_on) {
    colour = apply_grade(colour);
  }

  if (colour_ramp_on) {
    colour = apply_colour_ramp(colour);
  }

  if (edges_on) {
    vec2 step_size = uv_per_pixel * edges_width;
    float top_left = luminance(texture(TEXTURE, uv + step_size * vec2(-1.0, -1.0)).rgb);
    float top = luminance(texture(TEXTURE, uv + step_size * vec2(0.0, -1.0)).rgb);
    float top_right = luminance(texture(TEXTURE, uv + step_size * vec2(1.0, -1.0)).rgb);
    float left = luminance(texture(TEXTURE, uv + step_size * vec2(-1.0, 0.0)).rgb);
    float right = luminance(texture(TEXTURE, uv + step_size * vec2(1.0, 0.0)).rgb);
    float bottom_left = luminance(texture(TEXTURE, uv + step_size * vec2(-1.0, 1.0)).rgb);
    float bottom = luminance(texture(TEXTURE, uv + step_size * vec2(0.0, 1.0)).rgb);
    float bottom_right = luminance(texture(TEXTURE, uv + step_size * vec2(1.0, 1.0)).rgb);
    float across = (top_right + 2.0 * right + bottom_right) - (top_left + 2.0 * left + bottom_left);
    float down = (bottom_left + 2.0 * bottom + bottom_right) - (top_left + 2.0 * top + top_right);
    colour = apply_edges(colour, across, down);
  }

  if (halftone_on) {
    colour = apply_halftone(colour, pixel);
  }

  if (hatching_on) {
    colour = apply_hatching(colour, pixel);
  }

  if (grain_on) {
    colour = apply_grain(colour, local, TIME);
  }

  if (posterize_on) {
    colour = apply_posterize(colour);
  }

  if (scanlines_on) {
    colour = apply_scanlines(colour, FRAGCOORD.xy);
  }

  colour = clamp_to_palette(clamp(colour, 0.0, 1.0), FRAGCOORD.xy);

  if (picture_wear_on) {
    // The node's size in its own pixels, and a position measured from its top left corner.
    vec2 node_size = fwidth(node_position) / max(fwidth(UV), vec2(0.000001));
    vec2 node_local = UV * node_size;
    // The image's average colour picks the arrangement of marks, so different pictures wear differently
    // and a picture's marks stay in place while the node is animated.
    vec3 average = textureLod(TEXTURE, vec2(0.5), 20.0).rgb;
    float seed = floor(dot(average, vec3(97.0, 61.0, 29.0)) * 10.0);
    colour = print_panel_wear(colour, _picture_wear_settings(seed), node_local, node_size, picture_wear_dark_colour, picture_wear_light_colour);
  }

  COLOR = vec4(clamp(colour, 0.0, 1.0) * glow_brightness, source.a * node_colour.a);
}
