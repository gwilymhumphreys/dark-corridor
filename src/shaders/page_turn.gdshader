shader_type canvas_item;
// The page turn between screens (docs/systems/page_turn.md): one side of the screen turns over on the
// fold like a book page and lands on the other side. The front of the page is a still image of the
// screen being left (`snapshot`); its back and the part it uncovers are the new screen, read live
// from the screen texture, so the new screen keeps moving while the page turns.
//
// The page bends only across its width, so seen from the side it is a curve (`curve`), which
// `PageTurnAutoload` works out each frame. For each pixel the shader walks the curve, finds the points
// whose perspective projection lands on this pixel's column, and keeps the one closest to the camera.
// All positions are in window pixels, the space of FRAGCOORD.

const int SEGMENTS = 64;

uniform sampler2D snapshot : repeat_disable, filter_linear;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// The page seen from the side, SEGMENTS + 1 points from the hinge to the free edge: x is the distance
// along the screen from the hinge towards the side the page starts on, y is the height towards the
// camera.
uniform vec2 curve[65];
// The fold the page turns on, across the screen.
uniform float hinge = 1280.0;
// 1 when the page starts right of the hinge and lands on the left, -1 the other way.
uniform float direction = 1.0;
// The page's width, from the hinge to its free edge.
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
// 0 to 1: when the page is narrower than the side it lands on, the part it never covers changes from
// the old screen to the new one by this much.
uniform float uncovered_fade = 0.0;


vec3 live_at(vec2 position, vec2 size) {
  return textureLod(screen_texture, position / size, 0.0).rgb;
}


vec3 still_at(vec2 position, vec2 size) {
  return textureLod(snapshot, position / size, 0.0).rgb;
}


void fragment() {
  vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
  vec2 frag = FRAGCOORD.xy;
  vec3 camera = vec3(hinge - direction * camera_offset * page_length, size.y * 0.5, camera_distance);
  vec3 light = normalize(vec3(light_direction.x * direction, light_direction.yz));
  float shadow_shift = -light.x / max(light.z, 0.05);

  float hit_z = -1.0;
  float hit_along = -1.0;
  float hit_x = 0.0;
  float hit_y = 0.0;
  vec2 hit_tangent = vec2(1.0, 0.0);
  float shadow = 0.0;
  for (int i = 0; i < SEGMENTS; i++) {
    vec2 a = curve[i];
    vec2 b = curve[i + 1];
    float xa = hinge + direction * a.x;
    float xb = hinge + direction * b.x;

    // The shadow this piece of page throws straight down the light onto the screen, softer the higher
    // the piece is.
    float shadow_a = xa + shadow_shift * a.y;
    float shadow_b = xb + shadow_shift * b.y;
    float outside = max(max(min(shadow_a, shadow_b) - frag.x, frag.x - max(shadow_a, shadow_b)), 0.0);
    float soft = 1.0 + shadow_softness * (a.y + b.y) * 0.5;
    shadow = max(shadow, 1.0 - smoothstep(0.0, soft, outside));

    float pa = camera.x + (xa - camera.x) * camera.z / (camera.z - a.y);
    float pb = camera.x + (xb - camera.x) * camera.z / (camera.z - b.y);
    if (frag.x < min(pa, pb) || frag.x > max(pa, pb) || abs(pb - pa) < 0.0001) {
      continue;
    }
    float t = (frag.x - pa) / (pb - pa);
    float z = mix(a.y, b.y, t);
    if (z <= hit_z) {
      continue;
    }
    float y = camera.y + (frag.y - camera.y) * (camera.z - z) / camera.z;
    if (y < 0.0 || y > size.y) {
      continue;
    }
    hit_z = z;
    hit_along = (float(i) + t) * page_length / float(SEGMENTS);
    hit_x = mix(xa, xb, t);
    hit_y = y;
    hit_tangent = normalize(b - a);
  }

  vec3 colour;
  if (hit_along >= 0.0) {
    vec2 front_position = vec2(hinge + direction * hit_along, hit_y);
    // Where this point of the page lies once it has landed.
    vec2 back_position = vec2(hinge - direction * hit_along, hit_y);
    vec3 normal = vec3(-hit_tangent.y * direction, 0.0, hit_tangent.x);
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
    if (side >= 0.0) {
      colour = live_at(frag, size);
    } else if (-side > page_length) {
      colour = mix(still_at(frag, size), live_at(frag, size), uncovered_fade);
    } else {
      colour = still_at(frag, size);
    }
    colour *= 1.0 - shadow * shadow_darkness * lift;
  }
  COLOR = vec4(min(colour, vec3(1.0)), 1.0);
}
