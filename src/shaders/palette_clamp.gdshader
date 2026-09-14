shader_type canvas_item;
render_mode unshaded;
// Full-screen palette clamp (docs/systems/palette_clamp.md): replaces each screen pixel with the
// nearest colour in the selected palette. The matching is in palette_clamp.gdshaderinc.

#include "res://src/shaders/palette_clamp.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;


void fragment() {
  vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
  COLOR = vec4(clamp_to_palette(screen, FRAGCOORD.xy), 1.0);
}
