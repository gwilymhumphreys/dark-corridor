class_name Encounter
extends Node
## The per-beat orchestrator (docs/systems/encounter.md) — one resolved beat, instanced by the
## Run manager. A FIGHT spawns enemy Actors from their definitions (left-to-right)
## and, on begin(), creates the per-fight CombatManager; an EVENT waits for the Run manager to apply
## the picked option and call resolve_event; a REST
## applies a partial heal; a RELIC encounter resolves at once and its reward is a relic choice. It
## reports its outcome + reward-kind up via `resolved`; the Run manager fulfils the reward and applies
## HP/relic policy.
##
## The Encounter (and its CombatManager) are NOT mounted in the scene tree — the clock is supplied
## externally (the autotest steps sim_step; the run screen ticks the fight from its
## _physics_process). So begin() readies the fight but does not run it; the caller steps
## combat_manager() to a verdict, and the CM's `resolved` relays through here.

signal resolved(outcome: int, reward: int)

enum Outcome { WON, LOST, RESOLVED }   # RESOLVED = a non-fight beat completed

var def: EncounterDef
var player: Actor
var enemies: Array[Actor] = []   # spawned enemy Actors (fight), left-to-right (the live
                                 # CombatManager shares this array by reference — reaps show here)

var _combat_manager: CombatManager = null
var _resolved: bool = false
var _combat_seed: int = 0
# Run-scoped player-side allies seeded into the fight (Cap 3 Stage B). Untyped: shared
# BY REFERENCE down from RunManager.allies into the CombatManager.
var _allies: Array = []


## `generated_enemy_ids`, when non-empty, replaces the def's authored `enemy_ids` — the Run manager
## assembles a fight against a points target (docs/plans/encounter_points_budget.md) and hands the
## drawn set in. Everything else on the def, the location frame and the reward, still applies.
func _init(encounter_def: EncounterDef, player_actor: Actor, combat_seed: int = 0, ally_actors: Array = [], generated_enemy_ids: Array[String] = []) -> void:
  def = encounter_def
  player = player_actor
  _combat_seed = combat_seed   # the per-fight RNG seed, handed to the CombatManager on begin()
  _allies = ally_actors
  # Enemies are spawned at creation so the corridor can render them approaching
  # from depth (presentation; the logical beat resolves on arrival via begin()).
  if def.type == EncounterDef.Type.FIGHT:
    var ids: Array[String] = generated_enemy_ids if not generated_enemy_ids.is_empty() else def.enemy_ids
    for enemy_id: String in ids:
      enemies.append(_spawn_enemy(enemy_id))


func _spawn_enemy(enemy_id: String) -> Actor:
  return EnemyCatalog.get_def(enemy_id).make_actor()


func is_fight() -> bool:
  return def.type == EncounterDef.Type.FIGHT


func is_event() -> bool:
  return def.type == EncounterDef.Type.EVENT


func combat_manager() -> CombatManager:
  return _combat_manager


## Begin resolution (on arrival). FIGHT: create + start the CombatManager (the
## caller then supplies the clock via sim_step; its `resolved` relays here). REST:
## apply the partial heal and resolve immediately. Idempotent.
func begin() -> void:
  if _resolved or _combat_manager != null:
    return
  if is_fight():
    _combat_manager = CombatManager.new(player, enemies, _combat_seed, _allies)
    _combat_manager.resolved.connect(_on_fight_resolved)
    _combat_manager.start()
  elif is_event():
    pass   # await the option pick (RunManager.pick_event_option, which then calls resolve_event)
  elif def.type == EncounterDef.Type.RELIC:
    _resolve(Outcome.RESOLVED)   # no fight: the reward (a relic choice) is the whole encounter
  else:
    player.heal(def.heal_fraction * player.max_hp)
    _resolve(Outcome.RESOLVED)


## The event's options, in authored order. The Run manager decides which are available
## (RunManager.available_event_options) and applies the picked one.
func event_options() -> Array:
  return def.event_options


## Finish the event after the Run manager has applied the picked option's effects. Events report no
## reward: the option is the reward. A damaging option can be lethal, so the beat resolves LOST at
## once rather than the dead player walking on to the next fight.
func resolve_event() -> void:
  if not is_event() or _resolved:
    return
  _resolve(Outcome.LOST if not player.is_alive() else Outcome.RESOLVED)


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
  if _combat_manager != null:
    _combat_manager.teardown()
    _combat_manager.free()
    _combat_manager = null
  else:
    # Never begun (torn down before begin(), e.g. a run reset mid-approach): no CM
    # exists to dissolve the spawned enemies, so their Actor<->Item cycles are
    # broken here — clearing the array alone would leak them.
    for enemy in enemies:
      enemy.dissolve()
  enemies.clear()
