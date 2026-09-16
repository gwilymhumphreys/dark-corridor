shader_type canvas_item;
// Print wear on the screen background (docs/systems/background_wear.md). The effects are functions in
// print_wear.gdshaderinc; the uniforms and the settings struct they need are in
// background_wear_settings.gdshaderinc, shared with the wear drawn over the combat corridor. It draws
// only the background rectangle, so nothing above it changes.

#include "res://src/shaders/background_wear_settings.gdshaderinc"


void fragment() {
  vec3 colour = print_wear(COLOR.rgb, background_wear_settings(), FRAGCOORD.xy, 1.0 / SCREEN_PIXEL_SIZE,
    wear_dark_colour, wear_light_colour, print_corridor_rect, folds_shown);
  COLOR = vec4(colour, COLOR.a);
}
