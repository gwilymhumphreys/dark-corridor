# Localization

How translatable text is authored, extracted, and translated. All player-facing
text must be localizable (dev/debug/testbed UI stays English).

## Locales

Registered in `project.godot` (`internationalization/locale/translations`):
`en` — `locale/en.po`. `en.po` mirrors the source English (every `msgstr` equals its
`msgid`); add more locales by dropping `locale/<code>.po` files and listing them in
the same setting. An empty `msgstr` falls back to the source string.

## Two ways text gets translated

**1. Automatic (preferred for static UI).** Control nodes with the default
`auto_translate_mode` translate their `text` automatically and re-translate on a
locale change (the node keeps the source English and re-resolves it). So **static
menu / label / button text lives in the `.tscn` as plain English — no `tr()`**.
Examples: the title (`Dark Corridor` / `Start Run` / `Resume`), the draft overlay
title (`Choose a reward`), the outcome buttons, the `You` portrait label. Set
`auto_translate_mode = DISABLED` on a node whose text must NOT translate.

**2. Explicit `tr()` (for dynamic / formatted / data-driven text).** Use `tr('...')`
when the string is built at runtime, formatted, or comes from data — auto-translate
can't help there. Examples: item/enemy names via `tr(def.name_key)`, the map labels
(`tr('Fight')`…), the rarity labels, the outcome title (`tr('Victory')`), the draft
tooltip template (`tr('{0} — {1}…').format(...)`). **Put the literal inside `tr()`**,
not behind a variable — `tr('Common')`, not `tr(rarity_var)` — so the extractor sees
it (see `draft_card._rarity_name`). **Avoid** `node.text = tr('...')` for *static*
text: it stores the translated string and won't re-translate on a live locale switch.

## String sources & the catalog

Translatable strings come from three places (Dark Corridor authors content in
GDScript — decision #23 — not data files):

| Source | Holds |
|--------|-------|
| `.gd` — `tr('...')` / `tr("...")` literals | code-built UI, formatted strings, the map/rarity/outcome labels |
| `.tscn` — `text` / `tooltip_text` | static scene UI (menus, titles, buttons) |
| `.gd` — `name_key = '...'` literals | item / enemy / status / encounter / relic / enchant / consumable names (shown via `tr(def.name_key)`) |

Dev / throwaway hosts are excluded (see `EXCLUDE_FILES` in `tools/extract_pot.gd`):
the corridor testbed, the panel example, the combat sandbox — their text stays English.

## Regenerating the catalog

Godot's built-in POT generator can't read the GDScript `name_key` content, so the
project uses a headless extractor. **Run it after adding or changing any translatable
string:**

```bash
godot --headless --path . --script res://tools/extract_pot.gd
```

It writes `locale/messages.pot` and merges every `locale/*.po`, preserving existing
`msgstr` translations and dropping strings no longer present (no gettext / msgmerge
dependency). Then translate the empty `msgstr` entries in non-English `.po`s, and
**re-import** so the `.po` → `.translation` resources rebuild:

```bash
godot --headless --path . --import --exit
```
