# UI theme, pixel-scale & fonts

How the UI is themed, how it gets its **chunky ~360p look on a true high-res
canvas**, and which font it uses. The theme resource is
`assets/themes/dark_corridor.tres`, set as the project default via `project.godot`
→ `gui/theme/custom`. `assets/themes/black_white_ui.tres` (the original "Black &
White UI" pack theme) is kept as the previous theme, unchanged, but is no longer
wired into the game.

## The theme

A `Theme` resource of `StyleBoxTexture` 9-slices over the pack's PNGs
(`assets/ui/*.png`), plus type **variations** controls opt into with
`theme_type_variation`:

| Variation | Used by |
|---|---|
| `PanelSlot` | item cells (`item_cell.tscn`) and keyword chips — pack art, unchanged |
| `Panel` / `PanelContainer` / `PanelFlat` / `PanelFramed` / `PanelSmall` / `PanelDetail` / `PanelPause` | flat fills of `Colours.UI_BACKGROUND` (no border, corner radius or shadow), each wrapped in a `WornStyleBox` so the panel wear marks it |
| `LabelDim` | dimmer section labels ("Potions", "Items") |

`PanelFramed` is used by most overlay panels and by the tooltip panel
(`tooltip_panel.tscn`) — the combat item tooltip is therefore also a flat
background-coloured block now, over the corridor image instead of over another UI
panel (owner's call whether that still reads well enough).

Godot's own built-in tooltip popup (the `TooltipPanel` / `TooltipLabel` theme types
the engine wraps a [tooltip](tooltips.md) custom node in) stays pack art; it is a
separate theme entry from `PanelFramed`, its own `StyleBoxTexture`.

### Flat, palette-following panels

The seven flat panel types above have no edge: a panel with no border, corner
radius or shadow is told apart only by the space it takes up and the
[wear](panel_wear.md) drawn on it — the owner's starting point for building the
new look from. Each is a `PaletteStyleBox` (`src/ui/palette_style_box.gd`, `class_name
PaletteStyleBox extends StyleBoxFlat`) with an exported `colour_name` naming the
`Colours` variable it fills from (`'UI_BACKGROUND'` for all seven today), wrapped in
a `WornStyleBox`. An [interface palette](interface_palette.md) sets its `bg_color`
straight from that named colour, both when applied and on reset, instead of
mapping it through the brightness ramp used for the remaining pack art.

To add another flat, palette-following panel type: create a `StyleBoxFlat`
sub-resource with `script = ExtResource(...)` pointing at `palette_style_box.gd`
(declared as `[sub_resource type="StyleBoxFlat" ...]`, not by class name — see the
theme-loading note below), set its `colour_name` and `content_margin_*`, wrap it in
a `WornStyleBox`, and point the type's style at the wrapper.

To give a still-textured type panel wear, wrap its stylebox in a `WornStyleBox`
sub-resource (`base` = the existing stylebox) and point the type's style at the
wrapper instead. No other change is needed; `WornStyleBox` copies `base`'s content
margins and minimum size, so layout is unaffected.

**Theme-loading trap:** the default theme loads before autoloads and before the
global class cache, so a script-backed stylebox in the `.tres` must be declared by
its engine base type (`StyleBox` or `StyleBoxFlat`) with `script = ExtResource(...)`,
not by class name, and the script itself must not reference an autoload by its bare
identifier at load time (`WornStyleBox` looks up `PrintLook` by node path for this
reason; `PaletteStyleBox` never reads `Colours` itself, so it has no such lookup).

The theme's colours and images can be recoloured at runtime by an
[interface palette](interface_palette.md); its default `UI_PANEL_*` and `UI_TEXT_*`
colours in `colours.gd` are the greys the theme uses, so keep them in step when
the theme's greys change.

**Buttons.** Every Button state uses the pack's black button art
(`btn-large-0.png`). The art is pure black, so a stylebox tint cannot lighten it;
the hover, pressed and disabled states are shown by the theme's `Button/colors/font_*`
text colours instead. Hover feedback comes only from this colour change, because
[UIJuice](ui_juice.md) does not resize on hover. The grey squares
(`btn-unpressed-0.png` / `btn-pressed-0.png`) are the checkbox icons.

Style UI through this theme (per `CLAUDE.md` "theme over code"); reserve runtime
`add_theme_*_override` for genuinely per-instance **data** (e.g. a `value_pill`'s
effect-colour fill), not static styling.

## The look: ~360p chunky UI on a 1440p canvas

The window is a **true 2560×1440 canvas** (`stretch/mode = canvas_items`,
`default_texture_filter = Linear Mipmap`). There is **no low-res framebuffer** — the UI
is *designed* to read as ~360p (a notional `Consts.UI_BASE_RESOLUTION` = 640×360
upscaled by `Consts.UI_SCALE` = 4 = 1440), but rendered at full resolution so
**fonts can stay smooth**. The corridor is a 3D scene drawn at full resolution
([corridor_3d.md](corridors/corridor_3d.md)).

This is the idiomatic Godot path when smooth fonts matter; the alternative
(`stretch/mode = viewport` + integer scale) renders the whole scene — text
included — into a 360p buffer and upscales it, which **pixelates fonts by design**.

**`UI_SCALE` is a sizing unit, not a transform.** Author chrome, icons, paddings
and separations in multiples of it. Do **not** scale it via `Control.scale` (fights
anchors/containers) or `Theme.default_base_scale` (unreliable — it scales roughly
the text-cursor width, not fonts/panels/styleboxes, and is read only at startup).

**Scaling pixel-art chrome.** A `StyleBoxTexture` has **no "draw at N×" property**
(`expand_margin_*` only adds fixed outward overdraw; it is *not* a scaler). To get
chunky borders, **author the art at its final display size** (e.g. a 64px panel
with a 20px 9-slice margin, not a 16px panel scaled up) and set `texture_margin_*`
to the new border size. The pack art stays sharp only where it is drawn at 1:1.

**Texture filtering and imports.** The project is no longer set up for pixel art. The
default canvas filter is Linear Mipmap, and `[importer_defaults]` in `project.godot`
turns on mipmaps for newly imported textures, so painted art such as the 256px icons in
`assets/icons/` shrinks smoothly. Images that must keep exact colours (palette strips)
have mipmaps turned off in their own `.import` files.

**Integer at-rest, smooth in motion.** No pixel-snap render setting is enabled
(global snapping would break the corridor's sub-pixel scroll and UIJuice). Instead:
a Control's **resting** position/size lands on whole pixels — `round()` any
*computed* rest offset (e.g. a centred row's `-size.y * 0.5`). **Animations are
free to move sub-pixel**: `offset_transform_*` is visual-only and returns to the
integer rest pose, so press squashes / slides glide smoothly without disturbing
layout.

## Fonts

The UI font is **Rakkas** (`assets/fonts/rakkas.ttf`, a free Google Font), chosen
from a screenshot comparison of candidate fonts. The theme resource names it as its
`default_font`, so every Control that doesn't override a font uses it — there is no
code that sets the font at runtime, and no font setting in the settings screen.

A second, pixel font style used to be wired through `Prefs` (a Smooth / Pixel
dropdown plus a locale gate that kept the Latin-only pixel font off non-Latin
locales). The pixel font asset was never added and the pixel-art direction was set
aside on 2026-09-16, so all of that was removed. If a second font style is wanted
later, it needs both the runtime swap and the locale gate again: a pixel font
realistically covers only Latin, and mixing it with a vector font inside one string
gives missing-glyph boxes or visibly mixed text.

Notes for whoever adds fonts for other scripts:

- The **font must cover every shipped locale.** Godot defers missing glyphs to OS
  fonts (`allow_system_fallback`, on by default), but that is desktop-only
  reliable: it is broken on Web and unsupported on consoles (godot#78921 /
  #84590). If Web or console export is ever on the table, bundle a font for every
  script shipped (a Noto base plus per-language Noto Sans SC/JP/KR subsets as
  `Font.fallbacks`; the full Pan-CJK set is very large).
- A theme's **default font is not covered by locale resource remapping**
  (godot#17640), so a per-locale font has to be swapped in code rather than through
  the `.po` / remap system. CJK also wants a larger render size than Latin, which
  means a per-locale `default_font_size` at the same time.

### Font candidates

`assets/fonts/candidates/` holds the other shortlisted free fonts (all from Google Fonts): Alegreya
SC, Cinzel, Eczar and Germania One. Try one in game with the F1 debug panel's Font dropdown or the
start-up argument `--font=<res path>` ([debug_panel.md](debug_panel.md)), which replace Rakkas for
that session. None is named by the theme. Delete the folder once the choice is final.

### Font import settings

Godot 4.7, so per-font/per-viewport oversampling applies (`FontFile.oversampling`).

- **Smooth (what Rakkas uses):** `antialiasing = Grayscale`, `hinting = Light`,
  `subpixel_positioning = Auto`, MSDF off, `oversampling = 0.0` (inherit → sharpens
  to 1440p). MSDF only earns its cost for large/zooming text (titles), not small
  body labels.
- **Crisp pixel (if a pixel font is ever added):** `antialiasing = Disabled`,
  `subpixel_positioning = Disabled`, **`oversampling = 1.0`** — otherwise the canvas
  scale re-rasterises the vector pixel-TTF fractionally and it blurs — and a default
  size that is an integer multiple of the font's native pixel size. A true bitmap /
  Image font sidesteps oversampling entirely.

## Status

- **Built:** `Consts.UI_SCALE` / `UI_BASE_RESOLUTION`; Rakkas as the theme's
  default font.
- **On hold:** reworking UI chrome onto the ×4 grid. The pixel-art direction was set
  aside on 2026-09-16; whether the interface frame and item icons stay pixel art is
  open ([art_audio.md](../design/art_audio.md)).
