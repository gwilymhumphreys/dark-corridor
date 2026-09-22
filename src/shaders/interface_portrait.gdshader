shader_type canvas_item;
render_mode unshaded;
// The interface look (interface_look.gdshaderinc) with the per-node `picture_zoom` that PortraitBreath
// sets. Used by the breathing portraits only, through InterfaceLook.portrait_material.

#define PICTURE_ZOOM
#include "res://src/shaders/interface_look.gdshaderinc"
