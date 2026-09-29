# Plan: potions as items

**Status: built 2026-09-30.** As-built detail is in
[`../systems/content.md`](../systems/content.md#consumable-potions) and
[`../systems/tooltips.md`](../systems/tooltips.md).

A potion becomes a kind of item definition, as relics did ([`relics_as_items.md`](relics_as_items.md)),
so it is shown the same way as an item: the same cell with value pills, the same hover highlight and
the same tooltip, in the potion row, the reward panel and the shop (owner, 2026-09-30: "same as
items — anything we can do to make them more similar to items will help, like with relics").

## Current state

- `ConsumableDef` (`src/content/consumables/consumable_def.gd`) is its own `RefCounted` with `id`,
  `name_key`, `icon`, `rarity` (its own `Rarity` enum with the same values as `ItemDef.Rarity`) and
  `effects: Array[ItemEffect]`, the same fields `ItemDef` has.
- The potion row (`PotionSlot`) and the reward option (`RewardOption.setup_potion`) show only the
  picture (`ItemCell.show_picture`), with no `Item`, so there are no value pills and no tooltip.
- A throw reads `consumable.def.effects` (`CombatManager.throw_consumable`); potions skip the item-side
  value stages (decision #30).

## Changes

1. `ConsumableDef extends ItemDef` and drops the fields it now inherits, and its own `Rarity` enum.
   Nothing reads `ConsumableDef.Rarity`. Throwing, saving (by id) and the catalog are unchanged.
2. Checks that tell goods apart test `ConsumableDef` before `ItemDef`, because a potion is now also
   an `ItemDef`: `RunManager._gain` (`price_of` already does).
3. `PotionSlot`, `RewardOption`, `DraftOverlay` and `ShopEntry` show a potion through
   `ItemCell.setup(Item.new(def))`, like an item or relic, with the cooldown fill off.
   `RewardOption.setup_potion` goes.
4. `CombatViewFramed.inspectable_at` also looks through the potion slots, so a potion in the row has
   a tooltip.
5. `TooltipContent`: a potion's type line reads "Potion" and it has no charge-time line (like a
   relic). Its effect lines are an item's effect lines.

## Not changed

- Potions still skip enchant scaling, status bonuses and evasion when thrown (decision #30).
- A potion's `cooldown` and `trigger_subs` are unused, as a relic's `cooldown` is.

## Tests

Fixture potion: a potion is an `ItemDef`; the reward panel and the potion row give its tooltip; the
tooltip's type line reads "Potion" with no charge line; a picked or bought potion goes to the potions,
not the board.
