# Plan: item levels and merging

**Status:** stage 1 built (2026-09-30); stages 2 and 3 planned. Decision #61. The as-built description is in [item.md → Levels](../systems/item.md#levels) and [run_manager.md → Merging items](../systems/run_manager.md#merging-items).

## What the owner decided (2026-09-30)

- **Levels:** every item has a level, starting at 1. There are four levels (`Balance.ITEM_MAX_LEVEL`).
- **Merging:** two copies of the same item at the same level merge into one item of the next level. Merging is the player's choice: they select an item on the board, then press Merge.
- **Value:** the merged item's values are the two copies' values added together, times 1.2 (`Balance.ITEM_LEVEL_MERGE_MULT`). Merging therefore always gives more than keeping both copies.
- **Enchantments:** if both copies hold an enchantment, the selected item's is kept. If only one does, that one is kept, whichever it is.
- **Shops:** later shops offer higher-level items (stage 2).
- **Enchantments are not number increases.** They add different or unusual effects to an item. Number increases are levels. `game_design.md` is corrected to say this.

## Stage 1: levels and merging

### Value scale

A level multiplies an item's values by `level_scale(level) = (2 * ITEM_LEVEL_MERGE_MULT) ^ (level - 1)`. This is the merge rule applied once per level: level 2 is two level 1 copies times the multiplier, and so on.

**Item:**

- `var level: int = 1`.
- `static func level_scale(level: int) -> float` as above.
- `_scaled_value` multiplies `base` by `level_scale(level)` after the per-stack part is added and before the bonuses are combined, so enchantment and status percentages apply to the levelled value.
- `_resolve_effect` multiplies the payload's `consume_scale` and `consume_item_scale` by the same scale before they are used. That covers self-fuel, which resolves there, and the opponent-fuel and item consumes, which `CombatManager._fire_item` resolves from the payload, with no Combat manager change.
- Not scaled: cooldown, status duration, the number of stacks consumed (`consume_amount`), how many items are consumed, and effects with no value (summons, created items). The effect value of an applied status is its stack count, so it is scaled.
- `display_value` and `base_value` go through `_scaled_value`, so value pills and tooltips show the levelled numbers with no other change.

Values stay fractional until they land and are rounded then (decision #49). A value of 1 at level 2 is 2.4 and lands as 2.

### Merging

**RunManager** (a new "merging items" section beside selling):

- `merge_partner(item: Item) -> Item`: another item on `player.board` with the same `def` and `level`, or null. When there are several, it prefers one with no enchantment, so no enchantment is lost when one can be kept.
- `can_merge(item: Item) -> bool`: the same conditions as `can_sell` (the run has not ended, the item is on the board, no fight is under way), `item.level < Balance.ITEM_MAX_LEVEL`, and `merge_partner(item)` is not null. Relics and potions are not on the board, so they never merge.
- `merge_item(item: Item) -> bool`: raises `item.level` by one; if `item` has no enchantment and the partner has one, moves the partner's enchantment to `item`; erases the partner from the board and calls `partner.dissolve()`, as `sell_item` does. The selected item keeps its place on the board. Returns false and changes nothing when `can_merge` is false. Merging costs nothing and draws no run RNG.
- `will_lose_enchantment(item: Item) -> bool`: both `item` and its partner hold an enchantment. The Merge button uses it to warn.

**Prices:** `price_of` stays per definition. A new `item_price(item: Item) -> int` = `price_of(item.def) * 2 ^ (item.level - 1)`, the price of the level 1 copies it was made from, and `sell_price` uses it. Selling a level 2 item gives the same gold as selling the two copies.

### Saving

The board entry in `snapshot()` gains `'level'`, and `rehydrate` sets `item.level` from it.

### Interface

- **Merge button:** the run screen's selected-item button becomes a small row below the item (`ItemActions`, replacing `SellButton`): the Sell button and a Merge button. Merge is shown only when `can_merge` is true, the same rule as hidden event options (decision #55). Text `tr('Merge')`, or `tr('Merge (loses an enchantment)')` when `will_lose_enchantment`. The row is a scene with a `Juice` node on each button. Selecting an item already requires `can_sell`; that stays, since `can_merge` holds only where `can_sell` does.
- **Level tag:** a small tag with the level number in a corner of the item cell, drawn over the cell so it takes no layout space. Nothing is shown at level 1. The look is the owner's choice; this is a placeholder, with its corner and size on the F7 tab (`level_tag_corner`, `level_tag_size`), saved in presets. The cell rebuilds its value pills and tag when the item's level changes.
- **Tooltip:** the name reads "{name}, level {N}" above level 1 (`tr('{0}, level {1}')`).
- Rarity keeps the bronze, silver and gold borders. The level marker must not use the border.

### Autotest

The draft strategies never merge, so existing baselines do not change. A merge option for a strategy can come later if tuning needs it.

### Localization

New strings: `Merge`, `Merge (loses an enchantment)`, `{0}, level {1}`. Regenerate the POT.

### Tests (fixture content only)

- `level_scale` gives 1 at level 1 and `2 * ITEM_LEVEL_MERGE_MULT` at level 2; a level 2 item's `display_value` is the scaled authored value.
- A levelled item's payload value, with and without an enchantment and a status bonus, and the self-fuel consume part.
- `can_merge`: false with no copy, with a copy at another level, at the maximum level, and during a fight; true between fights with a same-level copy.
- `merge_item`: one item left at the next level in the selected item's place, the partner dissolved; each enchantment case (both, only the selected, only the partner, neither); the partner choice prefers an unenchanted copy.
- `sell_price` of a level 2 item equals two level 1 sell prices.
- Snapshot and rehydrate keep the level.

### Docs to update in the same change

- `systems/item.md`: the level field, the value scale and where it applies in the fire pipeline; duplicate stacking now mentions merging.
- `systems/run_manager.md`: a "Merging items" section beside "Selling items"; the sell price by level.
- `systems/run_screen.md`: the Merge button next to Sell.
- `systems/tooltips.md`: the level line.
- `systems/save.md`: the level in the board entry.
- `design/lexicon.md`: Level and Merge are already added.
- `systems/print_frame.md`, `systems/interface_look.md`, `systems/ui_layout.md`: the level tag settings, its material and the merge intent.

## Stage 2: higher-level items in offers

Owner (2026-09-30): shops, fight drafts and reward encounters can all offer items above level 1, and the chance of a higher level rises over the run.

Offers are definitions today (`Draft.draw_stock`, the draft candidates). An offered item needs a level as well, so each offer keeps a level beside each item good, the entry that shows it sets it on the display item, and `_gain` sets it on the item it adds. The level is drawn from odds that depend on the fight number, a table in `Balance` whose values are the owner's. A shop price is `item_price` of the levelled item.

## Stage 3: levelled enemy items

Owner (2026-09-30): enemy items can be levelled. An enemy definition can give a level for each of its items, and `EnemyDef` sets it when it builds the actor's board. Which enemies use it is content.

## Open questions for the owner

- **The level odds by fight number** (stage 2).
- **The Whetstone** (`content/enchants/whetstone.gd`) is the only enchantment and it is a straight ×1.5 on the item's values, which decision #61 says enchantments are not. It is content, so it is left as it is for the owner to change.
- **Effect-adding enchantments need engineering.** `EnchantDef` holds only `value_mult`. An enchantment that adds a new effect or trigger to its item (for example "when this item deals damage, apply poison") needs its own plan.
