// Antialiased-nearest ("sharp bilinear") canvas shader.
// Keeps texel interiors crisp like nearest-neighbour, but blends across a
// ~1-fragment band at texel boundaries so the diagonal trapezoid edges and
// continuous scaling don't crawl/shimmer.
//
// The sprite MUST use a LINEAR texture filter (set in code) — this shader
// manipulates UVs and relies on the hardware doing a bilinear fetch.
//
// aa_strength: 0.0 = behaves like pure nearest, 1.0 = full sharp-bilinear.
// Driven per-frame by corridor.gd's filter_mode (OFF / ON / WHEN_MOVING).
shader_type canvas_item;

uniform float aa_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = UV * tex_size;
	vec2 texel_floor = floor(texel);
	vec2 s = fract(texel);

	// Screen pixels per texel along each axis, derived from the on-screen
	// derivative of UV. Auto-adapts to art_scale, per-slice scale and the
	// window's stretch factor (1080p/1440p/4K) all at once.
	vec2 scale = TEXTURE_PIXEL_SIZE / max(fwidth(UV), vec2(1e-6));
	scale = max(scale, vec2(1.0));

	// Flat (crisp) inside each texel, smooth ramp only within the boundary band.
	vec2 region = 0.5 - 0.5 / scale;
	vec2 cd = s - 0.5;
	vec2 f = (cd - clamp(cd, -region, region)) * scale + 0.5;

	vec2 sharp_uv = (texel_floor + f) * TEXTURE_PIXEL_SIZE;
	vec2 nearest_uv = (texel_floor + 0.5) * TEXTURE_PIXEL_SIZE; // texel centre == nearest
	vec2 final_uv = mix(nearest_uv, sharp_uv, aa_strength);

	COLOR = texture(TEXTURE, final_uv) * COLOR;
}
