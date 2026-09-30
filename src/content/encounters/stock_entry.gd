class_name StockEntry
extends RefCounted
## One line of what a reward encounter or a shop offers (docs/systems/encounter.md →
## Reward encounters): a kind of goods, how many, and for items optional filters (type tags, a
## mechanic, a rarity) that an item must all pass. The goods are drawn by Draft.draw_stock on the run
## RNG.

enum Kind { ITEM, RELIC, POTION }

var kind: Kind = Kind.ITEM
var count: int = 1
## ITEM only: keep items with at least one of these type tags (ItemType); empty keeps every item.
var types: Array[String] = []
## ITEM only: keep items whose `mechanics` list has this MechanicRegistry id; '' keeps every item.
var mechanic: String = ''
## ITEM only: keep items of this ItemDef.Rarity; -1 keeps every rarity.
var rarity: int = -1


## `amount` items from the character's pool and the colourless items, optionally only those with one
## of `item_types`.
static func items(amount: int, item_types: Array[String] = []) -> StockEntry:
  var entry := _make(Kind.ITEM, amount)
  entry.types = item_types
  return entry


## `amount` items from the character's pool and the colourless items that list `mechanic_id` in their
## `mechanics` (ItemDef.mechanics, the author's list).
static func items_with_mechanic(amount: int, mechanic_id: String) -> StockEntry:
  var entry := _make(Kind.ITEM, amount)
  entry.mechanic = mechanic_id
  return entry


## `amount` items from the character's pool and the colourless items of `item_rarity` (ItemDef.Rarity).
static func items_of_rarity(amount: int, item_rarity: int) -> StockEntry:
  var entry := _make(Kind.ITEM, amount)
  entry.rarity = item_rarity
  return entry


## `amount` different relics from the reward relics the player does not hold (RunManager.relic_pool).
static func relics(amount: int) -> StockEntry:
  return _make(Kind.RELIC, amount)


## `amount` different potions from ConsumableCatalog.REWARD_POOL.
static func potions(amount: int) -> StockEntry:
  return _make(Kind.POTION, amount)


static func _make(entry_kind: Kind, amount: int) -> StockEntry:
  var entry := StockEntry.new()
  entry.kind = entry_kind
  entry.count = amount
  return entry
