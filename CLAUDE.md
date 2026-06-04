# CLAUDE.md

Guidance for Claude Code when working with this Godot 4 game.

## Before Starting Tasks

**Always reference the docs before searching the codebase.** Start at
[`docs/index.md`](docs/index.md) — a catalog of all project documentation with
descriptions and keywords. Find the relevant doc there, read it, and only then
search the code it points to. Most questions about the rendering, geometry,
filtering, motion, or scenes are already answered in `docs/`.

If you change behaviour a doc describes, update that doc in the same change.

Doc structure:
- `docs/index.md` — catalog / lookup index for all docs (read this first)
- `docs/corridors/` — the two corridor renderers (default + toggle) + shared base/host (`common.md`)

## Allowed External Directories

When working on this project, you may freely read from:
- `../battledraft` - Sister project with shared systems (VFX, debug panels, post-processing)
- `../dogmage` - Sister project with shared systems (VFX, debug panels, post-processing)

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

- **Files**: End with exactly one blank line
- **Filenames**: `snake_case` per the Godot 4 style guide (e.g., `corridor_renderer.gd`, `corridor_scaled.tscn`, `sharp_bilinear.gdshader`). `class_name` and in-scene node names stay PascalCase — so `class_name CorridorRenderer` lives in `corridor_renderer.gd`.
- **No preloads for `class_name` classes** — Godot makes them globally available
- **Autoload class names**: Use `<Name>Autoload` suffix (e.g., `class_name CursorManagerAutoload`) to avoid conflict with the autoload's registered name. Access via the registered name (e.g., `CursorManager.request_hand()`).
- **Surgical edits only** — Modify least code possible; ask before major refactors
- **Theme over code** — Style UI via the theme resource (`assets/themes/a-machine-theme.tres`), not `add_theme_*_override()` in code
- **Scenes over code** — Prefer `.tscn` scene files for UI and node trees over building them programmatically in `_ready()`
- **No opacity/transparency** — Do not use alpha fades or semi-transparent effects; they break the pixel-art aesthetic. Ask the user before adding any opacity.
- **Enter animations**: When adding new buildings, sprites, or visual entities, use `AnimUtils.enter(node, self)` for the standard elastic pop-in and `AnimUtils.swap(node, self, callback)` for collapse-swap-expand transitions
- **Full names, not abbreviations**: Refer to buildings and upgrades by their full names (e.g., `Beam Tier 1`, not `BT1`; `Crystal Grove`, not `CG`; `Research Center`, not `RC`; `Nuclear Plant`, not `NP`). Applies to code, comments, docs, run reports, tuning logs, and chat replies — abbreviations make grep harder and obscure what's being discussed.

## RichTextLabel fit_content Sizing (Godot-specific)

`RichTextLabel` with `fit_content = true` computes its height based on its **actual rendered width**, not `custom_minimum_size.x`. On first display, if sibling nodes (e.g. item rows) push the parent container wider than `custom_minimum_size.x`, the label's height was already computed at the narrower minimum width — producing extra empty space. On subsequent opens the cached width is correct.

**Fix:** set `custom_minimum_size.x` on the parent container wide enough to match the widest expected content, so the label computes height at the correct width from the start. Other approaches (deferred resize, re-setting text, updating `custom_minimum_size.x` after layout, switching to Label) did not work.

## Runtime Cleanup (Godot-specific)

Prevent leaks and invalid frees at scene changes / exit:

- **Textures**: Set `node.texture = null` before `queue_free()` in `_exit_tree()`
- **Reparented nodes**: Avoid reparenting during teardown; store `original_parent` with `set_meta()`
- **Signals/tweens/timers**: Disconnect and stop in `_exit_tree()`
- **Arrays/dicts with Node refs**: Clear in `_exit_tree()`
- **Deferred frees**: Use `call_deferred('queue_free')` for nodes with render resources

## Bugs

- When you encounter a bug or failing test, ask the user if you should fix it — don't dismiss anything as pre-existing or unrelated

## Testing

```gdscript
# Standard setup - reset autoloads between tests
func before_each() -> void:
  TestCleanup.reset_all_managers()

func after_each() -> void:
  TestCleanup.reset_all_managers()

# Signal testing
func test_something() -> void:
  watch_signals(SomeManager)
  SomeManager.do_thing()
  assert_signal_emitted(SomeManager, 'thing_done')
```

- Test files: `test_<component>.gd` in `tests/` subdirectories
- Work with autoloads, don't mock them
- Use `TestCleanup.setup_development_environment()` for auth tests

### AutoTest Mode (E2E)

AI-controlled E2E testing. See `docs/testing/autotest.md` for standard commands, defaults, and full argument reference. Always use `--nosave --notutorial` flags.

## Importing Assets

If you get errors due to files not having been imported, or if you add files, run:

```bash
godot --headless --import --exit
```

## Shell

- This is a Windows machine but Bash runs via Git Bash — do NOT use `cd /d` or Windows-style path arguments in commands. Run commands directly from the working directory (e.g., `git status`, not `cd /d C:\projects\a-machine && git status`).
- Do not prefix commands with `cd /c/projects/a-machine &&` — the working directory is already set and persists between commands.
- When paths are needed in Bash commands, use Unix-style paths in quotes (e.g., `git -C "/c/projects/a-machine" status`).

## Git

- Do not add your own attribution to any git messages

## Documentation

- After making changes, always review the documentation and create or update if needed
- Keep all documentation concise with minimal examples so that an agent can quickly reference it to understand the subject
- **Docs describe systems, mechanics, and design intent — not specific numbers.** Point to source files (`upgrades/*.json`, GDScript constants) for tunable values. This prevents docs from going stale when values are tuned. If a formula is important for understanding the system, include it but reference the source file for the actual constants.


## Localization

All player-facing text must be translatable (dev/debug panels stay English). See `docs/reference/localization.md` for the full system.

- **Static UI text** (menus, labels, buttons, dropdown items): put it in the `.tscn` as plain English and let auto-translate handle it — no `tr()`, no locale-change handler. Set `auto_translate_mode = DISABLED` for text that must not translate (e.g. language names).
- **Dynamic / formatted / data-driven text**: use `tr('...')` (e.g. `tr('Time: {0}').format(...)`, `tr(data.name)`). Never `node.text = tr('...')` for static text — it won't re-translate on a locale switch.
- After adding or changing any translatable string, run `godot --headless --path . --script res://tools/extract_pot.gd` to regenerate `locale/messages.pot` and merge the `.po` files, then re-import.

## Save files
Do not migrate save files, don't plan for this at all we're still in development

## Pre-existing Issues
If you discover pre-existing issues at any time address them immediately, but inform the user as well


## Never say "load bearing"

## Assumptions
- Never make assumptions about how things work or how the game plays. If you find yourself generalising to other games stop and read the docs.
