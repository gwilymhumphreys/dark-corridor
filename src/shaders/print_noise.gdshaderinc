// Hash and noise functions for the print look shaders (print_wear.gdshaderinc, print_border.gdshader).


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
