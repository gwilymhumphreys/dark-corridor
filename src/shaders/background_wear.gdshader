shader_type canvas_item;
// Print wear on the screen background (docs/systems/background_wear.md): specks, short scratches,
// rubbed edges and creases, like an old printed record sleeve. It draws only the background
// rectangle, so nothing above it changes. Every effect is off by default. The pattern is fixed to the
// screen and does not move. Each mark is one of two solid colours from the interface palette; nothing
// is blended.

// Set by ScreenBackground from Colours, so they are not look settings.
uniform vec3 wear_dark_colour : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 wear_light_colour : source_color = vec3(0.48, 0.47, 0.47);

group_uniforms background_pattern;
// Screen pixels per pattern pixel: 1 for full resolution, 4 for the interface pixel grid.
uniform float background_pattern_pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
// A different seed gives a different arrangement of marks.
uniform float background_pattern_seed : hint_range(0.0, 100.0, 1.0) = 0.0;
group_uniforms;

group_uniforms background_specks;
uniform bool background_specks_on = false;
// The chance that each cell holds a speck.
uniform float background_specks_density : hint_range(0.0, 1.0, 0.01) = 0.2;
// Cell size in pattern pixels; specks are spaced at roughly this distance.
uniform float background_specks_cell : hint_range(2.0, 64.0, 1.0) = 14.0;
// Largest speck radius in pattern pixels.
uniform float background_specks_size : hint_range(0.5, 6.0, 0.1) = 1.2;
uniform int background_specks_colour : hint_enum("Dark", "Light") = 1;
group_uniforms;

group_uniforms background_scratches;
uniform bool background_scratches_on = false;
// The chance that each cell holds a scratch.
uniform float background_scratches_density : hint_range(0.0, 1.0, 0.01) = 0.15;
// Cell size in pattern pixels. Scratches longer than about two cells are cut short.
uniform float background_scratches_cell : hint_range(8.0, 200.0, 1.0) = 48.0;
uniform float background_scratches_length : hint_range(2.0, 100.0, 1.0) = 16.0;
uniform float background_scratches_width : hint_range(0.5, 4.0, 0.1) = 1.0;
// Degrees; 90 is vertical. Each scratch turns by up to the spread either way.
uniform float background_scratches_angle : hint_range(0.0, 180.0, 1.0) = 90.0;
uniform float background_scratches_spread : hint_range(0.0, 90.0, 1.0) = 20.0;
uniform int background_scratches_colour : hint_enum("Dark", "Light") = 0;
group_uniforms;

group_uniforms background_edge_wear;
uniform bool background_edge_wear_on = false;
// How far in from the screen edges the wear reaches, in pattern pixels.
uniform float background_edge_wear_width : hint_range(1.0, 300.0, 1.0) = 40.0;
uniform float background_edge_wear_amount : hint_range(0.0, 1.0, 0.01) = 0.5;
// Size of the worn patches, in pattern pixels.
uniform float background_edge_wear_scale : hint_range(1.0, 64.0, 0.5) = 8.0;
// Extra wear where two edges meet.
uniform float background_edge_wear_corners : hint_range(0.0, 4.0, 0.05) = 1.5;
group_uniforms;

group_uniforms background_creases;
uniform bool background_creases_on = false;
uniform float background_creases_count : hint_range(1.0, 4.0, 1.0) = 1.0;
// Half the width of a crease, in pattern pixels.
uniform float background_creases_width : hint_range(1.0, 60.0, 1.0) = 8.0;
uniform float background_creases_amount : hint_range(0.0, 1.0, 0.01) = 0.35;
// Degrees; 90 is vertical. Each crease turns by up to 10 degrees either way.
uniform float background_creases_angle : hint_range(0.0, 180.0, 1.0) = 90.0;
group_uniforms;

const int MARK_NONE = 0;
const int MARK_DARK = 1;
const int MARK_LIGHT = 2;


float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}


vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}


float value_noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float bottom = mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x);
  float top = mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x);
  return mix(bottom, top, u.y);
}


float fbm(vec2 p) {
  float value = 0.0;
  float weight = 0.5;
  for (int i = 0; i < 4; i++) {
    value += weight * value_noise(p);
    p *= 2.03;
    weight *= 0.5;
  }
  return value / 0.9375;
}


int specks(vec2 p) {
  vec2 base = floor(p / background_specks_cell);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 cell = base + vec2(float(x), float(y));
      if (hash12(cell + 0.5) >= background_specks_density) {
        continue;
      }
      vec2 centre = (cell + hash22(cell)) * background_specks_cell;
      float radius = background_specks_size * (0.4 + 0.6 * hash12(cell + 7.7));
      // Squash each speck a little in a random direction so they are not all round.
      vec2 offset = p + 0.5 - centre;
      vec2 stretch = normalize(hash22(cell + 3.3) - 0.5 + 0.001);
      offset += stretch * dot(offset, stretch) * (hash12(cell + 1.9) - 0.3);
      if (length(offset) < radius) {
        return background_specks_colour + 1;
      }
    }
  }
  return MARK_NONE;
}


int scratches(vec2 p) {
  vec2 base = floor(p / background_scratches_cell);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 cell = base + vec2(float(x), float(y));
      if (hash12(cell + 3.1) >= background_scratches_density) {
        continue;
      }
      vec2 centre = (cell + hash22(cell + 11.0)) * background_scratches_cell;
      float turn = (hash12(cell + 5.3) * 2.0 - 1.0) * background_scratches_spread;
      float angle = radians(background_scratches_angle + turn);
      vec2 direction = vec2(cos(angle), sin(angle));
      float half_length = 0.5 * background_scratches_length * (0.5 + hash12(cell + 9.1));
      vec2 offset = p + 0.5 - centre;
      float along = clamp(dot(offset, direction), -half_length, half_length);
      float distance_to_line = length(offset - direction * along);
      // Gaps along the scratch so it reads as broken, not ruled.
      if (distance_to_line < background_scratches_width * 0.5 + 0.25 && value_noise(p * 0.35 + cell) > 0.3) {
        return background_scratches_colour + 1;
      }
    }
  }
  return MARK_NONE;
}


int edge_wear(vec2 p, vec2 grid_size, vec2 seeded) {
  vec2 edge = min(p, grid_size - 1.0 - p);
  float width = background_edge_wear_width;
  vec2 near = 1.0 - clamp(edge / width, 0.0, 1.0);
  float wear = max(near.x, near.y);
  wear = wear * wear + near.x * near.y * background_edge_wear_corners;
  float strength = wear * background_edge_wear_amount;
  if (strength <= 0.0) {
    return MARK_NONE;
  }
  float noise = fbm(seeded / background_edge_wear_scale) * 0.8 + hash12(seeded + 2.7) * 0.2;
  float threshold = 1.0 - strength;
  if (noise > threshold + 0.15) {
    return MARK_LIGHT;
  }
  if (noise > threshold) {
    return MARK_DARK;
  }
  return MARK_NONE;
}


int creases(vec2 p, vec2 grid_size, vec2 seeded) {
  int mark = MARK_NONE;
  for (int i = 0; i < int(background_creases_count); i++) {
    vec2 key = vec2(float(i) * 13.7 + background_pattern_seed, 4.2);
    vec2 origin = hash22(key) * grid_size;
    float angle = radians(background_creases_angle + (hash12(key + 2.0) - 0.5) * 20.0);
    vec2 normal = vec2(-sin(angle), cos(angle));
    vec2 direction = vec2(normal.y, -normal.x);
    float band = 1.0 - clamp(abs(dot(p - origin, normal)) / background_creases_width, 0.0, 1.0);
    if (band <= 0.0) {
      continue;
    }
    // Noise stretched along the crease, broken up by fine grit.
    vec2 local = vec2(dot(seeded, direction) * 0.04, dot(seeded, normal) * 0.4);
    float noise = value_noise(local) * 0.6 + hash12(seeded + 1.3) * 0.4;
    float threshold = 1.0 - background_creases_amount * band;
    if (noise > threshold + 0.15 && band > 0.6) {
      return MARK_LIGHT;
    }
    if (noise > threshold) {
      mark = MARK_DARK;
    }
  }
  return mark;
}


void fragment() {
  vec2 p = floor(FRAGCOORD.xy / background_pattern_pixel_size);
  vec2 grid_size = floor(1.0 / SCREEN_PIXEL_SIZE / background_pattern_pixel_size);
  vec2 seeded = p + background_pattern_seed * vec2(137.1, 71.3);
  int mark = MARK_NONE;
  if (background_specks_on) {
    mark = max(mark, specks(seeded));
  }
  if (background_scratches_on) {
    mark = max(mark, scratches(seeded));
  }
  if (background_edge_wear_on) {
    mark = max(mark, edge_wear(p, grid_size, seeded));
  }
  if (background_creases_on) {
    mark = max(mark, creases(p, grid_size, seeded));
  }
  vec3 colour = COLOR.rgb;
  if (mark == MARK_DARK) {
    colour = wear_dark_colour;
  } else if (mark == MARK_LIGHT) {
    colour = wear_light_colour;
  }
  COLOR = vec4(colour, COLOR.a);
}
