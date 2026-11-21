# Remove colour coding (plan)

The game drawn in greys only: no colour for mechanics, statuses, items, relics, beats or rarity, and
no red. Mechanics are told apart by their icons and their hit effects. Every colour that existed only
to code something is deleted, along with the code that carried it, and the interface palette is cut
down to the colours still in use.

Branch: `fewer-colours`. Status: the deletions are dropped (owner, 2026-11-21). The greys-only look
is now a choice of palettes instead ([main_and_mechanic_palettes.md](main_and_mechanic_palettes.md)):
`mechanics-greys.gpl` as the mechanic palette, with the other colours taken from the main palette.
What is still open from this plan, as separate later work: icons on the value pills, the shield drawn
as stripes, and one health bar fill for everyone.

## What changes on screen

| Part | Now | After |
|---|---|---|
| Value pills on items | Filled with the mechanic's colour | One fill, `TAG_FILL`, with the mechanic's icon left of the number |
| Status icons (outside the mechanic set) | A square and a count pill in the status's colour | Both in `TAG_FILL` |
| Numbers on the health bar | Shield in yellow, poison, burn, bleed and regen in their colours | All in `UI_TEXT`; the icons tell them apart |
| Health bars | Player and allies green, enemies red | One off-white fill (`HP_BAR_FILL`) on one background (`HP_BAR_BG`) for every bar |
| Shield on the health bar | A yellow fill over health | Diagonal stripes of `HP_BAR_FILL` and `HP_BAR_BG` over health |
| Projectiles, impacts, damage numbers, hit lights | The delivery's colour | One colour, `EFFECT` |
| Tooltip | Keyword icons tinted per mechanic, title tinted by rarity, changed values in pale yellow | Keyword icons and title in `UI_TEXT`; changed values in `UI_TEXT`, with an underline if that does not stand out from the line |
| Encounter cards | A band in the beat's colour | The band in `TAG_FILL` |
| Map | Boss square in purple, a yellow dot on the current beat | No square colour (the crown icon marks the boss), the dot in `UI_TEXT` |
| Paper burn | Orange ember and scorch | Ember in `UI_TEXT`, char in `UI_PANEL_SHADOW`, scorch untinted |
| Item browser page | Rarity and keyword colours | Follows the game |

`EFFECT` must differ from `UI_TEXT`, because the hit effects draw their base in the delivery colour
and their core in `UI_TEXT`; with one colour they would lose their shading.

## Colours after the cut

Kept: the 19 interface and control feedback greys, `HP_BAR_FILL`, `HP_BAR_BG`, `HP_BAR_LINE`,
`COOLDOWN_RING`, `COOLDOWN_FILL`, `ALLY_DOWNED`.

New: `EFFECT` (every combat effect) and `TAG_FILL` (value pills, status icon squares, encounter card
bands). Both greys; the owner tunes them on the F2 tab.

Deleted (39): `ATTACK`, `SHIELD`, `HEAL`, `POISON`, `BURN`, `BLEED`, `REGEN`, `CRIT`, `CHARGE`,
`DECHARGE`, every `STATUS_*`, `ARCANE`, every `RELIC_*`, every `BEAT_*`, `PORTRAIT_PLAYER`,
`PORTRAIT_ENEMY`, `ENEMY_HP_BAR_BG`, `ENEMY_HP_BAR_FILL`, `MAP_CURRENT_HALO`, every `PAPER_BURN_*`,
every `RARITY_*`, `TOOLTIP_CHANGED`.

## Code that goes

| Where | What |
|---|---|
| `src/content/mechanics/` | `Mechanic.color()` and every override |
| `src/content/statuses/` | `StatusEffect.color` and every `color =` in the status classes |
| `item_effect.gd`, `item_def.gd` | `ItemEffect.color`, `colour_name`, `ItemDef.panel_color`, `panel_colour_name` |
| `payload.gd`, `delivery.gd`, `combat_manager.gd` | `Payload.color`, `Delivery.color` and the two lines that copy it |
| `keyword_catalog.gd` | Every `'color'` entry and `refresh_colours()` |
| `keyword_icon.gd` | The colour argument of `dress`; mechanic icons are tinted `UI_TEXT` |
| `tooltip_content.gd`, `tooltip_panel.gd` | `panel_color` and the rarity tint |
| `encounter_card.gd`, `map_strip.gd` | The beat colour functions |
| `health_bar.gd`, `enemy_hud.tscn` | `fill_colour_name`, `background_colour_name`; the shield's colour reads |
| `board_view.gd`, `item_icon.gd` | The portrait and panel colours (used only by the combat sandbox dev scene) |
| `src/debug/` | The F2 sections for the deleted colours; the F6 Colour row; `_recolour_fight_statuses`; the per-mechanic colours in `hit_effects_preview` |
| `content/` | The `colour_name` and `panel_colour_name` lines in `hex_bolt`, `bone_saw`, `carving_knife`, `cleaver`, `iron_idol`, `stone_ward` and `vital_charm`. Only the colour line is removed; nothing else in the content changes. |
| `assets/palettes/new/ui/` | The deleted names in all six `.gpl` files, and the two new ones added. The loader warns on a name with no variable, so the deleted ones must go. |
| `tools/item_browser.gd` | The rarity and keyword colours |
| Tests | The mechanic colour test in `test_mechanic_registry.gd`; `test_interface_palette.gd` uses `ATTACK` as its example variable and switches to `HP_BAR_FILL` |

Readers that need a colour after the cut: the VFX drawers, damage numbers and hit lights read
`Colours.EFFECT`; `ValuePill` and `StatusIcon` read `Colours.TAG_FILL`.

## Health bar shield stripes

The bar's parts share `interface_element_material`. An instance uniform cannot go in that shader:
Godot reserves instance uniform space for every node drawn through a shader that has one, and there
is not enough for a full board (see the note in `interface_look.gdshaderinc`). So the stripes follow
the portrait's pattern:

- A new `interface_shield.gdshader` defines `SHIELD_STRIPES` and includes
  `interface_look.gdshaderinc`, which draws the stripes when it is defined.
- A new `InterfaceLook.shield_material` uses it, and joins the loop in `interface_look.gd` that pushes
  the element look's settings, so the shield keeps the same wear as the rest of the bar.
- `ShieldFill` uses it instead of `interface_element_material`. The stripe width is an ordinary
  uniform on that material, set from an F7 print setting.

Where shield is larger than max health, the stripes run past the end of the health fill onto the
background, so they still show.

## Pill icons

`ValuePill.setup` takes the effect's icon path and shows it left of the number at the number's
height, through `KeywordIcon.dress` with an `IconOutline` like the health bar's icons. A mechanic
effect uses its mechanic's icon; an effect that applies a status outside the set uses the status's
icon. `ItemCell._build_pills` passes it.

Pills are not counted in the cell's layout size, so a wider pill row can reach over the next cell on
an item with two or three effects. Check this on the Warhammer and on the widest item, and shrink the
icon or the gap if it does.

## Checks

- GUT suite, then grep `_temp/gut.log` for `SCRIPT ERROR`.
- `tools/lsp_check.sh`.
- A screenshot of a late-run fight with allies, and the encounter cards, the map and a tooltip, for
  the owner.

## Later steps

- Projectiles per mechanic, or per item. They are the same shape for every mechanic now, so in
  flight a heal and a poison look the same until they land.
- `UI_PANEL`, `UI_PANEL_EDGE` and `UI_PANEL_LIGHT` are read only by the panel brightness ramp in
  `InterfacePalette._recolour_theme`, which reaches theme styles that are not a `PaletteStyleBox`.
  If none are left, delete the three and the ramp.
- Clamp the interface colours to another palette, such as the world palette, as an F2 option.

## Docs to update when built

- [mechanics.md](../systems/mechanics.md): the Colours section and the `color()` member.
- [interface_palette.md](../systems/interface_palette.md), [shaders_and_palettes.md](../systems/shaders_and_palettes.md),
  [debug_panel.md](../systems/debug_panel.md): the cut palette and the F2 and F6 tabs.
- [run_screen.md](../systems/run_screen.md), [print_frame.md](../systems/print_frame.md): pill icons, the stripe setting.
- [tooltips.md](../systems/tooltips.md), [vfx_driver.md](../systems/vfx_driver.md), [paper_burn.md](../systems/paper_burn.md),
  [status_manager.md](../systems/status_manager.md), [item.md](../systems/item.md): colour mentions.
- [game_design.md](../design/game_design.md), [art_audio.md](../design/art_audio.md),
  [character_sheet.md](../design/character_sheet.md): they describe colour as the way the board is
  read. Rewrite those lines to say the game is drawn in greys and mechanics are read by icon.
- [decision_log.md](../decision_log.md): a new entry for the owner's decision to remove colour coding.
