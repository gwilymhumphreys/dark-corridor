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

## Resetting state between tests

`TestCleanup` (`tests/utils/cleanup.gd`) resets the autoloads that hold state
across tests. Call it in both `before_each` and `after_each`:

```gdscript
func before_each() -> void:
  TestCleanup.reset_all_managers()
```

`reset_all_managers()` frees the live run held by `Game`, re-enables saving,
keeps `Prefs` in memory rather than on disk, and resets the debug panel settings.

A test that builds an `Actor` without a `RunManager` should register it with
`TestCleanup.dissolve_at_reset(actor)`. In the game `RunManager.teardown` dissolves
the player side; without that call the actor's reference cycle with its items stays
alive. See [actor.md](actor.md) for the lifetime rules.

## Signals

```gdscript
func test_something() -> void:
  watch_signals(SomeManager)
  SomeManager.do_thing()
  assert_signal_emitted(SomeManager, 'thing_done')
```
