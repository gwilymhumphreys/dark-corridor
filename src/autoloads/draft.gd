class_name DraftAutoload
extends Node
## The reward-draw service (draft_prd) — autoload registered `Draft`. Stateless: it
## answers "given the pool and where the run is, what are the candidates?" and
## nothing else. The Run manager calls draw() with the pool + depth + the run RNG,
## holds the returned offer, and applies the pick to run-state (Draft writes
## nothing). The draw is seeded from the handed RNG, so a given run-state yields
## the same offer — not re-rollable by quit-and-resume (no save-scum).
##
## Phase 3 scope: 3 item candidates, distinct within an offer. Slot composition
## (the low chance of an enchant / potion instead) and rarity-by-depth weighting
## are tuning — `depth` is plumbed but not yet weighted (the prototype pool is flat
## common). The draw is Draftable-generic; subtype only matters at application.

const DEFAULT_COUNT: int = 3


## Return `count` candidate item defs drawn from `pool`, seeded from `rng` (which it
## advances — the consumed state is what the snapshot persists for deterministic
## resume). Distinct within the offer while the pool has the breadth; refills to
## allow repeats only if the pool is smaller than `count`.
func draw(pool: Array, depth: int, rng: RandomNumberGenerator, count: int = DEFAULT_COUNT) -> Array:
  var _depth: int = depth   # reserved for rarity-by-depth weighting (tuning) — inert in Phase 3
  var offer: Array = []
  var bag: Array = pool.duplicate()
  for i in count:
    if bag.is_empty():
      bag = pool.duplicate()
    var idx: int = rng.randi_range(0, bag.size() - 1)
    offer.append(ItemCatalog.get_def(bag[idx]))
    bag.remove_at(idx)
  return offer
