# UI theme, pixel-scale & fonts

How the UI is themed, how it gets its **chunky ~360p look on a true high-res
canvas**, and how the **vector ↔ pixel font** toggle works. The theme resource is
`assets/themes/black_white_ui.tres` (the "Black & White UI" pack), set as the
project default via `project.godot` → `gui/theme/custom`.

## The theme

A `Theme` resource of `StyleBoxTexture` 9-slices over the pack's PNGs
(`assets/ui/*.png`), plus type **variations** controls opt into with
`theme_type_variation`:

| Variation | Used by |
|---|---|
| `PanelSlot` | item cells (`item_cell.tscn`) — the item-slot frame |
| `PanelFramed` | the tooltip panel (`tooltip_panel.tscn`) |
| `PanelFlat` / `PanelSmall` / `PanelDetail` | general panels |

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
`default_texture_filter = Nearest`). There is **no low-res framebuffer** — the UI
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
to the new border size. Because the project filter is already Nearest, themed
StyleBoxTextures render crisp — no need to switch to `NinePatchRect` (which would
only matter if the global filter were Linear). Likewise use the 64px icons, not
16px sources stretched to fit.

**Integer at-rest, smooth in motion.** No pixel-snap render setting is enabled
(global snapping would break the corridor's sub-pixel scroll and UIJuice). Instead:
a Control's **resting** position/size lands on whole pixels — `round()` any
*computed* rest offset (e.g. a centred row's `-size.y * 0.5`). **Animations are
free to move sub-pixel**: `offset_transform_*` is visual-only and returns to the
integer rest pose, so press squashes / slides glide smoothly without disturbing
layout.

## Fonts: vector ↔ pixel toggle

Two looks share one mechanism — swap the **project theme's default font** at
runtime; every Control re-renders via `NOTIFICATION_THEME_CHANGED` (no manual
walk). Owned by `Prefs` (`src/autoloads/prefs.gd`):

- `Prefs.FontStyle` = `{ VECTOR, PIXEL }`; `Prefs.font_style()` / `set_font_style()`
  (persisted to `user://`, `display` section); `apply_font_style()` runs at boot.
- `apply_font_style()` loads the cached theme (`THEME_PATH`) and calls
  `theme.set_default_font(...)`. `null` = the engine built-in font.
- VECTOR uses **Rakkas** (`assets/fonts/rakkas.ttf`, a free Google Font), chosen
  from a screenshot comparison of candidate fonts.
- `FONT_PATHS` maps each style to a resource. PIXEL points at
  `assets/fonts/ui_pixel.ttf` **which does not exist yet** — until it's added,
  selecting PIXEL warns and falls back to the built-in font (the wiring is inert
  but harmless).

**Settings UI:** the settings screen (`settings_screen.tscn`) has a "Font"
`OptionButton` (Smooth / Pixel — static `.tscn` items, auto-translated) bound to
`Prefs.font_style` / `set_font_style`. Until the pixel asset lands, picking Pixel is
inert (falls back to the built-in vector font, with a warning).

### Localization: vector is the safe default; pixel is Latin-only

A pixel font realistically covers only Latin (an Eastern/CJK pixel font is rare and
huge — we deliberately won't ship one). So the system is built so **localization
can never produce missing-glyph "tofu" or pixel/vector-mixed text**, via two layers:

1. **Locale gate (`Prefs`).** `apply_font_style()` resolves an `_effective_style()`:
   PIXEL applies **only when it's selected AND the active locale's language is in
   `PIXEL_FONT_LOCALES`** (matched on the prefix, e.g. `en` in `en_US`). Any other
   locale renders fully in the **vector** font even when PIXEL is the stored
   preference (the preference is kept, so returning to a covered locale restores
   pixel). Default-deny: a new locale is vector until its language is explicitly
   added — so adding, say, `ja` can't accidentally tofu. `Prefs._notification`
   re-applies on `NOTIFICATION_TRANSLATION_CHANGED`, so a runtime language switch
   drops non-Latin locales back to vector automatically.
2. **Glyph fallback (the font assets).** Godot auto-defers missing glyphs to OS
   fonts (`allow_system_fallback`, default on) — the built-in Open Sans (Latin /
   Cyrillic / Greek only) shows CJK on desktop via this. Requirements when assets
   are added:
   - The **vector font must cover every shipped locale.** `allow_system_fallback`
     is **desktop-only reliable** — it's broken on **Web** and unsupported on
     consoles (godot#78921 / #84590). So if Web/console export is ever on the
     table, **bundle** a font for every script you ship (a Noto base +
     per-language **Noto Sans SC/JP/KR subsets** as `Font.fallbacks` — ship only
     the languages you localize into; the full Pan-CJK set is huge). Don't lean on
     system fallback there.
   - The **pixel font sets `fallbacks = [vector font]`** so any glyph it lacks
     (accents, punctuation, a stray symbol) degrades to vector instead of tofu —
     the safety net even within a Latin locale. (This per-glyph fallback is *only*
     a hole-filler; the pixel→vector switch for whole non-Latin locales is the
     locale gate above, not a fallback chain — a chain would render crisp-pixel
     ASCII mixed with smooth-vector ideographs in one string.)

Two more notes for when the vector CJK assets land: the theme's **default font is
not covered by locale resource remapping** (godot#17640) — which is *why* the swap
is done in code (`Prefs`), not via the `.po`/remap system. And **CJK wants a larger
render size** than Latin; the locale gate is the natural place to also pick a
per-locale `default_font_size` if needed.

So: vector = the universal, broad-coverage default for all locales; pixel = an
opt-in Latin-only flourish that the locale gate confines to covered locales.

### Font candidates

`assets/fonts/candidates/` holds the other shortlisted free fonts (all from Google Fonts): Alegreya
SC, Cinzel, Eczar and Germania One. Try one in game with the F1 debug panel's Font dropdown or the
start-up argument `--font=<res path>` ([debug_panel.md](debug_panel.md)), which replace Rakkas for
that session. None is wired into `Prefs.FONT_PATHS`. Delete the folder once the choice is final.

### Font import settings (when adding the assets)

Godot 4.7, so per-font/per-viewport oversampling applies (`FontFile.oversampling`).

- **Vector (smooth):** `antialiasing = Grayscale`, `hinting = Light`,
  `subpixel_positioning = Auto`, MSDF off, `oversampling = 0.0` (inherit → sharpens
  to 1440p). MSDF only earns its cost for large/zooming text (titles), not small
  body labels.
- **Pixel (crisp):** `antialiasing = Disabled`, `subpixel_positioning = Disabled`,
  **`oversampling = 1.0`** (the gotcha — otherwise the canvas scale re-rasterises
  the vector pixel-TTF fractionally → blur), and a default size that is an integer
  multiple of the font's native pixel size. A true bitmap / Image font sidesteps
  oversampling entirely.

## Status

- **Built:** `Consts.UI_SCALE` / `UI_BASE_RESOLUTION`; the `Prefs` font-style
  wiring (persist + apply at boot, VECTOR active with Rakkas) incl. the locale gate
  (`PIXEL_FONT_LOCALES` / `_effective_style` / re-apply on locale change); the
  settings-menu Font dropdown (`settings_screen.tscn`).
- **Pending:** the pixel font asset + its import settings; reworking existing UI
  chrome onto the ×4 grid (e.g. the item cell at 128px with a 64px icon) and
  rounding computed rest offsets.
