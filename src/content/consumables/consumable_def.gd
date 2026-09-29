class_name ConsumableDef
extends ItemDef
## A consumable (potion) definition (docs/systems/content.md, decision #23) — an item definition that
## is thrown by hand instead of firing on a timer (docs/plans/potions_as_items.md). Held in a potion
## slot, consumed on use. It uses the item fields it needs (id, name, icon, rarity, effects) and is
## shown like an item, through an Item built from it, with the same cell and tooltip. On throw the
## Combat manager builds its effects into Deliveries — the same resolution surface as an item fire,
## minus the cooldown and the item-side value stages (decision #30). Its `cooldown` and
## `trigger_subs` are unused.
