shader_type canvas_item;
render_mode unshaded;
// The interface look (interface_look.gdshaderinc) on the combat effects, through
// InterfaceLook.effects_material: patterns laid out on the screen, no vignette or picture wear, and the
// effects group's switches.

#define EFFECTS
#include "res://src/shaders/interface_look.gdshaderinc"
