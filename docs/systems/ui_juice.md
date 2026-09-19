# UI Juice

`UIJuice` (`src/ui/ui_juice.gd`) is a drop-in node that gives an interactive
Control a centred squash and a small drop on press, the highlight that answers the
pointer ([control_feedback.md](control_feedback.md)), and hover and click sounds.
Hovering does not change the Control's size.

> Convention (CLAUDE.md): when adding new UI, add a UIJuice node to it.

## Usage

Add a `UIJuice` node as a **child** of the Control you want juiced (it appears
in the Create Node dialog). It targets its parent, so no wiring is needed. Pick a
**Preset** in the inspector.

- Works on any **Control** (the parent must be a Control, or juice disables
  itself with a warning). Hover sounds fire on any Control.
- **Press** effects (squash, drop, click sound and the release pulse) fire only on
  `BaseButton`, via its `button_down` / `button_up` / `pressed` signals.
- **Hover and press feedback** is drawn by [control feedback](control_feedback.md).
  The Preset decides the kind: BUTTON lights the whole body, CARD and ICON take the
  border only.

## Presets

| Preset | Use |
|---|---|
| **BUTTON** | Standard menu and control buttons. |
| **CARD** | Big interactive panels; a gentler, slower squash. |
| **ICON** | Icon and toolbar buttons; a stronger, quicker squash. |

The values for each preset are in `_PRESETS` at the top of `ui_juice.gd`.

## Overrides

Under the **Overrides** group, `press_scale` replaces the preset's squash size.
It defaults to `-1`, which keeps the preset value.

`highlight` overrides what the Preset decided: BORDER, FILL or NONE.
`highlight_target` names a child Control to draw the highlight on instead of the
parent — an item cell uses it to draw on its frame, because its value pills hang
outside the cell's own rectangle. The timing of the hover, press and release
effects is set in the [Feedback tab](control_feedback.md#the-feedback-tab); the
squash size and timing stay in the presets here.

## Sounds

- `play_sounds` toggles audio.
- `hover_sound` / `click_sound` are optional per-node `AudioStream` overrides;
  leave them null to use [SfxManager](audio.md)'s shared UI bank.

Sounds do nothing until audio assets exist, so juice is safe to add before sound
is wired.

## Behaviour notes

- **Offset transform (Godot 4.7)**: the squash runs on the parent's visual-only
  `offset_transform_scale` (enabled on ready), never the layout `scale`, so it
  does not fight the container that lays the Control out.
- **Centred scaling**: relies on `offset_transform_pivot_ratio`'s default of
  `(0.5, 0.5)`.
- **Release**: letting go of the button returns the scale to `1` with a small
  overshoot. The press lands quickly and the release springs back, so the control
  reads as pushed rather than dragged.
- **Cleanup**: kills its tweens, disconnects the parent's signals and drops the
  highlight in `_exit_tree()`.

## Portrait breathing

`PortraitBreath` (`src/ui/portrait_breath.gd`) is a second drop-in node, for
portraits rather than buttons. Add it as a **child** of a portrait's
`TextureRect` and the picture scales slowly up and back down forever, so a still
portrait looks like it is breathing.

- It is on the character select cards (`character_card.tscn`), the player
  portrait in the framed combat view, and the ally slots.
- The frames around those portraits have `clip_contents = true` so the picture
  never spills past the frame as it grows.
- `amount` is how much larger the picture gets at the top of the breath and
  `period` is how long one full breath takes; the defaults are in the script.
  The scale never goes below the resting size, so the frame is always filled.
- Each node starts at a random point in the cycle, so several portraits on
  screen do not breathe in unison.
- Like `UIJuice`, it animates the visual-only `offset_transform_scale` and
  restores the resting size in `_exit_tree()`.
