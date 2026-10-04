# CLAUDE.md

Guidance for Claude Code when working with this Godot 4 game.

## Start with the docs

Read [`docs/index.md`](docs/index.md) first. It lists every doc with a one-line description. Read the relevant doc, then search the code it points to.

- `docs/handoff.md`, `docs/decision_log.md` — orientation for a new agent, and the record of decisions
- `docs/systems/` — one doc per engineering system, including the corridor and dev tooling
- `docs/design/` — game and content design (the owner's domain) and the content authoring guide
- `docs/history/` — build log and the original phase plans

## External directories you may read

- `../a-machine` — previous project (juice, VFX, audio, UI, save/load)
- `../battledraft`, `../dogmage` — sister projects (VFX, debug panels, post-processing)
- `../dark-corridor-design` — source art packs; see [`docs/design/asset_library.md`](docs/design/asset_library.md)

## Code standards (mandatory)

```gdscript
# Static typing, single quotes, 2-space indent, 2 blank lines between functions
var text: String = 'hello'


func example(param: int) -> void:
  pass


# Trailing comma in multi-line arrays and dicts
var data: Dictionary = {
  'key': 'value',
}
```

- **Filenames** are `snake_case`; `class_name` and node names are PascalCase (`class_name CombatCorridor` in `combat_corridor.gd`).
- **No preloads** for `class_name` classes.
- **Autoload classes** take an `Autoload` suffix (`class_name StatusManagerAutoload`) and are accessed by the registered name (`StatusManager.apply(...)`).
- **Surgical edits.** Change as little code as possible; ask before major refactors.
- **Style UI through the theme** (`assets/themes/dark_corridor.tres`), not `add_theme_*_override()`.
- **Never hardcode a font size.** Use a `theme_type_variation` rung (`LabelSmall`, `ButtonHeading`, …) so text follows the player's size setting. See [`docs/systems/ui_theme.md`](docs/systems/ui_theme.md).
- **Prefer `.tscn` scenes** over building node trees in code.
- **Add the UI juice node** to new UI or visual entities.
- **Animate Controls with `offset_transform_*`** (set `offset_transform_enabled = true`, tween `offset_transform_position`/`_scale`/`_rotation`). It is visual-only, so it does not fight container layout. Tween `position`/`scale`/`rotation` only when the animation must change layout.
- **Use full names** for game entities, never abbreviations — in code, docs, reports and chat.
- **Use the lexicon.** Game terms mean what [`docs/design/lexicon.md`](docs/design/lexicon.md) says; add new terms there.
- **No jargon.** Use plain, concrete words. Define any new term where it first appears and do not reuse a word the game already uses.

## Bugs and pre-existing issues

Fix any bug, failing test or pre-existing issue you find, or ask whether to fix it, and tell the user. Never dismiss one as unrelated.

## Running Godot

Use the wrappers, never a raw Godot command. Each writes full output to `_temp/` and prints only failures and a summary.

- `tools/gut.sh` — GUT suite
- `tools/autotest.sh` — headless run
- `tools/import.sh` — reimport; required after adding a file or a `class_name`
- `tools/lsp_check.sh` — GDScript analyzer warnings

## Searching

For searches across many files or naming conventions, use the Explore subagent.

## Reference docs

- Testing: [`docs/systems/testing.md`](docs/systems/testing.md)
- Autotest (AI-controlled end-to-end runs): [`docs/systems/autotest.md`](docs/systems/autotest.md)
- Godot engine notes (importing, `RichTextLabel` sizing, cleanup at exit): [`docs/systems/godot_notes.md`](docs/systems/godot_notes.md)
- Localization: [`docs/systems/localization.md`](docs/systems/localization.md). All player-facing text must be translatable; static text in `.tscn` translates automatically, dynamic text uses `tr()`. Debug panels stay English.

## Shell

Bash is Git Bash on Windows. Do not use `cd /d`, Windows-style paths or a `cd` prefix; the working directory is already set. Quote Unix-style paths (`git -C "/c/projects/dark-corridor" status`).

## Git

Do not add your own attribution to git messages.

## Documentation

Full conventions: [`docs/documentation.md`](docs/documentation.md).

- Update docs in the same change as the behaviour they describe.
- Add every new doc to [`docs/index.md`](docs/index.md), except temporary plans in `docs/plans/`.
- Keep docs concise, with minimal examples.
- Describe systems and intent, not tunable numbers. Point to `src/data/balance.gd` or `content/` for values.

## Other rules

- Do not migrate save files or plan for it; the game is still in development.
- Never say "load bearing".
- Do not assume how the game works from other games. Read the docs.
- Plan tool calls ahead and batch them; wait for all results before reading any.
