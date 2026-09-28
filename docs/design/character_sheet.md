# Character sheet look

Ideas and principles for drawing the combat screen's right-hand column (the player's portrait, HP,
statuses, allies, potions, gold and items) as a paper character sheet, taking inspiration from 80s
and 90s gamebook and board-game sheets without copying any one of them. Nothing here is decided
unless it is listed under [Built](#built). The owner picks between options from screenshots; options
are not ranked. Every label and name is a placeholder for the owner to rename.

Related: the theme in [art_audio.md](art_audio.md), the combat view as built in
[run_screen.md](../systems/run_screen.md).

## References

| Sheet | What it has |
|---|---|
| Fighting Fantasy Adventure Sheet | Skill, Stamina and Luck boxes across the top; a large Equipment box; small Gold, Jewels, Potions and Provisions boxes; a grid of Monster Encounter boxes. |
| Lone Wolf Action Chart | Combat Skill and Endurance boxes; Kai Disciplines; two Weapons slots; Belt Pouch (gold); Meals; eight numbered Backpack Items lines; a Special Items list. |
| HeroQuest 1989 character sheet | Hero picture and name; Attack and Defend dice; Body and Mind points with space to tally points lost; Weapons, Armour, Items and Gold lists. |
| Sorcery! (inkle) | A Fighting Fantasy adventure sheet drawn as a physical object in a video game. |
| Card Hunter | Character sheets whose equipment slots show the cards each item gives. |
| Eye of the Beholder | Portrait, name, HP bar and items in hand in one small panel. |

What the three paper sheets share: each piece of information sits in its own ruled box with a
printed label on the box edge.

## Principles

1. **The printed form and the player's marks are separate layers.** The printed form is what stays
   the same all run: box outlines, labels, empty slots and the item grid. It is drawn in straight,
   clean lines in one ink. The player's marks are what changes: HP, shield, gold, ticks and the
   character's name. They are drawn in pencil or a handwriting style and are slightly uneven.
2. **Game pieces are cardboard, numbers are written.** Items, potions, statuses and summoned allies
   are tokens placed on the sheet. HP, shield and gold are numbers written into boxes.
3. **The sheet is quiet and the pieces are loud.** The sheet uses one or two inks at low contrast.
   Mechanic colours appear only on tokens, value pills and effects, following the dread-and-juice
   contrast in [art_audio.md](art_audio.md).
4. **Every change is something a hand could do:** write, cross out, rub out, tick, place, lift or
   slide. An item firing lifts its token (its shadow grows) and drops it back; damage crosses out
   the HP number and writes the new one; a status is a small token dropped into its box; a cleared
   beat gets a tick.
5. **The form stays the same all run, and the run fills it in.** Empty slots are printed, such as
   potion outlines and the item grid's squares. The board has no item limit, so when items outgrow
   the printed grid, extra squares are drawn on in pencil beyond its edge.
6. **Only boxes for things the game has.** No decorative stat boxes. Every box has a label.
7. **Keep what reads at a glance.** HP must still show how full it is at a glance, for example as a
   printed row of boxes shaded in pencil beside the written number. Cooldown fills and value pills
   stay as clear as they are now.
8. **Size follows importance.** The player has a full sheet, allies have smaller cards and enemies
   have small slips, all with the same parts (`CharacterPanel` is already shared between them).

## Colours

Every colour on the sheet comes from the interface palette (`Colours` variables, set from a `.gpl`
file by the [interface palette](../systems/interface_palette.md)), so one palette file changes the
whole sheet at once:

| Part | `Colours` variable |
|---|---|
| Paper (screen background, corridor overlay) | `UI_BACKGROUND` |
| Pencil lines: the grids, the allies box and the write-in lines | `UI_BACKGROUND_WEAR_LIGHT` |
| Printed labels | `UI_TEXT_DIM` |
| Panels | `UI_PANEL` and the other `UI_PANEL_*` variables |
| Token card, blended onto the paper by `token_fill_amount` (a print setting on the F7 tab) | `UI_TOKEN_CARD` |

New sheet parts should take their colours from `Colours`.

## Directions for the whole screen

- **One page:** the whole screen is one printed page; the corridor is the illustration box on it and
  the sheet's boxes fill the rest.
- **Objects on a table:** the corridor and the sheet are separate objects lying slightly askew on a
  table surface. The table around the edges takes space.
- **Dark sheet:** the current dark background, with box outlines and labels in light ink. The
  corridor stays the brightest part of the screen.

Paper colour (dark, mid-tone aged paper, or light) is a palette choice that works with any of the
three.

## Ideas for each part

| Part | Idea |
|---|---|
| Header | The portrait in a printed picture box, with Name and Class fields. |
| HP | A large written number with the maximum printed small beside it, over a pencil-shaded row of boxes. Crossed-out old values kept to the last one or two and cleared each fight. |
| Shield | A number in a small shield outline beside HP, rubbed out when it runs out. |
| Statuses | Small cardboard tokens with their stack pills in a labelled box; tally marks could be tried for small counts. |
| Potions | Three printed flask outlines; a potion token sits on each and the outline shows again when it is used. |
| Items | The pencil grid inside a labelled box. |
| Allies | Small cards clipped to the sheet's edge, each with portrait, name, HP and items. |
| Enemy | A small paper slip pinned over the corridor, based on Fighting Fantasy's Monster Encounter boxes. |
| Map | A row of small encounter boxes: cleared beats ticked, the current beat circled, the boss box larger. |
| Report and speed buttons | Printed tabs or stamps. |

## Risks

- A light sheet next to the dark corridor may draw the eye from the corridor and make it look darker.
- Handwriting fonts slow down reading numbers, so HP needs a clear hand.
- More boxes and labels take room from the item grid, so items shrink sooner, and labels add text to
  translate.

## Things to try next

Each as a setting on the F7 or F2 tab, screenshotted in the same fight on one comparison page:

1. HP as a written number with a pencil-shaded row of boxes instead of the filled bar.

## Built

- **Paper colour tried** (2026-09-29): dark, mid-tone and light paper palettes were compared in the
  same fight. The owner did not like the lighter papers and is staying with the dark sheet for now.
  Only `ui-paper-light.gpl` is kept in `assets/palettes/new/ui/` as an option. On it the text is dark,
  so the enemy names and HP numbers over the corridor are hard to read.

- **Gold beside the potions** (2026-09-28): a "Gold" label and a pencil-grid box in line with the
  potion row ([run_screen.md](../systems/run_screen.md#overlays)).
- **Name and Class fields** (2026-09-28): the player's panel shows "Name:" and "Class:" with the
  character's name and class written on underlines. "Class" replaced "subtitle" as the name for a
  character's role line ([lexicon.md](lexicon.md#characters)).
- **No panel backgrounds by default** (2026-09-28): the `panel_background` dropdown on the F7 tab
  chooses which character panels draw one (none, player and allies, enemies, all).
- **One spacing for the whole sheet** (2026-09-28): a section gap between the parts and a label gap
  between a label and its box, set in the theme and tuned on the Print tab
  ([ui_theme.md](../systems/ui_theme.md#spacing-on-the-character-sheet)).
- **Map in the item column** (2026-09-28): the map sits under the items, one section gap below them,
  with its "Act N" label in the same style as the other labels (the `map_in_column` setting on the F3
  Layout group).
- **Map as tokens** (2026-09-28): the act's squares as a row of pencil grid squares, each with a
  cardboard token showing an icon (fight, elite, relic, boss); cleared tokens face down, the current one
  bordered, and a marker between squares during an event. Three token sizes: large for items, potions
  and relics, medium (`medium_token_size`) for enemy items and map tokens, small (`status_size`) for
  status icons ([run_screen.md](../systems/run_screen.md#overlays)).
- **Relics box** (2026-09-28): a "Relics" label over a pencil grid beside the gold, with a token for
  each relic in its own square ([run_screen.md](../systems/run_screen.md#overlays)).
- **Allies box** (2026-09-28): an "Allies" label over one pencil rectangle holding the ally rows,
  divided by pencil lines into a cell for each ally slot, shown even with no allies (the `allies_box` setting on the F7 tab).
