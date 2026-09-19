// Hover, selected and press feedback on an interactive control (docs/systems/control_feedback.md):
// a rough printed border just inside the control's edge, and, on a button, a light wash that lifts its
// dark fill as the pointer arrives. Included by panel_wear.gdshader, so the feedback is drawn by the
// same canvas item as the control's own panel: behind its text and children, and already carrying the
// panel's rectangle. `ControlFeedback` pushes the four amounts per control as instance uniforms, so
// one material serves every control.

// The noise functions come from print_noise.gdshaderinc, which panel_wear.gdshader already includes
// through print_wear.gdshaderinc; Godot has no include guards, so this file must not include it again.


// Set from Colours by ControlFeedback, so they are not look settings. The control's rectangle comes
// from panel wear's own `panel_rect`. The control's rectangle comes
// from panel wear's own `panel_rect`.
uniform vec3 highlight_colour : source_color = vec3(0.82, 0.8, 0.76);
uniform vec3 fill_colour : source_color = vec3(0.78, 0.77, 0.74);
uniform vec3 bloom_colour : source_color = vec3(0.2, 0.2, 0.2);

// How far the pointer feedback has come in, 0 to 1.
instance uniform float hover = 0.0;
// Held at 1 while the control is the chosen one, whatever the pointer is doing.
instance uniform float selected = 0.0;
// How far the press has gone in, 0 to 1.
instance uniform float press = 0.0;
// A short pulse of extra ink on release, 0 to 1.
instance uniform float bloom = 0.0;
// 1 on a control whose whole body lights up (a plain button); 0 on one that only takes a border,
// such as an item cell or a character card, whose body is a picture.
instance uniform float fill_shown = 0.0;

group_uniforms highlight_border;
uniform bool highlight_border_on = true;
// Line width, in screen pixels.
uniform float highlight_border_width : hint_range(1.0, 16.0, 0.5) = 3.0;
// Space between the control's edge and the line, in screen pixels.
uniform float highlight_border_inset : hint_range(0.0, 16.0, 0.5) = 2.0;
// How far the line's edges wander, in screen pixels.
uniform float highlight_border_roughness : hint_range(0.0, 8.0, 0.1) = 1.5;
// How much of the line is rubbed away, as on the printed border around the corridor.
uniform float highlight_border_wear : hint_range(0.0, 1.0, 0.01) = 0.25;
// Size of the rough edges and rubbed spots, in screen pixels.
uniform float highlight_border_scale : hint_range(1.0, 64.0, 0.5) = 6.0;
// How solid the line is at full hover and while selected.
uniform float highlight_border_hover : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform float highlight_border_selected : hint_range(0.0, 1.0, 0.01) = 1.0;
// How much further in the line is pulled at full press, in screen pixels.
uniform float highlight_border_press_inset : hint_range(0.0, 8.0, 0.5) = 1.0;
group_uniforms;

group_uniforms highlight_fill;
uniform bool highlight_fill_on = true;
// How far the body lifts towards the light colour at full hover and at full press.
uniform float highlight_fill_hover : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float highlight_fill_press : hint_range(0.0, 1.0, 0.01) = 1.0;
// How dark the release pulse of extra ink goes. It is drawn on every control, not only filled ones.
uniform float highlight_fill_bloom : hint_range(0.0, 1.0, 0.01) = 0.35;
group_uniforms;


// `top` drawn over `bottom`, both straight (not premultiplied) colours.
vec4 highlight_over(vec4 top, vec4 bottom) {
  float alpha = top.a + bottom.a * (1.0 - top.a);
  if (alpha <= 0.0) {
    return vec4(0.0);
  }
  return vec4((top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / alpha, alpha);
}


// How solid the border line is at this pixel: 0 off the line, and less than 1 where it is rubbed.
// `frag` is the pixel's screen position: the language only offers FRAGCOORD inside fragment().
float highlight_border_alpha(vec2 local, vec2 size, vec2 frag, float amount, out vec3 colour) {
  colour = highlight_colour;
  if (!highlight_border_on || amount <= 0.0) {
    return 0.0;
  }
  vec2 edge = min(local, size - local);
  float from_outside = min(edge.x, edge.y);
  float roughness = highlight_border_roughness;
  float inset = highlight_border_inset + press * highlight_border_press_inset;
  float outer = inset + (value_noise(frag / highlight_border_scale) - 0.5) * 2.0 * roughness;
  float inner = outer + highlight_border_width
    + (value_noise(frag.yx / highlight_border_scale + 9.1) - 0.5) * 2.0 * roughness;
  if (from_outside < outer || from_outside >= inner) {
    return 0.0;
  }
  float rub = fbm(frag / (highlight_border_scale * 2.0)) * 0.7 + hash12(frag + 1.7) * 0.3;
  float threshold = 1.0 - highlight_border_wear * 0.6;
  if (rub > threshold) {
    return 0.0;
  }
  if (rub > threshold - 0.06) {
    colour = mix(highlight_colour, bloom_colour, 0.5);
  }
  return amount;
}


// `base` with the wash, the release pulse and the border drawn over it, in that order.
vec3 control_highlight(vec3 base, vec2 local, vec2 size, vec2 frag) {
  float fill = 0.0;
  if (highlight_fill_on) {
    fill = fill_shown * max(hover * highlight_fill_hover, press * highlight_fill_press);
  }
  vec4 result = highlight_over(vec4(fill_colour, fill), vec4(base, 1.0));
  result = highlight_over(vec4(bloom_colour, bloom * highlight_fill_bloom), result);
  vec3 line_colour;
  float line = highlight_border_alpha(local, size, frag,
    max(hover * highlight_border_hover, selected * highlight_border_selected), line_colour);
  return highlight_over(vec4(line_colour, line), result).rgb;
}
