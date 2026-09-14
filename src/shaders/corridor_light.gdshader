shader_type spatial;
// The light at the camera for Corridor3D (docs/systems/corridors/corridor_3d.md). Drawn as a
// material overlay on every corridor piece: it multiplies the piece's own colour by the light
// level, so it works for any piece source. The light level is 1 at the camera and falls to 0
// at `light_range`; beyond that the corridor is black.
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float light_range = 12.0;
// Brightness at the camera, 0 to 1. 1 shows the texture's own colours.
uniform float light_energy = 1.0;
// Shape of the fade. 1 is a straight line; higher values darken sooner.
uniform float light_falloff = 1.0;
// How much darker surfaces are when they face away from the light. 0 ignores the angle.
uniform float angle_shading = 0.5;
// 0 fades smoothly. Above 0, the light level is rounded up to this many equal steps.
uniform int light_bands = 0;
// Measure distance straight along the corridor instead of from the camera, so the fade and the
// band edges are square rings rather than curves on the walls.
uniform bool measure_along_corridor = false;
// Multiplies the light level; set each frame by Corridor3D to make the light flicker.
uniform float flicker = 1.0;


void fragment() {
  // The camera, and so the light, is at the origin of view space.
  float distance_to_light = measure_along_corridor ? -VERTEX.z : length(VERTEX);
  float level = pow(clamp(1.0 - distance_to_light / light_range, 0.0, 1.0), light_falloff);
  float facing = abs(dot(normalize(NORMAL), normalize(-VERTEX)));
  level *= mix(1.0, facing, angle_shading);
  level = clamp(level * light_energy * flicker, 0.0, 1.0);
  if (light_bands > 0) {
    level = ceil(level * float(light_bands)) / float(light_bands);
  }
  ALBEDO = vec3(level);
}
