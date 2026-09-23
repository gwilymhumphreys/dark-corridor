class_name ItemPoints
## Prices items in points (docs/design/item_heuristics.md). One point is one damage from a
## single-target attack; every other mechanic has an exchange rate into points, so an item with
## several effects is priced by adding up what each part costs. Static only, like `IconSlots`.
##
## `budget` is what an item on its cooldown is ALLOWED to spend; `spend` is what an authored item
## actually spends. Comparing the two is how a new item gets a starting number. The rates and the
## curve constants live in `Balance`.

# The mechanics `spend` has a rate for (docs/design/item_heuristics.md → Spending the budget).
const PRICED_MECHANICS: Array[String] = [
  'attack', 'heal', 'shield', 'poison', 'burn', 'bleed', 'charge', 'decharge',
]


## Points per second at this cooldown: a straight line through Balance.POINTS_RATE_AT_BASELINE at
## Balance.POINTS_RATE_BASELINE_COOLDOWN, rising by Balance.POINTS_RATE_PER_SECOND per second of
## cooldown. Slow items earn a higher rate because they lose value to overkill, to firing fewer
## per-hit triggers, and to committing early.
static func rate(cooldown: float) -> float:
  return Balance.POINTS_RATE_AT_BASELINE \
      + Balance.POINTS_RATE_PER_SECOND * (cooldown - Balance.POINTS_RATE_BASELINE_COOLDOWN)


## The points an item on this cooldown and of this rarity may spend. Uncommon and rare items get a
## larger budget (Balance.POINTS_UNCOMMON_MULTIPLIER, Balance.POINTS_RARE_MULTIPLIER).
static func budget(cooldown: float, rarity: int = ItemDef.Rarity.COMMON) -> float:
  return cooldown * rate(cooldown) * rarity_multiplier(rarity)


## How much larger than a common item's this rarity's budget is.
static func rarity_multiplier(rarity: int) -> float:
  match rarity:
    ItemDef.Rarity.UNCOMMON:
      return Balance.POINTS_UNCOMMON_MULTIPLIER
    ItemDef.Rarity.RARE:
      return Balance.POINTS_RARE_MULTIPLIER
  return 1.0


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
  total *= 1.0 + def.crit_chance * (Balance.CRIT_MULTIPLIER - 1.0)
  for sub: Dictionary in def.trigger_subs:
    total += trigger_points(def, sub)
  return total


## The points a trigger costs: the seconds of its item's bar it fills each time it goes off, times
## Balance.POINTS_TRIGGERS_PER_COOLDOWN, at the item's own budget per second (its rate with its
## rarity multiplier).
static func trigger_points(def: ItemDef, sub: Dictionary) -> float:
  return float(sub.get('seconds', 0.0)) * Balance.POINTS_TRIGGERS_PER_COOLDOWN * rate(def.cooldown) * rarity_multiplier(def.rarity)


## True when `spend` prices this effect. Anything else (a status, summon or created item, an
## unpriced mechanic such as regen or the attack bonuses, or a value read from a status the owner
## holds) adds nothing, so an item carrying it is worth more than its points say.
static func is_priced(effect: ItemEffect) -> bool:
  return effect.kind == Delivery.Kind.MECHANIC and PRICED_MECHANICS.has(effect.mechanic)       and effect.per_owner_stack_id == ''


## An effect aimed at every opponent costs Balance.POINTS_ALL_OPPONENTS_MULTIPLIER times the same
## effect on one target, whatever its mechanic.
static func _effect_points(effect: ItemEffect) -> float:
  var points: float = _single_target_points(effect)
  if effect.shape == ItemEffect.Shape.ALL_OPPONENTS:
    points *= Balance.POINTS_ALL_OPPONENTS_MULTIPLIER
  return points


static func _single_target_points(effect: ItemEffect) -> float:
  match effect.mechanic:
    'attack':
      # An attack aimed at SELF is the holder paying health as a cost, which frees budget to spend
      # elsewhere, so it subtracts.
      if effect.shape == ItemEffect.Shape.SELF:
        return -Balance.POINTS_PER_SELF_DAMAGE * effect.value
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
