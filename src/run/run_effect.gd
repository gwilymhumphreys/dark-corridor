class_name RunEffect
extends RefCounted
## A change to run state made outside fights: by a relic's run trigger (docs/systems/content.md →
## Relic) or an event option (docs/systems/encounter.md). The Run manager applies it
## (RunManager._apply_run_effect). Separate from ItemEffect because it changes the run, not a fight,
## so it has no mechanic, shape or target.

enum Kind {
  MAX_HP,
  HEAL,
  GOLD,
  HEAL_FRACTION,
  DAMAGE,
  ADD_ALLY,
  SET_FLAG,
  ADD_FLAG,
  GAIN_ITEM,
  GAIN_RELIC,
  GAIN_POTION,
}

var kind: Kind = Kind.MAX_HP
var amount: int = 0
var fraction: float = 0.0   # HEAL_FRACTION: the fraction of maximum health healed
var id: String = ''         # the flag name, or the ally, item, relic or potion id


## Raise the player's maximum and current health by `value`.
static func max_hp(value: int) -> RunEffect:
  return _make(Kind.MAX_HP, value)


## Heal the player by `value`, up to maximum health.
static func heal(value: int) -> RunEffect:
  return _make(Kind.HEAL, value)


## Add `value` gold. A negative value takes gold away.
static func gold(value: int) -> RunEffect:
  return _make(Kind.GOLD, value)


## Heal the player by `part` of maximum health, up to maximum health.
static func heal_fraction(part: float) -> RunEffect:
  var effect := _make(Kind.HEAL_FRACTION, 0)
  effect.fraction = part
  return effect


## Deal `value` damage to the player. In an event, lethal damage ends the run as a loss.
static func damage(value: int) -> RunEffect:
  return _make(Kind.DAMAGE, value)


## Add the ally built from the EnemyCatalog id `ally_id`, if an ally slot is free.
static func add_ally(ally_id: String) -> RunEffect:
  return _make(Kind.ADD_ALLY, 0, ally_id)


## Set the run flag `flag` to `value`.
static func set_flag(flag: String, value: int = 1) -> RunEffect:
  return _make(Kind.SET_FLAG, value, flag)


## Add `value` to the run flag `flag` (an unset flag is 0).
static func add_flag(flag: String, value: int = 1) -> RunEffect:
  return _make(Kind.ADD_FLAG, value, flag)


## Add the item `item_id` to the player's board.
static func gain_item(item_id: String) -> RunEffect:
  return _make(Kind.GAIN_ITEM, 0, item_id)


## Give the player the relic `relic_id`. Its PICKED_UP run triggers fire.
static func gain_relic(relic_id: String) -> RunEffect:
  return _make(Kind.GAIN_RELIC, 0, relic_id)


## Give the player the potion `potion_id`.
static func gain_potion(potion_id: String) -> RunEffect:
  return _make(Kind.GAIN_POTION, 0, potion_id)


static func _make(effect_kind: Kind, value: int, effect_id: String = '') -> RunEffect:
  var effect := RunEffect.new()
  effect.kind = effect_kind
  effect.amount = value
  effect.id = effect_id
  return effect
