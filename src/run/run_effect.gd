class_name RunEffect
extends RefCounted
## A change to run state that a relic's run trigger makes outside fights (docs/systems/content.md →
## Relic). The Run manager applies it (RunManager._apply_run_effect). Separate from ItemEffect
## because it changes the run, not a fight, so it has no mechanic, shape or target.

enum Kind { MAX_HP, HEAL, GOLD }

var kind: Kind = Kind.MAX_HP
var amount: int = 0


## Raise the player's maximum and current health by `value`.
static func max_hp(value: int) -> RunEffect:
  return _make(Kind.MAX_HP, value)


## Heal the player by `value`, up to maximum health.
static func heal(value: int) -> RunEffect:
  return _make(Kind.HEAL, value)


## Add `value` gold.
static func gold(value: int) -> RunEffect:
  return _make(Kind.GOLD, value)


static func _make(effect_kind: Kind, value: int) -> RunEffect:
  var effect := RunEffect.new()
  effect.kind = effect_kind
  effect.amount = value
  return effect
