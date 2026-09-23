# Tests

How unit and integration tests are written in this project. They run under GUT
(vendored in `addons/gut/`); the commands to run the suite are in
[handoff.md](../handoff.md#how-to-work-the-rhythm).

**Location:** `tests/`, one folder per area (`combat/`, `content/`, `run/`, `ui/`,
`corridors/`, `autotest/`, `smoke/`, `debug/`, `fixtures/`, `utils/`).

For the headless end-to-end harness that drives a whole run, see
[autotest.md](autotest.md).

## Conventions

- Test files are named `test_<component>.gd` and live in the folder for their area.
  A helper that is not a test case must not be named `test_*`, or GUT collects it.
- Work with the real autoloads. Do not mock them.
- Collected directories and log level come from `.gutconfig.json`.

## Fixtures

Tests use fixture content from `tests/fixtures/` instead of authored content, so authoring, tuning,
renaming or removing real content cannot change a test's result. Fixture numbers are constants in
the fixture files and are never read from `Balance`.

| File | What it gives |
|---|---|
| `fixture_items.gd` | `FixtureItems`: an attack, an enemy attack, a shield, a poison applier, two filtered-target items, a poison-charged trigger item, a Vulnerable applier, a random-item silence and an empower applier, as fresh `ItemDef`s. |
| `fixture_character.gd` | `FixtureCharacter`: a character with a fixed starting board and a pool of fixture items only. |
| `fixture_enemies.gd` | `FixtureEnemies`: a small and a large enemy, and an ally for summons and recruits, each with fixed health and one fixture attack. |
| `fixture_encounters.gd` | `FixtureEncounters`: a fight against one fixture enemy, a rest, and an event with a heal, a maximum-health and a recruit option (`OPTION_*` give their indexes). |
| `fixture_kit.gd` | `FixtureKit`: a heal potion, a value-multiplying enchant, a combat-start shield relic and a maximum-health relic. |
| `fixture_content.gd` | `FixtureContent.install()`: adds every fixture to its catalog, puts a fixture in place of every authored enemy, encounter and relic under the authored id, and empties every act's `EnemyPools` lists. |

A test that plays a run, an encounter or an autotest, or that builds fixture content by id
(`CombatManager.add_item`, a summon, a save and reload), calls `FixtureContent.install()` in
`before_each`. A run test passes `FixtureCharacter.ID` to `run.start`, `Game.start_run` or
`AutoTestMode.character`. Authored ids are replaced rather than added to because the map names
encounters, encounters name enemies and the relic reward draws from `RelicCatalog.REWARD_POOL`.
Emptying the `EnemyPools` lists keeps every whole-run fight on its encounter's enemies, so filling the authored lists cannot change a whole-run test; the fight generator is tested on its own in `tests/run/test_encounter_budget.gd`. The map's beat layout in `RunMap` stays real. The fixture character beats the fixture enemies by a
wide margin; keep that margin if you change either.

`install()` fails an assert if `ColorlessPool.ITEMS` is not empty, because the draft adds the
colorless pool to every character's pool, so a fixture run would draft authored items.

### Tests that read real content

Only the tests in `tests/content/` that check the authored content itself read it: pool integrity,
starting boards, item points, icons and portraits, and `test_authored_content.gd`, which checks
specific authored cards, enemies, potions, enchants, relics and events. Engine rules in `Balance`
(`STEP`, time scales, status multipliers, `CRIT_MULTIPLIER`, `GOLD_SKIP`)
are not content, and any test may read them. `test_interface_palette.gd` also reads a few authored
definitions, because it checks that authored definitions show a palette's colours.

## Resetting state between tests

`TestCleanup` (`tests/utils/cleanup.gd`) resets the autoloads that hold state
across tests. Call it in both `before_each` and `after_each`:

```gdscript
func before_each() -> void:
  TestCleanup.reset_all_managers()
```

`reset_all_managers()` frees the live run held by `Game`, re-enables saving,
keeps `Prefs` in memory rather than on disk, resets the debug panel settings, and
removes the fixtures if a test installed them.

A test that builds an `Actor` without a `RunManager` should register it with
`TestCleanup.dissolve_at_reset(actor)`. In the game `RunManager.teardown` dissolves
the player side; without that call the actor's reference cycle with its items stays
alive. See [actor.md](actor.md) for the lifetime rules.

A test that changes an icon choice writes `IconSlots.CHOSEN_PATH`, which
`reset_all_managers()` does not touch, so the choice would survive into the next
run. Call `TestCleanup.snapshot_chosen_icons()` in `before_each` and
`TestCleanup.restore_chosen_icons()` in `after_each`. A test that needs no icon
to be chosen calls `TestCleanup.clear_chosen_icons()` after the snapshot,
because the developer may have chosen icons in the Icons tab.

## Signals

```gdscript
func test_something() -> void:
  watch_signals(SomeManager)
  SomeManager.do_thing()
  assert_signal_emitted(SomeManager, 'thing_done')
```
