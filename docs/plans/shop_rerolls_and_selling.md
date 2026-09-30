# Plan: shop rerolls, selling items, real shop prices

**Status:** built (2026-09-30). Owner's answers are below.

## What the owner decided (2026-09-30)

- **Prices:** the current `Balance.SHOP_PRICE_ITEM`, `SHOP_PRICE_RELIC` and `SHOP_PRICE_POTION` values are the real prices, no longer placeholders.
- **Rerolls:** a shop can reroll its goods for gold. The first reroll in a visit costs 1 gold and each later one costs 1 more.
- **Selling:** the player can sell an item from the board for half its shop price, rounded down. Selling works at any time outside fights, not only in shops. Only items are sold; relics and potions are not.
- **Rerolls replace every good**, bought ones included.
- **The last item can be sold**, leaving an empty board.
- **Selling interface:** select an item, then act on it, because that also works with a controller and on the Steam Deck. Built for now as a click that selects and a Sell button beside the item; the rest of that interface is deferred. The owner's other idea, dragging an item to the lower right section, is not built; it could come later as a mouse shortcut.

This changes the design doc: `docs/design/game_design.md` ("Structural note — what no size limit costs") says the game has no card removal or selling. That section is the owner's to rewrite.

## Rerolls

**RunManager** (the shop section):

- `_shop_open: bool` becomes the test for `has_open_shop()`, set when the shop's goods are drawn and cleared by `_close_shop()`. Today `has_open_shop()` is `not _shop_goods.is_empty()`, so a reroll that draws nothing (a relic-only shop with the relic pool empty) would close the shop while the run screen waits in `SHOPPING`.
- `_shop_rerolls: int`, reset when the shop opens and closes.
- `reroll_price() -> int` = `Balance.SHOP_REROLL_PRICE + Balance.SHOP_REROLL_PRICE_STEP * _shop_rerolls`.
- `can_reroll() -> bool`: a shop is open and `gold >= reroll_price()`.
- `reroll_shop() -> bool`: pays, then redraws every good with `Draft.draw_stock(def.stock, _draft_pool(), relic_pool(), rng)` and clears `_shop_sold`, so bought goods are replaced too. A relic bought earlier is no longer in the relic pool, so it is not offered again. Returns false and changes nothing when `can_reroll()` is false.
- The shop is still not saved. A resume re-enters it with the gold it had when picked, and the run RNG from that save draws the first goods again, so rerolls and purchases in the visit are undone together.

**Balance:** `SHOP_REROLL_PRICE: int = 1`, `SHOP_REROLL_PRICE_STEP: int = 1`, with a comment naming the owner's decision.

**ShopOverlay:** a Reroll button beside Leave (`ButtonBare` or the Leave button's variation, with a `Juice` node), text `tr('Reroll ({0} gold)')`, disabled when `can_reroll()` is false. It emits `rerolled`. `setup` splits into building the entries (`_show_goods(run)`, which frees the old entries first) and `refresh(run)`, which also updates the Reroll button's price and state.

**RunScreen:** `_on_shop_rerolled()` calls `_run.reroll_shop()`, then rebuilds the panel's goods and refreshes the gold box.

**Autotest:** unchanged. It leaves every shop at once, so it never rerolls.

## Selling

**RunManager:**

- `sell_price(item: Item) -> int` (static) = `floori(price_of(item.def) * Balance.SELL_SHARE)`, with `SELL_SHARE: float = 0.5` in `Balance`. An enchant does not change the price.
- `can_sell(item: Item) -> bool`: the run has not ended, the item is on `player.board`, and no fight is under way: `combat_manager()` is null or `is_resolved()`. This allows the choice of encounters, events, rests, a fight's draft, reward encounters and shops, and refuses the approach and the fight itself.
- `sell_item(item: Item) -> bool`: adds `sell_price(item)` to gold, erases the item from `player.board` and calls `item.dissolve()` (as `CombatManager.remove_item` does). Returns false and changes nothing when `can_sell` is false. It fires no run event; a relic that reacts to a sale would need a new `RunEvent` kind, which content can add later.
- A sale is kept by the next save (picking a card or advancing); quitting before then undoes it, the same as a shop purchase.

The combat view already removes a cell whose item has left the board (`CombatViewFramed._sync_player_items`), so selling needs no view refresh except the gold box.

**Which board item is under the pointer:** `CombatViewFramed.board_item_at(point) -> Item` returns the player's board item whose cell contains `point`, or null. `inspectable_at` has the same loop and calls it.

**Input (RunScreen):** the run screen reads mouse clicks in its `_gui_input`. Its root is a full-screen Control that stops the mouse, so a click on the board reaches it (the board cells ignore the mouse) while clicks on panels and buttons do not; `_unhandled_input` never sees these clicks.

- A left click on a board item that `can_sell` selects it: `ItemCell.set_marked(true)` on its cell, and a Sell button appears below the cell.
- Clicking another item selects that one. Clicking anywhere else, pressing Escape, the item leaving the board, or `can_sell` becoming false (a fight's approach starting) clears the selection.

**SellButton** (`src/scenes/screens/sell_button.gd/.tscn`, new): a button with text `tr('Sell for {0} gold')`, placed below the selected cell on the HUD layer and kept inside the screen. Pressing it emits `sell_requested(item)`. It has a `Juice` node.

**RunScreen** connects it to `_on_sell_requested(item)`: `_run.sell_item(item)`, clear the selection, `_refresh_gold()`, and `_shop.refresh(_run)` when a shop is open (the gold changed what the player can afford).

**Tooltips:** hovering still shows the item tooltip. A selected item's tooltip is not pinned.

**Autotest:** does not sell.

## Localization

New strings: `Reroll ({0} gold)`, `Sell for {0} gold`. Regenerate the POT with `tools/pot.sh`.

## Docs to update in the same change

- `docs/systems/encounter.md` → Shops: rerolls; remove "no rerolls and no selling"; prices are no longer placeholders.
- `docs/systems/run_manager.md`: selling and the shop reroll API.
- `docs/systems/run_screen.md`: the Reroll button, the selected item and the Sell button.
- `docs/systems/ui_layout.md`: the sell-item and reroll intents in the list of intents.
- `docs/design/lexicon.md`: **reroll** and **sell**.
- `docs/decision_log.md`: decision #58, rerolls and selling.

## Tests

- `tests/run/test_run_manager.gd`: reroll price rises by the step; a reroll replaces sold goods and charges; `can_reroll` false when too poor; a shop whose reroll draws nothing stays open; `sell_price` is half the price rounded down; `sell_item` pays, removes and dissolves; `can_sell` false during an unresolved fight and for an item not on the board.
- `tests/ui/test_shop_overlay.gd`: the Reroll button shows the price, is disabled when the player cannot pay, and emits `rerolled`.
- `tests/ui/test_run_screen.gd`: in a shop, rerolling rebuilds the goods; outside a fight, clicking a board item selects it and its Sell button sells it; during a fight a click selects nothing.
