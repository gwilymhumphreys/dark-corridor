# Control feedback

How an interactive control answers the pointer: a rough printed border just inside its edge while it
is hovered or selected, a light wash that lifts a plain button's dark fill, a squash and a small drop
on press, and one short pulse of extra ink on release. It applies to buttons, character and choice
cards, potion slots and board item cells.

**Location:** `src/shaders/control_highlight.gdshaderinc` (the drawing), `ControlFeedback`
(`src/autoloads/control_feedback.gd`, class `ControlFeedbackAutoload`), `UIJuice`
(`src/ui/ui_juice.gd`, [ui_juice.md](ui_juice.md)), the Feedback tab in `src/debug/feedback_panel.*`.
Saved as the feedback part of a [look preset](look_presets.md).

## How it works

- The highlight is drawn by the [panel wear](panel_wear.md) shader, which includes
  `control_highlight.gdshaderinc` and calls it after the wear. It therefore uses panel wear's material
  and its per-control canvas item, which is already behind the control's own text and children and
  already carries the control's rectangle. A control takes a highlight only where its own panel draws.
- Each control's four amounts — `hover`, `selected`, `press` and `bloom` — plus `fill_shown` are
  instance uniforms on that canvas item, so one material serves every control.
- `fill_shown` decides whether the whole body lights up. It is on for a plain button and off for a
  control whose body is a picture, such as an item cell or a character card, which take the border
  only.
- `hover` and `selected` are separate, so a selected control stays marked while another is hovered.
- Press completes what hover started rather than reversing it: the wash and the text colour go the
  rest of the way while the control is held, and settle back to the hover values on release.
- The text colour is not part of the shader. `UIJuice` overrides the button's font colours with a
  colour tweened between `Colours.UI_TEXT_BUTTON` and `UI_TEXT_BUTTON_DARK`. It has its own amounts
  (`text_hover`, `text_press`), so the text can reach nearly black while the body is only part way
  lit. The theme's own hover and pressed font colours would jump ahead of the tween, so every state's
  colour is overridden while the juice node is alive; the disabled colour is left to the theme.
- Colours come from `Colours` (`UI_HIGHLIGHT` for the border, `UI_BUTTON_LIGHT` for the wash,
  `UI_PANEL_WEAR` for the release pulse) and are pushed into the material at start and whenever an
  [interface palette](interface_palette.md) is applied or reset. The button's resting fill is
  `UI_BUTTON`, set through the theme ([ui_theme.md](ui_theme.md)).

## Who drives it

| Control | Driven by |
|---|---|
| Buttons, character and choice cards, potion slots, reward options, debug panel rows | `UIJuice` on `mouse_entered` / `mouse_exited` and the `BaseButton` press signals |
| Board item cells | `ItemCell.hovered`, set by `combat_view_framed.gd` from the tooltip hover poll — board items take no mouse events of their own ([tooltips.md](tooltips.md)). Setting it to true also plays the shared hover sound (`SfxManager.play_ui_hover()`) |
| Selection | Nothing yet. `set_selected` is there for a screen that keeps a chosen control marked |

`UIJuice` picks fill or border from its Preset (BUTTON lights the body, CARD and ICON take the border
only); its `highlight` export overrides that, and `highlight_target` names a child Control to draw on
instead of the parent, which an item cell needs because its value pills hang outside its rectangle.

## The Feedback tab

F5 opens the [debug panel](debug_panel.md) on this tab: a Timing section (how quickly the feedback
comes in, how far a pressed control drops, how long the release pulse lasts), a Text section (how far
the text darkens on hover and while held), and then the border and fill groups of the shader. The
press squash itself is a `UIJuice` preset, not a setting here.

In a preset, the feedback part has a `control_highlight` section for the shader settings and a
`control_settings` section for the rest.

## Public API

| Member | Use |
|---|---|
| `ControlFeedback.attach(control, fill)` | Give `control` a highlight; `fill` lights its whole body |
| `ControlFeedback.detach(control)` | Forget it. Called for you when the control leaves the tree |
| `set_hover`, `set_selected`, `set_press`, `set_bloom` | The four amounts, per control |
| `has_highlight(control)`, `highlight_count()` | Whether a control has one, and how many do |
| `setting_value(name)`, `setting_float(name)`, `set_setting(name, value)` | Read and set one setting, shader uniform or not |
| `defaults()`, `reset()`, `write_look(file)`, `read_look(file)` | Defaults, reset, and the preset part |
| `push_colours()` | Push the `Colours` values into the material |

Start-up arguments `--feedback-set=name=value`, `--feedback-panel` and `--feedback-demo=<amount>`
(hold every control hovered, for screenshots) are listed in
[dev_tools.md](dev_tools.md#look-arguments).

Tests: `tests/ui/test_control_feedback.gd`.
