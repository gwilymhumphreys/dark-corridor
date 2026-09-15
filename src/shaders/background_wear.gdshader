shader_type canvas_item;
// Print wear on the screen background (docs/systems/background_wear.md). The effects and their settings
// are in print_wear.gdshaderinc, shared with the wear drawn over the combat corridor. It draws only the
// background rectangle, so nothing above it changes.

#include "res://src/shaders/print_wear.gdshaderinc"


void fragment() {
  COLOR = vec4(print_wear(COLOR.rgb, FRAGCOORD.xy, 1.0 / SCREEN_PIXEL_SIZE), COLOR.a);
}
