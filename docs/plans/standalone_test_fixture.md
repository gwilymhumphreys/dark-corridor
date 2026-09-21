# Plan: a standalone test fixture for whole-run tests

> **Shipped 2026-09-21.** The as-built description is in
> [`../systems/testing.md`](../systems/testing.md#fixtures). This file is kept for the reasoning.

Give the tests that play a run or a fight a character and enemies that belong to the tests, so that
tuning, renaming or re-rostering real content cannot change their result.

Current state: [`../systems/testing.md`](../systems/testing.md). The item fixtures this builds on
are `tests/fixtures/fixture_items.gd` (decision #39).

## The problem

The item fixtures cover combat, interface and event tests, but every test that starts a run uses a
real character (`CharacterCatalog.DEFAULT` unless it names one) against real enemies whose health
comes from `Balance`. Raising `ENEMY_PLACEHOLDER_HP` to the curve's target and moving `DEFAULT` to
the Smith broke four such tests:

- `test_game_manager.gd` `test_win_sets_win_phase_and_clears_save` needs the default character to
  win a full run on one seed.
- `test_auto_test_run.gd` `test_resume_mid_run_finishes_the_descent` needs it to survive beat 1.
- `test_auto_test_run.gd` `test_shield_is_tallied_per_item_for_the_report` and
  `test_run_full_keeps_a_firing_non_damage_item_off_the_trap_list` look for the Fleshmancer's
  Femur by name, because it was in the old default starting kit.

## What the fixture is

Three new files in `tests/fixtures/`, alongside `fixture_items.gd`:

| File | Contents |
|---|---|
| `fixture_character.gd` | `class_name FixtureCharacter`. One `CharacterDef` with id `fixture_character`, a fixed starting board (`starting_item_ids`, no `starting_item_types`, so no random draw) and an item pool made only of fixture items. No starting relic, potion or enchant. |
| `fixture_enemies.gd` | `class_name FixtureEnemies`. Builds a fixture `EnemyDef` for a given enemy id: fixed health from a fixture constant and a board of `FixtureItems.enemy_attack()`. |
| `fixture_run.gd` | `class_name FixtureRun`. `install()` puts the fixture content into the catalogs; `uninstall()` takes it out. |

`FixtureRun.install()` does three things:

1. Adds every `FixtureItems` definition to `ItemCatalog`, so the run can build them by id.
2. Adds the fixture character to `CharacterCatalog`.
3. Replaces **every** `EnemyCatalog` definition with a fixture enemy under the same id. The map and
   the encounters name enemies by id, so the fixture has to take over the ids rather than add new
   ones. Replacing every id, rather than a list of them, keeps the fixture working when the owner
   adds enemies.

Each catalog is built before it is written to, because the catalogs build lazily on first access
and would otherwise skip building once they are not empty. The fixture writes to each catalog's
`_defs` dictionary directly, so no test-only code is added to the game.

`FixtureRun.uninstall()` clears the `_defs` of `ItemCatalog`, `CharacterCatalog` and
`EnemyCatalog`, so the next access rebuilds them from the real content. `TestCleanup.reset_all_managers()`
calls it, so a test that installed the fixture cannot leak it into the next test.

## Sizing rule

The fixture player must beat the fixture enemies by a wide margin. Every enemy id, the boss
included, becomes the same one-attack fixture enemy. The run still uses real encounters, events, rests and relic rewards, because those are
structure rather than balance. The margin is what stops them from changing a test's result. Today
`ColorlessPool.ITEMS` is empty and the relic reward pool only helps the player. If either changes,
the margin still has to hold.

The fixture numbers are constants in the fixture files and are never read from `Balance`, following
the same rule as `fixture_items.gd`.

## Which tests move

A test moves to the fixture unless it is testing a specific real character, item or enemy.

| Moves to the fixture | Stays on real content |
|---|---|
| `tests/run/test_game_manager.gd` | `tests/content/test_starting_board.gd` |
| `tests/run/test_run_manager.gd`, except the tests about choosing a real character | `tests/content/test_pool_integrity.gd` |
| `tests/autotest/test_auto_test_run.gd` | The `test_run_manager.gd` tests that check a chosen real character's pool |
| `tests/autotest/test_auto_test_mode.gd`, where it plays a run or the default sandbox fight | |
| `tests/run/test_encounter_budget.gd`, the tests that start a run | |
| `tests/ui/test_run_screen.gd` | `tests/corridors/test_combat_corridor.gd` (its one run checks the RNG, not an outcome) |
| `tests/run/test_encounter.gd` (found by the independence check below) | |

A moved test calls `FixtureRun.install()` in `before_each` and passes `FixtureCharacter.ID` to
`run.start`, `Game.start_run` or `AutoTestMode.character`. The shield tests look for
`FixtureItems.shield()`'s name instead of the Femur's.

## One game-code change

`AutoTestMode._build_fight()` builds the single-fight sandbox from `CharacterCatalog.DEFAULT`
and ignores `--character`. It changes to use the `character` field, so the sandbox follows
`--character` like run mode does and a test can point it at the fixture character. `autotest.md`
is updated to say `--character` applies to both modes.

## Docs

- `docs/systems/testing.md` gets a Fixtures section: what each fixture file is for, the install
  and uninstall calls, the sizing rule, and the rule for which tests use the fixture.
- `docs/design/authoring.md` already points combat tests at `fixture_items.gd`; it gains one line
  saying run tests use `FixtureRun`.
- `docs/systems/autotest.md` for the `--character` change.

## Checks

- The full GUT suite passes with `ENEMY_PLACEHOLDER_HP` at 164.
- As a check that the fixture is really independent, temporarily set every enemy health constant
  in `Balance` to 10000 and `CharacterCatalog.DEFAULT` to the Spore Druid, then run the moved test
  files. They must still pass. Revert both afterwards.
- `tools/import.sh` is clean after adding the three `class_name` files (run it twice).
