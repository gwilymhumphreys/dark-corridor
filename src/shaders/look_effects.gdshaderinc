// Effects shared by the corridor look (corridor_look.gdshader, docs/systems/corridor_look.md) and the
// interface look (interface_look.gdshader, docs/systems/interface_look.md): their settings and the
// functions that draw them. Both shaders declare the same settings under the same names, so settings
// can be copied from one look to the other.
//
// Each effect is a uniform group whose first uniform is `<group>_on`; the look panels build one section
// per group. Effects that read the image at other positions (pixelate, colour fringe, bloom)
// sample in each shader, because TEXTURE cannot be passed to a function. The interface look does not
// use bloom, and its panel does not show it.

group_uniforms pixelate;
uniform bool pixelate_on = false;
// The size of one visible pixel, in screen pixels.
uniform float pixelate_size : hint_range(1.0, 16.0, 1.0) = 3.0;
group_uniforms;

group_uniforms colour_fringe;
uniform bool colour_fringe_on = false;
// How far the red and blue channels separate at the edge of the image, in screen pixels.
uniform float colour_fringe_amount : hint_range(0.0, 16.0, 0.1) = 3.0;
group_uniforms;

group_uniforms bloom;
uniform bool bloom_on = false;
// Brightness above which a pixel glows.
uniform float bloom_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float bloom_strength : hint_range(0.0, 4.0, 0.01) = 1.0;
// How far the glow spreads, in screen pixels.
uniform float bloom_radius : hint_range(1.0, 200.0, 1.0) = 40.0;
group_uniforms;

group_uniforms grade;
uniform bool grade_on = false;
// Brightness in photographic stops: +1 doubles it.
uniform float grade_exposure : hint_range(-3.0, 3.0, 0.01) = 0.0;
uniform float grade_contrast : hint_range(0.0, 3.0, 0.01) = 1.0;
// The brightness contrast turns around: darker than this gets darker.
uniform float grade_contrast_pivot : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float grade_saturation : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float grade_gamma : hint_range(0.2, 3.0, 0.01) = 1.0;
// Brightness that becomes black, and brightness that becomes white.
uniform float grade_black_point : hint_range(0.0, 0.5, 0.005) = 0.0;
uniform float grade_white_point : hint_range(0.2, 1.0, 0.005) = 1.0;
uniform vec3 grade_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float grade_tint_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
group_uniforms;

group_uniforms colour_ramp;
uniform bool colour_ramp_on = false;
// Each pixel's brightness picks a colour from dark, through middle, to light.
uniform vec3 colour_ramp_dark : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 colour_ramp_middle : source_color = vec3(0.45, 0.4, 0.35);
uniform vec3 colour_ramp_light : source_color = vec3(1.0, 0.95, 0.85);
// The brightness that maps to the middle colour.
uniform float colour_ramp_middle_point : hint_range(0.01, 0.99, 0.01) = 0.3;
uniform float colour_ramp_amount : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms halftone;
uniform bool halftone_on = false;
// Dots on a black ground; brighter areas get bigger dots.
uniform float halftone_cell : hint_range(2.0, 48.0, 1.0) = 8.0;
uniform float halftone_angle : hint_range(0.0, 90.0, 1.0) = 45.0;
// How much each dot is lifted towards the full brightness of its colour.
uniform float halftone_lift : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform vec3 halftone_ground : source_color = vec3(0.0, 0.0, 0.0);
uniform float halftone_amount : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms hatching;
uniform bool hatching_on = false;
// On: light lines on a dark ground, like an engraving. Off: dark lines over the image.
uniform bool hatching_light_lines = true;
uniform float hatching_spacing : hint_range(2.0, 32.0, 0.5) = 6.0;
// Line thickness as a fraction of the spacing.
uniform float hatching_thickness : hint_range(0.05, 0.95, 0.01) = 0.35;
uniform float hatching_angle : hint_range(0.0, 180.0, 1.0) = 45.0;
// Brightness at which the first, second and third line directions appear (light lines) or stop
// (dark lines).
uniform float hatching_level_1 : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float hatching_level_2 : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float hatching_level_3 : hint_range(0.0, 1.0, 0.01) = 0.45;
// How much line colour is lifted towards the full brightness of the image colour.
uniform float hatching_lift : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform vec3 hatching_ground : source_color = vec3(0.0, 0.0, 0.0);
uniform float hatching_amount : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms vignette;
uniform bool vignette_on = false;
uniform float vignette_amount : hint_range(0.0, 1.0, 0.01) = 0.6;
// Distance from the centre where darkening starts (0.5 = the middle of an edge).
uniform float vignette_size : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float vignette_softness : hint_range(0.01, 1.0, 0.01) = 0.4;
group_uniforms;

group_uniforms grain;
uniform bool grain_on = false;
uniform float grain_amount : hint_range(0.0, 0.5, 0.005) = 0.06;
// Grain speck size, in screen pixels.
uniform float grain_size : hint_range(1.0, 8.0, 1.0) = 2.0;
// New grain patterns per second. 0 is still.
uniform float grain_speed : hint_range(0.0, 60.0, 1.0) = 24.0;
group_uniforms;

group_uniforms posterize;
uniform bool posterize_on = false;
// Brightness steps per colour channel.
uniform float posterize_levels : hint_range(2.0, 32.0, 1.0) = 6.0;
group_uniforms;

group_uniforms scanlines;
uniform bool scanlines_on = false;
// Screen pixels from one line to the next.
uniform float scanlines_spacing : hint_range(2.0, 16.0, 1.0) = 4.0;
uniform float scanlines_amount : hint_range(0.0, 1.0, 0.01) = 0.35;
// Vertical red, green and blue stripes, like the mask of an old screen.
uniform float scanlines_stripes : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float scanlines_stripe_width : hint_range(1.0, 8.0, 1.0) = 1.0;
group_uniforms;


float luminance(vec3 colour) {
  return dot(colour, vec3(0.2126, 0.7152, 0.0722));
}


// `colour` moved `amount` of the way towards its own hue at full brightness. Near-black stays dark
// so noise in the shadows is not blown up.
vec3 lift(vec3 colour, float amount) {
  float peak = max(colour.r, max(colour.g, colour.b));
  vec3 full = colour / max(peak, 0.001);
  return mix(colour, full, amount * smoothstep(0.0, 0.08, peak));
}


// 1 on a line of parallel stripes through `pixel`, 0 between them.
float stripe(vec2 pixel, float angle_degrees, float spacing, float thickness) {
  float angle = radians(angle_degrees);
  float along = dot(pixel, vec2(cos(angle), sin(angle))) / spacing;
  float from_centre = abs(fract(along) - 0.5) * 2.0;
  // One screen pixel of blur, so lines are smooth without derivatives (which break on pixelated
  // positions).
  float soft = 1.0 / spacing;
  return 1.0 - smoothstep(thickness - soft, thickness + soft, from_centre);
}


float hash(vec2 point) {
  return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}


vec3 apply_grade(vec3 colour) {
  colour *= pow(2.0, grade_exposure);
  colour = max((colour - grade_contrast_pivot) * grade_contrast + grade_contrast_pivot, vec3(0.0));
  colour = mix(vec3(luminance(colour)), colour, grade_saturation);
  colour = pow(max(colour, vec3(0.0)), vec3(1.0 / grade_gamma));
  colour = clamp((colour - grade_black_point) / max(grade_white_point - grade_black_point, 0.001), 0.0, 1.0);
  return mix(colour, colour * grade_tint, grade_tint_amount);
}


vec3 apply_colour_ramp(vec3 colour) {
  float level = clamp(luminance(colour), 0.0, 1.0);
  vec3 mapped;
  if (level < colour_ramp_middle_point) {
    mapped = mix(colour_ramp_dark, colour_ramp_middle, level / colour_ramp_middle_point);
  } else {
    mapped = mix(colour_ramp_middle, colour_ramp_light, (level - colour_ramp_middle_point) / (1.0 - colour_ramp_middle_point));
  }
  return mix(colour, mapped, colour_ramp_amount);
}


// `pixel` is the position the dot pattern is laid out on, in screen pixels.
vec3 apply_halftone(vec3 colour, vec2 pixel) {
  float angle = radians(halftone_angle);
  mat2 rotation = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
  vec2 point = rotation * pixel / halftone_cell;
  float distance_to_centre = length(point - (floor(point) + 0.5));
  float level = clamp(luminance(colour), 0.0, 1.0);
  // A radius of 0.71 fills the whole cell.
  float radius = sqrt(level) * 0.71;
  float soft = 0.5 / halftone_cell;
  float in_dot = 1.0 - smoothstep(radius - soft, radius + soft, distance_to_centre);
  vec3 dotted = mix(halftone_ground, lift(colour, halftone_lift), in_dot);
  return mix(colour, dotted, halftone_amount);
}


// `pixel` is the position the lines are laid out on, in screen pixels.
vec3 apply_hatching(vec3 colour, vec2 pixel) {
  float level = clamp(luminance(colour), 0.0, 1.0);
  float line_1 = stripe(pixel, hatching_angle, hatching_spacing, hatching_thickness);
  float line_2 = stripe(pixel, hatching_angle + 90.0, hatching_spacing, hatching_thickness);
  float line_3 = stripe(pixel, hatching_angle + 45.0, hatching_spacing, hatching_thickness);
  vec3 hatched;
  if (hatching_light_lines) {
    float lines = max(max(
      line_1 * step(hatching_level_1, level),
      line_2 * step(hatching_level_2, level)),
      line_3 * step(hatching_level_3, level));
    hatched = mix(hatching_ground, lift(colour, hatching_lift), lines);
  } else {
    float lines = max(max(
      line_1 * step(level, hatching_level_3),
      line_2 * step(level, hatching_level_2)),
      line_3 * step(level, hatching_level_1));
    hatched = mix(colour, hatching_ground, lines);
  }
  return mix(colour, hatched, hatching_amount);
}


// `pixel` is the position the specks are laid out on, in screen pixels; `time` is TIME.
vec3 apply_grain(vec3 colour, vec2 pixel, float time) {
  vec2 speck = floor(pixel / grain_size);
  float frame = grain_speed > 0.0 ? floor(time * grain_speed) : 0.0;
  return colour + (hash(speck + frame * vec2(17.13, 29.71)) - 0.5) * grain_amount;
}


vec3 apply_posterize(vec3 colour) {
  float steps = max(posterize_levels - 1.0, 1.0);
  return floor(clamp(colour, 0.0, 1.0) * steps + 0.5) / steps;
}


// `pixel` is the position the lines and stripes are laid out on, in screen pixels.
vec3 apply_scanlines(vec3 colour, vec2 pixel) {
  float row = fract(pixel.y / scanlines_spacing);
  colour *= 1.0 - scanlines_amount * (0.5 + 0.5 * cos(row * TAU));
  int channel = int(mod(floor(pixel.x / scanlines_stripe_width), 3.0));
  vec3 mask = vec3(1.0 - scanlines_stripes);
  mask[channel] = 1.0;
  return colour * mask;
}
