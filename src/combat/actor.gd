class_name Actor
extends RefCounted
## The symmetric combatant (docs/systems/actor.md): HP + an ordered board of items + an
## actor-targeted status list. Deliberately dumb — a passive holder others act
## on. It never knows which side it's on; ordering / targeting / win-loss are the
## Combat manager's. `take_damage` is its one sideways call (to StatusManager, to
## resolve block and future damage-modifier statuses).

signal died

var hp: float
var max_hp: float
var board: Array[Item] = []              # ordered, not a grid
var statuses: Array[StatusEffect] = []   # actor-targeted instances
var display_name: String = ''  # presentation label (the def's name_key, tr()'d by the view); combat ignores it


func _init(starting_max_hp: float = Balance.PLAYER_START_HP) -> void:
  max_hp = starting_max_hp
  hp = starting_max_hp


func is_alive() -> bool:
  return hp > 0.0


## Run the raw amount through the target's incoming-damage modifiers (block, and
## later amplifiers), then apply the remainder to HP. Dead actors ignore damage
## (so `died` fires once). Returns the ACTUAL HP lost — post-block, capped at the
## remaining HP (a killing blow returns effective, not inflated raw, damage) — so
## the CombatLog records honest numbers with no HP-diff machinery (docs/systems/
## combat_log.md). Statement-callers may ignore the return.
func take_damage(amount: float, flags: int = 0) -> float:
  if not is_alive():
    return 0.0
  var net: float = StatusManager.resolve_incoming_damage(self, amount, flags)
  var hp_before: float = hp
  hp = maxf(hp - net, 0.0)
  if hp <= 0.0:
    died.emit()
  return hp_before - hp


## A dead actor stays dead — heal cannot revive (death is final this fight).
## Currently unreachable via Deliveries (a HEAL to a dead target fizzles in the
## Combat manager) but guarded here so no future caller can resurrect a corpse.
## Returns the ACTUAL HP restored (post-overheal-cap) — see take_damage.
func heal(amount: float) -> float:
  if not is_alive():
    return 0.0
  var hp_before: float = hp
  hp = minf(hp + amount, max_hp)
  return hp - hp_before


## Break the Actor<->Item reference cycle (the board holds each item; every item's
## `owner` points back here) so a DISCARDED actor + its board can free — RefCounted
## has no cycle collection. Only call when the actor is being thrown away: an enemy
## at fight end (CombatManager.teardown), the player at run end (RunManager.teardown).
## Never mid-run — it clears the board.
func dissolve() -> void:
  for it in board:
    it.dissolve()   # the single-item cycle break (Item.dissolve)
  board.clear()
  statuses.clear()
