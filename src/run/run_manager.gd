class_name RunManager
extends Node
## The descent (docs/systems/run_manager.md) — one run, instanced/owned by the Game manager.
## Owns the map, the player run-state { actor, relics, potions, position, gold, rng },
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

# How many relics the relic encounter offers to choose from.
const RELIC_OFFER_COUNT: int = 3

# Run-state (the snapshot persists exactly this). `position` is the global beat index
# (0 .. RunMap.TOTAL_BEATS-1); the act/beat-within-act are derived (RunMap).
var player: Actor
var allies: Array[Actor] = []        # run-scoped (persistent) player-side allies (shared
                                     # BY REFERENCE into the live CombatManager — untyped there)
var relics: Array[Relic] = []
var potions: Array[Consumable] = []
var position: int = 0
# Banked gold — a run-state resource (docs decision #33). The ONLY source today is skipping a
# draft (apply_draft_skip); there is NO sink yet (shops are out of scope). Persists in the snapshot.
var gold: int = 0
var rng: RandomNumberGenerator
var character: CharacterDef    # the chosen character (#27) — its item pool feeds the draft

var _ally_def_ids: Array[String] = []  # parallel to `allies` — each ally's EnemyCatalog def id (snapshot)

var _current: Encounter = null
var _current_def_id: String = ''    # the resolved EncounterDef id for the current beat (resume)
# The enemies drawn for the current beat (docs/plans/encounter_points_budget.md). Empty for a
# non-fight, a boss, or an unpooled act — the Encounter then uses the def's authored enemy_ids.
# Saved, because the RNG state is written AFTER the draw, so a resume cannot redraw the same set.
var _current_enemy_ids: Array[String] = []

## Dev and test only (docs/systems/autotest.md): when non-empty, EVERY fight uses these EnemyCatalog
## ids — bosses and authored compositions included — so a tuning run reads one composition rather
## than generation noise. Static so the autotest can set it before a run starts. Never set in play.
static var pinned_enemy_ids: Array[String] = []
var _pending_choice: Array[String] = []  # kept empty — the choice layer is dormant
var _pending_offer: Array[ItemDef] = []   # the held draft offer (1-of-3)
var _pending_relic_offer: Array[RelicDef] = []   # the relic encounter's offer (pick one)
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
  gold = 0
  _ended = false
  _pending_offer = []
  _pending_relic_offer = []
  _current_def_id = ''
  _pending_choice = []
  allies = []                  # no starting allies by default (the owner wires acquisition)
  _ally_def_ids = []
  _enter_beat(position)
  _save()


## Build the run-start player Actor from the character's starting board (#27). Run-lifetime,
## owned here. Max HP is the character's (the global default unless its def sets one).
func _make_starting_player() -> Actor:
  var actor: Actor = character.make_actor()
  for id in CharacterCatalog.starting_board(character, rng):
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


# --- the choice layer (DORMANT — every beat's encounter is set by the map; see _enter_beat) ----
# Every beat's encounter is fixed or drawn by the map (RunManager._enter_beat), so no beat produces a pending
# choice: has_pending_choice() is always false and these three are inert. They're kept so the run
# screen / autotest choice branch + the choice_overlay component stay wired for a possible future
# fork-beat (one that genuinely offers the player a pick). Remove them if that's ruled out.

## True only when a beat is waiting on a player pick — never, while the map sets every beat.
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
      _grant_relic()                                          # an act boss
    EncounterDef.Reward.RELIC_CHOICE:
      _pending_relic_offer = _draw_relic_offer()              # the relic encounter: pick one
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


## The relic encounter's offer: up to RELIC_OFFER_COUNT different relics from the reward pool,
## drawn on the run RNG (deterministic + resume-stable, like a draft).
func _draw_relic_offer() -> Array[RelicDef]:
  var pool: Array = RelicCatalog.REWARD_POOL.duplicate()
  var offer: Array[RelicDef] = []
  while not pool.is_empty() and offer.size() < RELIC_OFFER_COUNT:
    offer.append(RelicCatalog.get_def(pool.pop_at(rng.randi_range(0, pool.size() - 1))))
  return offer


func has_pending_relic_offer() -> bool:
  return not _pending_relic_offer.is_empty()


func pending_relic_offer() -> Array:
  return _pending_relic_offer


## Apply the player's pick from the relic offer: add the relic to run-state, apply its one-time
## effect, clear the offer.
func apply_relic_pick(index: int) -> void:
  if _pending_relic_offer.is_empty():
    return
  var relic := Relic.new(_pending_relic_offer[clampi(index, 0, _pending_relic_offer.size() - 1)])
  relics.append(relic)
  _apply_relic_grant(relic)
  _pending_relic_offer = []


## Apply a granted relic's ONE-TIME direct run-state mod (MAX_HP_BONUS raises max + current
## HP). Baked into the saved snapshot's hp/max_hp — NOT re-applied on rehydrate. A
## COMBAT_START_STATUS relic has no grant-time effect (it applies per fight, below).
func _apply_relic_grant(relic: Relic) -> void:
  if relic.def.kind == RelicDef.Kind.MAX_HP_BONUS:
    player.max_hp += roundi(relic.def.max_hp_bonus)
    player.hp += roundi(relic.def.max_hp_bonus)


func has_pending_draft() -> bool:
  return not _pending_offer.is_empty()


func pending_draft() -> Array:
  return _pending_offer


## Apply the player's draft pick (a draft-pick intent) — add the chosen item to the
## board, clear the offer. Skipping instead banks gold — apply_draft_skip.
func apply_draft_pick(index: int) -> void:
  if _pending_offer.is_empty():
    return
  var picked: ItemDef = _pending_offer[clampi(index, 0, _pending_offer.size() - 1)]
  player.board.append(Item.new(picked, player))
  _pending_offer = []


## Skip the pending draft (a draft-skip intent, the sibling of apply_draft_pick): bank a fixed
## amount of gold (Balance.GOLD_SKIP) instead of taking an item, then clear the offer. The escape
## hatch from an anti-synergy draft (docs decision #33 — reverses #17's no-skip). Draws no run RNG,
## like a pick.
func apply_draft_skip() -> void:
  if _pending_offer.is_empty():
    return
  gold += Balance.GOLD_SKIP
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
  return EnemyCatalog.get_def(def_id).make_actor()


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
    # The consume-before-advance invariant: a draft must be resolved — by a pick OR a skip
    # (docs decision #33) — before advancing. A caller that advances past one has a flow bug —
    # drop the offer loudly rather than carry it unsaved into the next beat.
    push_error('RunManager.advance: advancing past an unconsumed draft offer — dropping it')
    _pending_offer = []
  if not _pending_relic_offer.is_empty():
    push_error('RunManager.advance: advancing past an unconsumed relic offer — dropping it')
    _pending_relic_offer = []
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

## Set up the beat at `pos` (RunMap.beat_spec): a FIXED beat (an elite fight, the relic encounter,
## the boss) names its encounter; a DRAWN beat (a regular fight or an event) draws a def from its
## pool on the run RNG (deterministic + resume-stable). The encounter is live at once. Clears any
## prior beat's transient state.
func _enter_beat(pos: int) -> void:
  _current_def_id = ''
  _current_enemy_ids = []
  var spec: Dictionary = RunMap.beat_spec(pos, rng.seed)
  if spec['kind'] == RunMap.BeatKind.FIXED:
    _current_def_id = spec['id']
  else:
    var pool: Array = spec['pool']
    _current_def_id = pool[rng.randi_range(0, pool.size() - 1)]
  _current_enemy_ids = _draw_enemies(EncounterCatalog.get_def(_current_def_id))
  _create_current_encounter()


func _create_current_encounter() -> void:
  _current = Encounter.new(EncounterCatalog.get_def(_current_def_id), player, _combat_seed_for(position), allies, _current_enemy_ids)


## Draw the enemies for a generated fight (docs/plans/encounter_points_budget.md): add enemies from
## the act's pool on the run RNG until their points reach the beat's target, up to the enemy limit.
## The draw is random and ignores composition — positioning is handled later. A boss is not drawn:
## it takes the act's boss list (EnemyPools.BOSS). Returns empty, leaving the def's authored
## enemy_ids in place, for a non-fight, for a boss with an empty list and for an empty pool.
func _draw_enemies(def: EncounterDef) -> Array[String]:
  if def.type != EncounterDef.Type.FIGHT:
    return []
  if not pinned_enemy_ids.is_empty():
    return pinned_enemy_ids.duplicate()
  if _current_def_id == RunMap.boss_for(RunMap.act_of(position)):
    return EnemyPools.boss(RunMap.act_of(position))
  var target: float = RunMap.target_points(position)
  if def.reward == EncounterDef.Reward.ELITE:
    target *= Balance.POINTS_ELITE_MULTIPLIER
  return RunMap.draw_enemies(RunMap.enemy_pool(RunMap.act_of(position)), target, rng)


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
    'gold': gold,   # banked run-state (decision #33); optional on read (.get) — no migration
    # The current beat's encounter id (resume re-enters it, never redrawn).
    'current_def_id': _current_def_id,
    'current_enemy_ids': _current_enemy_ids,   # the drawn set — the RNG has already moved past it
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
  player = character.make_actor()
  player.max_hp = roundi(float(snap['max_hp']))
  player.hp = roundi(float(snap['hp']))
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
  gold = int(snap.get('gold', 0))   # absent in pre-gold snapshots → 0 (forward-compatible, no migration)
  rng = RandomNumberGenerator.new()
  rng.seed = int(snap['rng']['seed'])
  rng.state = int(snap['rng']['state'])
  _ended = false
  _pending_offer = []
  _pending_relic_offer = []
  _pending_choice = []
  # Restore the current beat's encounter exactly — never redraw it (no save-scum).
  _current_def_id = str(snap['current_def_id'])
  _current_enemy_ids = []
  for enemy_id: Variant in snap.get('current_enemy_ids', []):
    _current_enemy_ids.append(str(enemy_id))
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

## Dev and test only: move the run to beat `pos` and enter it, without playing the beats before it.
func jump_to(pos: int) -> void:
  _teardown_current()
  position = pos
  _enter_beat(pos)


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
