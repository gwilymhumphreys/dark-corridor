shader_type canvas_item;
render_mode unshaded;
// Corridor look (docs/systems/corridor_look.md): post-processing for the corridor walls and enemy
// images, set as the material of whatever draws the corridor's image (the combat corridor's
// SubViewportContainer, the testbed's corridor display). It reads its own texture, not the screen,
// so the interface is not affected.
//
// Each effect is a uniform group whose first uniform is `<group>_on`. The debug look panel builds
// one section per group and one control per uniform, so a new uniform gets a control with no panel
// changes. Most effects and their settings are in look_effects.gdshaderinc, shared with the interface
// look; effects run in the order of fragment() below. The dithering group is the palette clamp
// (palette_clamp.gdshaderinc); its palette and colour matching are set from the F1 panel.

#include "res://src/shaders/look_effects.gdshaderinc"

group_uniforms dithering;
#include "res://src/shaders/palette_clamp.gdshaderinc"
group_uniforms;


bool is_inside(vec2 uv) {
  return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}


// The corridor image at `uv`, black outside it so warped edges read as the edge of a screen. A
// macro because TEXTURE cannot be passed to a function.
#define SOURCE(uv) (is_inside(uv) ? texture(TEXTURE, uv).rgb : vec3(0.0))


void fragment() {
  vec2 uv = UV;
  vec2 texel = TEXTURE_PIXEL_SIZE;
  vec2 grid = FRAGCOORD.xy;
  float block = 1.0;

  if (warp_on) {
    vec2 centred = uv * 2.0 - 1.0;
    centred *= 1.0 + warp_amount * dot(centred, centred);
    uv = centred * 0.5 + 0.5;
  }
  bool outside = !is_inside(uv);

  if (pixelate_on) {
    block = max(pixelate_size, 1.0);
    vec2 cell = texel * block;
    uv = (floor(uv / cell) + 0.5) * cell;
    grid = floor(FRAGCOORD.xy / block);
  }
  // Screen position in pixels, snapped to the visible pixel size, for the patterns below.
  vec2 pixel = floor(FRAGCOORD.xy / block) * block;

  vec3 colour;
  if (colour_fringe_on) {
    vec2 offset = (uv - 0.5) * 2.0 * colour_fringe_amount * texel;
    colour = vec3(
      SOURCE(uv + offset).r,
      SOURCE(uv).g,
      SOURCE(uv - offset).b
    );
  } else {
    colour = SOURCE(uv);
  }

  if (bloom_on) {
    vec3 glow = vec3(0.0);
    float weight_total = 0.0;
    for (int i = 0; i < 32; i++) {
      float t = (float(i) + 0.5) / 32.0;
      float angle = float(i) * 2.39996;
      vec2 offset = vec2(cos(angle), sin(angle)) * sqrt(t) * bloom_radius * texel;
      float weight = 1.0 - t;
      glow += max(SOURCE(uv + offset) - bloom_threshold, vec3(0.0)) * weight;
      weight_total += weight;
    }
    colour += glow / weight_total * bloom_strength;
  }

  if (grade_on) {
    colour = apply_grade(colour);
  }

  if (colour_ramp_on) {
    colour = apply_colour_ramp(colour);
  }

  if (edges_on) {
    vec2 step_size = texel * edges_width;
    float top_left = luminance(SOURCE(uv + step_size * vec2(-1.0, -1.0)));
    float top = luminance(SOURCE(uv + step_size * vec2(0.0, -1.0)));
    float top_right = luminance(SOURCE(uv + step_size * vec2(1.0, -1.0)));
    float left = luminance(SOURCE(uv + step_size * vec2(-1.0, 0.0)));
    float right = luminance(SOURCE(uv + step_size * vec2(1.0, 0.0)));
    float bottom_left = luminance(SOURCE(uv + step_size * vec2(-1.0, 1.0)));
    float bottom = luminance(SOURCE(uv + step_size * vec2(0.0, 1.0)));
    float bottom_right = luminance(SOURCE(uv + step_size * vec2(1.0, 1.0)));
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

  if (vignette_on) {
    float distance_from_centre = length(UV - 0.5);
    float shade = smoothstep(vignette_size + vignette_softness, vignette_size, distance_from_centre);
    colour *= mix(1.0, shade, vignette_amount);
  }

  if (grain_on) {
    colour = apply_grain(colour, FRAGCOORD.xy, TIME);
  }

  if (posterize_on) {
    colour = apply_posterize(colour);
  }

  colour = clamp_to_palette(clamp(colour, 0.0, 1.0), grid);

  if (scanlines_on) {
    colour = apply_scanlines(colour, FRAGCOORD.xy);
  }

  if (outside) {
    colour = vec3(0.0);
  }
  COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
