class_name Actor
extends RefCounted
## The symmetric combatant (actor_prd): HP + an ordered board of items + an
## actor-targeted status list. Deliberately dumb — a passive holder others act
## on. It never knows which side it's on; ordering / targeting / win-loss are the
## Combat manager's. `take_damage` is its one sideways call (to StatusManager, to
## resolve block and future damage-modifier statuses).

signal died

var hp: float
var max_hp: float
var board: Array = []        # Item instances (Step 3); ordered, not a grid
var statuses: Array = []     # actor-targeted Status instances


func _init(starting_max_hp: float = Balance.PLAYER_START_HP) -> void:
  max_hp = starting_max_hp
  hp = starting_max_hp


func is_alive() -> bool:
  return hp > 0.0


## Run the raw amount through the target's incoming-damage modifiers (block, and
## later amplifiers), then apply the remainder to HP. Dead actors ignore damage
## (so `died` fires once).
func take_damage(amount: float, flags: int = 0) -> void:
  if not is_alive():
    return
  var net: float = StatusManager.resolve_incoming_damage(self, amount, flags)
  hp = maxf(hp - net, 0.0)
  if hp <= 0.0:
    died.emit()


## A dead actor stays dead — heal cannot revive (death is final this fight).
## Currently unreachable via Deliveries (a HEAL to a dead target fizzles in the
## Combat manager) but guarded here so no future caller can resurrect a corpse.
func heal(amount: float) -> void:
  if not is_alive():
    return
  hp = minf(hp + amount, max_hp)
