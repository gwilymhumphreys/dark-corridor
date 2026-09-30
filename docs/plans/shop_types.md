# Plan: shop types

**Status:** built (2026-09-30). Owner's request and answers are below.

## What the owner decided (2026-09-30)

- A shop sells only items unless its definition says otherwise.
- **Normal shop:** any item from the character's pool.
- **One shop per mechanic:** only items that list that mechanic in `ItemDef.mechanics` (the author's list, so an item that charges off poison counts as a poison item). Every mechanic gets one: the ten of decision #60, not the attack bonus effects.
- **Rare shop:** only rare items.
- A shop is not offered when fewer than six items in the character's pool (plus the colourless items) pass its filters ("more than five"). With today's pools, Smith gets only the normal shop, the Fleshmancer and the Spore Druid also get the attack shop, and nobody gets the rare shop: Smith's pool has two rare items (Deep Forge, Wide Forge), fewer than six.
- Every shop puts four items on sale.
- Every shop that can be offered has the same chance to be the left card.

## Changes

**StockEntry:** two more item filters beside `types`: `mechanic: String` (keep items whose `mechanics` list has it) and `rarity: int` (-1 keeps every rarity). Builders `StockEntry.items_with_mechanic(amount, mechanic_id)` and `StockEntry.items_of_rarity(amount, rarity)`. The filters combine: an item must pass all that are set.

**Draft:** `matching_items(entry, item_pool)` (public, replacing the private `_matching_items`) applies all three filters; `draw_stock` and `can_draw_stock` use it.

**The cut-off:** `EncounterDef.min_items: int`, defaulting to `Balance.SHOP_MIN_ITEMS` (6). `EncounterDef.offer_weight` returns 0 for a shop when any of its item entries has fewer than `min_items` matching items (`RunManager.has_items_for(stock, minimum)`, which counts through `Draft.matching_items`). Reward encounters are not affected. The test shop sets its own `min_items`, since the test character's pool has three items.

**Content** (placeholder names, flagged for the owner):

- `shop_pedlar` becomes the normal shop: `[StockEntry.items(Balance.SHOP_ITEM_COUNT)]`.
- `shop_rare`: `[StockEntry.items_of_rarity(Balance.SHOP_ITEM_COUNT, ItemDef.Rarity.RARE)]`.
- `shop_<mechanic>` for each of the twelve mechanics, such as `shop_poison`: `[StockEntry.items_with_mechanic(Balance.SHOP_ITEM_COUNT, PoisonMechanic.ID)]`.
- `EncounterPools.LEFT` lists all fourteen.

**Balance:** `SHOP_ITEM_COUNT: int = 4` and `SHOP_MIN_ITEMS: int = 6`, both the owner's.

## Tests

- `tests/run/test_draft.gd`: the mechanic and rarity filters, alone and with type tags.
- `tests/run/test_run_manager.gd`: a shop with too few matching items gets offer weight 0; one with enough does not.
- `tests/content/test_pool_integrity.gd`: every id in `EncounterPools.LEFT` is a shop.

## Docs

`docs/systems/encounter.md` (Shops: the filters, the cut-off, the shop types), `docs/design/authoring.md` (writing a shop), `docs/design/lexicon.md` if a term is needed, `docs/decision_log.md` #59.
