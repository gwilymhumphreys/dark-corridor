// Print wear, like an old printed record sleeve (docs/systems/background_wear.md): faded areas, specks,
// rubbed edges, creases and folds. Shared by the screen background (background_wear.gdshader) and the
// wear drawn over the combat corridor (corridor_overlay.gdshader), which gets the same settings, so marks
// line up across the corridor's edge. The pattern is fixed to the screen and does not move. Marks are
// one of two solid colours from the interface palette; faded areas and fold shading are the only
// blended effects.

#include "res://src/shaders/print_noise.gdshaderinc"

// Set from Colours, so they are not look settings.
uniform vec3 wear_dark_colour : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 wear_light_colour : source_color = vec3(0.48, 0.47, 0.47);
// The corridor's rectangle on screen in screen pixels (x, y, width, height), set by PrintFrame while a
// fight is on screen; zero width when there is none. Folds can line up with it.
uniform vec4 print_corridor_rect = vec4(0.0);
// False on menu screens, so folds are only drawn during a run. Set by ScreenBackground.
uniform bool folds_shown = true;

group_uniforms background_pattern;
// Screen pixels per pattern pixel: 1 for full resolution, 4 for the interface pixel grid.
uniform float background_pattern_pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
// A different seed gives a different arrangement of marks.
uniform float background_pattern_seed : hint_range(0.0, 100.0, 1.0) = 0.0;
group_uniforms;

group_uniforms background_faded_areas;
uniform bool background_faded_areas_on = true;
// How much of the screen fades: 0 gives almost none, 1 fades most of it.
uniform float background_faded_areas_coverage : hint_range(0.0, 1.0, 0.01) = 0.18;
// How far the middle of a patch blends towards the dark mark colour: 1 reaches it.
uniform float background_faded_areas_amount : hint_range(0.0, 1.0, 0.005) = 0.13;
// Size of the patches, in pattern pixels.
uniform float background_faded_areas_size : hint_range(50.0, 2000.0, 10.0) = 370.0;
// How gradually a patch fades out at its edge.
uniform float background_faded_areas_softness : hint_range(0.01, 0.5, 0.01) = 0.18;
// 1 keeps patches round; higher stretches them upright.
uniform float background_faded_areas_stretch : hint_range(1.0, 4.0, 0.1) = 2.2;
// Fine pixel noise inside the fade, so it looks worn rather than airbrushed.
uniform float background_faded_areas_grain : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

group_uniforms background_specks;
uniform bool background_specks_on = true;
// The average chance that each cell holds a speck.
uniform float background_specks_density : hint_range(0.0, 1.0, 0.01) = 0.01;
// Cell size in pattern pixels; specks are spaced at roughly this distance where they are densest.
uniform float background_specks_cell : hint_range(2.0, 64.0, 1.0) = 15.0;
// Largest speck radius in pattern pixels.
uniform float background_specks_size : hint_range(0.5, 6.0, 0.1) = 2.0;
// 0 keeps every speck near the largest size; 1 makes most specks tiny with a few large ones.
uniform float background_specks_size_variation : hint_range(0.0, 1.0, 0.01) = 0.69;
// 0 spreads specks evenly; 1 gathers them into clumps with clear areas between.
uniform float background_specks_clumping : hint_range(0.0, 1.0, 0.01) = 0.74;
// Size of the clumps and clear areas, in pattern pixels.
uniform float background_specks_clump_size : hint_range(20.0, 1000.0, 1.0) = 260.0;
// Mixed makes the larger specks and about a third of the rest light, and the others dark.
uniform int background_specks_colour : hint_enum("Dark", "Light", "Mixed") = 2;
group_uniforms;

group_uniforms background_edge_wear;
uniform bool background_edge_wear_on = true;
// How far in from the screen edges the wear reaches, in pattern pixels.
uniform float background_edge_wear_width : hint_range(1.0, 300.0, 1.0) = 40.0;
uniform float background_edge_wear_amount : hint_range(0.0, 1.0, 0.01) = 0.5;
// Size of the worn patches, in pattern pixels.
uniform float background_edge_wear_scale : hint_range(1.0, 64.0, 0.5) = 7.5;
// Extra wear where two edges meet.
uniform float background_edge_wear_corners : hint_range(0.0, 4.0, 0.05) = 1.55;
group_uniforms;

group_uniforms background_creases;
uniform bool background_creases_on = true;
uniform float background_creases_count : hint_range(1.0, 4.0, 1.0) = 4.0;
// Half the width of a crease, in pattern pixels.
uniform float background_creases_width : hint_range(1.0, 60.0, 1.0) = 9.0;
uniform float background_creases_amount : hint_range(0.0, 1.0, 0.01) = 0.34;
// Degrees; 90 is vertical. Each crease turns by up to 10 degrees either way.
uniform float background_creases_angle : hint_range(0.0, 180.0, 1.0) = 91.0;
group_uniforms;

group_uniforms background_folds;
uniform bool background_folds_on = true;
// Folds running top to bottom.
uniform float background_folds_across : hint_range(0.0, 4.0, 1.0) = 1.0;
// Folds running side to side.
uniform float background_folds_down : hint_range(0.0, 3.0, 1.0) = 1.0;
// On a fight screen, the last fold across sits past the corridor's right edge by the corridor's
// distance from the left of the screen, with the others spaced evenly to its left, and the last fold
// down sits past its bottom edge by its distance from the top, so the corridor has the same margin on
// every side. Otherwise folds are spaced evenly over the screen.
uniform bool background_folds_follow_layout = true;
// Width of the raised line along each fold, in pattern pixels.
uniform float background_folds_line_width : hint_range(1.0, 8.0, 1.0) = 1.0;
// How far rubbed wear reaches from a fold, in pattern pixels.
uniform float background_folds_wear_width : hint_range(0.0, 80.0, 1.0) = 30.0;
uniform float background_folds_wear_amount : hint_range(0.0, 1.0, 0.01) = 0.55;
// Extra wear where two folds cross.
uniform float background_folds_crossings : hint_range(0.0, 4.0, 0.05) = 0.7;
// How much lighter or darker each section between folds is: lighter blends towards the dark mark
// colour, darker towards black.
uniform float background_folds_shading : hint_range(0.0, 0.5, 0.01) = 0.0;
group_uniforms;

// Marks in drawing order: a higher mark covers a lower one.
const int MARK_NONE = 0;
const int MARK_DARK = 1;
const int MARK_LIGHT = 2;


// Chance multiplier for clumped marks: about three times inside clumps and near zero between them,
// from a large-scale noise with a sharp threshold, keeping the average near 1.
float clump_factor(vec2 position, float clump_size, float clumping) {
  vec2 clump_position = position / clump_size;
  float clump_noise = value_noise(clump_position) * 0.7 + value_noise(clump_position * 2.3 + 5.1) * 0.3;
  return mix(1.0, smoothstep(0.5, 0.65, clump_noise) * 3.0, clumping);
}


// How far this pattern pixel blends towards the dark mark colour, 0 to the faded areas amount.
float faded_areas(vec2 seeded) {
  vec2 patch_position = seeded / background_faded_areas_size * vec2(1.0, 1.0 / background_faded_areas_stretch);
  // Two noise layers give a wider spread of values than fbm, so the coverage threshold leaves clear
  // areas; a finer layer roughens the patch outlines.
  float noise = value_noise(patch_position) * 0.7 + value_noise(patch_position * 2.3 + 5.1) * 0.3;
  noise += (fbm(seeded / (background_faded_areas_size * 0.08)) - 0.5) * 0.12;
  float threshold = mix(0.85, 0.3, background_faded_areas_coverage);
  float fade = smoothstep(threshold, threshold + background_faded_areas_softness, noise);
  fade *= 1.0 - background_faded_areas_grain * hash12(seeded + 6.1);
  return fade * background_faded_areas_amount;
}


int specks(vec2 p) {
  vec2 base = floor(p / background_specks_cell);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 cell = base + vec2(float(x), float(y));
      // A large-scale noise with a sharp threshold makes clumps at about three times the density and
      // near-empty areas between them, keeping the average near the density.
      float chance = background_specks_density
        * clump_factor(cell * background_specks_cell, background_specks_clump_size, background_specks_clumping);
      if (hash12(cell + 0.5) >= chance) {
        continue;
      }
      vec2 centre = (cell + hash22(cell)) * background_specks_cell;
      float size_roll = hash12(cell + 7.7);
      float radius = max(background_specks_size * mix(1.0, size_roll * size_roll * size_roll, background_specks_size_variation), 0.6);
      // Squash each speck a little in a random direction so they are not all round.
      vec2 offset = p + 0.5 - centre;
      vec2 stretch = normalize(hash22(cell + 3.3) - 0.5 + 0.001);
      offset += stretch * dot(offset, stretch) * (hash12(cell + 1.9) - 0.3);
      if (length(offset) < radius) {
        if (background_specks_colour < 2) {
          return background_specks_colour + MARK_DARK;
        }
        bool light = radius > background_specks_size * 0.6 || hash12(cell + 4.4) < 0.35;
        return light ? MARK_LIGHT : MARK_DARK;
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


// For `count` folds along an axis `size` pattern pixels long: the distance from `x` to the nearest
// fold, and how many folds lie before `x`. With `edge` above 0 the last fold sits at `edge` and the
// others are spaced evenly before it; otherwise all are spaced evenly over the axis.
vec2 nearest_fold(float x, float count, float size, float edge) {
  float nearest = 1e6;
  float passed = 0.0;
  for (int i = 0; i < int(count); i++) {
    float position = edge > 0.0 ? edge * float(i + 1) / count : size * float(i + 1) / (count + 1.0);
    nearest = min(nearest, abs(x - position));
    passed += step(position, x);
  }
  return vec2(nearest, passed);
}


// A broken raised line along each fold (light on the fold, dark beside it) and rubbed wear around it,
// heavier where folds cross.
int folds(vec2 seeded, float distance_across, float distance_down) {
  bool on_across = distance_across < distance_down;
  float distance_to_fold = min(distance_across, distance_down);
  float along = on_across ? seeded.y : seeded.x;
  float line_noise = value_noise(vec2(along * 0.05, on_across ? 3.1 : 7.3)) * 0.7 + hash12(seeded + 5.9) * 0.3;
  float width = background_folds_line_width;
  if (distance_to_fold < width * 0.5 && line_noise > 0.5) {
    return MARK_LIGHT;
  }
  if (distance_to_fold < width * 1.5 && line_noise > 0.35) {
    return MARK_DARK;
  }
  float wear_width = max(background_folds_wear_width, 0.001);
  float near_across = 1.0 - clamp(distance_across / wear_width, 0.0, 1.0);
  float near_down = 1.0 - clamp(distance_down / wear_width, 0.0, 1.0);
  float wear = max(near_across, near_down);
  wear = wear * wear + near_across * near_down * background_folds_crossings;
  float strength = wear * background_folds_wear_amount;
  if (strength <= 0.0) {
    return MARK_NONE;
  }
  float noise = fbm(seeded / 6.0) * 0.8 + hash12(seeded + 4.1) * 0.2;
  float threshold = 1.0 - strength;
  if (noise > threshold + 0.15) {
    return MARK_LIGHT;
  }
  if (noise > threshold) {
    return MARK_DARK;
  }
  return MARK_NONE;
}


// `base` at screen pixel `frag` (on a screen `screen_size` pixels) with every wear effect that is on
// drawn over it.
vec3 print_wear(vec3 base, vec2 frag, vec2 screen_size) {
  vec2 p = floor(frag / background_pattern_pixel_size);
  vec2 grid_size = floor(screen_size / background_pattern_pixel_size);
  vec2 seeded = p + background_pattern_seed * vec2(137.1, 71.3);
  vec3 colour = base;
  int mark = MARK_NONE;
  if (background_faded_areas_on) {
    colour = mix(colour, wear_dark_colour, faded_areas(seeded));
  }
  if (background_folds_on && folds_shown) {
    vec4 rect = print_corridor_rect / background_pattern_pixel_size;
    bool follow = background_folds_follow_layout && rect.z > 0.0;
    vec2 across = nearest_fold(p.x, background_folds_across, grid_size.x, follow ? rect.x * 2.0 + rect.z : -1.0);
    vec2 down = nearest_fold(p.y, background_folds_down, grid_size.y, follow ? rect.y * 2.0 + rect.w : -1.0);
    float shade = (hash12(vec2(across.y, down.y) + background_pattern_seed + 0.5) * 2.0 - 1.0) * background_folds_shading;
    colour = shade > 0.0 ? mix(colour, wear_dark_colour, shade) : colour * (1.0 + shade);
    mark = max(mark, folds(seeded, across.x, down.x));
  }
  if (background_specks_on) {
    mark = max(mark, specks(seeded));
  }
  if (background_edge_wear_on) {
    mark = max(mark, edge_wear(p, grid_size, seeded));
  }
  if (background_creases_on) {
    mark = max(mark, creases(p, grid_size, seeded));
  }
  if (mark == MARK_DARK) {
    colour = wear_dark_colour;
  } else if (mark == MARK_LIGHT) {
    colour = wear_light_colour;
  }
  return colour;
}
