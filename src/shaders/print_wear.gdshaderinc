// Print wear functions, like an old printed record sleeve (docs/systems/background_wear.md,
// docs/systems/panel_wear.md): faded areas, specks, rubbed edges, creases and folds. Functions only, no
// uniforms — each surface declares its own uniforms and fills a PrintWearSettings struct to call them:
// background_wear_settings.gdshaderinc for the screen background and the wear drawn over the combat
// corridor (identical uniform names on both, so PrintFrame can copy them by name), panel_wear.gdshader
// for panel wear. The pattern is fixed to the surface and does not move. Marks are one of two solid
// colours from the interface palette; faded areas and fold shading are the only blended effects.

#include "res://src/shaders/print_noise.gdshaderinc"

struct PrintWearSettings {
  float pattern_pixel_size;
  float pattern_seed;
  bool faded_areas_on;
  float faded_areas_coverage;
  float faded_areas_amount;
  float faded_areas_size;
  float faded_areas_softness;
  float faded_areas_stretch;
  float faded_areas_grain;
  bool specks_on;
  float specks_density;
  float specks_cell;
  float specks_size;
  float specks_size_variation;
  float specks_clumping;
  float specks_clump_size;
  int specks_colour;
  bool edge_wear_on;
  float edge_wear_width;
  float edge_wear_amount;
  float edge_wear_scale;
  float edge_wear_corners;
  bool creases_on;
  float creases_count;
  float creases_width;
  float creases_amount;
  float creases_angle;
  // Not used by panel wear (folds are laid out for a whole screen, not a panel).
  bool folds_on;
  float folds_across;
  float folds_down;
  bool folds_follow_layout;
  float folds_line_width;
  float folds_wear_width;
  float folds_wear_amount;
  float folds_crossings;
  float folds_shading;
};

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
float faded_areas(PrintWearSettings settings, vec2 seeded) {
  vec2 patch_position = seeded / settings.faded_areas_size * vec2(1.0, 1.0 / settings.faded_areas_stretch);
  // Two noise layers give a wider spread of values than fbm, so the coverage threshold leaves clear
  // areas; a finer layer roughens the patch outlines.
  float noise = value_noise(patch_position) * 0.7 + value_noise(patch_position * 2.3 + 5.1) * 0.3;
  noise += (fbm(seeded / (settings.faded_areas_size * 0.08)) - 0.5) * 0.12;
  float threshold = mix(0.85, 0.3, settings.faded_areas_coverage);
  float fade = smoothstep(threshold, threshold + settings.faded_areas_softness, noise);
  fade *= 1.0 - settings.faded_areas_grain * hash12(seeded + 6.1);
  return fade * settings.faded_areas_amount;
}


int specks(PrintWearSettings settings, vec2 p) {
  vec2 base = floor(p / settings.specks_cell);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 cell = base + vec2(float(x), float(y));
      // A large-scale noise with a sharp threshold makes clumps at about three times the density and
      // near-empty areas between them, keeping the average near the density.
      float chance = settings.specks_density
        * clump_factor(cell * settings.specks_cell, settings.specks_clump_size, settings.specks_clumping);
      if (hash12(cell + 0.5) >= chance) {
        continue;
      }
      vec2 centre = (cell + hash22(cell)) * settings.specks_cell;
      float size_roll = hash12(cell + 7.7);
      float radius = max(settings.specks_size * mix(1.0, size_roll * size_roll * size_roll, settings.specks_size_variation), 0.6);
      // Squash each speck a little in a random direction so they are not all round.
      vec2 offset = p + 0.5 - centre;
      vec2 stretch = normalize(hash22(cell + 3.3) - 0.5 + 0.001);
      offset += stretch * dot(offset, stretch) * (hash12(cell + 1.9) - 0.3);
      if (length(offset) < radius) {
        if (settings.specks_colour < 2) {
          return settings.specks_colour + MARK_DARK;
        }
        bool light = radius > settings.specks_size * 0.6 || hash12(cell + 4.4) < 0.35;
        return light ? MARK_LIGHT : MARK_DARK;
      }
    }
  }
  return MARK_NONE;
}


int edge_wear(PrintWearSettings settings, vec2 p, vec2 grid_size, vec2 seeded) {
  vec2 edge = min(p, grid_size - 1.0 - p);
  float width = settings.edge_wear_width;
  vec2 near = 1.0 - clamp(edge / width, 0.0, 1.0);
  float wear = max(near.x, near.y);
  wear = wear * wear + near.x * near.y * settings.edge_wear_corners;
  float strength = wear * settings.edge_wear_amount;
  if (strength <= 0.0) {
    return MARK_NONE;
  }
  float noise = fbm(seeded / settings.edge_wear_scale) * 0.8 + hash12(seeded + 2.7) * 0.2;
  float threshold = 1.0 - strength;
  if (noise > threshold + 0.15) {
    return MARK_LIGHT;
  }
  if (noise > threshold) {
    return MARK_DARK;
  }
  return MARK_NONE;
}


int creases(PrintWearSettings settings, vec2 p, vec2 grid_size, vec2 seeded) {
  int mark = MARK_NONE;
  for (int i = 0; i < int(settings.creases_count); i++) {
    vec2 key = vec2(float(i) * 13.7 + settings.pattern_seed, 4.2);
    vec2 origin = hash22(key) * grid_size;
    float angle = radians(settings.creases_angle + (hash12(key + 2.0) - 0.5) * 20.0);
    vec2 normal = vec2(-sin(angle), cos(angle));
    vec2 direction = vec2(normal.y, -normal.x);
    float band = 1.0 - clamp(abs(dot(p - origin, normal)) / settings.creases_width, 0.0, 1.0);
    if (band <= 0.0) {
      continue;
    }
    // Noise stretched along the crease, broken up by fine grit.
    vec2 local = vec2(dot(seeded, direction) * 0.04, dot(seeded, normal) * 0.4);
    float noise = value_noise(local) * 0.6 + hash12(seeded + 1.3) * 0.4;
    float threshold = 1.0 - settings.creases_amount * band;
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
int folds(PrintWearSettings settings, vec2 seeded, float distance_across, float distance_down) {
  bool on_across = distance_across < distance_down;
  float distance_to_fold = min(distance_across, distance_down);
  float along = on_across ? seeded.y : seeded.x;
  float line_noise = value_noise(vec2(along * 0.05, on_across ? 3.1 : 7.3)) * 0.7 + hash12(seeded + 5.9) * 0.3;
  float width = settings.folds_line_width;
  if (distance_to_fold < width * 0.5 && line_noise > 0.5) {
    return MARK_LIGHT;
  }
  if (distance_to_fold < width * 1.5 && line_noise > 0.35) {
    return MARK_DARK;
  }
  float wear_width = max(settings.folds_wear_width, 0.001);
  float near_across = 1.0 - clamp(distance_across / wear_width, 0.0, 1.0);
  float near_down = 1.0 - clamp(distance_down / wear_width, 0.0, 1.0);
  float wear = max(near_across, near_down);
  wear = wear * wear + near_across * near_down * settings.folds_crossings;
  float strength = wear * settings.folds_wear_amount;
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
// drawn over it, including folds. Folds can line up with `corridor_rect` (zero width when there is
// none) while `folds_shown`.
vec3 print_wear(vec3 base, PrintWearSettings settings, vec2 frag, vec2 screen_size, vec3 dark_colour, vec3 light_colour, vec4 corridor_rect, bool folds_shown) {
  vec2 p = floor(frag / settings.pattern_pixel_size);
  vec2 grid_size = floor(screen_size / settings.pattern_pixel_size);
  vec2 seeded = p + settings.pattern_seed * vec2(137.1, 71.3);
  vec3 colour = base;
  int mark = MARK_NONE;
  if (settings.faded_areas_on) {
    colour = mix(colour, dark_colour, faded_areas(settings, seeded));
  }
  if (settings.folds_on && folds_shown) {
    vec4 rect = corridor_rect / settings.pattern_pixel_size;
    bool follow = settings.folds_follow_layout && rect.z > 0.0;
    vec2 across = nearest_fold(p.x, settings.folds_across, grid_size.x, follow ? rect.x * 2.0 + rect.z : -1.0);
    vec2 down = nearest_fold(p.y, settings.folds_down, grid_size.y, follow ? rect.y * 2.0 + rect.w : -1.0);
    float shade = (hash12(vec2(across.y, down.y) + settings.pattern_seed + 0.5) * 2.0 - 1.0) * settings.folds_shading;
    colour = shade > 0.0 ? mix(colour, dark_colour, shade) : colour * (1.0 + shade);
    mark = max(mark, folds(settings, seeded, across.x, down.x));
  }
  if (settings.specks_on) {
    mark = max(mark, specks(settings, seeded));
  }
  if (settings.edge_wear_on) {
    mark = max(mark, edge_wear(settings, p, grid_size, seeded));
  }
  if (settings.creases_on) {
    mark = max(mark, creases(settings, p, grid_size, seeded));
  }
  if (mark == MARK_DARK) {
    colour = dark_colour;
  } else if (mark == MARK_LIGHT) {
    colour = light_colour;
  }
  return colour;
}


// The same wear as print_wear(), except no folds: panel wear is laid out for a whole screen, not a
// panel, so panels never use it. `local` is a position in the panel's own pixels (0,0 at its top left),
// `panel_size` its size.
vec3 print_panel_wear(vec3 base, PrintWearSettings settings, vec2 local, vec2 panel_size, vec3 dark_colour, vec3 light_colour) {
  vec2 p = floor(local / settings.pattern_pixel_size);
  vec2 grid_size = floor(panel_size / settings.pattern_pixel_size);
  vec2 seeded = p + settings.pattern_seed * vec2(137.1, 71.3);
  vec3 colour = base;
  int mark = MARK_NONE;
  if (settings.faded_areas_on) {
    colour = mix(colour, dark_colour, faded_areas(settings, seeded));
  }
  if (settings.specks_on) {
    mark = max(mark, specks(settings, seeded));
  }
  if (settings.edge_wear_on) {
    mark = max(mark, edge_wear(settings, p, grid_size, seeded));
  }
  if (settings.creases_on) {
    mark = max(mark, creases(settings, p, grid_size, seeded));
  }
  if (mark == MARK_DARK) {
    colour = dark_colour;
  } else if (mark == MARK_LIGHT) {
    colour = light_colour;
  }
  return colour;
}
