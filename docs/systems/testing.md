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

Tests use fixture content from `tests/fixtures/` instead of authored content, so tuning, renaming or
re-rostering real content cannot change a test's result. Fixture numbers are constants in the
fixture files and are never read from `Balance`.

| File | What it gives |
|---|---|
| `fixture_items.gd` | `FixtureItems`: an attack, an enemy attack, a shield, a poison applier and two filtered-target items, as fresh `ItemDef`s. |
| `fixture_character.gd` | `FixtureCharacter`: a character with a fixed starting board and a pool of fixture items only. |
| `fixture_enemies.gd` | `FixtureEnemies`: an enemy with fixed health and one fixture attack. |
| `fixture_run.gd` | `FixtureRun.install()`: adds the fixture items and character to the catalogs and replaces every authored enemy with the fixture enemy under the same id. |

A test that plays a run, an encounter or an autotest calls `FixtureRun.install()` in `before_each`
and passes `FixtureCharacter.ID` to `run.start`, `Game.start_run` or `AutoTestMode.character`. The
map, encounters, events and relic rewards stay real; the fixture character beats the fixture
enemies by a wide margin so that they cannot change a result. Keep that margin if you change either.

Use real content only when the test is about that content: a specific card, a character's pool, the
catalog itself.

## Resetting state between tests

`TestCleanup` (`tests/utils/cleanup.gd`) resets the autoloads that hold state
across tests. Call it in both `before_each` and `after_each`:

```gdscript
func before_each() -> void:
  TestCleanup.reset_all_managers()
```

`reset_all_managers()` frees the live run held by `Game`, re-enables saving,
keeps `Prefs` in memory rather than on disk, resets the debug panel settings, and
removes the run fixtures if a test installed them.

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
