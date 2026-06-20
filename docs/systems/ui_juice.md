# UI Juice

`UIJuice` (`src/ui/ui_juice.gd`) is a drop-in node that makes any interactive
Control feel alive: a centred scale bounce on hover and a squash on press, with
hover/click sounds. The tween recipe is derived from a-machine's `HoverButton`,
generalised from "a Button subclass" to "a child node you attach to anything".

> Convention (CLAUDE.md): when adding new UI, add a UIJuice node to it.

## Usage

Add a `UIJuice` node as a **child** of the Control you want juiced (it appears
in the Create Node dialog). It auto-targets its parent — no wiring. Pick a
**Preset** in the inspector; that's usually all you need.

- Works on any **Control** (the parent must be a Control, or juice disables
  itself with a warning).
- **Press** effects (squash + click sound) additionally fire on `BaseButton`
  via its `button_down` / `button_up` / `pressed` signals.

## Presets

Choose the feel from the `preset` dropdown:

- **BUTTON** — standard menu/control button: modest pop, snappy.
- **CARD** — larger, slower, lifts slightly; for big interactive panels.
- **ICON** — small, punchy pop; for icon/toolbar buttons.

Each preset is a table of scale/time values in `_PRESETS` at the top of
`ui_juice.gd` — see there for the actual numbers.

## Overrides

Under the **Overrides** group, set a value to replace the preset's. Each
defaults to `-1` meaning "inherit from preset":

- `hover_scale` — resting hover size multiplier.
- `press_scale` — squash size while pressed.
- `lift` — pixels the node rises on hover. Safe on container-managed nodes: the
  rise is applied through the visual-only offset transform (see below), so it
  no longer fights layout.

## Sounds

- `play_sounds` toggles audio.
- `hover_sound` / `click_sound` are optional per-node `AudioStream` overrides;
  leave them null to use [SfxManager](audio.md)'s shared UI bank.

Sounds no-op until audio assets exist, so juice is safe to add now and wire
sound later.

## Behaviour notes

- **Offset transform (Godot 4.7)** — all motion runs on the parent's visual-only
  `offset_transform_*` (enabled on ready), never the layout `scale`/`position`.
  This is what lets juice live on container-managed Controls without fighting the
  container — including `lift`.
- **Centred scaling** — relies on `offset_transform_pivot_ratio`'s default of
  `(0.5, 0.5)`, so it grows from the centre at any size (no pivot recompute on
  resize).
- **Bounce** — hover overshoots past the hover size then settles back (a small
  secondary dip via `TRANS_BACK`); release from a press pops back up.
- **Rest state** — the offset transform rests at scale `1` / position `0`, so
  interrupted hovers always return cleanly without capturing a base transform.
- **Cleanup** — kills its tween in `_exit_tree()`.
