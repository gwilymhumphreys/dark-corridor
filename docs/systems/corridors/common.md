# Corridors — shared base & host

Both corridor renderers extend a common base and run inside a shared host. Read
this once; the per-renderer docs only cover what's unique.

The corridor is **pseudo-3D**: perspective is computed by hand and drawn with 2D
nodes. No `Camera3D`, meshes, or depth buffer.

## Which renderer?

- **Default — `CorridorScaled`** ([scale_and_place.md](scale_and_place.md)): rigid
  (no swim), four-side box (walls + floor + ceiling), per-side textures, easy
  tile-size experimentation. Build the game on this.
- **Toggle — `CorridorPerspective`** ([perspective_quad.md](perspective_quad.md)):
  fully parametric perspective (tune FOV freely) with any flat wall texture; side
  walls only (floor/ceiling = backdrop).

(A third "nested-frames" prototype was removed — `CorridorScaled` does the same
more flexibly via per-side textures.)

**Bundled texture:** `assets/sprites/test_wall.png` (52×192) — the default
side-wall tile for `CorridorScaled` (all four sides) and the placeholder for
`CorridorPerspective`'s wall + backdrop.

## Architecture

Host in `src/scenes/`; renderers in `src/scenes/corridors/`; shader in `src/shaders/`.
```
corridor_testbed.tscn/.gd  Host: UI (blur slider, mode switch, Back/Forward) +
                           a CorridorHolder node. Instances ONE renderer into the
                           holder and toggles it at runtime (M key / Mode button).
corridor_renderer.gd       Base class CorridorRenderer. Movement, velocity ramp,
                           blur/filter model, shared material, set_*/blur interface.
corridor_scaled.gd         Default renderer (extends CorridorRenderer).
corridor_perspective.gd    Toggle renderer (extends CorridorRenderer).
corridor_*.tscn            Each renderer's node tree (root carries position/scale).
sharp_bilinear.gdshader    Antialiased-nearest canvas shader (aa_strength uniform).
```

The host references renderers only through `CorridorRenderer`, and toggling swaps
the holder's child (the UI persists; no full scene reload). Anything built
against the interface works on either renderer.

### Embedding in the game / clipping

A renderer fills its viewport but its near "engulfing" tiles draw *beyond*
`view_size`; full-screen the screen clips them, but as a sub-rect they'd overdraw.
**`corridor_panel.tscn`** is the drop-in for that: a `SubViewportContainer`
(stretch) → `SubViewport` → `corridor_scaled.tscn`. Size/position the container
like any Control — the SubViewport matches it, `auto_view_size` fills it, and the
container **clips** the overflow. (Keyboard input still reaches the renderer; wire
`set_forward_held/back_held/blur` from the game for programmatic control.)

**Worked example: `corridor_panel_example.tscn` / `.gd`.** A standalone scene
showing the panel embedded in a themed `PanelFramed` frame, driven by themed
Buttons (Back / Forward hold to glide, Blur toggles the filter) that each carry a
`UIJuice` child. The script reaches the renderer via
`$Frame/CorridorPanel/SubViewport/CorridorScaled` and calls the interface only —
it never touches the geometry. Run it directly (it's not the main scene):
```powershell
& "...Godot...console.exe" --path "C:\projects\dark-corridor" res://src/scenes/corridor_panel_example.tscn
```
(`--shot` captures a mid-glide frame, same as the host.)

## `CorridorRenderer` base — what it owns

- **`view_size: Vector2`** — the W×H rectangle (local px) the corridor fills; the
  node origin is its centre (= the vanishing point). All geometry derives from
  this, so **aspect ratio = view_size.x : view_size.y**, independent of the node's
  `scale`.
- **`auto_view_size: bool`** (default true) — `view_size` is set automatically to
  the size of the viewport the renderer is in (the main viewport, or a SubViewport
  sized by its container) and re-synced on resize via `rebuild()`. So you size the
  container and the corridor follows — no manual numbers. Turn off to set
  `view_size` yourself. (Requires the renderer's parent to sit at origin (0,0).)
- **Input → motion**: `move_forward`/`move_back` (or `set_forward_held`/
  `set_back_held` from UI) set `dir`; a `velocity` eases toward `dir*speed` via
  `move_toward` over `ramp_time` (0.3s); `player_z += velocity*delta`.
  `player_z` is a continuous float in **cells**; `fposmod(player_z, 1.0)` is the
  sub-cell offset passed to `_layout()`.
- **Blur/filter model**: `aa_strength = blur_amount * (|velocity|/speed)`. So the
  sharp-bilinear filter is **never on at rest**, **scales with speed** while
  moving, and is **fully off at blur 0**. The shared `BlurSlider` (host UI) drives
  `set_blur`.
- **Filter/crispness**: nodes are spawned at hardware **NEAREST** (crisp at rest);
  `_apply_filter()` flips them to **LINEAR** only while moving (sharp-bilinear
  needs the bilinear fetch). Only touches nodes on a state change.
- **Interface**: `set_forward_held(bool)`, `set_back_held(bool)`, `set_blur(float)`.

### Subclass contract (virtuals)
- `_build()` — spawn nodes; assign each `_mat`; start at NEAREST filter.
- `_layout(frac)` — position/scale nodes for sub-cell offset `frac`.
- `_wall_nodes()` — return the CanvasItems whose `texture_filter` the base toggles.

Subclasses must NOT override `_ready()` (the base calls `_build()` from it).

## The filter: `sharp_bilinear.gdshader`

Continuously scaling nearest-neighbour pixel art shimmers ("texel crawl"). The
shader is **antialiased-nearest**: snaps UVs toward texel centres but blends a
~1-fragment band at texel boundaries. Uniform `aa_strength`: `0` = nearest, `1` =
full sharp-bilinear. (At rest the base also forces hardware NEAREST, because the
shader's nearest-reconstruction drifts slightly on heavily-scaled nodes.)

## Project configuration (`project.godot`)

- **Window** `2560×1440`, `stretch/mode = canvas_items`, `aspect = keep` — scales
  to any 16:9 monitor with no letterbox and no blurry blit.
- `rendering/.../default_texture_filter = 0` (Nearest).
- **Input map**: `move_forward` = W + Up, `move_back` = S + Down (physical keys).
- `application/run/main_scene = "res://src/scenes/corridor_testbed.tscn"` (the host).

## Pixel-art "low-res look at high-res"

No SubViewport: the corridor is drawn in the high-res canvas and the pixel-art
textures are scaled *up* (each renderer scene's root has a large `scale`). Slice
transforms are floats (no pixel snapping) → sub-pixel-smooth motion. UI lives on
a `CanvasLayer` and stays crisp at full resolution.

## Host extras (`corridor_testbed.gd`)

- **Toggle**: M key or Mode button cycles the renderers in `CORRIDOR_SCENES`.
- **Buttons**: Back/Forward use `button_down`/`button_up` → `_set_*` which forward
  to the current renderer (so the wiring survives a toggle). `focus_mode = 0`
  everywhere so UI never steals the arrow keys.
- **Dev hooks**: `--perspective` starts on the toggle renderer; `--shot` captures
  a mid-glide frame then quits (`--still` = stopped frame). Output → `user://shot.png`,
  path printed as `SHOT_SAVED:...`.

## Running

```powershell
& "C:\projects\godot\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --path "C:\projects\dark-corridor"
```
Headless reimport after adding/replacing PNGs:
```powershell
& "C:\projects\godot\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --path "C:\projects\dark-corridor" --import
```
(Godot **4.6**; the runnable exe is nested inside the per-version folder.)
