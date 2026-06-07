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
var _combat_seed: int = 0
var _allies: Array = []   # run-scoped player-side allies, seeded into the fight (Cap 3 Stage B)


func _init(encounter_def: EncounterDef, player_actor: Actor, combat_seed: int = 0, ally_actors: Array = []) -> void:
  def = encounter_def
  player = player_actor
  _combat_seed = combat_seed   # the per-fight RNG seed, handed to the CombatManager on begin()
  _allies = ally_actors
  # Enemies are spawned at creation so the corridor can render them approaching
  # from depth (presentation; the logical beat resolves on arrival via begin()).
  if def.type == EncounterDef.Type.FIGHT:
    for enemy_id in def.enemy_ids:
      enemies.append(_spawn_enemy(enemy_id))


func _spawn_enemy(enemy_id: String) -> Actor:
  var enemy_def: EnemyDef = EnemyCatalog.get_def(enemy_id)
  var actor := Actor.new(enemy_def.max_hp)
  for item_id in enemy_def.item_ids:
    actor.board.append(Item.new(ItemCatalog.get_def(item_id), actor))
  return actor


func is_fight() -> bool:
  return def.type == EncounterDef.Type.FIGHT


func is_event() -> bool:
  return def.type == EncounterDef.Type.EVENT


func combat_manager() -> CombatManager:
  return _cm


## Begin resolution (on arrival). FIGHT: create + start the CombatManager (the
## caller then supplies the clock via sim_step; its `resolved` relays here). REST:
## apply the partial heal and resolve immediately. Idempotent.
func begin() -> void:
  if _resolved or _cm != null:
    return
  if is_fight():
    _cm = CombatManager.new(player, enemies, _combat_seed, _allies)
    _cm.resolved.connect(_on_fight_resolved)
    _cm.start()
  elif is_event():
    pass   # await the tier-2 binary choice (pick_event_option) — the event's resolution
  else:
    player.heal(def.heal_fraction * player.max_hp)
    _resolve(Outcome.RESOLVED)


## The event's binary choice (a tier-2, within-encounter pick — encounter_prd). The
## options are presented by the UI; this applies the chosen option's direct outcome to the
## player run-state, then resolves the beat (events report no reward — the outcome is it).
func event_options() -> Array:
  return def.event_options


func pick_event_option(index: int) -> void:
  if not is_event() or _resolved or def.event_options.is_empty():
    return
  var opt: EventOptionDef = def.event_options[clampi(index, 0, def.event_options.size() - 1)]
  _apply_event_outcome(opt)
  _resolve(Outcome.RESOLVED)


func _apply_event_outcome(opt: EventOptionDef) -> void:
  match opt.effect:
    EventOptionDef.Effect.HEAL_FRACTION:
      player.heal(opt.amount * player.max_hp)
    EventOptionDef.Effect.MAX_HP_BONUS:
      player.max_hp += opt.amount
      player.hp += opt.amount
    EventOptionDef.Effect.DAMAGE:
      player.take_damage(opt.amount)


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
