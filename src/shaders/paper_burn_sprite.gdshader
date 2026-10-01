shader_type spatial;
render_mode cull_disabled;
// The paper burn on an enemy sprite in the corridor (docs/systems/paper_burn.md, "Enemy sprites"):
// the same hole and bands as the interface burn, on a Sprite3D's image. `SpriteBurn` makes this the
// sprite's material and sets `rect_size` to the sprite's size on screen, so the bands are as many
// screen pixels wide as on the interface. The sprite stays lit by the corridor light; the ember line
// also emits, so it shows in the dark. The corridor look shader runs over the result, so the colours
// are snapped to the world palette with the rest of the corridor.

// The hole, the bands and their uniforms; this also includes print_noise.gdshaderinc.
#include "res://src/shaders/paper_burn.gdshaderinc"

// The sprite's image. A material override does not receive it, so `SpriteBurn` sets it.
uniform sampler2D image : source_color, filter_linear_mipmap;
// Pixels below this alpha are not drawn, as with the corridor's other enemy sprites.
uniform float alpha_scissor_threshold = 0.5;


void fragment() {
  vec4 picture = texture(image, UV);
  vec2 inside = UV * rect_size;
  float depth = burn_depth(inside);
  float soft = max(fwidth(depth), 0.5);
  float remaining = 1.0 - smoothstep(-soft, soft, depth);
  float glow = 1.0;
  bool banded = false;
  vec3 colour = burn_colour(picture.rgb, inside, depth, -1.0, TIME, glow, banded);
  ALBEDO = colour;
  // The part of the ember line above white glows on its own, so it is bright however dark the corridor.
  EMISSION = colour * max(glow - 1.0, 0.0);
  ALPHA = picture.a * remaining;
  ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
