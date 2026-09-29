class_name DraftAutoload
extends Node
## The reward-draw service (docs/systems/draft.md) — autoload registered `Draft`. Stateless: it
## answers "given the pool and where the run is, what are the candidates?" and
## nothing else. The Run manager calls draw() with the pool + depth + the run RNG,
## holds the returned offer, and applies the pick to run-state (Draft writes
## nothing). The draw is seeded from the handed RNG, so a given run-state yields
## the same offer — not re-rollable by quit-and-resume (no save-scum).
##
## Fight drafts (`draw`): 3 item candidates, distinct within an offer. Reward encounters (`draw_stock`)
## draw a mix of items, relics and potions from their stock entries. Slot composition
## (the low chance of an enchant / potion instead) and rarity-by-depth weighting
## are tuning — `depth` is plumbed but not yet weighted (the prototype pool is flat
## common). The draw is Draftable-generic; subtype only matters at application.

const DEFAULT_COUNT: int = 3


## Return `count` candidate item defs drawn from `pool`, seeded from `rng` (which it
## advances — the consumed state is what the snapshot persists for deterministic
## resume). Distinct within the offer while the pool has the breadth; refills to
## allow repeats only if the pool is smaller than `count`.
func draw(pool: Array, _depth: int, rng: RandomNumberGenerator, count: int = DEFAULT_COUNT) -> Array[ItemDef]:
  # `_depth` is reserved for rarity-by-depth weighting (tuning) — inert in Phase 3.
  var offer: Array[ItemDef] = []
  var bag: Array = pool.duplicate()
  for i in count:
    if bag.is_empty():
      bag = pool.duplicate()
    var idx: int = rng.randi_range(0, bag.size() - 1)
    offer.append(ItemCatalog.get_def(bag[idx]))
    bag.remove_at(idx)
  return offer


## Draw the goods a reward encounter offers (docs/systems/encounter.md → Reward encounters): each
## StockEntry in order, on `rng`. Returns a mix of ItemDef, RelicDef and ConsumableDef. Items come
## from `item_pool` (the character's pool plus the colourless items), kept to the entry's type tags
## if it has any, and may repeat only when too few items match (as in `draw`). Relics come from
## `relic_pool` (RunManager.relic_pool, the reward relics not held) and potions from their reward
## pool; neither repeats within an entry, so an entry gives fewer when its pool is small. An entry
## whose pool is empty gives nothing.
func draw_stock(entries: Array[StockEntry], item_pool: Array, relic_pool: Array, rng: RandomNumberGenerator) -> Array:
  var goods: Array = []
  for entry: StockEntry in entries:
    match entry.kind:
      StockEntry.Kind.ITEM:
        var matching: Array = _matching_items(item_pool, entry.types)
        if not matching.is_empty():
          goods.append_array(draw(matching, 0, rng, entry.count))
      StockEntry.Kind.RELIC:
        for id: String in _draw_distinct(relic_pool, entry.count, rng):
          goods.append(RelicCatalog.get_def(id))
      StockEntry.Kind.POTION:
        for id: String in _draw_distinct(ConsumableCatalog.REWARD_POOL, entry.count, rng):
          goods.append(ConsumableCatalog.get_def(id))
  return goods


## Whether draw_stock would give at least one good from `entries` with these pools. Draws nothing.
func can_draw_stock(entries: Array[StockEntry], item_pool: Array, relic_pool: Array) -> bool:
  for entry: StockEntry in entries:
    if entry.count <= 0:
      continue
    match entry.kind:
      StockEntry.Kind.ITEM:
        if not _matching_items(item_pool, entry.types).is_empty():
          return true
      StockEntry.Kind.RELIC:
        if not relic_pool.is_empty():
          return true
      StockEntry.Kind.POTION:
        if not ConsumableCatalog.REWARD_POOL.is_empty():
          return true
  return false


# The ids in `item_pool` with one of `types` (all of them when `types` is empty).
func _matching_items(item_pool: Array, types: Array[String]) -> Array:
  return item_pool.filter(func(id: String) -> bool: return _has_any_type(id, types))


# Up to `count` different ids from `pool`, drawn on `rng`.
func _draw_distinct(pool: Array, count: int, rng: RandomNumberGenerator) -> Array[String]:
  var bag: Array = pool.duplicate()
  var picked: Array[String] = []
  while not bag.is_empty() and picked.size() < count:
    picked.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
  return picked


# Whether the item `id` has one of `types`; true when `types` is empty.
func _has_any_type(id: String, types: Array[String]) -> bool:
  if types.is_empty():
    return true
  var item_types: Array[String] = ItemCatalog.get_def(id).types
  return types.any(func(type: String) -> bool: return type in item_types)
