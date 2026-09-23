# Plan: one file per content definition

**Status: shipped 2026-09-23.** The owner chose the top-level `content/` folder and dropping the
character prefixes. As-built detail is in [`../design/authoring.md`](../design/authoring.md) and
decision #44. Differences from the plan are listed at the end.

Move every authored item, enemy, relic, potion, enchant, encounter and character into its own
file, with its numbers written on it, so that adding a piece of content means adding one file and
changing it means editing one file.

Related: decision #23 in [`../decision_log.md`](../decision_log.md) (content is written in
GDScript), [`../design/authoring.md`](../design/authoring.md), [`../systems/item.md`](../systems/item.md),
[`../systems/interface_palette.md`](../systems/interface_palette.md), [`../systems/testing.md`](../systems/testing.md).

## What is there now

- Each kind has one catalog file holding every definition as a builder function:
  `item_catalog.gd` (836 lines, all characters plus enemy items and unpooled examples),
  `enemy_catalog.gd`, `relic_catalog.gd`, `consumable_catalog.gd`, `enchant_catalog.gd`,
  `encounter_catalog.gd`, `character_catalog.gd`.
- Each definition is written in three places: an id constant (`const SMITH_WARHAMMER := 'smith_warhammer'`),
  a line in `_build()`, and the builder function.
- Almost every number an item uses is a per-item constant in `balance.gd`
  (`SMITH_WARHAMMER_COOLDOWN`, `SMITH_WARHAMMER_DAMAGE`), read by that one item and, for a few, by
  `tests/content/test_authored_content.gd`. The same holds for enemy health, relic amounts, the
  potion, the enchant and encounter amounts.
- About 40 id constants are used outside the catalogs, in 11 files under `src/` plus tests
  (`EncounterCatalog.FIGHT_GRUNT` in the run map, `ItemCatalog.SMITH_*` in the character pools,
  `EnemyCatalog.GRUNT` in the enemy lists).
- Colours are copied onto a definition when it is built (`panel_color`, and `ItemEffect.color` for
  status appliers). A palette change therefore calls `refresh_colours()` on the item, relic and
  potion catalogs to copy fresh colours onto the cached definitions
  (`src/debug/interface_palette.gd`). An attack or shield effect already reads its colour from its
  mechanic when the delivery is made (`src/combat/payload.gd`).
- 26 of the 43 item effects target the other side, and every one of them sets
  `travel = Balance.WEAPON_TRAVEL`. The other 17 target the holder or its own items, with no travel.
- Test fixtures put their definitions straight into each catalog's `_defs` dictionary
  (`tests/fixtures/fixture_content.gd`).

## Changes

### 1. Authored content moves to a top-level `content/` folder, one file per definition

```
content/items/smith/warhammer.gd
content/items/spore_druid/druid_staff.gd
content/items/fleshmancer/cleaver.gd
content/items/enemy/claw.gd
content/items/examples/hex_bolt.gd
content/enemies/grunt.gd
content/relics/stone_ward.gd
content/consumables/healing_draught.gd
content/enchants/whetstone.gd
content/encounters/fight_grunt.gd
content/characters/smith.gd
```

- `src/content/` keeps the engine side: the def classes, the catalogs, `ItemEffect`, the
  mechanics, statuses, keywords and pools. `content/` holds only what the owner writes.
- Statuses stay where they are. They are already one class per file and are code, not data.
- The item subfolders are for finding things. The catalog does not read any meaning from them.

A definition file extends its def class and sets its fields in `_init()`. It has no `class_name`,
so hundreds of items do not add hundreds of global names.

```gdscript
# content/items/smith/warhammer.gd
extends ItemDef


func _init() -> void:
  id = 'warhammer'
  name_key = 'Warhammer'              # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID, DechargeMechanic.ID]
  icon = 'res://assets/icons/items/war_hammer.png'
  attack_sound = 'blunt'
  cooldown = 6.0
  effects = [
    ItemEffect.attack(73.0),
    ItemEffect.make(DechargeMechanic.ID, 1.0, ItemEffect.Shape.OPPONENT_ITEM_RANDOM),
  ]
```

`name_key` stays written out on each definition, because the translation extractor looks for that
literal. `tools/extract_pot.gd` scans `res://src` only, so `res://content` is added to its scan.

### 2. Catalogs find definitions by scanning their folder

- Each catalog keeps its public functions (`get_def`, `has`, `all_ids`, `ids`) and its `_defs`
  dictionary, so callers and the test fixtures do not change.
- `_build()` walks its `content/<kind>/` folder, subfolders included, with
  `ResourceLoader.list_directory`, which also lists scripts correctly in an exported build. It
  creates each script and stores it by its `id`.
- Two definitions with the same id is an error pushed at build time, and a content test fails on it.
- The character-select order cannot come from the folder, so `CharacterCatalog` keeps an ordered
  list of character ids for `ids()`. `DEFAULT` stays.

### 3. Ids become plain strings, and the id constants go

- The per-definition id constants are removed from every catalog. Pools, enemy boards, encounters,
  the run map and tests write the id as a string (`'warhammer'`).
- A misspelt id is caught by the existing reference checks in `tests/content/test_pool_integrity.gd`,
  which already resolve every character pool, starting kit, enemy board, act enemy list, encounter
  reference and reward relic.
- The `smith_`, `flesh_` and similar prefixes are dropped where the name is unique, since the folder
  now shows the character. Ids stay unique per kind, and the duplicate check from step 2 enforces it.
  Save files are not migrated.
- Lists that are not a single definition stay where they are: the character pools, `colorless_pool.gd`,
  `enemy_pools.gd`, `RelicCatalog.REWARD_POOL`.

### 4. Numbers are written on the definition

- Every value used by one definition moves onto that definition, and its constant is removed from
  `balance.gd`. Comments on those constants that explain a design reason move to the definition's
  header comment. Comments that only restate the number are dropped.
- Values shared by several definitions or systems stay in `Balance`, for example `WEAPON_TRAVEL`,
  the status durations, `TRIGGER_PUSH_FULL`, `EMPOWER_MULT`, `CRIT_MULTIPLIER`,
  `PLAYER_START_HP` and the points-curve constants. The rule for each constant: if one definition
  reads it, it moves.
- `tests/content/test_authored_content.gd` stops comparing definitions to their own constants. It
  keeps the checks that describe what an item is (a weapon, single-target, applies Empowered to
  itself) and drops the ones that restate its numbers.

### 5. Short constructors for common effects

Static functions on `ItemEffect` that return a filled-in effect:

| Function | Makes |
|---|---|
| `attack(value, shape = OPPONENT_LEFTMOST)` | an attack |
| `shield(value)` | shield on the holder |
| `heal(value)` | healing on the holder |
| `make(mechanic, value, shape)` | any mechanic on any shape |
| `apply_status(status_id, value, shape, duration = 0.0)` | a status applier |

- Travel is worked out from the shape: `Balance.WEAPON_TRAVEL` for a shape on the other side, 0 for
  the holder or its own items. This matches every current item. An effect that needs something else
  sets `travel` after construction.
- Effects that spend statuses, summon or create items keep setting their fields directly.
- Potions use the same constructors.

### 6. Colours are read when they are needed, not stored

- `ItemDef.panel_color` becomes a read-only property. By default it returns the colour of the first
  effect: its mechanic's `color()`, or for a status applier the status's colour.
- A definition that wants a different panel colour sets `panel_colour_name` to a `Colours` variable
  name (`'STATUS_DECAY'` for the Fleshmancer's chunk makers, `'ARCANE'` for Hex Bolt). It is looked
  up on each read, the same way `interface_palette.gd` sets colours by name.
- `ItemEffect.color` is removed. `payload.gd` reads a status applier's colour from the status, as it
  already does for a mechanic.
- `RelicDef.panel_color` works the same way, through `panel_colour_name`.
- `refresh_colours()` is removed from the item, relic and potion catalogs, and its calls from
  `interface_palette.gd`. `KeywordCatalog.refresh_colours()` is outside this change and stays.

## Order of work

1. Steps 5 and 6 first, inside the current catalogs, with the suite green.
2. Step 4 (numbers onto the builders), with the suite green.
3. Steps 1 to 3, one kind at a time, starting with the smallest (enchants), then potions, relics,
   characters, enemies, encounters, items. Reimport after each kind (`tools/import.sh`), since the
   new files need `.uid` files.
4. Run `tools/pot.sh` and check the POT has the same strings as before.
5. Run the autotest for each character and compare the report to one taken before the change. The
   numbers should be the same, because only where values are written changes.

## Docs to update

`design/authoring.md` (the whole "To add a draftable item" section), `systems/item.md`,
`systems/enemy.md`, `systems/content.md`, `systems/encounter.md`, `systems/testing.md` (fixtures),
`systems/interface_palette.md` (no more `refresh_colours` for content), `systems/localization.md`
(the scan folders), the "Location" lines in `design/smith.md`, `design/spore_druid.md` and the
other character files, the `/content` skill, and a new decision in `decision_log.md` recording the
file-per-definition layout and the numbers-on-the-definition rule.

## Differences from the plan

- `ItemEffect.color` stayed, as a read-only property worked out on use, with a `colour_name` field
  for an effect that wants a different colour. The Fleshmancer's create-item effects use it for the
  Decay colour, and Hex Bolt keeps its `ARCANE` colour through it, so no colour on screen changed.
- Ids were also renamed to match item names where they differed: `poison_dagger` is `venom_fang`,
  `avenger` is `spite_ward`, `sunder` is `sundering_bolt`, `flesh_bone_maul` is `bone_saw` and
  `flesh_chunk` is `chunk_of_flesh`, so each file is named after its item.
- `Balance.ENEMY_PLACEHOLDER_HP` stayed, as the default health of an `EnemyDef` and the combat
  sandbox's enemy.
- The autotest reports for all three characters on seed 1 matched the pre-change reports exactly.
