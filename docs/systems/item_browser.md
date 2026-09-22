# Item browser

A dev tool that writes one web page listing every item in `ItemCatalog`, for browsing a character's items while authoring content. The page can be filtered and sorted.

**Location:** `tools/item_browser.sh` (wrapper), `tools/item_browser.gd` + `tools/item_browser.tscn` (export), `tools/item_browser.html` (page template)

## Running it

```
tools/item_browser.sh
```

This writes `_temp/item_browser.html`, which opens in any browser. The page is one self-contained file: the item data and the icons are embedded in it, and only the fonts come from the internet. Run the tool again after changing items to refresh the page. The `/items` skill (`.claude/skills/items/`) runs it and opens the page, and updates the private online copy when asked.

The export runs as a scene, not with `--script`, because the tooltip code it reuses refers to autoloads, and autoloads do not exist when a script runs on its own.

## What the export reads

| Source | Used for |
|--------|----------|
| `ItemCatalog.all_ids()` | Every item, including items in no pool |
| `TooltipContent.build()` | The name, type line, charge line, effect lines, flavour line and keyword list, as the in-game tooltip shows them |
| `KeywordCatalog.get_entry()`, `IconSlots.icon_for()` | Keyword names, descriptions, icons and colours. Icons under `assets/icons/mechanics/` are white shapes tinted with the keyword colour, the same rule as `KeywordIcon` |
| `CharacterCatalog.ids()` + each `item_pool`, `ColorlessPool.ITEMS` | Which characters can draft the item |
| `EnemyCatalog.all_ids()` + each `item_ids` | Which enemies carry the item |
| `Colours.RARITY_*` | The rarity colour of the name and icon border |

Icons are shrunk to `ICON_SIZE` in `item_browser.gd` before embedding to keep the page small.

## The page

- Character buttons at the top pick one character's pool. Three more buttons show all items, items in no pool, and items on enemy boards. The starting selection is `CharacterCatalog.DEFAULT`.
- Type, rarity and keyword chips filter the list. Within one row, an item matches if it has any of the selected values. The keyword row lists only keywords on the selected character's items. Clicking a keyword on a card toggles that keyword's filter.
- The search box matches item names, ids, and the text of effect lines, flavour lines and keywords.
- Items sort by name, rarity, charge time or first type, and can be grouped by first type or rarity.
- Each card's footer shows the item id, other characters whose pool has the item, enemies that carry it, and `starting_uses` when it is set. A card for an item in no pool has a dashed border.
- The selected character, filters, sort and grouping are kept in the browser's local storage.

The page is dev tooling and stays English.

## Changing the page

Layout, styling and filters live in `tools/item_browser.html`. The export replaces the `/*ITEM_DATA*/null` marker in its script with the data as JSON, so the template must keep that marker. A new field shown on the page is added to the item dictionary in `_build_data()` in `item_browser.gd`.
