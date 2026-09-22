# Panel wear

A dev tool that draws print wear on UI panels: faded areas, specks, rubbed edges and creases, in
palette colours, applied by default through the theme with no per-node setup. Each panel gets its own
canvas item and its own arrangement of marks, on one shared material and one shared setting group, so
every panel wears the same way but does not look identical. This is a step towards a cohesive paper-like
theme for the whole interface; the [screen background](background_wear.md) and the
[print frame](print_frame.md) around the combat corridor already have the same kind of wear.

**Location:** `src/ui/worn_style_box.gd` (class `WornStyleBox`), `src/shaders/panel_wear.gdshader`,
`src/shaders/print_wear.gdshaderinc` (the shared effect functions), `PrintLook`
(`src/autoloads/print_look.gd`, class `PrintLookAutoload`), which owns the material, settings, defaults
and reset for panel wear alongside background wear and the print frame. Settings are in the Print tab
([print_frame.md](print_frame.md)), under headings that say they apply to item borders and other panels.
Images outside a panel frame have their own picture wear in the Interface tab ([interface_look.md](interface_look.md#picture-wear)).

## How it works

- `WornStyleBox` wraps another `StyleBox` (its `base`) and copies `base`'s content margins and minimum
  size onto itself, so wrapping a style does not change a control's layout.
- Instead of drawing `base` itself, `WornStyleBox` asks `PrintLook` for a canvas item behind the
  control's own (`PrintLook.panel_wear_child`) and draws `base` into that, through
  `PrintLook.panel_material` (`panel_wear.gdshader`). The control's own text and child nodes draw on top
  of this, unworn.
- One canvas item is created per control (keyed by the control's own canvas item RID) and reused; it is
  cleared once per process frame before drawing, so a control that draws several styles in one frame
  (for example normal then focus) keeps both, and a resize leaves nothing from an earlier frame. It is
  also cleared when a draw in the same frame uses a different rectangle, so a control resized and
  drawn again within one frame does not keep its style at the old size too.
- A style's drop shadow is drawn outside its rectangle and takes no wear or control highlight
  (the `PanelToken` styles, [ui_theme.md](ui_theme.md)).
  `PrintLook` frees a control's canvas item when the control leaves the tree, and frees every remaining
  one at its own exit.
- The same shader and the same canvas item also draw the [control feedback](control_feedback.md):
  the highlight is applied after the wear, from its own per-control instance uniforms. Its settings
  are a separate preset part and a separate tab, and they stay out of `panel_defaults()` because that
  reads the shader's own code, not the included file's. `PrintLook.panel_child()` hands out the same
  canvas item without clearing it, for code that only sets instance uniforms on it.
- Each canvas item gets a `panel_seed` instance uniform, a counter that increases with every panel
  created, so same-size panels do not look identical. The material also takes the panel's rectangle as
  an instance uniform, so the wear reads in the panel's own pixels: edge wear rubs the panel's own
  edges, and the worn area size is the panel's size, not the screen's.
- Panel wear shares its faded areas, specks, edge wear and creases effects with the screen background
  and the corridor overlay (`print_wear.gdshaderinc`): each surface declares its own uniforms and fills
  a `PrintWearSettings` struct to call the same functions. Panel wear has no folds group; folds are laid
  out for a whole screen, not a panel.
- `assets/themes/dark_corridor.tres` wraps every panel type in a `WornStyleBox`: `Panel`, `PanelContainer`,
  `PanelFlat`, `PanelFramed`, `PanelSmall`, `PanelDetail`, `PanelPause` and `PanelSlot` each wrap a flat,
  palette-following `PaletteStyleBox` ([interface_palette.md](interface_palette.md),
  [ui_theme.md](ui_theme.md#flat-palette-following-panels)). `PanelSlot` is the frame behind icons and
  portraits. Godot's built-in `TooltipPanel` stays unwrapped pack art.
- The picture inside a `PanelSlot` draws on top of the wear unworn, and takes no picture wear of its
  own: those pictures are drawn through `InterfaceLook.framed_material`, which keeps picture wear off
  ([interface_look.md](interface_look.md#picture-wear)). The frame's wear is what shows around them.
  Pictures outside a `PanelSlot` do take picture wear.
- An [interface palette](interface_palette.md) sets `Colours.UI_PANEL_WEAR` and `UI_PANEL_WEAR_LIGHT`,
  the panel's two mark colours; `PrintLook` pushes them into `panel_material` at start and whenever a
  palette is applied or reset. `InterfacePalette` also recolours a `WornStyleBox`'s wrapped `base` when
  it walks the theme's styleboxes, the same way it recolours an unwrapped one.

| Group | Does |
|---|---|
| Panel Pattern | Pixel size, matching the background's |
| Panel Faded Areas | Soft patches lifting the panel towards the dark mark colour, scaled down from the background's |
| Panel Specks | Small solid dots, scaled down from the background's |
| Panel Edge Wear | Rubbed wear along the panel's own edges |
| Panel Creases | Faint bands across the panel |

The defaults are scaled down from the background's own (smaller faded areas, fewer and closer specks, a
narrower edge) and are starting values for the owner to tune from the Print tab.

## What is not covered

- `ColorRect`s, icons and text are unaffected; only a control's stylebox draws through this.
- Controls the theme does not define a stylebox for (for example `OptionButton`, sliders) are unworn.
- A control's `self_modulate` does not reach the worn copy, because it is a separate canvas item
  parented to the control's own, not drawn by the control itself; `modulate` does reach it.

## Presets and screenshots

Panel wear is saved in a preset's `print_panel` section and reset with the rest of the print part
([print_frame.md](print_frame.md#in-a-preset)). The mark colours are not saved; they come from
`Colours`.

For screenshots, `--panel-set=<uniform>=<value>` sets one setting (repeatable)
([debug_panel.md](debug_panel.md#start-up-arguments)).

Tests: `tests/debug/test_print_look.gd`, `tests/debug/test_worn_style_box.gd`.
