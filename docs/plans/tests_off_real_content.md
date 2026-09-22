# Plan: move the remaining tests off real content

Make every test that checks an engine or run system use fixture content, so that authoring,
tuning, renaming or removing real items, characters, enemies, relics, potions, enchants and
encounters cannot change a test's result. This continues
[`standalone_test_fixture.md`](standalone_test_fixture.md), which moved the whole-run tests onto
`FixtureRun`.

Current fixture rules: [`../systems/testing.md`](../systems/testing.md#fixtures).

## What counts as real content

A test uses real content when it reads any of these:

- A catalog id or definition: `ItemCatalog`, `CharacterCatalog`, `EnemyCatalog`,
  `EncounterCatalog`, `RelicCatalog`, `ConsumableCatalog`, `EnchantCatalog`.
- A `Balance` constant that belongs to one piece of content, such as `ENEMY_PLACEHOLDER_HP`,
  `MIGHTY_BLOW_CHARGES`, `RELIC_STONE_WARD_SHIELD`, `EVENT_SHRINE_MAX_HP` or `POTION_HEAL`.
- A run that plays real content indirectly. With `FixtureRun` installed, a run still meets real
  encounters, real events (the shrine and the wanderer, whose ally is the real Spore Thrall), real
  rest heal amounts and real reward relics.

These are **not** content and stay as they are:

- `Balance` constants for engine rules: `STEP`, time scales, battle speeds, status multipliers
  and durations, `CRIT_MULTIPLIER`, `EMPOWER_MULT`, shield multipliers, burn and regen per tick,
  `TRIGGER_PUSH_FULL`, `GOLD_SKIP`, `POINTS_TARGET_TOLERANCE`, presentation timings.
- The map's structure in `RunMap` (which beat is the boss, the relic fight, the elite pool). It
  names encounter ids, and the fixture keeps those ids.
- Name strings passed straight to the combat log in the log tests ('Claw', 'Grunt'). They are
  labels, not catalog lookups.

## New fixture content

Added to `tests/fixtures/`. Every number is a fixture constant, never read from `Balance`.

| File | Contents |
|---|---|
| `fixture_items.gd` (extended) | A trigger item that pushes its cooldown when poison is applied (replaces Spite Ward), a vulnerable applier (replaces Sundering Bolt), a random-enemy-item silence (replaces Hex Bolt), an empower applier (replaces Mighty Blow), and a created item with limited uses (replaces Chunk of Flesh). |
| `fixture_enemies.gd` (extended) | A fixture ally id and definition (replaces the Spore Thrall), and a second fixture enemy with different health so budget draws have two sizes. |
| `fixture_kit.gd` (new) | `FixtureKit`: a heal potion, a value-multiplying enchant, a combat-start shield relic and a max-health relic. |
| `fixture_encounters.gd` (new) | `FixtureEncounters`: builds a fixture encounter for a given real encounter id, keeping the real definition's id, type and reward and replacing everything else. A fight gets fixture enemies, a rest a fixture heal fraction, and an event two fixture options: a max-health option and an add-ally option naming the fixture ally. |

## Changes to `FixtureRun`

`FixtureRun` is renamed `FixtureContent` (file `fixture_content.gd`), because combat and interface
tests will install it too. `install()` then:

1. Adds every fixture item, potion, enchant and relic to its catalog.
2. Adds the fixture character, whose kit stays as it is.
3. Adds the fixture enemies and ally, and replaces every real enemy id with a fixture enemy (as now).
4. Replaces every real encounter id with `FixtureEncounters` output under the same id.
5. Replaces every real relic id with a fixture relic under the same id, because
   `RelicCatalog.REWARD_POOL` is a constant list of real ids and the relic reward draws from it.

`uninstall()` clears all seven catalogs. `ColorlessPool.ITEMS` is empty today; if the owner adds
an id, fixture runs will draft it. `install()` asserts it is empty so that change fails loudly
instead of silently mixing real items into the tests.

One game change is needed: `ItemCatalog.refresh_colours()` and the matching functions on the
relic and potion catalogs look up every cached id in a fresh build, which fails for fixture ids.
They skip ids the fresh build does not have.

## Test changes

| File | Change |
|---|---|
| `autotest/test_auto_test_mode.gd` | Fixture health instead of `PLAYER_START_HP` and `ENEMY_PLACEHOLDER_HP`. |
| `autotest/test_auto_test_run.gd` | The fixture potion instead of the Healing Draught. |
| `autotest/test_draft_strategy.gd` | The fixture trigger item instead of Spite Ward. |
| `combat/test_applied_event.gd`, `test_item.gd` | Trigger and vulnerable tests use the fixture items. |
| `combat/test_combat_log_wiring.gd` | Fixture health constants. |
| `combat/test_combat_manager.gd` | Fixture items for Spite Ward, Hex Bolt, the Claw and the Femur; fixture ally for the summon tests; install `FixtureContent` where an item is added by id. |
| `combat/test_empower.gd` | Empower tests use the fixture empower applier. |
| `content/test_consumable.gd`, `test_enchant.gd`, `test_relic.gd` | Use the `FixtureKit` definitions. |
| `debug/test_interface_palette.gd` | Picks the first real definition of each kind that has the needed colour, instead of naming the Flesh Cleaver, Healing Draught and Stone Ward. |
| `run/test_draft.gd` | The fixture character's pool, with enough fixture items for three distinct picks. |
| `run/test_encounter.gd` | Installs `FixtureContent`; event health checks use fixture amounts. |
| `run/test_encounter_budget.gd` | The two fixture enemies instead of the grunt and brute. |
| `run/test_run_manager.gd` | Fixture kit, fixture ally, fixture event amounts. The "chosen character" test starts as the fixture character. |
| `corridors/test_combat_corridor.gd` | Its one run uses the fixture character. |
| `ui/test_choice_overlay.gd`, `test_event_overlay.gd`, `test_combat_view.gd`, `test_run_screen.gd` | Install `FixtureContent`; fixture potion and created item. |
| `ui/test_character_select.gd` | Unchanged: it checks that the screen shows one card per entry in `CharacterCatalog.ids()`, whatever that list holds. |

## Tests that check the real content itself

These exist to catch mistakes in the authored content, so they cannot run on fixtures:

- `content/test_pool_integrity.gd`: every pool id resolves.
- `content/test_starting_board.gd`: each character's starting kit is valid.
- `content/test_item_points.gd`: items sit on the points curve.
- `content/test_icons.gd`: every item, potion, character and enemy has its art.
- `combat/test_enemy.gd`: the grunt carries the Claw.
- The card checks in `combat/test_empower.gd` (Mighty Blow is a skill on its authored cooldown,
  the three Smith weapons have their authored numbers) and `content/test_consumable.gd` (the
  catalog builds the Healing Draught).

**Open question for the owner:** keep these as the only tests that read real content, moved
together into `tests/content/`, or delete them.

## Checks

- Full `tools/gut.sh`: same pass count apart from deleted tests; check the script and test counts.
- `tools/import.sh` twice after adding the new `class_name` files.
- Independence check, reverted afterwards: set every content constant in `Balance` to an extreme
  value, empty every character pool except the fixture's, and change `CharacterCatalog.DEFAULT`.
  Every test outside the real-content group must still pass.
- Update `docs/systems/testing.md` (fixtures table, the rule for which tests read real content) and
  `docs/design/authoring.md`, which names `FixtureRun`.
