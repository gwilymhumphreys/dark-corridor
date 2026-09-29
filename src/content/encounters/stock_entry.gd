class_name StockEntry
extends RefCounted
## One line of what a reward encounter or a shop offers (docs/systems/encounter.md →
## Reward encounters): a kind of goods, how many, and for items an optional list of type tags. The
## goods are drawn by Draft.draw_stock on the run RNG.

enum Kind { ITEM, RELIC, POTION }

var kind: Kind = Kind.ITEM
var count: int = 1
## ITEM only: keep items with at least one of these type tags (ItemType); empty keeps every item.
var types: Array[String] = []


## `amount` items from the character's pool and the colourless items, optionally only those with one
## of `item_types`.
static func items(amount: int, item_types: Array[String] = []) -> StockEntry:
  var entry := _make(Kind.ITEM, amount)
  entry.types = item_types
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
