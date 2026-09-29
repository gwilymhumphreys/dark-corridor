# Localization

How translatable text is authored, extracted, and translated. All player-facing
text must be localizable (dev/debug/testbed UI stays English).

## Locales

Registered in `project.godot` (`internationalization/locale/translations`):
`en` — `locale/en.po`. `en.po` mirrors the source English (every `msgstr` equals its
`msgid`); to add a locale, add its `locale/<code>.po`, list it in the same setting, and add its
code to `LOCALES` in `tools/extract_pot.gd` so the extractor merges it. An empty `msgstr` falls back to the source string.

## Two ways text gets translated

**1. Automatic (preferred for static UI).** Control nodes with the default
`auto_translate_mode` translate their `text` automatically and re-translate on a
locale change (the node keeps the source English and re-resolves it). So **static
menu / label / button text lives in the `.tscn` as plain English — no `tr()`**.
Examples: the title (`Dark Corridor` / `Start` / `Resume`), the draft overlay
title (`Choose a reward`), the outcome buttons, the `You` portrait label. Set
`auto_translate_mode = DISABLED` on a node whose text must NOT translate.

**2. Explicit `tr()` (for dynamic / formatted / data-driven text).** Use `tr('...')`
when the string is built at runtime, formatted, or comes from data — auto-translate
can't help there. Examples: item/enemy names via `tr(def.name_key)`, the map strip's act label
(`tr('Act {0}')`), the outcome title (`tr('Victory')`), the draft gold button
(`tr('+{0} gold').format(...)`). **Put the literal inside `tr()`**, not behind a
variable — `tr('Victory')`, not `tr(title_var)` — so the extractor sees it. **Avoid** `node.text = tr('...')` for *static*
text: it stores the translated string and won't re-translate on a live locale switch.

## String sources & the catalog

Translatable strings come from these places (Dark Corridor authors content in
GDScript — decision #23 — not data files):

| Source | Holds |
|--------|-------|
| `.gd` — `tr('...')` / `tr("...")` literals | code-built UI, formatted strings, the map and outcome labels |
| `.tscn` — `text` / `tooltip_text` / `popup/item_<n>/text` | static scene UI (menus, titles, buttons, OptionButton / menu items) |
| `.gd` — `name_key = '...'` literals | item / enemy / status / encounter / relic / enchant / consumable names (shown via `tr(def.name_key)`) |
| `.gd` — `class_key = '...'` literals | a character's class, under its name on the select screen and in the player's Class field (`tr(def.class_key)`) |
| `.gd` — `label_key`, `desc_key`, `description_key` literals (also as `'desc_key': '...'` dictionary entries) | event option buttons, status keyword card text, item flavour lines |
| `.gd` — `event_prose_key` (may be split across lines and joined) | event body text |

The whole `src/debug/` folder is skipped (`EXCLUDE_DIRS` in `tools/extract_pot.gd`): the
[debug panel](debug_panel.md), the corridor testbed and the combat sandbox, whose text stays English.

## Regenerating the catalog

Godot's built-in POT generator can't read the GDScript `name_key` content, so the
project uses a headless extractor. **Run it after adding or changing any translatable
string:**

```bash
tools/pot.sh   # extract the POT, merge the .po files, then reimport
```

It writes `locale/messages.pot` and merges each locale in `LOCALES`, preserving existing
`msgstr` translations and dropping strings no longer present (no gettext / msgmerge
dependency). Then translate the empty `msgstr` entries in non-English `.po`s, and
**re-import** so the `.po` → `.translation` resources rebuild:

```bash
tools/import.sh
```

## Fonts per locale

There is one UI font, named as the theme's default font, and it must cover every
shipped locale (it relies on `allow_system_fallback` plus optional bundled Noto
fallbacks). Details, including what a second font style would need:
[ui_theme.md](ui_theme.md#fonts).
