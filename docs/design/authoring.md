# Content Authoring Guide

> How to add content to the game — the **file mechanics**. The *design* (what to make) lives in
> the other `docs/design/` files + [`design.md`](game_design.md); the *systems* (how each
> kind works) live in the `docs/systems/` PRDs. This is the bridge: where a def goes, how it's
> keyed, and how it goes live. The front door for content work is the **`/content`** skill.

## Ownership

The project owner designs the content; an assisting agent is a **sounding board + scribe** —
pressure-test ideas, surface tensions, connect them to the built systems, pitch options *with
their costs*, and write down what the owner decides. Agents don't originate content and author it
unilaterally; they pitch, the owner calls it. (Dev/debug strings stay English; player-facing text
is localizable.)

## The model

Content is typed GDScript **definitions** keyed by a **string id** (decision #23). Each authored
definition is **one file** under the top-level `content/` folder:

`content/items/<character>/` · `enemies/` · `relics/` · `consumables/` · `enchants/` · `encounters/` · `characters/`

A definition file extends its def class (`ItemDef`, `EnemyDef`, …) and sets its fields in `_init()`.
Its numbers are written on it; `Balance` holds only values shared by several definitions or systems
(`TRAVEL_STEPS`, status durations, the points curve). The engine side stays in `src/content/<kind>/`:
the def class (the schema), the catalog, and where relevant a runtime class (`relic.gd`,
`enchantment.gd`, `consumable.gd`). Each catalog builds itself on first access by loading every
script in its `content/` folder, subfolders included (`ContentFolder`), so adding a file is all it
takes. Two definitions with the same id is an error. **Statuses are the exception:** they are
`StatusEffect` subclasses in `src/content/statuses/`, registered in `StatusRegistry` — see below.

## To add a draftable item (the common case)

1. **Write the file.** `content/items/<character>/<id>.gd`, named after the item:

   ```gdscript
   extends ItemDef
   ## Warhammer — what the item is for, and anything a tuner needs to know about its numbers.


   func _init() -> void:
     id = 'warhammer'
     name_key = 'Warhammer'            # PLACEHOLDER name — owner's to rename
     types = [ItemType.WEAPON]
     mechanics = [AttackMechanic.ID, DechargeMechanic.ID]
     icon = 'res://assets/icons/items/war_hammer.png'
     cooldown = 6.0
     effects = [
       ItemEffect.attack(73.0),
       ItemEffect.make(DechargeMechanic.ID, 1.0, ItemEffect.Shape.OPPONENT_ITEM_RANDOM),
     ]
   ```

   - The id matches the file name and is unique across all items. There is no character prefix;
     the folder shows the character, and the folder means nothing to the catalog.
   - Effects come from the `ItemEffect` constructors: `attack`, `shield`, `heal`, `make` (any
     mechanic on any shape) and `apply_status`. Travel is not authored: every delivery flies
     `Balance.TRAVEL_STEPS`. Effects that spend statuses, summon or create items set their fields
     on an `ItemEffect.new()` ([item.md](../systems/item.md)).
   - `types` are inert synergy labels (`weapon` / `armour` / `skill` / `spell` / `trinket`).
     `mechanics` is the keyword list, written by hand in alphabetical order.
   - Write `name_key = '...'` out in full; the translation extractor finds names by that literal.
   - `icon` is a `res://` path under `assets/icons/items/`; `tests/content/test_icons.gd` fails if it
     is missing.
   - The panel colour follows the first effect's mechanic or status. Set `panel_colour_name` to a
     `Colours` variable name (`'STATUS_DECAY'`) only when that is the wrong colour.
2. **Make it live.** Add the id to the character's `item_pool` in
   `content/characters/<character>.gd`, or to `src/content/items/colorless_pool.gd` if it genuinely
   belongs to every character (the exception that earns it, never a default tier — decision #27).
3. **Reimport** (`tools/import.sh`) so Godot sees the new file.

To see a character's items side by side with their tooltip text, run `tools/item_browser.sh` and open
`_temp/item_browser.html` ([item_browser.md](../systems/item_browser.md)).

**Active / disabled = pool membership.** A def that exists but is in no pool is "disabled" — it's
authored and inspectable but never drafted. That is the toggle: add/remove the id from a pool. Not
a flag on the def. (`content/items/examples/` holds the unpooled working examples.)

## Other kinds

Enemies, relics, potions, enchants, encounters and characters follow the same one-file-per-definition
pattern in their own `content/` folder — see the matching PRD ([item](../systems/item.md) ·
[enemy](../systems/enemy.md) ·
[content](../systems/content.md) (relics/enchants/potions) · [encounter](../systems/encounter.md))
for each def's fields and how it resolves.

- A **status** is NOT a def — it's a **`StatusEffect` subclass** (`statuses/<name>_status.gd`)
  overriding the hooks it needs (`outgoing_bonus`, `absorb`, `on_step`, …; default no-op),
  extending an intermediate base (`TimedStatus` / `PeriodicStatus` / `PoolStatus`) or `StatusEffect`
  directly. Set `id` / `name_key` / `color` / `icon` (under `assets/icons/statuses/`) by plain assignment in `_init` (the `name_key = '...'`
  assignment is what localizes it). Make it live with **one line** in `StatusRegistry` (`id →
  creator`). An applier (item/relic) references it by string id (`status_id = 'weak'`) and, for a
  timed status, sets `duration` (per-application). See [status PRD](../systems/status_manager.md).

- A **character** is a `CharacterDef` (`content/characters/<id>.gd`): its own `item_pool`,
  starting board, starting relic, starting potions/enchants. The starting board is normally written
  as **type constraints** (`starting_item_types`, e.g. `[WEAPON, SKILL, ARMOUR]`) rather than fixed
  ids: one random item of each listed type is drawn from the character's own pool at run start, so
  every run opens differently. Repeating a type asks for two of it, and each slot draws a distinct
  item. `starting_item_ids` still works for a fixed opening and is used when no types are set. Its display is two lines on the select
  screen: `name_key` is the character's personal name, `subtitle_key` the role beneath it
  (`'Rot Shepherd'`). The `id` stays the internal working label (`spore_druid`) and never displays. Adding a character = a file plus its place in
  `CharacterCatalog.ids()`, which sets the select-screen order.
- An **enemy** (also used for allies and summons) is an `EnemyDef` (`content/enemies/<id>.gd`):
  health, an ordered board of item ids (any item, including one from a player pool — #43), and
  optionally an `image` (its cut-out monster painting) and a `portrait` (falls back to the image).
  Size it to its act's points range in [`encounter_points_budget.md`](../plans/encounter_points_budget.md).
  Make it live by adding its id to an act's `REGULAR` or `BOSS` list in `enemies/enemy_pools.gd`. The
  image steps and the list rules are in [enemy.md](../systems/enemy.md).
- **Enemies are shared by every character** and the **reward-relic pool stays shared** — only *item*
  pools split per character (#27).

## Tests do not use authored content

Tests use fixture content from `tests/fixtures/` rather than authored content
([`testing.md`](../systems/testing.md#fixtures)), so authoring, tuning, renaming or removing a card,
character, enemy, relic, potion, enchant or encounter cannot break them. The only tests that read
authored content are the ones in `tests/content/` that check it, such as pool integrity, icons and
`test_authored_content.gd`. Adding content needs no test change unless one of those checks catches
a mistake.

## After authoring

- **Added a new `class_name` script?** Run a headless `--import --exit` once or the test suite won't
  see the global (commands in [`../handoff.md`](../handoff.md)).
- **Player-facing strings** (names, encounter prose) show via `tr(def.name_key)` — run the POT
  pipeline after adding them ([localization](../systems/localization.md)).
- Keep the GUT suite green; update the relevant design doc if the design shifted, and the card-pool
  running counts. Commit coherent additions (`/c`).

## What's buildable now

The spore engine is fully built — status-stack **consume** (Mass fuel), **evasion** (blinding
whiff), and **summon** (mid-fight roster + persistent allies); see
[`../systems/spore_engine.md`](../systems/spore_engine.md). So the **entire spore pillar is
authorable today**: appliers, Mass payoffs, blinding, lethal-as-execute, summon tokens. Nothing in
the spore design is engine-gated.
