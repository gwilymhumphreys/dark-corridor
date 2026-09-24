# Plan: dev and test code in one place

> **Status: built (2026-09-25).** The system doc is [dev_tools.md](../systems/dev_tools.md). Moves the start-up arguments and demo code that
> screenshots, dev scenes and look checks use out of the game's screens and autoloads, into
> `src/debug/`, with one doc listing every argument. It also fixes `--nosave`, which the game never
> read.

## Why

Code that exists only for screenshots and demos is spread through real game code:

| Where | What it does |
|---|---|
| `run_screen.gd` | `--allies N`, `--board-items N`, `--potions N` add to the run; `--autofight` picks the first fight on the path choice |
| `title_screen.gd` | `--autostart`, `--character=ID`, `--select`, `--settings` |
| `main_controller.gd` | `--shot`, `--shot-delay` |
| `prefs.gd`, `sfx_manager.gd`, `music_manager.gd` | each keeps its own copy of `SILENT_ARGS` (`--autotest`, `--shot`) |
| `interface_glow.gd` | `--glow-demo=` |
| `src/scenes/combat_sandbox`, `corridor_testbed`, `src/scenes/dev/tooltip_demo` | dev scenes stored beside the game's scenes, each with its own screenshot code |

Problems this causes:

- The run screen's header says it never changes game state, but the three add hooks write to the
  run, two of them around the Run manager.
- The add hooks run in the run screen's `_ready`, which also runs on Resume, so each resume adds
  more.
- `--nosave` appears in the documented screenshot command but nothing in the game reads it. Only
  the autotest sets `Save.disabled`. A screenshot run overwrites the player's real run save.
- About twelve scripts read arguments, each in its own way: some read only the user arguments
  (after `--`), some read both lists; some take `--name=value` and some `--name value`
  (`--shot-delay` is `--shot-delay 6` in the game and `--shot-delay=6` in the corridor testbed).
- The arguments are documented in `run_screen.md`, `debug_panel.md`, `handoff.md` and the corridor
  docs, and no single list is complete.

## Out of scope

- **The autotest** stays in `src/autotest/` with its own parser and its own argument table in
  `autotest.md`. It is already separate from game code, it has its own wrapper (`tools/autotest.sh`),
  and the `tune` skill depends on its arguments. The new doc links to its table.
- **Seams the tools use** stay in game code, because they are the smallest way in: `Save.disabled`,
  `Prefs.disabled`, `RunManager.pinned_enemy_ids`, `MonsterImages.forced_path`.
- **The look arguments** (`--preset=`, `--corridor-set=` and the rest) stay parsed in
  `DebugPanels._apply_command_line`, because they set the panels' own state. Only the reading of
  the arguments changes (below), and their table moves to the new doc.

## Design

### Folder

Everything goes under `src/debug/`, which is already dev-only and already excluded from POT
extraction (`tools/extract_pot.gd` `EXCLUDE_DIRS`):

- `src/debug/dev_args.gd` — new, `class_name DevArgs`
- `src/debug/dev.gd` — new autoload, `class_name DevAutoload`, registered as `Dev`
- `src/debug/scenes/` — the three dev scenes move here: `combat_sandbox`, `corridor_testbed`,
  `tooltip_demo` (`.gd`, `.tscn`, `.uid`)

### `DevArgs` (static helpers, no state)

| Function | Returns |
|---|---|
| `all() -> PackedStringArray` | the engine arguments followed by the user arguments |
| `has(flag: String) -> bool` | whether `flag` appears in either list |
| `value(name: String, default: String = '') -> String` | the value of `--name=value` or `--name value`, whichever form was used |
| `values(name: String) -> PackedStringArray` | every value of a repeatable `--name=value` argument |
| `is_silent_run() -> bool` | whether `--autotest` or `--shot` is present |

Accepting both value forms keeps every command already in the docs and skills working. In the
`--name value` form, a following argument that starts with `--` is not a value, so `--allies --shot`
gives the default.

`DevArgs` is a static class rather than part of the `Dev` autoload because `SfxManager` is the first
autoload and asks `is_silent_run()` in its own `_ready`, before `Dev` exists.

### `Dev` autoload

Registered last in `project.godot`, after `DebugPanels`. It does nothing unless one of its arguments
is present.

| Argument | Behaviour | Replaces |
|---|---|---|
| `--nosave` | sets `Save.disabled = true` in `_ready`, before any run can start | nothing (bug fix) |
| `--notutorial` | accepted and ignored; there is no tutorial yet | nothing |
| `--shot`, `--shot-delay` | waits the delay (default 1.5 seconds), saves the frame with `Screenshot.save` named after the running scene's file, quits | `main_controller`, and the capture in the three dev scenes |
| `--autostart`, `--character=ID` | when the title screen is added, starts a run with `Game.start_run(TitleScreen.DEFAULT_SEED, id)`; an unknown id warns and uses the default | `title_screen` |
| `--select`, `--settings` | when the title screen is added, calls its public `open_select()` or `open_settings()` | `title_screen` |
| `--autofight` | when a `ChoiceOverlay` is added, picks the first fight in `Game.run.pending_choice()` by emitting its `picked` signal on the next frame | `run_screen` |
| `--allies N`, `--board-items N`, `--potions N` | on `Game.run_started`, adds to the new run | `run_screen` |

`Dev` watches `SceneTree.node_added` for the title screen and the choice overlay, and connects only
when one of those arguments is present. The screens keep no dev code. The title screen arguments
act on the first title screen only; today they fire again after Quit to Menu, which drops the
player straight back into a run.

The title screen gets `class_name TitleScreen`, and `_open_select` / `_open_settings` become public,
since `Dev` calls them.

The add arguments:

- warn and do nothing when the content id they use does not exist (`EnemyCatalog.has` for the ally;
  `ConsumableCatalog.get_def` already returns null with an error);
- use `RunManager.add_ally` for allies; board items and potions are appended directly, as today,
  because the Run manager has no method for either and adding one only for a dev tool is not worth it;
- keep their content ids as constants at the top of `dev.gd`.

### `Game.run_started`

A new signal on the Game manager, `run_started(run: RunManager)`, emitted in `start_run` after
`run.start()` and before `_set_phase(Phase.RUN)`. So the additions land before the run screen or its
combat view is built, and only on a new run, never on Resume.

`run.start()` saves the first beat before the signal, so without `--nosave` the save lacks the
additions until the next beat's save. The doc says to use the add arguments with `--nosave`.

### Screenshot delays

The dev scenes each used a different fixed delay (sandbox 2 s, corridor testbed 0.6 s, tooltip demo
1.5 s). With one capture they all use `--shot-delay`, default 1.5 s. The corridor testbed keeps its
scene-specific set-up for a shot (`--still`, `--monster`, moving forward) in its own `_ready`, since
those change the scene, not the capture.

Screenshot files are named after the scene file, so the game's shots become `main_shot_<date>_<time>.png`
instead of `run_shot_…`, and the testbed's become `corridor_testbed_shot_…` (named in `corridor_3d.md`).

### Game code after the change

- `prefs.gd`, `sfx_manager.gd`, `music_manager.gd`: remove `SILENT_ARGS`, call `DevArgs.is_silent_run()`.
- `interface_glow.gd`: remove the argument loop; add a public `demo_brightness` that
  `DebugPanels._apply_command_line` sets from `--glow-demo=`.
- `debug_panels.gd`: read through `DevArgs.all()` instead of only the user arguments.
- `corridor_testbed.gd`: read `--view=`, `--set=`, `--still`, `--monster` through `DevArgs`.
- `main_controller.gd`, `title_screen.gd`, `run_screen.gd`: dev code removed.

### Paths that change

| File | Change |
|---|---|
| `tests/ui/test_cursor.gd` | the corridor testbed's path |
| `tools/extract_pot.gd` | drop the three names from `EXCLUDE_FILES`; the folder exclusion covers them |
| docs naming the moved scenes | `handoff.md`, `corridor_3d.md`, `corridor_look.md`, `palette_clamp.md`, `tooltips.md` |

`decision_log.md` records the testbed rename as history; it is not changed.

## Docs

- New `docs/systems/dev_tools.md`, catalogued in `docs/index.md`: the `Dev` autoload, `DevArgs`, the
  dev scenes, and one table of every start-up argument (game and dev scenes, plus the look table
  moved from `debug_panel.md`), linking to `autotest.md` for the autotest's arguments.
- `debug_panel.md`: the start-up arguments section becomes a link to the new doc.
- `run_screen.md`: remove the dev hook sentences.
- `handoff.md`: point the screenshot and sandbox commands at the new doc and paths.
- `game_manager.md`: add the `run_started` signal.

## Tests

- `tests/debug/test_dev_args.gd`: `value` with both forms and a missing value, `values` with a
  repeated argument, `has`. `DevArgs` reads `OS`, so the parsing goes through a static function that
  takes the argument list, and the tests call that.
- A test that `Game.start_run` emits `run_started` before the phase changes to RUN.
- The existing run screen, title and cursor tests must pass unchanged, apart from the path fix.
- Check by hand: the documented screenshot command still produces a mid-fight shot, and the save
  slot is unchanged after it.
