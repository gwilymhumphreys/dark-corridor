class_name ItemPoints
## Prices items in points (docs/design/item_heuristics.md). One point is one damage from a
## single-target attack; every other mechanic has an exchange rate into points, so an item with
## several effects is priced by adding up what each part costs. Static only, like `IconSlots`.
##
## `budget` is what an item on its cooldown is ALLOWED to spend; `spend` is what an authored item
## actually spends. Comparing the two is how a new item gets a starting number. The rates and the
## curve constants live in `Balance`.


## Points per second at this cooldown: a rising curve that flattens towards
## Balance.POINTS_RATE_CEILING and is steepest at Balance.POINTS_RATE_MIDPOINT seconds. Slow items
## earn a higher rate because they lose value to overkill, to firing fewer per-hit triggers, and to
## committing early; it flattens because those losses are bounded.
static func rate(cooldown: float) -> float:
  var t: float = Balance.POINTS_RATE_STEEPNESS * (cooldown - Balance.POINTS_RATE_MIDPOINT)
  return Balance.POINTS_RATE_CEILING / (1.0 + exp(-t))


## The points an item on this cooldown may spend.
static func budget(cooldown: float) -> float:
  return cooldown * rate(cooldown)


## The points an authored item actually spends per fire. Effects that are not MECHANIC deliveries
## add nothing: APPLY_STATUS covers the parked timed statuses, and SUMMON and CREATE_ITEM are on the
## unpriced list. Regen and crit are unpriced too, so they add nothing here.
static func spend(def: ItemDef) -> float:
  if def == null:
    return 0.0
  var total: float = 0.0
  for effect: ItemEffect in def.effects:
    if effect.kind != Delivery.Kind.MECHANIC:
      continue
    total += _effect_points(effect)
  # A crit chance raises the item's expected output, so it is worth more than its values read.
  return total * (1.0 + def.crit_chance * (Balance.CRIT_MULTIPLIER - 1.0))


static func _effect_points(effect: ItemEffect) -> float:
  match effect.mechanic:
    'attack':
      # An attack aimed at SELF is the holder paying health as a cost, which frees budget to spend
      # elsewhere, so it subtracts.
      if effect.shape == ItemEffect.Shape.SELF:
        return -Balance.POINTS_PER_SELF_DAMAGE * effect.value
      if effect.shape == ItemEffect.Shape.ALL_OPPONENTS:
        return Balance.POINTS_PER_AOE_DAMAGE * effect.value
      return Balance.POINTS_PER_DAMAGE * effect.value
    'heal':
      return Balance.POINTS_PER_HEAL * effect.value
    'shield':
      return Balance.POINTS_PER_SHIELD * effect.value
    'poison':
      return _triangular(effect.value) * Balance.POINTS_PER_POISON_DAMAGE
    'burn':
      return _triangular(effect.value) * Balance.POINTS_PER_BURN_DAMAGE
    'bleed':
      return _triangular(effect.value) * Balance.POINTS_PER_BLEED_DAMAGE
    'charge', 'decharge':
      return Balance.POINTS_PER_CHARGE_SECOND * effect.value
  return 0.0


## N stacks of a decaying damage status deal N + (N-1) + ... + 1 damage in total, because a tick
## deals its stacks and then loses one.
static func _triangular(stacks: float) -> float:
  return stacks * (stacks + 1.0) / 2.0
