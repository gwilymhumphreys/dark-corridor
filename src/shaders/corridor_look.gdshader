shader_type canvas_item;
render_mode unshaded;
// Corridor look (docs/systems/corridor_look.md): post-processing for the corridor walls and enemy
// images, set as the material of whatever draws the corridor's image (the combat corridor's
// SubViewportContainer, the testbed's corridor display). It reads its own texture, not the screen,
// so the interface is not affected.
//
// Each effect is a uniform group whose first uniform is `<group>_on`. The debug look panel builds
// one section per group and one control per uniform, so a new uniform here gets a control with no
// panel changes. Effects run in the order they appear below. The palette clamp step
// (palette_clamp.gdshaderinc) is controlled by the main debug panel.

#include "res://src/shaders/palette_clamp.gdshaderinc"

group_uniforms warp;
uniform bool warp_on = false;
// How far the edges bulge outward, like a curved screen. Corners go black.
uniform float warp_amount : hint_range(0.0, 0.5, 0.005) = 0.08;
group_uniforms;

group_uniforms pixelate;
uniform bool pixelate_on = false;
// The size of one visible pixel, in screen pixels.
uniform float pixelate_size : hint_range(1.0, 16.0, 1.0) = 3.0;
group_uniforms;

group_uniforms colour_fringe;
uniform bool colour_fringe_on = false;
// How far the red and blue channels separate at the edge of the view, in screen pixels.
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

group_uniforms edges;
uniform bool edges_on = false;
// How sharp a brightness change must be to draw a line.
uniform float edges_threshold : hint_range(0.0, 2.0, 0.01) = 0.3;
// Line width, in screen pixels.
uniform float edges_width : hint_range(0.5, 6.0, 0.1) = 1.0;
uniform vec3 edges_colour : source_color = vec3(0.0, 0.0, 0.0);
uniform float edges_amount : hint_range(0.0, 1.0, 0.01) = 1.0;
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


bool is_inside(vec2 uv) {
  return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}


// The corridor image at `uv`, black outside it so warped edges read as the edge of a screen. A
// macro because TEXTURE cannot be passed to a function.
#define SOURCE(uv) (is_inside(uv) ? texture(TEXTURE, uv).rgb : vec3(0.0))


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
    colour *= pow(2.0, grade_exposure);
    colour = max((colour - grade_contrast_pivot) * grade_contrast + grade_contrast_pivot, vec3(0.0));
    colour = mix(vec3(luminance(colour)), colour, grade_saturation);
    colour = pow(max(colour, vec3(0.0)), vec3(1.0 / grade_gamma));
    colour = clamp((colour - grade_black_point) / max(grade_white_point - grade_black_point, 0.001), 0.0, 1.0);
    colour = mix(colour, colour * grade_tint, grade_tint_amount);
  }

  if (colour_ramp_on) {
    float level = clamp(luminance(colour), 0.0, 1.0);
    vec3 mapped;
    if (level < colour_ramp_middle_point) {
      mapped = mix(colour_ramp_dark, colour_ramp_middle, level / colour_ramp_middle_point);
    } else {
      mapped = mix(colour_ramp_middle, colour_ramp_light, (level - colour_ramp_middle_point) / (1.0 - colour_ramp_middle_point));
    }
    colour = mix(colour, mapped, colour_ramp_amount);
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
    float edge = smoothstep(edges_threshold, edges_threshold + 0.1, length(vec2(across, down)));
    colour = mix(colour, edges_colour, edge * edges_amount);
  }

  if (halftone_on) {
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
    colour = mix(colour, dotted, halftone_amount);
  }

  if (hatching_on) {
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
    colour = mix(colour, hatched, hatching_amount);
  }

  if (vignette_on) {
    float distance_from_centre = length(UV - 0.5);
    float shade = smoothstep(vignette_size + vignette_softness, vignette_size, distance_from_centre);
    colour *= mix(1.0, shade, vignette_amount);
  }

  if (grain_on) {
    vec2 speck = floor(FRAGCOORD.xy / grain_size);
    float frame = grain_speed > 0.0 ? floor(TIME * grain_speed) : 0.0;
    colour += (hash(speck + frame * vec2(17.13, 29.71)) - 0.5) * grain_amount;
  }

  if (posterize_on) {
    float steps = max(posterize_levels - 1.0, 1.0);
    colour = floor(clamp(colour, 0.0, 1.0) * steps + 0.5) / steps;
  }

  colour = clamp_to_palette(clamp(colour, 0.0, 1.0), grid);

  if (scanlines_on) {
    float row = fract(FRAGCOORD.y / scanlines_spacing);
    colour *= 1.0 - scanlines_amount * (0.5 + 0.5 * cos(row * TAU));
    int channel = int(mod(floor(FRAGCOORD.x / scanlines_stripe_width), 3.0));
    vec3 mask = vec3(1.0 - scanlines_stripes);
    mask[channel] = 1.0;
    colour *= mask;
  }

  if (outside) {
    colour = vec3(0.0);
  }
  COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
