shader_type canvas_item;
render_mode unshaded;
// World palette clamp (docs/systems/palette_clamp.md): set as the material of the combat
// corridor's SubViewportContainer, so it clamps the corridor walls and enemy images and nothing
// drawn outside the container. It reads the container's own texture, not the screen. The
// matching is in palette_clamp.gdshaderinc.

#include "res://src/shaders/palette_clamp.gdshaderinc"


void fragment() {
  vec4 source = texture(TEXTURE, UV);
  COLOR = vec4(clamp_to_palette(source.rgb, FRAGCOORD.xy), source.a);
}
