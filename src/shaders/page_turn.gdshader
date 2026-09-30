shader_type canvas_item;
// The page turn between screens (docs/systems/page_turn.md): one side of the screen turns over on the
// fold like a book page and lands on the other side. The front of the page is a still image of the
// screen being left (`snapshot`); its back and the part it uncovers are the new screen, read live
// from the screen texture, so the new screen keeps moving while the page turns.
//
// Seen from the side, the page's top edge and bottom edge are each a curve (`curve_top`,
// `curve_bottom`), which `PageTurnAutoload` works out each frame; every row between them is a blend of
// the two, so the page twists when one corner leads. For each pixel the shader guesses which row of
// the page it shows, walks that row's curve for the points whose perspective projection lands on the
// pixel's column, keeps the one closest to the camera, corrects the row for perspective and searches
// again until the row settles. All positions are in window pixels, the space of FRAGCOORD.

const int SEGMENTS = 64;
// Searches for the row of the page a pixel shows; the row stops changing after two or three.
const int ROW_PASSES = 3;

uniform sampler2D snapshot : repeat_disable, filter_linear;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// The page's top and bottom edges seen from the side, SEGMENTS + 1 points from the hinge to the free
// edge: x is the distance along the screen from the hinge towards the side the page starts on, y is
// the height towards the camera.
uniform vec2 curve_top[65];
uniform vec2 curve_bottom[65];
// The fold the page turns on, down the middle of the screen.
uniform float hinge = 1280.0;
// 1 when the page starts right of the hinge and lands on the left, -1 the other way.
uniform float direction = 1.0;
// The page's width, from the hinge to its free edge: half the screen.
uniform float page_length = 1280.0;
// The camera's height above the screen.
uniform float camera_distance = 3000.0;
// How far the camera sits from the hinge towards the side the page lands on, as a fraction of the page
// width, so the page is not seen edge-on when it stands upright. It is level with the screen's middle.
uniform float camera_offset = 0.3;
// Towards the light, with z towards the camera. x is mirrored for a turn the other way.
uniform vec3 light_direction = vec3(-0.35, -0.3, 1.0);
// How much the light darkens the side of the page turned away from it. A flat page is never shaded.
uniform float shading = 0.6;
// A faint highlight where the bend faces the light.
uniform float highlight = 0.15;
// How much of the page's front shows through on its back, like thin paper.
uniform float show_through = 0.0;
uniform float shadow_darkness = 0.55;
// How much wider the shadow's soft edge grows for each pixel the page is above the screen.
uniform float shadow_softness = 0.25;
// How far the page is off the screen, 0 to 1. Fades the shadow and the edge line in and out, so a
// flat page matches the screen exactly.
uniform float lift = 0.0;
// The light line along the page's free edge, in pixels.
uniform float edge_width = 2.0;
uniform vec3 edge_colour : source_color = vec3(0.48, 0.47, 0.47);


vec3 live_at(vec2 position, vec2 size) {
  return textureLod(screen_texture, position / size, 0.0).rgb;
}


vec3 still_at(vec2 position, vec2 size) {
  return textureLod(snapshot, position / size, 0.0).rgb;
}


// Point `i` of the page's row `row` (0 at the top edge, 1 at the bottom) seen from the side.
vec2 page_point(int i, float row) {
  return mix(curve_top[i], curve_bottom[i], row);
}


// The point of the page's row `row` nearest the camera whose projection lands on screen column
// `column`: its piece of page, how far along that piece, and its height. False when there is none.
bool nearest_point(float column, float row, vec3 camera, out int piece, out float t, out float z) {
  bool found = false;
  z = -1.0;
  for (int i = 0; i < SEGMENTS; i++) {
    vec2 a = page_point(i, row);
    vec2 b = page_point(i + 1, row);
    float xa = hinge + direction * a.x;
    float xb = hinge + direction * b.x;
    float pa = camera.x + (xa - camera.x) * camera.z / (camera.z - a.y);
    float pb = camera.x + (xb - camera.x) * camera.z / (camera.z - b.y);
    if (column < min(pa, pb) || column > max(pa, pb) || abs(pb - pa) < 0.0001) {
      continue;
    }
    float along = (column - pa) / (pb - pa);
    float height = mix(a.y, b.y, along);
    if (height <= z) {
      continue;
    }
    found = true;
    piece = i;
    t = along;
    z = height;
  }
  return found;
}


void fragment() {
  vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
  vec2 frag = FRAGCOORD.xy;
  vec3 camera = vec3(hinge - direction * camera_offset * page_length, size.y * 0.5, camera_distance);
  vec3 light = normalize(vec3(light_direction.x * direction, light_direction.yz));

  // Which row of the page this pixel shows: start from the pixel's own row, and move it by the
  // perspective of the point found until it settles.
  float row = frag.y / size.y;
  bool found = false;
  int piece = 0;
  float t = 0.0;
  float hit_z = 0.0;
  for (int attempt = 0; attempt < ROW_PASSES; attempt++) {
    found = nearest_point(frag.x, clamp(row, 0.0, 1.0), camera, piece, t, hit_z);
    if (!found) {
      break;
    }
    float settled = (camera.y + (frag.y - camera.y) * (camera.z - hit_z) / camera.z) / size.y;
    bool still = abs(settled - row) * size.y < 0.25;
    row = settled;
    if (still) {
      break;
    }
  }

  vec3 colour;
  if (found && row >= 0.0 && row <= 1.0) {
    vec2 a = page_point(piece, row);
    vec2 b = page_point(piece + 1, row);
    float hit_along = (float(piece) + t) * page_length / float(SEGMENTS);
    float hit_x = hinge + direction * mix(a.x, b.x, t);
    float hit_y = row * size.y;
    vec2 front_position = vec2(hinge + direction * hit_along, hit_y);
    // Where this point of the page lies once it has landed.
    vec2 back_position = vec2(hinge - direction * hit_along, hit_y);
    // The page's slope across its width and down its height, for its normal.
    vec3 across = vec3(direction * (b.x - a.x), 0.0, b.y - a.y);
    vec2 twist = mix(curve_bottom[piece] - curve_top[piece], curve_bottom[piece + 1] - curve_top[piece + 1], t);
    vec3 down = vec3(direction * twist.x, size.y, twist.y);
    vec3 normal = normalize(cross(across, down)) * direction;
    vec3 to_camera = normalize(camera - vec3(hit_x, hit_y, hit_z));
    bool front = dot(normal, to_camera) >= 0.0;
    if (front) {
      colour = still_at(front_position, size);
    } else {
      normal = -normal;
      colour = mix(live_at(back_position, size), still_at(front_position, size), show_through);
    }
    float flat_light = max(light.z, 0.05);
    float lambert = max(dot(normal, light), 0.0) / flat_light;
    colour *= mix(1.0, lambert, shading);
    vec3 halfway = normalize(light + to_camera);
    float sheen = pow(max(dot(normal, halfway), 0.0), 24.0) - pow(max(halfway.z, 0.0), 24.0);
    colour += max(sheen, 0.0) * highlight;
    float edge = 1.0 - smoothstep(edge_width * 0.5, edge_width + 0.001, page_length - hit_along);
    colour = mix(colour, edge_colour, edge * lift * step(0.001, edge_width));
  } else {
    float side = direction * (frag.x - hinge);
    colour = side >= 0.0 ? live_at(frag, size) : still_at(frag, size);
    // The shadow the page's row level with this pixel throws straight down the light onto the screen,
    // softer the higher the page is.
    float shadow_shift = -light.x / max(light.z, 0.05);
    float table_row = frag.y / size.y;
    float shadow = 0.0;
    for (int i = 0; i < SEGMENTS; i++) {
      vec2 a = page_point(i, table_row);
      vec2 b = page_point(i + 1, table_row);
      float shadow_a = hinge + direction * a.x + shadow_shift * a.y;
      float shadow_b = hinge + direction * b.x + shadow_shift * b.y;
      float outside = max(max(min(shadow_a, shadow_b) - frag.x, frag.x - max(shadow_a, shadow_b)), 0.0);
      float soft = 1.0 + shadow_softness * (a.y + b.y) * 0.5;
      shadow = max(shadow, 1.0 - smoothstep(0.0, soft, outside));
    }
    colour *= 1.0 - shadow * shadow_darkness * lift;
  }
  COLOR = vec4(min(colour, vec3(1.0)), 1.0);
}
