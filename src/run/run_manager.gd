class_name RunManager
extends Node
## The descent (run_manager_prd) — one run, instanced/owned by the Game manager.
## Owns the map, the player run-state { actor, relics, potions, position, rng },
## the HP-economy, the sequencing cycle, and the run snapshot. Signals
## `run_ended(outcome)` up to Game on a death / final win.
##
## It advances by explicit call + signal — never _process. A fight beat's
## CombatManager clock is supplied externally (the autotest steps sim_step; the
## Phase-4 run screen will drive _physics_process), so the cycle here is: enter a
## beat (create the Encounter + auto-save) → begin it → on its `resolved` fulfil
## the reward (a pending draft offer / relic / none) and check run-end → the caller
## supplies a draft pick → advance. The Run manager is kept out of the scene tree
## in Phase 3 (driven by calls); freeing is manual via teardown().

signal run_ended(outcome: int)

enum Outcome { WON, DIED }

# A short linear map (counts are tuning, not design). The final beat is a fight;
# winning it ends the run (won). Two fights grant drafts; a rest sits before the
# finale.
const MAP: Array = [
  EncounterCatalog.Id.FIGHT_GRUNT,
  EncounterCatalog.Id.FIGHT_GRUNT,
  EncounterCatalog.Id.REST,
  EncounterCatalog.Id.FIGHT_GRUNT,
]

# Run-state (the snapshot persists exactly this).
var player: Actor
var relics: Array = []        # Array[Relic]
var potions: Array = []       # Array[Consumable] — empty in the relic-only scope
var position: int = 0
var rng: RandomNumberGenerator

var _current: Encounter = null
var _pending_offer: Array = []   # Array[ItemDef] — the held draft offer (1-of-3)
var _ended: bool = false
var _outcome: int = Outcome.WON


# --- fresh run --------------------------------------------------------------

func start(seed_value: int) -> void:
  rng = RandomNumberGenerator.new()
  rng.seed = seed_value
  player = _make_starting_player()
  relics = [Relic.new(RelicCatalog.get_def(RelicCatalog.Id.STONE_WARD))]
  potions = []
  position = 0
  _ended = false
  _pending_offer = []
  _enter_beat(position)
  _save()


## The stand-in for a Characters definition (deferred): a default board + the
## Stone Ward starting relic. The player Actor is run-lifetime, owned here.
func _make_starting_player() -> Actor:
  var actor := Actor.new(Balance.PLAYER_START_HP)
  for id in [ItemCatalog.Id.WEAPON, ItemCatalog.Id.ARMOR, ItemCatalog.Id.POISON_DAGGER]:
    actor.board.append(Item.new(ItemCatalog.get_def(id), actor))
  return actor


# --- the cycle (driven by the autotest / run screen) ------------------------

func current_encounter() -> Encounter:
  return _current


func combat_manager() -> CombatManager:
  return _current.combat_manager() if _current != null else null


## Begin resolving the current beat. Applies relic combat-start statuses (fights),
## then begins it. A rest resolves synchronously (its heal lands and `resolved`
## fires here); a fight readies its CombatManager for the caller to step.
func begin_current() -> void:
  if _current == null or _ended:
    return
  if not _current.resolved.is_connected(_on_encounter_resolved):
    _current.resolved.connect(_on_encounter_resolved)
  _current.begin()
  if _current.is_fight():
    _apply_relics_to_player()


## Relic effect shape (a): apply each combat-start relic's status to the player at
## fight start (content_prd). Combat-scoped — CombatManager.teardown clears it, so
## it is re-applied fresh each fight.
func _apply_relics_to_player() -> void:
  for relic in relics:
    if relic.def.kind == RelicDef.Kind.COMBAT_START_STATUS:
      StatusManager.apply(player, relic.def.status_type, relic.def.status_count)


func _on_encounter_resolved(outcome: int, reward: int) -> void:
  if outcome == Encounter.Outcome.LOST:
    _end_run(Outcome.DIED)
    return
  if _is_final_beat():
    _end_run(Outcome.WON)
    return
  match reward:
    EncounterDef.Reward.DRAFT:
      _pending_offer = Draft.draw(DraftPool.ITEMS, position, rng)
    EncounterDef.Reward.RELIC:
      pass   # direct relic grants aren't in the prototype map (Encounter reward routing later)
    _:
      pass


func has_pending_draft() -> bool:
  return not _pending_offer.is_empty()


func pending_draft() -> Array:
  return _pending_offer


## Apply the player's draft pick (a draft-pick intent) — add the chosen item to the
## board, clear the offer. No skip (draft_prd): a pick always resolves.
func apply_draft_pick(index: int) -> void:
  if _pending_offer.is_empty():
    return
  var picked: ItemDef = _pending_offer[clampi(index, 0, _pending_offer.size() - 1)]
  player.board.append(Item.new(picked, player))
  _pending_offer = []


## Advance to the next beat: tear the resolved one down, step position, create the
## next Encounter, and auto-save (the encounter-entry resume point).
func advance() -> void:
  if _ended:
    return
  _teardown_current()
  position += 1
  _enter_beat(position)
  _save()


func is_ended() -> bool:
  return _ended


func outcome() -> int:
  return _outcome


# --- map + run-end ----------------------------------------------------------

func _enter_beat(pos: int) -> void:
  _current = Encounter.new(EncounterCatalog.get_def(MAP[pos]), player)


func _is_final_beat() -> bool:
  return position >= MAP.size() - 1


func _end_run(outcome_value: int) -> void:
  if _ended:
    return
  _ended = true
  _outcome = outcome_value
  run_ended.emit(outcome_value)


# --- snapshot / rehydrate (the Run manager owns the schema) -----------------

func _save() -> void:
  Save.write(snapshot())


func snapshot() -> Dictionary:
  var board: Array = []
  for it in player.board:
    board.append({ 'id': it.def.id, 'enchant': null })
  var relic_ids: Array = []
  for relic in relics:
    relic_ids.append(relic.def.id)
  return {
    'hp': player.hp,
    'max_hp': player.max_hp,
    'board': board,
    'relics': relic_ids,
    'potions': [],
    'position': position,
    # RNG full state as strings — a JSON double can't hold a 64-bit value exactly.
    'rng': { 'seed': str(rng.seed), 'state': str(rng.state) },
  }


## Rebuild run-state from a snapshot and re-enter the saved beat (the resume point).
## Does not re-save (this is a load, not an encounter entry).
func rehydrate(snap: Dictionary) -> void:
  player = Actor.new(float(snap['max_hp']))
  player.hp = float(snap['hp'])
  player.board.clear()
  for entry in snap['board']:
    player.board.append(Item.new(ItemCatalog.get_def(int(entry['id'])), player))
  relics = []
  for rid in snap['relics']:
    relics.append(Relic.new(RelicCatalog.get_def(int(rid))))
  potions = []
  position = int(snap['position'])
  rng = RandomNumberGenerator.new()
  rng.seed = int(snap['rng']['seed'])
  rng.state = int(snap['rng']['state'])
  _ended = false
  _pending_offer = []
  _enter_beat(position)


# --- teardown ---------------------------------------------------------------

func _teardown_current() -> void:
  if _current != null:
    _current.teardown()
    _current.free()
    _current = null


func teardown() -> void:
  _teardown_current()
  relics.clear()
  potions.clear()
  _pending_offer.clear()
