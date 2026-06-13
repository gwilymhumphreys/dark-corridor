class_name RunManager
extends Node
## The descent (docs/systems/run_manager.md) — one run, instanced/owned by the Game manager.
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

# Spreads the run seed into a distinct per-beat combat stream (a prime stride).
const COMBAT_SEED_STRIDE: int = 1000003

# The player side holds at most this many run-scoped allies (the 4 ally slots flanking the
# player — UI/Layout). The cap is the safety net: add_ally past it is a no-op. The placeholder
# recruit event relies on that; richer acquisition content can gate on can_add_ally() first to
# avoid offering a "join me" choice that can't be filled.
const MAX_ALLIES: int = 4

# Auto-roll bias for ROLL beats (run_map). A beat with both a combat and an event option rolls
# COMBAT vs EVENT: the streaking type's chance falls ROLL_BIAS_STEP points per consecutive prior
# roll of it (from ROLL_BASE_CHANCE), floored at 0 so a long run is force-broken; the first beat
# that lands the OTHER type resets the streak. (#1 — the owner's map design.)
enum RollType { COMBAT, EVENT }
const ROLL_BASE_CHANCE: int = 50
const ROLL_BIAS_STEP: int = 10

# Run-state (the snapshot persists exactly this). `position` is the global beat index
# (0 .. RunMap.TOTAL_BEATS-1); the act/beat-within-act are derived (RunMap).
var player: Actor
var allies: Array[Actor] = []        # run-scoped (persistent) player-side allies (shared
                                     # BY REFERENCE into the live CombatManager — untyped there)
var relics: Array[Relic] = []
var potions: Array[Consumable] = []
var position: int = 0
var rng: RandomNumberGenerator
var character: CharacterDef    # the chosen character (#27) — its item pool feeds the draft

var _ally_def_ids: Array[String] = []  # parallel to `allies` — each ally's EnemyCatalog def id (snapshot)

var _current: Encounter = null
var _current_def_id: String = ''    # the resolved EncounterDef id for the current beat (resume)
# The COMBAT/EVENT anti-repeat streak for ROLL beats (run-state — saved so resume reproduces the
# rolls). `_roll_streak_count == 0` means no streak (base 50/50); otherwise `_roll_streak` is the
# type on the streak and the count is the bias depth.
var _roll_streak: int = RollType.COMBAT
var _roll_streak_count: int = 0
var _pending_choice: Array[String] = []  # kept empty — the choice layer is dormant (see _roll_beat)
var _pending_offer: Array[ItemDef] = []   # the held draft offer (1-of-3)
var _ended: bool = false
var _outcome: int = Outcome.WON
var _torn_down: bool = false


# --- fresh run --------------------------------------------------------------

func start(seed_value: int, character_id: String = CharacterCatalog.DEFAULT) -> void:
  rng = RandomNumberGenerator.new()
  rng.seed = seed_value
  character = CharacterCatalog.get_def(character_id)
  player = _make_starting_player()
  # Starting kit from the character (#27): its signature relic, any starting enchants on
  # the board, and its starting potions — the run opens in the character's identity.
  relics = []
  if character.starting_relic_id != '':
    relics.append(Relic.new(RelicCatalog.get_def(character.starting_relic_id)))
  potions = []
  for potion_id in character.starting_potion_ids:
    potions.append(Consumable.new(ConsumableCatalog.get_def(potion_id)))
  for enchant_spec in character.starting_enchants:
    apply_enchant(Enchantment.new(EnchantCatalog.get_def(enchant_spec['enchant_id'])), enchant_spec['item_index'])
  position = 0
  _ended = false
  _pending_offer = []
  _current_def_id = ''
  _pending_choice = []
  _roll_streak = RollType.COMBAT
  _roll_streak_count = 0
  allies = []                  # no starting allies by default (the owner wires acquisition)
  _ally_def_ids = []
  _enter_beat(position)
  _save()


## Build the run-start player Actor from the character's starting board (#27). Run-lifetime,
## owned here. Max HP is the global default for now (a per-character start-HP comes later).
func _make_starting_player() -> Actor:
  var actor := Actor.new(Balance.PLAYER_START_HP)
  for id in character.starting_item_ids:
    actor.board.append(Item.new(ItemCatalog.get_def(id), actor))
  return actor


# --- the cycle (driven by the autotest / run screen) ------------------------

func current_encounter() -> Encounter:
  return _current


func combat_manager() -> CombatManager:
  return _current.combat_manager() if _current != null else null


func act() -> int:
  return RunMap.act_of(position)


func beat_in_act() -> int:
  return RunMap.beat_in_act(position)


# --- the choice layer (DORMANT — beats auto-roll; see _roll_beat) ------------
# Every beat now auto-rolls its content (RunManager._roll_beat), so no beat produces a pending
# choice: has_pending_choice() is always false and these three are inert. They're kept so the run
# screen / autotest choice branch + the choice_overlay component stay wired for a possible future
# fork-beat (one that genuinely offers the player a pick). Remove them if that's ruled out.

## True only when a beat is waiting on a player pick — never, while beats auto-roll.
func has_pending_choice() -> bool:
  return not _pending_choice.is_empty()


## The candidate EncounterDef ids on offer (the UI telegraphs them; the autotest picks one).
func pending_choice() -> Array:
  return _pending_choice


## Apply the player's choice-point pick: the chosen candidate becomes the live `Encounter`
## (created here, then it approaches + resolves). Re-saves so resume re-enters the PICKED
## encounter, not the choice. No skip — a pick always resolves.
func pick_path(index: int) -> void:
  if _pending_choice.is_empty():
    return
  _current_def_id = _pending_choice[clampi(index, 0, _pending_choice.size() - 1)]
  _pending_choice = []
  _create_current_encounter()
  _save()


## Begin resolving the current beat. Applies relic combat-start statuses (fights),
## then begins it. A rest resolves synchronously (its heal lands and `resolved`
## fires here); a fight readies its CombatManager for the caller to step.
func begin_current() -> void:
  if _current == null or _ended:
    return
  if not _current.resolved.is_connected(_on_encounter_resolved):
    _current.resolved.connect(_on_encounter_resolved)
  _current.begin()
  # Ordering constraint: revive + relic statuses run AFTER begin() (the CM exists, its
  # registration done). Safe because registration reads neither HP nor statuses and no
  # sim time passes until the caller steps — don't insert anything between that changes that.
  if _current.is_fight():
    _revive_allies()          # run-scoped allies enter every fight at full HP (downed → revived)
    _apply_relics_to_player()


## Run-scoped allies are revived to full HP at the start of every fight (design: allies revive
## between combats — only the player carries HP attrition through the run). A downed ally from
## the previous fight is restored; its slot was kept on the roster, so it simply rejoins.
func _revive_allies() -> void:
  for ally in allies:
    ally.hp = ally.max_hp


## Relic effect shape (a): apply each combat-start relic's status to the player at
## fight start (docs/systems/content.md). Combat-scoped — CombatManager.teardown clears it, so
## it is re-applied fresh each fight.
func _apply_relics_to_player() -> void:
  for relic in relics:
    if relic.def.kind == RelicDef.Kind.COMBAT_START_STATUS:
      StatusManager.apply(player, relic.def.status_id, relic.def.status_count, relic.def.status_duration)


func _on_encounter_resolved(outcome_value: int, reward: int) -> void:
  if outcome_value == Encounter.Outcome.LOST:
    _end_run(Outcome.DIED)
    return
  if RunMap.is_final_beat(position):   # the final act's boss — beating it ends the descent
    _end_run(Outcome.WON)
    return
  match reward:
    EncounterDef.Reward.DRAFT:
      _pending_offer = Draft.draw(_draft_pool(), position, rng)
    EncounterDef.Reward.RELIC:
      _grant_relic()                                          # a mid-boss / guaranteed-relic beat
    EncounterDef.Reward.ELITE:
      _grant_relic()                                          # an elite is richer: a relic AND
      _pending_offer = Draft.draw(_draft_pool(), position, rng)   # a draft (reward asymmetry, #2)
    _:
      pass


## The draft pool handed to Draft (#27): the chosen character's pool plus the shared
## colorless items (the exception-that-earns-it). Draft stays pool-agnostic — it draws
## from whatever this composes.
func _draft_pool() -> Array:
  return character.item_pool + ColorlessPool.ITEMS


## Grant a relic reward (#2): draw one from the reward pool on the run RNG (so it's
## deterministic + resume-stable), add it to run-state, and apply any one-time direct mod.
func _grant_relic() -> void:
  var pool: Array = RelicCatalog.REWARD_POOL
  if pool.is_empty():
    push_warning('RunManager: a relic reward fired but RelicCatalog.REWARD_POOL is empty — nothing granted')
    return
  var id: String = pool[rng.randi_range(0, pool.size() - 1)]
  var relic := Relic.new(RelicCatalog.get_def(id))
  relics.append(relic)
  _apply_relic_grant(relic)


## Apply a granted relic's ONE-TIME direct run-state mod (MAX_HP_BONUS raises max + current
## HP). Baked into the saved snapshot's hp/max_hp — NOT re-applied on rehydrate. A
## COMBAT_START_STATUS relic has no grant-time effect (it applies per fight, below).
func _apply_relic_grant(relic: Relic) -> void:
  if relic.def.kind == RelicDef.Kind.MAX_HP_BONUS:
    player.max_hp += relic.def.max_hp_bonus
    player.hp += relic.def.max_hp_bonus


func has_pending_draft() -> bool:
  return not _pending_offer.is_empty()


func pending_draft() -> Array:
  return _pending_offer


## Apply the player's draft pick (a draft-pick intent) — add the chosen item to the
## board, clear the offer. No skip (docs/systems/draft.md): a pick always resolves.
func apply_draft_pick(index: int) -> void:
  if _pending_offer.is_empty():
    return
  var picked: ItemDef = _pending_offer[clampi(index, 0, _pending_offer.size() - 1)]
  player.board.append(Item.new(picked, player))
  _pending_offer = []


## Whether the player side has a free ally slot (cap = MAX_ALLIES). The gating surface for
## acquisition content (a draftable `ally` category, or a recruit event that wants to hide its
## offer when full) — the cap in add_ally enforces it regardless.
func can_add_ally() -> bool:
  return allies.size() < MAX_ALLIES


## Acquire a run-scoped (persistent) ally (docs/systems/spore_engine.md Cap 3, Stage B): build an Actor
## from an EnemyDef and add it to the player-side roster. It persists across fights, is saved
## in the snapshot, and joins every fight (the Encounter seeds the CombatManager with it).
## The acquisition path today is the recruit EVENT (RunManager.pick_event_option → here); a
## draftable `ally` category is the deferred alternative. No-op past the MAX_ALLIES cap.
func add_ally(def_id: String) -> void:
  if not can_add_ally():
    return   # the 4 ally slots are full — the source should have gated on can_add_ally()
  var ally := _make_ally(def_id)
  allies.append(ally)   # the live CombatManager shares this array by reference, so it sees it
  _ally_def_ids.append(def_id)
  var combat: CombatManager = combat_manager()
  if combat != null and not combat.is_resolved():
    combat.register_ally(ally)   # acquired mid-fight → register its Tickers so it joins the fight


## The event's binary-choice intent, routed through the RunManager (not straight to the
## Encounter) so an option can touch run-state beyond the player Actor. An ADD_ALLY option
## recruits a run-scoped ally here; the player-Actor effects (heal / max-HP / damage) + the
## beat resolution stay in the Encounter, which this then delegates to. The autotest + run
## screen call THIS, not Encounter.pick_event_option, for events.
func pick_event_option(index: int) -> void:
  if _current == null or not _current.is_event():
    return
  var opts: Array = _current.event_options()
  if not opts.is_empty():
    var opt: EventOptionDef = opts[clampi(index, 0, opts.size() - 1)]
    if opt.effect == EventOptionDef.Effect.ADD_ALLY:
      add_ally(opt.ally_def_id)
  _current.pick_event_option(index)


func _make_ally(def_id: String) -> Actor:
  var def: EnemyDef = EnemyCatalog.get_def(def_id)
  var actor := Actor.new(def.max_hp)
  actor.display_name = def.name_key
  for item_id in def.item_ids:
    actor.board.append(Item.new(ItemCatalog.get_def(item_id), actor))
  return actor


## Attach an enchantment to a chosen board item (the enchant-target sub-choice; a
## drafted-enchant intent, or the starting-kit grant). One enchant per item.
func apply_enchant(enchant: Enchantment, item_index: int) -> void:
  if item_index < 0 or item_index >= player.board.size():
    return
  player.board[item_index].enchant = enchant


## Throw-potion intent: consume the potion in `index` and activate it in the live
## fight (docs/systems/content.md). Only valid mid-fight (a consumable resolves through the
## Combat manager). Returns whether it was thrown.
func throw_potion(index: int) -> bool:
  var combat: CombatManager = combat_manager()
  if combat == null or index < 0 or index >= potions.size():
    return false
  var consumable: Consumable = potions[index]
  potions.remove_at(index)
  combat.throw_consumable(consumable, player)
  return true


## Advance to the next beat: tear the resolved one down, apply the between-act full heal
## when crossing into a new act (HP-economy, design), step position, enter the next beat
## (a fixed encounter OR a fresh choice), and auto-save (the encounter-entry resume point).
func advance() -> void:
  if _ended:
    return
  if not _pending_offer.is_empty():
    # The no-skip invariant: a draft must be consumed before advancing. A caller that
    # advances past one has a flow bug — drop the offer loudly rather than carry it
    # unsaved into the next beat (the run RNG already advanced; resume would diverge).
    push_error('RunManager.advance: advancing past an unconsumed draft offer — dropping it')
    _pending_offer = []
  _teardown_current()
  if RunMap.crosses_act(position):   # the act boss was just cleared → enter the next act full
    _full_heal()
  position += 1
  _enter_beat(position)
  _save()


## HP-economy: the automatic between-act full restore (design — players enter each act at
## full HP). The in-act partial rest is the REST encounter; max-HP growth comes from relics.
func _full_heal() -> void:
  if player != null:
    player.hp = player.max_hp
  for ally in allies:   # the between-act restore covers the whole run-scoped player side
    ally.hp = ally.max_hp


func is_ended() -> bool:
  return _ended


func outcome() -> int:
  return _outcome


# --- map + run-end ----------------------------------------------------------

## Set up the beat at `pos`: a FIXED beat (boss / midpoint relic) creates its live encounter
## immediately; a ROLL beat auto-selects COMBAT vs EVENT and draws a def (no player choice —
## the encounter is live at once). Clears any prior beat's transient state.
func _enter_beat(pos: int) -> void:
  _current_def_id = ''
  var spec: Dictionary = RunMap.beat_spec(pos)
  if spec['kind'] == RunMap.BeatKind.FIXED:
    _current_def_id = spec['id']
    _create_current_encounter()
  else:
    _roll_beat(spec['combat_pool'], spec['event_pool'])


func _create_current_encounter() -> void:
  _current = Encounter.new(EncounterCatalog.get_def(_current_def_id), player, _combat_seed_for(position), allies)


## Roll a ROLL beat's content (run_map bands): pick COMBAT or EVENT via the anti-repeat weighted
## roll, then draw a def from that pool on the run RNG (deterministic + resume-stable). An empty
## event pool forces combat (the easy opener) and does NOT count toward the streak — only genuine
## two-way rolls bias it.
func _roll_beat(combat_pool: Array, event_pool: Array) -> void:
  var pool: Array
  if event_pool.is_empty():
    pool = combat_pool
  elif combat_pool.is_empty():
    pool = event_pool
  else:
    pool = combat_pool if _roll_type() == RollType.COMBAT else event_pool
  _current_def_id = pool[rng.randi_range(0, pool.size() - 1)]
  _create_current_encounter()


## Roll COMBAT vs EVENT with the −ROLL_BIAS_STEP-per-repeat bias and update the streak. The
## streaking type's chance is ROLL_BASE_CHANCE − step×count (floored at 0); landing the other
## type resets the streak to that type (count 1).
func _roll_type() -> int:
  var combat_chance: int = ROLL_BASE_CHANCE
  if _roll_streak_count > 0:
    var bias: int = ROLL_BIAS_STEP * _roll_streak_count
    combat_chance = ROLL_BASE_CHANCE - bias if _roll_streak == RollType.COMBAT else ROLL_BASE_CHANCE + bias
  combat_chance = clampi(combat_chance, 0, 100)
  var picked: int = RollType.COMBAT if rng.randi_range(1, 100) <= combat_chance else RollType.EVENT
  if picked == _roll_streak and _roll_streak_count > 0:
    _roll_streak_count += 1
  else:
    _roll_streak = picked
    _roll_streak_count = 1
  return picked


## The per-fight RNG seed for beat `pos` (decision #20): derived from the run SEED (a
## constant, saved) + the beat index — NOT the evolving run stream. So combat randomness
## is reproducible, a re-entered fight replays identically (resume isn't save-scummable),
## and deriving it never perturbs the run stream that draft offers draw from.
func _combat_seed_for(pos: int) -> int:
  return rng.seed + (pos + 1) * COMBAT_SEED_STRIDE


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
  for item in player.board:
    board.append({ 'id': item.def.id, 'enchant': item.enchant.def.id if item.enchant != null else null })
  var relic_ids: Array = []
  for relic in relics:
    relic_ids.append(relic.def.id)
  var potion_ids: Array = []
  for consumable in potions:
    potion_ids.append(consumable.def.id)
  var ally_snaps: Array = []
  for ally_def_id in _ally_def_ids:
    # Def id only — an ally's HP is NOT saved: allies are revived to full at every fight
    # begin (only the player carries HP attrition), so a saved value would be dead weight.
    ally_snaps.append({ 'id': ally_def_id })
  return {
    'character': character.id,
    'hp': player.hp,
    'max_hp': player.max_hp,
    'board': board,
    'allies': ally_snaps,   # run-scoped allies persist (def id + current HP; board is the def's)
    'relics': relic_ids,
    'potions': potion_ids,
    'position': position,
    # The current beat's resolution: the rolled/fixed encounter id (resume re-enters it, never
    # re-rolled) + the COMBAT/EVENT streak so the NEXT beat's roll reproduces on resume.
    'current_def_id': _current_def_id,
    'roll_streak': _roll_streak,
    'roll_streak_count': _roll_streak_count,
    # RNG full state as strings — a JSON double can't hold a 64-bit value exactly.
    'rng': { 'seed': str(rng.seed), 'state': str(rng.state) },
  }


# Snapshot keys a save must carry to be usable. Save already discards corrupt / wrong-
# version files; this catches a parsable save with a broken SHAPE (truncated, hand-edited)
# so resume discards to fresh instead of crashing (the no-migration rule, docs/systems/save.md).
const SNAPSHOT_KEYS: Array = [
  'hp', 'max_hp', 'board', 'relics', 'potions', 'position', 'current_def_id', 'rng',
]


## Rebuild run-state from a snapshot and re-enter the saved beat (the resume point).
## Does not re-save (this is a load, not an encounter entry). Returns false — building
## nothing — when the snapshot is shape-incompatible; the Game manager then discards it.
func rehydrate(snap: Dictionary) -> bool:
  if not _snapshot_usable(snap):
    return false
  character = CharacterCatalog.get_def(snap.get('character', CharacterCatalog.DEFAULT))
  player = Actor.new(float(snap['max_hp']))
  player.hp = float(snap['hp'])
  player.board.clear()
  for entry in snap['board']:
    var item := Item.new(ItemCatalog.get_def(str(entry['id'])), player)
    if entry['enchant'] != null:
      item.enchant = Enchantment.new(EnchantCatalog.get_def(str(entry['enchant'])))
    player.board.append(item)
  allies = []
  _ally_def_ids = []
  for entry in snap.get('allies', []):
    add_ally(str(entry['id']))
  relics = []
  for relic_id in snap['relics']:
    relics.append(Relic.new(RelicCatalog.get_def(str(relic_id))))
  potions = []
  for potion_id in snap['potions']:
    potions.append(Consumable.new(ConsumableCatalog.get_def(str(potion_id))))
  position = int(snap['position'])
  rng = RandomNumberGenerator.new()
  rng.seed = int(snap['rng']['seed'])
  rng.state = int(snap['rng']['state'])
  _ended = false
  _pending_offer = []
  _pending_choice = []
  # Restore the current beat's resolution + the roll streak exactly — never re-roll (no save-scum).
  _current_def_id = str(snap['current_def_id'])
  _roll_streak = int(snap.get('roll_streak', RollType.COMBAT))
  _roll_streak_count = int(snap.get('roll_streak_count', 0))
  _create_current_encounter()
  return true


## Shape check for a parsed snapshot: every required key present, the RNG pair intact,
## and a resolved current beat (every save happens after _enter_beat sets one).
func _snapshot_usable(snap: Dictionary) -> bool:
  for key in SNAPSHOT_KEYS:
    if not snap.has(key):
      return false
  var rng_snap: Variant = snap['rng']
  if not (rng_snap is Dictionary and rng_snap.has('seed') and rng_snap.has('state')):
    return false
  return str(snap['current_def_id']) != ''


# --- teardown ---------------------------------------------------------------

func _teardown_current() -> void:
  if _current != null:
    _current.teardown()
    _current.free()
    _current = null


## End the run cleanly (idempotent). The player is run-lifetime, so this is where
## its Actor<->Item cycle is finally broken (dissolve) — never at fight end, where
## its board must survive. Called by Game on the next start / resume / reset.
func teardown() -> void:
  if _torn_down:
    return
  _torn_down = true
  _teardown_current()
  if player != null:
    player.dissolve()
    player = null
  for ally in allies:   # run-scoped allies are run-lifetime too — break their cycle at run end
    ally.dissolve()
  allies.clear()
  _ally_def_ids.clear()
  relics.clear()
  potions.clear()
  _pending_offer.clear()
  _pending_choice.clear()
