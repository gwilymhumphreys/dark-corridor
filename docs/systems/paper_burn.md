# Paper burn

A reusable effect that burns a Control away like paper catching fire. A ragged hole spreads from a
point on its edge. The edge of the hole has a glowing ember line, a black char band behind it and a
dithered scorch ahead of it, and sparks and ash rise from it. Nothing is left at the end. The map uses
it to burn away the token on a square once its fight is won, and a dead enemy's HUD and corridor
sprite burn away with it. Run backwards, it makes a Control appear out of the fire instead, as the
pictures on character select do. It is a visual effect only and has nothing to do with the Burn mechanic.

**Location:** `src/ui/paper_burn.gd` + `.tscn` (`PaperBurn`), `src/shaders/paper_burn.gdshader`, the
hole and bands shared with the sprite burn in `src/shaders/paper_burn.gdshaderinc`, the sprite burn
(`src/scenes/corridors/sprite_burn.gd`, `src/shaders/paper_burn_sprite.gdshader`), the
Paper burn section of the F7 tab (`src/debug/tokens_panel.gd`), and the preview scene
`src/debug/scenes/paper_burn_preview.tscn`.

## How it works

- `PaperBurn.burn(target)` adds a `PaperBurn` node under the target. The node sets the target to clip
  its children (`clip_children = CLIP_CHILDREN_ONLY`), gives it the burn material, and draws a
  rectangle on it through its `draw` signal.
- In clip mode Godot draws the children into a buffer and then draws the target's own drawing over
  them, the way a `CanvasGroup` works. The burn shader reads the children's pixels from the screen
  texture, cuts the hole and colours the bands on those pixels. Everything under the target burns:
  a worn panel and its drop shadow, an icon, value pills and text. The bands take the children's shape,
  so they stay on a tilted token.
- The rectangle is the target grown by `MARGIN`, so the drop shadow and pills outside the target are
  drawn. Outside the target's own rectangle the hole takes its value from the nearest point on the
  edge and no bands are drawn.
- The hole is the distance from the ignition point, pushed in and out by warped noise. The ignition
  point is on the edge, on a side picked by `SIDE_WEIGHTS`.
- The ember line is brighter than white and flickers. The sparks ask `InterfaceGlow` for glow, which
  switches the screen glow on for the length of the burn ([interface_glow.md](interface_glow.md)).
- `Sparks` and `Ash` are `CPUParticles2D` set to `top_level`, so the clip does not cut them. Each frame
  they emit from points on the burn front, which is the circle around the ignition point where it
  crosses the target.
- At the end the target's `clip_children`, material and draw connection are put back, and its
  `modulate` alpha is set to 0, so it keeps its place in a container. The particles move to the
  target's parent and free themselves after their lifetime. If the `PaperBurn` node is freed early,
  it puts the target back and does not hide it.

**Backwards.** `PaperBurn.burn(target, true)` runs the same burn from nothing left to whole. The
target is shown when it starts and stays shown at the end.

**What to burn.** The target's own drawing is replaced by the burn rectangle, so burn a Control that
draws nothing itself and holds the visible nodes. An `ItemCell` or a `StatusIcon` qualifies. A panel
does not: a worn panel draws its background in a canvas item behind itself, and in clip mode that
background covers the panel's own children. Put the panel inside a plain Control and burn that. The
preview scene does this for its wide panel.

## Look

Colours come from the [interface palette](interface_palette.md): `PAPER_BURN_EMBER`,
`PAPER_BURN_CHAR` and `PAPER_BURN_SCORCH` in `Colours`, named in every palette file. Each file sets them
to colours it already has, so the burn adds no colours of its own: the ember and the scorch take the
Burn mechanic's colour, and the char takes the file's darkest colour. The scorch
multiplies the pixels under it towards the scorch colour, so a light icon browns while the dark card
stays dark. It is dithered with the palette clamp's dither pattern unless `paper_burn_dither` is off.
Sizes are in pixels, so the ember line is the same thickness on every size of token.

With `paper_burn_palette` on, the pixels the bands colour are snapped to the combat effects' palette
([interface_look.md](interface_look.md#the-combat-effects)), and the hole's edge is solid or empty by the
dither pattern. `PaperBurn` copies the palette, matching, dithering switch and dither pattern from
`InterfaceLook.effects_material` when a burn starts. The token's untouched pixels are not snapped again,
because its pictures are already snapped to their own palette. The ember line is snapped first and then
multiplied by `paper_burn_brightness`, so above 1 it still glows but its brightest pixels are no longer
palette colours; at 1 every pixel of the line is a palette colour.

## Settings

Print settings (`PrintLook.PRINT_SETTING_DEFAULTS`), on the F7 tab's Paper burn section and saved in
presets ([print_frame.md](print_frame.md)). They are read when a burn starts.

| Setting | Sets |
|---|---|
| `paper_burn_duration` | Seconds from the first mark to nothing left |
| `paper_burn_raggedness` | How far the noise pushes the edge in and out, in pixels |
| `paper_burn_detail` | The size of the edge's bumps, in pixels |
| `paper_burn_ember_width`, `paper_burn_char_width`, `paper_burn_scorch_width` | The widths of the bands, in pixels |
| `paper_burn_brightness` | How far above white the ember line and sparks go |
| `paper_burn_dither` | Dithered or smooth scorch |
| `paper_burn_palette` | Bands snapped to the combat effects' palette, and a solid hole edge |
| `paper_burn_particles` | Sparks and ash on or off |

## Enemy sprites

An enemy sprite is a `Sprite3D` in the corridor, not a Control, so it burns through its own shader.
`Corridor3D.burn_enemy(sprite)` adds a `SpriteBurn` node under the corridor node, which gives the
sprite `paper_burn_sprite.gdshader` as its material override and removes the sprite through
`remove_enemy` when nothing is left.

- The hole and the bands come from `paper_burn.gdshaderinc`, the same code as the interface burn.
  `rect_size` is the sprite's size on screen, and the image's UV is scaled to it, so the bands are as
  many screen pixels wide as on a token.
- The sprite stays lit by the corridor light. The part of the ember line above white is also
  emission, so it shows in the dark.
- The scorch is smooth and the bands are not snapped by the burn. The corridor look shader runs over
  the corridor image, so the world palette snaps them with everything else.
- The sparks and ash are the same emitters as the interface burn's (`PaperBurn.new_particles()`),
  children of the `SpriteBurn` node, so they are drawn over the corridor image in the corridor
  node's coordinates. They do not ask `InterfaceGlow` for glow.
- It reads the same `paper_burn_*` settings, except `paper_burn_dither` and `paper_burn_palette`.

## Uses

- **The map.** When a fight is won, `RunScreen` calls `MapStrip.burn_current_square()`, which burns
  the current square's token when `map_cleared_look` is Burnt away ([run_screen.md](run_screen.md)).
- **Dead enemies.** When an enemy is reaped, its HUD and its corridor sprite burn away where they
  stand ([run_screen.md](run_screen.md#enemies-in-the-corridor-the-approach)). The HUD's panel is
  see-through, so burning it whole would show a rectangle, and `CharacterPanel.burn_away()` burns each
  shown part separately instead: the name, the health bar, each status icon and each item cell. A
  label draws itself, so the name is put in a plain Control the size of its text, and that burns.
  After the last enemy dies the run screen waits for the view's `burns_finished`, then
  `Balance.FIGHT_END_PAUSE`, before it moves on, since the next beat frees the view.

- **Character select.** Hovering a character's card burns its large picture in backwards on the left
  page, and leaving the card burns it away. A burn still running on the picture is freed first
  ([run_screen.md](run_screen.md)).

## Preview

`paper_burn_preview.tscn` shows map-size and item-size tokens held at points through a burn, and a map
token, an item token and a wide panel burning over and over. The settings are read again each time
the burns restart, so the F7 sliders can be tuned while it runs ([dev_tools.md](dev_tools.md)).

## Public API

| Member | Use |
|---|---|
| `PaperBurn.burn(target: Control, backwards := false) -> PaperBurn` | Start a burn with the current settings; backwards makes the target appear |
| `reverse` | Whether the burn runs backwards |
| `finished` | Emitted when nothing is left |
| `hide_when_done` | Set false to leave the target shown at the end (the preview repeats burns) |
| `hold(progress)` | Stop at a fixed progress from 0 to 1 |
| `finish()` | Jump to the end |

Tests: `tests/ui/test_paper_burn.gd`, `tests/ui/test_character_select.gd`, the dead enemy cases in `tests/corridors/test_combat_corridor.gd`
and `tests/ui/test_combat_view.gd`, and the burn cases in `tests/ui/test_map_strip.gd` and
`tests/ui/test_run_screen.gd`.

Research the look was built from: [Kyle Halladay's burning paper shader](https://kylehalladay.com/blog/tutorial/2015/11/10/Dissolve-Shader-Redux.html)
(a dissolve spreading from a point, with noise on the distance), [Game Dev Bill's paper burn
shader](https://gamedevbill.com/paper-burn-shader-in-unity/) (the char, grey and ember bands), and the
[2D dissolve with burn edge](https://godotshaders.com/shader/2d-dissolve-with-burn-edge/) and
[burning paper](https://godotshaders.com/shader/burning-paper/) shaders on Godot Shaders.
