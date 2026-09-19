# Plan: icon slots, the icon panel and a custom palette

Three connected pieces of work:

1. Flat glyph icons that stay readable at the size they appear in text, with a
   pool of candidates per slot rather than one pick.
2. A new debug tab for choosing a slot's icon and colour in game, with live
   samples, saving each choice as it is made.
3. A custom interface palette the tab writes chosen colours into, cloned from
   whichever palette is active, plus colour pickers for the rest of its colours.

Status: plan, not built.

The steps below are sized so each one is a single delegate run with a diff that
can be reviewed on its own. Each says which files it touches, what it must not
change, and how to tell it is done. Steps marked **(here)** are not delegated:
they need tools the local model does not have, or are too small to be worth a
task file.

## Why the current icons fail

The mechanic icons come from `6000FantasyIcons`, which is painted illustration
at 256x256: each one is a small scene with a light source, a glow and several
colours. At the 20 to 28 pixels a keyword chip gives them they become coloured
smears. Seven are already marked `# PLACEHOLDER icon` in
`src/content/mechanics/*.gd`, heal and regen share one file, and attack and crit
share another.

Contact sheets in `screenshots/`: `mechanic_icons_current.png` is the ten we
have, `mechanic_icons_pools.png` is the replacement pools.

## Icon slots

A slot is a name that owns one icon. The ten mechanics are slots, and so are two
things that are not mechanics:

| Slot | What it marks |
|---|---|
| `attack` to `decharge` | The ten mechanics, one slot each. |
| `charge_time` | An item's `cooldown`, which the tooltip stat block prints as `Every {0}s`. |
| `card` | One item in the player's collection, for text that refers to an item without naming it. |

`charge_time` and `card` have no `Mechanic` class, so the slot list cannot be
`MechanicRegistry`. A new `IconSlots` class owns it.

## The candidate icons

From game-icons.net (`https://github.com/game-icons/icons`): single-colour
silhouette SVG at 512x512. Twelve candidates per slot, 144 in total, rasterised
to white-on-transparent PNG at 128x128 and tinted at runtime with the slot's
colour.

PNG rather than shipping the SVG: Godot rasterises an imported SVG once at a
fixed scale anyway, so there is no runtime gain, and every other icon in
`assets/icons/` is a PNG.

Layout, so the panel can list a slot's pool by reading one folder:

```
assets/icons/mechanics/<slot>/<source-name>.png
```

### Default per slot

The icon a slot uses until one is chosen in the panel. These are starting points
picked for readability at 16px, not final choices — choosing the final ones in
game is what this plan is for.

| Slot | Default file |
|---|---|
| `attack` | `attack/crossed-swords.png` |
| `shield` | `shield/shield.png` |
| `heal` | `heal/heart-plus.png` |
| `poison` | `poison/skull-crossed-bones.png` |
| `burn` | `burn/fire.png` |
| `bleed` | `bleed/droplets.png` |
| `regen` | `regen/cycle.png` |
| `crit` | `crit/round-star.png` |
| `charge` | `charge/fast-forward-button.png` |
| `decharge` | `decharge/fast-backward-button.png` |
| `charge_time` | `charge_time/hourglass.png` |
| `card` | `card/card-draw.png` |

## Deferred

The `charge_time` glyph beside the tooltip's `Every {0}s` line. That means
rebuilding the stat block, which `TooltipPanel._set_stats` currently joins into
one `Label`, into segment rows like the effect lines. The `charge_time` slot
still exists and its icon is still chosen in the panel; only the tooltip
display waits.

---

## Step 1 — Rasterise the candidate icons **(here)**

**Goal.** Put the 144 candidate PNGs in the tree.

Rasterise each SVG to a white-on-transparent PNG at 128x128 into
`assets/icons/mechanics/<slot>/<source-name>.png`, keeping the game-icons file
name. Run `tools/import.sh`.

Not delegated: it needs the game-icons archive and an SVG rasteriser.

**Done when** the twelve folders hold twelve PNGs each and the import reports no
failures.

---

## Step 2 — The `IconSlots` class

**Goal.** One class owning the slot list, the chosen icons and the saved file.
Nothing uses it yet, so this step changes no existing behaviour.

**Files.** New `src/content/mechanics/icon_slots.gd`; new
`tests/content/test_icon_slots.gd`.

**The class.** `class_name IconSlots`, static only, like `MechanicRegistry` and
`StatusRegistry` beside it. No autoload: the change signal goes on
`DebugPanels` in step 7, in the same shape as its existing
`interface_palette_changed`.

| Member | Signature | Behaviour |
|---|---|---|
| `SLOTS` | `const Array[String]` | The twelve slot ids in the order of the table above. |
| `DEFAULTS` | `const Dictionary` | Slot id to `res://` path, from the defaults table. |
| `CHOSEN_PATH` | `const String` | `res://assets/icons/mechanics/chosen.cfg` |
| `icon_for` | `static (slot: String) -> String` | The chosen path, else the slot's default, else `''` for an unknown slot. |
| `candidates` | `static (slot: String) -> Array[String]` | Every `.png` in the slot's folder, sorted by file name. |
| `display_name` | `static (slot: String) -> String` | `'charge_time'` gives `'Charge time'`. |
| `set_icon` | `static (slot: String, path: String) -> void` | Records the choice and saves `CHOSEN_PATH`. Unknown slot pushes an error and does nothing. |

Chosen icons are read from `CHOSEN_PATH` the first time one is asked for, as a
`ConfigFile` with one section, `icons`, holding `slot = path` — the same lazy
build `MechanicRegistry` uses. A missing file is not an error; every slot falls
back to its default. Saving on every `set_icon` is what "auto save" means here —
there is no Save button.

A `.cfg` rather than rewriting the `.gd` files: the panel would otherwise have to
edit source, and the change would not take effect until restart.

`candidates` uses `DirAccess`, which is debug-only, like the palette loader. In
an exported build it returns the default alone.

**Must not change.** No existing file. `Mechanic.icon` still holds its literal
after this step.

**Done when** the tests pass: an unset slot returns its default, `set_icon`
then `icon_for` returns the new path, `set_icon` with an unknown slot pushes an
error, and `candidates('attack')` returns twelve paths.

The test writes to `CHOSEN_PATH`, so it restores the file it found (or deletes
the one it created) in `after_each`, per
[testing.md](../systems/testing.md).

---

## Step 3 — Point the mechanics at their slots

**Goal.** Every mechanic takes its icon from `IconSlots`, and a change while the
game is running reaches what is on screen.

**Files.** The ten `src/content/mechanics/*_mechanic.gd`;
`src/content/mechanics/mechanic_registry.gd`.

**The change.** In each `Mechanic._init`, replace the `icon = 'res://...'`
literal with `icon = IconSlots.icon_for(ID)` and delete the trailing
`# PLACEHOLDER icon` comment. Leave the `# PLACEHOLDER desc` comments alone.

`MechanicRegistry` builds one shared instance per id, so a change at runtime has
to reach that instance. Add `MechanicRegistry.refresh_icons()`, which sets
`icon` on every built instance from `IconSlots.icon_for(id)` and does nothing
when nothing is built yet.

The five statuses that copy a mechanic's icon (`ShieldStatus`, `PoisonStatus`,
`BurnStatus`, `BleedStatus`, `RegenStatus`) need no change: each copies in
`_init`, so a status built after a change already has the new icon. Statuses
already on an actor mid-fight are the panel's job in step 7, the same way
`DebugPanels.set_interface_palette` recolours live statuses.

**Must not change.** The descriptions, the colours, `status_id`, any `land`
override, or the five status classes.

**Done when** the suite passes and `MechanicRegistry.get_mechanic('attack').icon`
is the path `IconSlots.icon_for('attack')` returns.

---

## Step 4 — Tint the keyword chip **(here)**

**Goal.** The white glyph is drawn in the slot's colour, on the material meant
for flat palette-coloured shapes.

**Files.** `src/scenes/ui/tooltip/keyword_chip.gd`.

A chip's icon is one of two kinds and they want opposite treatment, so the
choice is made in `setup` rather than in the scene. `KeywordCatalog` serves
mechanic icons, outside-the-set status icons and its own keyword icons, and only
the first of those is now a white glyph. The rest are painted pack art with
their own colours, which a tint would ruin.

An icon whose path is under `res://assets/icons/mechanics/` gets the entry's
colour as `modulate` and `InterfaceLook.element_material`, which keeps grade,
colour ramp and posterize off so a pixel stays on its palette colour
([interface_look.md](../systems/interface_look.md)). Everything else keeps white
modulate and `InterfaceLook.material`, the picture material the scene already
sets.

One file and a few lines, so not worth a task file.

**Done when** a keyword chip shows its glyph in the mechanic's colour.

---

## Step 5 — The inline icon segment

**Goal.** An effect line can carry a glyph, so `Deal 10 damage to the enemy`
becomes `10 <attack glyph> to the enemy`.

**Files.** `src/scenes/ui/tooltip/tooltip_content.gd`;
`src/scenes/ui/tooltip/tooltip_panel.gd`; `tests/ui/test_tooltip_content.gd`.

**The change.** `TooltipContent.build` returns effect lines as arrays of segment
dictionaries and `TooltipPanel._build_line` turns each into a Control in an
`HFlowContainer`. The existing types are `text`, `value` and `chip`. Add a
fourth, `{'t': 'icon', 'id': <slot id>}`, which `_build_line` turns into a
`TextureRect` carrying `IconSlots.icon_for(id)`, sized square to the row's font
height, modulated with the mechanic's colour, `MOUSE_FILTER_IGNORE`, on
`interface_element_material.tres`.

Then change the attack and heal branches of `TooltipContent._effect_line` to use
an icon segment in place of the words "damage" and "Heal".

No BBCode or `RichTextLabel` is involved. The tooltip is already a flow of
discrete Controls, which is why the keyword chips can carry their own hover
cards.

**Must not change.** The `text`, `value` and `chip` segment types, the keyword
chip's hover card, or the effect lines of any mechanic other than attack and
heal.

**Done when** the suite passes and a new test asserts an attack item's first
effect line contains a segment with `'t'` of `'icon'` and `'id'` of `'attack'`.

---

## Step 6 — Separate tab index from `LookPresets.Part` **(here)**

**Goal.** Make room for a sixth tab that is not part of a look preset.

**Files.** `src/debug/debug_panels.gd`.

`TAB_TITLES` and `TAB_KEYS` are keyed by `LookPresets.Part`, so tab index and
preset part are the same number today. Re-key both by plain tab index, with the
five look parts keeping 0 to 4. `toggle_tab` already takes an int. Nothing
outside `DebugPanels` passes a `Part` to it.

Adding the Icons tab to `Part` instead would wrongly give it a "Take this part
from" row and a preset section, because `LookPresets.PART_SECTIONS` and the
preset bar are driven by that enum.

**Done when** F1 to F5 still open their own tabs and the suite passes.

---

## Step 7 — The Icons tab

**Goal.** A new F6 tab with a slot dropdown and an icon dropdown, saving each
choice as it is made.

**Files.** New `src/debug/icon_panel.gd` and `icon_panel.tscn`;
`src/debug/debug_panels.tscn`; `src/debug/debug_panels.gd`.

**The tab.** `class_name IconPanel`, `extends LookPanel`, built like
`FeedbackPanel`: a `rebuild()` that clears the sections and adds rows. Two rows
in a "Choose" section:

| Row | Scene | Effect |
|---|---|---|
| Slot | `look_option_row.tscn` | `IconSlots.SLOTS` by display name. Selecting one rebuilds the Icon row. |
| Icon | `look_option_row.tscn` | `IconSlots.candidates(slot)` by file name. Selecting one calls `IconSlots.set_icon`. |

Register it in `debug_panels.tscn` as a sixth child of
`PanelLayer/Panel/Rows/Tabs`, named `Icons`, and add it to `TAB_TITLES`
(`'Icons (F6)'`) and `TAB_KEYS` (`KEY_F6`) at index 5.

`DebugPanels` gets `set_slot_icon(slot, path)`, which calls
`IconSlots.set_icon`, then `MechanicRegistry.refresh_icons()` and the statuses'
from step 3, then emits a new `icons_changed` signal. This is the same shape as
`set_interface_palette` and `interface_palette_changed`, and it is why
`IconSlots` itself stays static. The tab calls `DebugPanels.set_slot_icon`,
never `IconSlots.set_icon`.

The tab has no "Take this part from" row, because it is not a look preset part.
`LookPanel` builds that row from `$PartRow`, so `icon_panel.tscn` leaves that
node out and `IconPanel` must not call into it.

**Must not change.** The five existing tabs, the preset bar, or
`LookPresets.Part`.

**Done when** F6 opens the tab, picking a slot repopulates the icon dropdown,
picking an icon writes `chosen.cfg`, and the choice survives a restart.

---

## Step 8 — Samples on the Icons tab

**Goal.** See the chosen icon and colour where they actually appear, without
leaving the panel.

**Files.** `src/debug/icon_panel.gd` (the `icon_panel.tscn` is unchanged: the
samples are built in code in `rebuild()`, the way the tab already builds its
rows).

A "Samples" section below the Choose rows, opened with `set_open(true)` and
rebuilt whenever the slot or its icon changes (so no extra wiring). A single
`VBoxContainer` of labelled rows is added to the section's `Rows` node through a
small public `LookSection.add_node(node: Control)`. Three samples, each a label
plus its content:

- **Sizes** — the glyph at 16, 24 and 40 pixels side by side, so the small end
  is visible. Each a `TextureRect` on `InterfaceLook.element_material`, tinted
  with the slot colour.
- **Chip** — a `KeywordChip` for the slot, `setup` deferred to its `ready` so it
  runs once the chip is in the tree.
- **In text** — an `HBoxContainer` holding a `Label` reading `10`, the glyph at
  the label's font height, and a `Label` reading `to the enemy`, so the glyph
  can be judged against text at its real size.

The slot colour is the mechanic's colour, or plain white (`Colours.UI_TEXT`) for
a slot that is not a mechanic. `charge_time` and `card` have no `Mechanic`
class, so they have no keyword chip: for those two the Chip sample is left out
entirely and only Sizes and In text show.

**Must not change.** The Choose rows from step 7, `LookSection.setup`,
`set_switch`, `set_open` and `add_row` (only `add_node` is added), or anything
outside `src/debug/`.

**Done when** changing either dropdown updates every sample at once.

---

## Step 9 — Writing `.gpl` files

**Goal.** A palette can be written, not only read.

**Files.** `src/debug/palette_loader.gd`; `tests/debug/test_palette_loader.gd`.

Add `PaletteLoader.save_named_colours(path: String, colours: Dictionary) -> Error`,
the write half of the existing `load_named_colours`. It writes a GIMP `.gpl`:
the `GIMP Palette` header, a `Name:` line, then one `R G B name` line per entry
in the dictionary's order. `.gpl` carries no alpha, so alpha is dropped.

**Must not change.** `load_named_colours`, `load_palette`, `find_palettes` or
any existing palette file.

**Done when** a test writes a dictionary, reads it back with
`load_named_colours` and gets the same names and colours.

---

## Step 10 — The custom palette and the slot colour picker

**Goal.** A colour picked in the panel is saved to a custom palette and is what
the screen shows.

**Files.** `src/debug/interface_palette.gd`; `src/debug/icon_panel.gd`;
`src/debug/debug_panels.gd`; `tests/debug/test_interface_palette.gd`.

**The custom palette.** `assets/palettes/new/ui/ui-custom.gpl`. Add
`InterfacePalette.write_custom(variable: String, colour: Color) -> void`, which:

1. Creates the file on first use by copying the colours of whichever interface
   palette is active, or `ui-default.gpl` when none is.
2. Sets `variable` to `colour`.
3. Writes the whole file with `PaletteLoader.save_named_colours`.
4. Applies it through `DebugPanels.set_interface_palette`, so the custom palette
   becomes the active one and the screen matches the file.

It must write every settable name each time. Three tests in
`test_interface_palette.gd` require every palette in that folder to name the
same set as `ui-default.gpl`, and a partial file would fail them.

**The row.** A Colour row (`look_colour_row.tscn`) in the Icons tab's Choose
section, showing the slot's `Colours` variable and calling `write_custom` when
it changes. `charge_time` and `card` have no colour variable, so the row is
hidden for them.

**Must not change.** `ui-default.gpl` or any other existing palette file.

**Done when** picking a colour recolours the samples and the rest of the
interface at once, `ui-custom.gpl` holds the new value, and the three existing
palette tests still pass with the new file in the folder.

---

## Step 11 — Palette colours on the Interface tab

**Goal.** Reach the other 50-odd palette colours, not only the mechanics'.

**Files.** `src/debug/interface_look_panel.gd`.

A "Palette colours" section on the Interface tab (F2), which already owns the
interface palette row. One subsection per group heading in
`src/data/colours.gd` (Mechanics, Statuses, Combat payloads, Relic panels, Beat
categories, Combat view, Map strip, Tooltip, Interface), each row a Colour row
calling `InterfacePalette.write_custom`.

`COOLDOWN_FILL` is translucent and `.gpl` carries no alpha, so it is left out,
as it already is from the palette files.

The mechanic colours appear both here and on the Icons tab on purpose. The Icons
tab shows one mechanic at a time next to its icon; this section shows the whole
palette together.

**Must not change.** The existing Interface tab sections, the interface palette
and portrait palette rows, or the interface look shader sections.

**Done when** every group has a subsection, changing any row writes
`ui-custom.gpl`, and the suite passes.

---

## What this plan does not cover

- Retuning or renaming anything. No mechanic behaviour changes.
- Icon markers in authored text. Item effect lines are generated from
  `ItemEffect` data, not authored as strings, so there is no authored text to
  put a marker in.
- The chosen colours becoming the game's defaults. They live in the custom
  palette; moving them into `colours.gd` is a separate decision.

## Docs to update

Each step updates the docs for the behaviour it changes, in the same change:

| Step | Doc |
|---|---|
| 2, 3 | [systems/mechanics.md](../systems/mechanics.md) — icon slots, `IconSlots`, the new autoload. |
| 5 | [systems/tooltips.md](../systems/tooltips.md) — the icon segment. |
| 7, 8, 11 | [systems/debug_panel.md](../systems/debug_panel.md) — the Icons tab, F6, the palette colours section. |
| 9, 10 | [systems/interface_palette.md](../systems/interface_palette.md) — the custom palette and the `.gpl` writer. |
| 1 | [design/asset_library.md](../design/asset_library.md) and [design/asset_credits.md](../design/asset_credits.md) — game-icons.net as a source. |
