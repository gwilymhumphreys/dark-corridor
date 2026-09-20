# CLAUDE.md

Guidance for Claude Code when working with this Godot 4 game.

## Before Starting Tasks

**Always reference the docs before searching the codebase.** Start at
[`docs/index.md`](docs/index.md) — a catalog of all project documentation with
one-line descriptions. Find the relevant doc there, read it, and only then
search the code it points to. Most questions about the rendering, geometry,
filtering, motion, or scenes are already answered in `docs/`.

If you change behaviour a doc describes, update that doc in the same change.

Doc structure:

- `docs/index.md` — catalog / lookup index for all docs (read this first)
- `docs/handoff.md` + `docs/decision_log.md` — fresh-agent orientation + the canonical decision record
- `docs/systems/` — one doc per engineering system (spec + as-built), incl. the corridor renderers (`systems/corridors/`) and dev tooling (autotest, localization)
- `docs/design/` — game/content design (the owner's domain) + the content authoring guide
- `docs/history/` — the chronological build log + the original phase plans

## Allowed External Directories

When working on this project, you may freely read from:

- `../a-machine` - Previous project, most useful (Juice, VFX, Audio, UI, save/load)
- `../battledraft` - Sister project with shared systems (VFX, debug panels, post-processing)
- `../dogmage` - Sister project with shared systems (VFX, debug panels, post-processing)
- `../dark-corridor-design` - Source art packs for this game (icons, portraits, monsters, palettes, UI sheets). See [`docs/design/asset_library.md`](docs/design/asset_library.md) for what is where and how to find a named file.

## Code Standards (MANDATORY)

```gdscript
# Static typing - ALWAYS
var name: String = 'value'
func example(param: int) -> void:

# Single quotes for strings
var text: String = 'hello'

# 2 spaces indentation, 2 blank lines between functions
func first() -> void:
  pass

func second() -> void:
  pass

# Trailing comma in multi-line arrays/dicts
var data: Dictionary = {
  'key': 'value',
}
```

- **Filenames**: `snake_case` per the Godot 4 style guide (e.g., `corridor_3d.gd`, `combat_corridor.tscn`, `corridor_look.gdshader`). `class_name` and in-scene node names stay PascalCase — so `class_name CombatCorridor` lives in `combat_corridor.gd`.
- **No preloads for `class_name` classes** — Godot makes them globally available
- **Autoload class names**: Use `<Name>Autoload` suffix (e.g., `class_name CursorManagerAutoload`) to avoid conflict with the autoload's registered name. Access via the registered name (e.g., `CursorManager.request_hand()`).
- **Surgical edits only** — Modify least code possible; ask before major refactors
- **Theme over code** — Style UI via the theme resource (`assets/themes/dark_corridor.tres`, the project default), not `add_theme_*_override()` in code
- **Never hardcode a font size** — every label and button takes a rung of the text ladder through `theme_type_variation` (`LabelSmall`, `LabelMedium`, `ButtonHeading`, …); a label with no variation gets the body size. A `theme_override_font_sizes/font_size` in a scene does not follow the player's text size setting, so it is always wrong. The rungs and the setting: [`docs/systems/ui_theme.md`](docs/systems/ui_theme.md)
- **Scenes over code** — Prefer `.tscn` scene files for UI and node trees over building them programmatically in `_ready()`
- **Juicy animations**: When adding new ui or visual entities, add the ui juice node to it
- **Animate UI with `offset_transform_*`** (Godot 4.7) — When animating a Control's position/scale/rotation (hover bounces, presses, slides, shakes), set `offset_transform_enabled = true` and tween the `offset_transform_position` / `offset_transform_scale` / `offset_transform_rotation` properties (pivot via `offset_transform_pivot` / `offset_transform_pivot_ratio`) instead of the layout `position` / `scale` / `rotation`. The offset transform is visual-only (`offset_transform_visual_only` defaults true), so it does not fight container layout — use it wherever a container positions the node (the old `position`-tween caveat). Tween the layout properties only when the node is not container-managed and the animation must affect layout.
- **Full names, not abbreviations**: Refer to game entities by their full names. Applies to code, comments, docs, run reports, tuning logs, and chat replies — abbreviations make grep harder and obscure what's being discussed.
- **Don't add jargon**: No invented terms or vague, high-level, obtuse shorthand. Use plain, concrete language; if a term is genuinely needed, define it where it's introduced, and don't reuse a word that already means something specific in the game. Applies to code, comments, docs, run reports, tuning logs, and chat replies.

## Bugs

- When you encounter a bug or failing test, always fix it or ask the user if you should fix it — don't dismiss anything as pre-existing or unrelated.

## Running Godot

Use the wrappers, never a raw Godot command: `tools/gut.sh` (GUT suite),
`tools/autotest.sh` (headless run), `tools/import.sh` (reimport, required after adding
a file or a new `class_name`). Each writes the full output to `_temp/` and prints only
the failures and the summary. A raw Godot command is refused by the `PreToolUse` hook
in `.claude/settings.json` unless its output is redirected to a file or piped through
`tail` or `grep`.

## Searching

When a search will span many files or several naming conventions, use the Explore
subagent instead of running it here. It returns the answer without the file listings.

## Testing

Conventions, `TestCleanup`, and signal tests: [`docs/systems/testing.md`](docs/systems/testing.md).

AI-controlled E2E testing: [`docs/systems/autotest.md`](docs/systems/autotest.md) for
standard commands, defaults, and the full argument reference.

## Godot engine notes

Asset importing, `RichTextLabel` `fit_content` sizing, and runtime cleanup (leaks and
invalid frees at scene changes and exit):
[`docs/systems/godot_notes.md`](docs/systems/godot_notes.md).

## Shell

- This is a Windows machine but Bash runs via Git Bash — do NOT use `cd /d` or Windows-style path arguments in commands. Run commands directly from the working directory (e.g., `git status`, not `cd /d C:\projects\a-machine && git status`).
- Do not prefix commands with `cd /c/projects/a-machine &&` — the working directory is already set and persists between commands.
- When paths are needed in Bash commands, use Unix-style paths in quotes (e.g., `git -C "/c/projects/a-machine" status`).

## Git

- Do not add your own attribution to any git messages

## Documentation

**Full conventions: [`docs/documentation.md`](docs/documentation.md).** The essentials:

- **Always update the docs in the SAME change as the behaviour they describe.** After any change, review the affected doc(s) and create/update as needed — code and its doc are never left out of sync. This is mandatory, not a follow-up.
- **Every new doc gets a catalog entry in [`docs/index.md`](docs/index.md)** — an uncatalogued doc is invisible (the index is read first). **Exception: `docs/plans/` plans are temporary and NOT catalogued** — a plan earns an index row only if it ships as a `systems/` doc.
- Keep all documentation concise with minimal examples so that an agent can quickly reference it to understand the subject
- **Docs describe systems, mechanics, and design intent — not specific numbers.** Point to source files (`upgrades/*.json`, GDScript constants) for tunable values. This prevents docs from going stale when values are tuned. If a formula is important for understanding the system, include it but reference the source file for the actual constants.

## Localization

All player-facing text must be translatable; dev and debug panels stay English.
Static UI text goes in the `.tscn` as plain English and auto-translates; dynamic,
formatted or data-driven text uses `tr()`. Full rules and the POT regeneration step:
[`docs/systems/localization.md`](docs/systems/localization.md).

## Save files

Do not migrate save files, don't plan for this at all we're still in development

## Pre-existing Issues

If you discover pre-existing issues at any time address them immediately, but inform the user as well

## Never say "load bearing"

## Assumptions

- Never make assumptions about how things work or how the game plays. If you find yourself generalising to other games stop and read the docs.
