class_name Encounter
extends Node
## The per-beat orchestrator (encounter_prd) — one resolved beat, instanced by the
## Run manager. A FIGHT spawns enemy Actors from their definitions (left-to-right)
## and, on begin(), creates the per-fight CombatManager; a REST applies a partial
## heal. It reports its outcome + reward-kind up via `resolved`; the Run manager
## fulfils the reward and applies HP/relic policy.
##
## Phase 3 driving model: the Encounter (and its CombatManager) are NOT mounted in
## the scene tree — the clock is supplied externally (the autotest steps sim_step;
## the Phase-4 run screen will drive _physics_process). So begin() readies the
## fight but does not run it; the caller steps combat_manager() to a verdict, and
## the CM's `resolved` relays through here.

signal resolved(outcome: int, reward: int)

enum Outcome { WON, LOST, RESOLVED }   # RESOLVED = a non-fight beat completed

var def: EncounterDef
var player: Actor
var enemies: Array = []          # spawned enemy Actors (fight), left-to-right

var _cm: CombatManager = null
var _resolved: bool = false


func _init(encounter_def: EncounterDef, player_actor: Actor) -> void:
  def = encounter_def
  player = player_actor
  # Enemies are spawned at creation so the corridor can render them approaching
  # from depth (presentation; the logical beat resolves on arrival via begin()).
  if def.type == EncounterDef.Type.FIGHT:
    for enemy_id in def.enemy_ids:
      enemies.append(_spawn_enemy(enemy_id))


func _spawn_enemy(enemy_id: int) -> Actor:
  var enemy_def: EnemyDef = EnemyCatalog.get_def(enemy_id)
  var actor := Actor.new(enemy_def.max_hp)
  for item_id in enemy_def.item_ids:
    actor.board.append(Item.new(ItemCatalog.get_def(item_id), actor))
  return actor


func is_fight() -> bool:
  return def.type == EncounterDef.Type.FIGHT


func combat_manager() -> CombatManager:
  return _cm


## Begin resolution (on arrival). FIGHT: create + start the CombatManager (the
## caller then supplies the clock via sim_step; its `resolved` relays here). REST:
## apply the partial heal and resolve immediately. Idempotent.
func begin() -> void:
  if _resolved or _cm != null:
    return
  if is_fight():
    _cm = CombatManager.new(player, enemies)
    _cm.resolved.connect(_on_fight_resolved)
    _cm.start()
  else:
    player.heal(def.heal_fraction * player.max_hp)
    _resolve(Outcome.RESOLVED)


func _on_fight_resolved(player_won: bool) -> void:
  _resolve(Outcome.WON if player_won else Outcome.LOST)


func _resolve(outcome: int) -> void:
  if _resolved:
    return
  _resolved = true
  resolved.emit(outcome, def.reward)


## Free the fight's combat resources (the Run manager calls this after reading the
## result, before advancing). Breaks the CombatManager's RefCounted cycles.
func teardown() -> void:
  if _cm != null:
    _cm.teardown()
    _cm.free()
    _cm = null
  enemies.clear()
