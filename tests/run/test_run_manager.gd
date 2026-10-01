extends GutTest
## Step 5 — the descent. A full short run reaches WON, drafts land on the board, a
## starting relic grants combat-start shield, a loss ends the run DIED, and a
## save-mid-run + rehydrate reproduces the exact continuation (deterministic
## resume — the no-save-scum property end to end).


var _runs: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()
  Save.clear()


func after_each() -> void:
  for r in _runs:
    if is_instance_valid(r):
      r.teardown()
      r.free()
  _runs.clear()
  Save.clear()
  TestCleanup.reset_all_managers()


# --- helpers ----------------------------------------------------------------

func _run() -> RunManager:
  var r := RunManager.new()
  _runs.append(r)
  return r


## Put an enchant on the first board item and a potion in the slot. The fixture character's
## starting kit carries neither, so the tests that exercise those paths grant them here.
func _grant_enchant_and_potion(run: RunManager) -> void:
  run.apply_enchant(Enchantment.new(FixtureKit.enchant()), 0)
  run.potions.append(Consumable.new(FixtureKit.potion()))


func _board_ids(actor: Actor) -> Array:
  var ids: Array = []
  for it in actor.board:
    ids.append(it.def.id)
  return ids


func _shield_count(actor: Actor) -> float:
  for s in actor.statuses:
    if s.id == 'shield':
      return s.count
  return 0.0


## Resolve one beat. At a choice of encounters, pick the fixture rest; begin the encounter; resolve
## an event by picking its first option; step a fight's CombatManager to a verdict; take the draft if offered;
## advance. (Mirrors the autotest run loop.) `pick` indexes the draft card.
func _play_one_beat(run: RunManager, pick: int) -> void:
  if run.has_pending_choice():
    run.pick_path(FixtureEncounters.CHOICE_REST)
  run.begin_current()
  var enc: Encounter = run.current_encounter()
  if enc != null and enc.is_event():
    run.pick_event_option(0)   # resolve the event with its first option
  var cm: CombatManager = run.combat_manager()
  if cm != null:
    cm.run_headless()
  if run.is_ended():
    return
  if run.has_pending_draft():
    run.apply_draft_pick(pick)
  run.advance()


## Hold an offer of items drawn from the player's pool, as a reward encounter would.
func _offer_items(run: RunManager) -> void:
  run._set_offer(Draft.draw(run._draft_pool(), run.position, run.rng))


## Start a run and walk past the opening choice of encounters, so the run is on its first fight.
func _start_at_fight(run: RunManager, seed_value: int) -> void:
  run.start(seed_value, FixtureCharacter.ID)
  run.skip_choice()
  run.advance()


func _play_to_end(run: RunManager, pick: int) -> void:
  var guard: int = 0
  while not run.is_ended() and guard < 100:
    _play_one_beat(run, pick)
    guard += 1


# --- tests ------------------------------------------------------------------

func test_full_run_reaches_won() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_eq(run.player.board.size(), 3, 'the fixture character has a three-item starting board')
  _play_to_end(run, 0)
  assert_true(run.is_ended(), 'the run resolved')
  assert_eq(run.outcome(), RunManager.Outcome.WON, 'the fixture build clears the multi-act map')


func test_draft_pick_lands_on_the_board() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  _offer_items(run)
  run.apply_draft_pick(0)
  assert_eq(run.player.board.size(), 4, 'the drafted item was added to the board')


func test_starting_relic_grants_fight_start_shield() -> void:
  var run := _run()
  _start_at_fight(run, 1)
  # Granted here: the fixture character has no starting relic, and this is about the hook.
  run.relics.append(Relic.new(FixtureKit.shield_relic()))
  # the first fight — begin it; the relic fires on step two and its shield
  # lands one delivery flight later.
  run.begin_current()
  assert_eq(run.player.relics.size(), 1, 'the player holds an item for the relic during the fight')
  var cm: CombatManager = run.combat_manager()
  var steps: int = 0
  while _shield_count(run.player) <= 0.0 and steps < 2 + Balance.TRAVEL_STEPS:
    cm.sim_step()
    steps += 1
  assert_almost_eq(_shield_count(run.player), FixtureKit.RELIC_SHIELD, 0.0001,
    'the relic gives its shield at the start of the fight')


func test_each_fight_gets_fresh_relic_items() -> void:
  var run := _run()
  _start_at_fight(run, 1)
  run.relics.append(Relic.new(FixtureKit.shield_relic()))
  run.begin_current()
  var first: Item = run.player.relics[0]
  run.combat_manager().run_headless()
  if run.has_pending_draft():
    run.apply_draft_pick(0)
  run.advance()
  assert_true(run.player.relics.is_empty(), 'the relic items leave with the fight when the run moves on')
  run.skip_choice()
  run.advance()
  run.begin_current()
  assert_not_null(run.combat_manager(), 'the next beat after the choice is a fight')
  assert_eq(run.player.relics.size(), 1, 'the next fight builds the relic item again')
  assert_ne(run.player.relics[0], first, 'as a new item, so its fire count starts at zero')


func test_loss_ends_run_died() -> void:
  var run := _run()
  _start_at_fight(run, 1)
  run.relics.clear()       # drop the protective relic so the glass player actually dies
  run.player.hp = 1
  watch_signals(run)
  _play_one_beat(run, 0)
  assert_true(run.is_ended())
  assert_eq(run.outcome(), RunManager.Outcome.DIED)
  assert_signal_emitted_with_parameters(run, 'run_ended', [RunManager.Outcome.DIED])


func test_save_and_rehydrate_reproduces_the_continuation() -> void:
  var run_a := _run()
  run_a.start(7, FixtureCharacter.ID)
  _play_one_beat(run_a, 0)        # clear beat 0 (the choice, the rest picked); position now 1, the first fight
  var snap: Dictionary = run_a.snapshot()
  _play_to_end(run_a, 0)
  var board_a := _board_ids(run_a.player)
  var outcome_a: int = run_a.outcome()

  var run_b := _run()
  run_b.rehydrate(snap)           # resume at the saved beat with the saved RNG state
  assert_eq(run_b.position, 1, 'resumed at the saved beat')
  _play_to_end(run_b, 0)
  assert_eq(_board_ids(run_b.player), board_a, 'the resumed run drafts the same items (no save-scum)')
  assert_eq(run_b.outcome(), outcome_a, 'and reaches the same outcome')


func test_relic_reward_grants_a_relic_from_the_pool() -> void:
  # The RELIC reward (a mid-boss / guaranteed-relic beat) grants a relic — it was a stub.
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var before: int = run.relics.size()
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  assert_eq(run.relics.size(), before + 1, 'a relic was granted')
  assert_true(run.relics[-1].def.id in RelicCatalog.REWARD_POOL, 'and it came from the reward pool')
  assert_false(run.has_pending_draft(), 'a relic-only beat offers no draft')


func test_elite_reward_grants_a_relic() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var before: int = run.relics.size()
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.ELITE)
  assert_eq(run.relics.size(), before + 1, 'an elite grants a relic')
  assert_false(run.has_pending_draft(), 'and offers no draft')


func test_a_regular_fight_offers_no_draft() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.NONE)
  assert_false(run.has_pending_draft(), 'a won fight gives its gold and offers nothing to pick')


func test_max_hp_relic_grant_raises_max_and_current_hp() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var before_max: int = run.player.max_hp
  var before_hp: int = run.player.hp
  var charm := Relic.new(FixtureKit.max_hp_relic())
  run.relics.append(charm)
  run._apply_relic_grant(charm)
  assert_eq(run.player.max_hp, before_max + FixtureKit.RELIC_MAX_HP, 'max HP grew')
  assert_eq(run.player.hp, before_hp + FixtureKit.RELIC_MAX_HP, 'and current HP too')


# --- relic run triggers (docs/systems/content.md → Relic) ----------------------

## A relic with one run trigger entry.
func _run_trigger_relic(event: RunManager.RunEvent, effects: Array[RunEffect]) -> RelicDef:
  var d := RelicDef.new()
  d.id = 'test_run_trigger_relic'
  d.run_triggers = [{'event': event, 'effects': effects}]
  return d


func test_starting_relic_fires_its_pickup_trigger() -> void:
  var plain := _run()
  plain.start(1, FixtureCharacter.ID)
  CharacterCatalog.get_def(FixtureCharacter.ID).starting_relic_id = FixtureKit.MAX_HP_RELIC_ID
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_eq(run.player.max_hp, plain.player.max_hp + FixtureKit.RELIC_MAX_HP,
      'the starting relic raises maximum health like a granted one')


func test_pickup_trigger_is_not_applied_again_on_resume() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var charm := Relic.new(FixtureKit.max_hp_relic())
  run.relics.append(charm)
  run._apply_relic_grant(charm)
  var max_after: int = run.player.max_hp
  var run_b := _run()
  run_b.rehydrate(run.snapshot())
  assert_eq(run_b.player.max_hp, max_after, 'the raised maximum is loaded, not raised again')


func test_fight_won_trigger_fires_after_a_won_fight_only() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.relics.append(Relic.new(_run_trigger_relic(RunManager.RunEvent.FIGHT_WON, [RunEffect.gold(3)])))
  run._on_encounter_resolved(Encounter.Outcome.RESOLVED, EncounterDef.Reward.NONE)
  assert_eq(run.gold, 0, 'a rest or event is not a won fight')
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.NONE)
  assert_eq(run.gold, Balance.FIGHT_WON_GOLD + 3, 'a won fight adds the relic gold to the fight-won gold')


func test_lethal_fight_won_damage_ends_the_run_before_the_reward() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.relics.append(Relic.new(_run_trigger_relic(RunManager.RunEvent.FIGHT_WON, [RunEffect.damage(100000)])))
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.NONE)
  assert_true(run.is_ended(), 'the run ends at once')
  assert_eq(run.outcome(), RunManager.Outcome.DIED, 'as a death')
  assert_false(run.has_pending_draft(), 'with no draft offered')


func test_lethal_draft_skipped_damage_ends_the_run() -> void:
  var run := _run()
  _start_at_fight(run, 1)
  run.relics.append(Relic.new(_run_trigger_relic(RunManager.RunEvent.DRAFT_SKIPPED, [RunEffect.damage(100000)])))
  _offer_items(run)
  run.apply_draft_skip()
  assert_true(run.is_ended(), 'skipping the draft kills the player and ends the run')
  assert_eq(run.outcome(), RunManager.Outcome.DIED, 'as a death')


func test_relic_won_from_a_fight_does_not_react_to_that_fight() -> void:
  for id: String in RelicCatalog.REWARD_POOL:
    var d := _run_trigger_relic(RunManager.RunEvent.FIGHT_WON, [RunEffect.gold(3)])
    d.id = id
    RelicCatalog._defs[id] = d
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  assert_eq(run.relics[-1].def.run_triggers[0]['event'], RunManager.RunEvent.FIGHT_WON, 'the fight-won relic was granted')
  assert_eq(run.gold, Balance.FIGHT_WON_GOLD, 'but the fight that granted it does not count')


func test_draft_skipped_trigger_adds_to_the_skip_gold() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.relics.append(Relic.new(_run_trigger_relic(RunManager.RunEvent.DRAFT_SKIPPED, [RunEffect.gold(4)])))
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.NONE)
  _offer_items(run)
  run.apply_draft_skip()
  assert_eq(run.gold, Balance.FIGHT_WON_GOLD + Balance.GOLD_SKIP + 4, 'the fight-won gold, the skip gold and the relic gold')


func test_run_heal_is_capped_at_maximum_health() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.relics.append(Relic.new(_run_trigger_relic(RunManager.RunEvent.FIGHT_WON, [RunEffect.heal(5)])))
  run.player.hp = run.player.max_hp - 2
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.NONE)
  assert_eq(run.player.hp, run.player.max_hp, 'healed to full, not past it')
  run.player.hp = run.player.max_hp - 40
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.NONE)
  assert_eq(run.player.hp, run.player.max_hp - 40 + Balance.FIGHT_WON_HEAL + 5,
    'healed by the relic amount on top of the fight-won heal')


func test_relic_grant_is_deterministic_by_seed() -> void:
  var run_a := _run()
  run_a.start(99, FixtureCharacter.ID)
  run_a._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  var run_b := _run()
  run_b.start(99, FixtureCharacter.ID)
  run_b._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  assert_eq(run_a.relics[-1].def.id, run_b.relics[-1].def.id, 'same seed grants the same relic (no save-scum)')


func test_granted_relic_survives_save_and_resume() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  var granted_id: String = run.relics[-1].def.id
  var max_after: int = run.player.max_hp
  var snap: Dictionary = run.snapshot()

  var run_b := _run()
  run_b.rehydrate(snap)
  var ids: Array = []
  for r in run_b.relics:
    ids.append(r.def.id)
  assert_true(granted_id in ids, 'the granted relic is restored on resume')
  assert_eq(run_b.player.max_hp, roundi(max_after), 'a max-HP grant is baked into the snapshot, not re-applied')


func test_per_fight_seed_is_seed_based_not_stream_based() -> void:
  # The per-fight combat seed derives from the run SEED (constant, saved), not the
  # evolving run stream — so it is resume-stable and doesn't shift as draft draws consume
  # the stream (decision #20).
  var run := _run()
  run.start(42, FixtureCharacter.ID)
  var s0: int = run._combat_seed_for(2)
  run.rng.randi()
  run.rng.randi()                     # advance the run stream
  assert_eq(run._combat_seed_for(2), s0, 'deriving the per-fight seed ignores the run stream state')


func test_per_fight_seeds_differ_by_beat() -> void:
  var run := _run()
  run.start(42, FixtureCharacter.ID)
  assert_ne(run._combat_seed_for(0), run._combat_seed_for(1), 'each beat gets its own combat stream')


func test_fight_rng_is_seeded_from_the_beat_seed() -> void:
  var run := _run()
  _start_at_fight(run, 5)
  run.begin_current()                 # the first fight, live and seeded
  assert_eq(run.combat_manager().rng.seed, run._combat_seed_for(run.position),
    'the fight RNG is seeded from the derived per-beat seed')


func test_resumed_run_derives_the_same_per_fight_seed() -> void:
  # End to end: a fight re-entered from a save uses the identical combat seed, so its
  # random targeting replays exactly (no save-scumming a bad random outcome).
  var run := _run()
  run.start(7, FixtureCharacter.ID)
  _play_one_beat(run, 0)              # advance to beat 1
  var seed_a: int = run._combat_seed_for(run.position)
  var snap: Dictionary = run.snapshot()

  var run_b := _run()
  run_b.rehydrate(snap)
  assert_eq(run_b.position, run.position, 'resumed at the same beat')
  assert_eq(run_b._combat_seed_for(run_b.position), seed_a, 'and derives the identical per-fight seed')


# --- run-scoped allies (docs/systems/spore_engine.md Cap 3, Stage B) ---------------------

func test_ally_persists_through_save_and_resume() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.add_ally(FixtureEnemies.ALLY_ID)
  run.allies[0].take_damage(5.0)   # mid-run damage — deliberately NOT persisted
  var run_b := _run()
  run_b.rehydrate(run.snapshot())
  assert_eq(run_b.allies.size(), 1, 'the ally is restored on resume')
  # An ally's HP is not saved: allies are revived to full at every fight begin (only the
  # player carries HP attrition), so resume rebuilds the ally at full.
  assert_eq(run_b.allies[0].hp, run_b.allies[0].max_hp, 'rebuilt at full HP')
  assert_eq(run_b.allies[0].board.size(), 1, 'and its board (rebuilt from the def)')


func test_between_act_full_heal_revives_allies() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.add_ally(FixtureEnemies.ALLY_ID)
  run.allies[0].take_damage(10.0)
  run.skip_choice()
  run.position = RunMap.BEATS_PER_ACT - 1
  run.advance()                    # cross into the next act
  assert_eq(run.allies[0].hp, run.allies[0].max_hp, 'the between-act restore heals allies too')


func test_run_scoped_allies_revive_to_full_each_fight() -> void:
  # Allies revive between combats (only the player carries HP attrition) — a downed ally enters
  # the next fight at full HP.
  var run := _run()
  _start_at_fight(run, 5)
  run.add_ally(FixtureEnemies.ALLY_ID)
  run.allies[0].take_damage(run.allies[0].max_hp)   # down it
  assert_false(run.allies[0].is_alive(), 'the ally is downed')
  run.begin_current()                               # the first fight
  assert_eq(run.allies[0].hp, run.allies[0].max_hp, 'the ally enters the fight revived to full')


func test_add_ally_mid_fight_joins_the_live_combat() -> void:
  var run := _run()
  _start_at_fight(run, 5)
  run.begin_current()                     # the first fight
  var cm: CombatManager = run.combat_manager()
  assert_not_null(cm, 'a live fight is running')
  run.add_ally(FixtureEnemies.ALLY_ID)
  assert_true(run.allies[0] in cm.allies, 'the ally joined the live fight (shared roster)')
  for _i in 3:
    cm.sim_step()
  assert_gt(run.allies[0].board[0].cooldown.accum, 0.0, 'and its items fight (registered mid-fight)')


func test_run_scoped_ally_dissolved_at_run_teardown() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.add_ally(FixtureEnemies.ALLY_ID)
  var weak_ally: WeakRef = weakref(run.allies[0])
  var weak_item: WeakRef = weakref(run.allies[0].board[0])
  run.teardown()
  assert_null(weak_ally.get_ref(), 'a run-scoped ally frees at run end (its cycle is broken)')
  assert_null(weak_item.get_ref(), 'and its board items free')


# --- ally acquisition via a recruit EVENT (the event-driven path) ------------

## Drive a freshly-created EVENT beat to a chosen option (deterministic, seed-independent):
## set the current def + create the encounter, begin it, pick the option through the RunManager.
func _resolve_event(run: RunManager, def_id: String, option: int) -> void:
  run._teardown_current()   # drop any current encounter before swapping in the event
  run._current_def_id = def_id
  run._create_current_encounter()
  run.begin_current()
  run.pick_event_option(option)


func test_recruit_event_adds_a_run_scoped_ally() -> void:
  # The option with an ADD_ALLY effect, applied by RunManager.pick_event_option, recruits a run-scoped
  # ally (the event-driven acquisition path) — it then joins every later fight + persists.
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_eq(run.allies.size(), 0, 'no allies before the event')
  _resolve_event(run, FixtureEncounters.EVENT, FixtureEncounters.OPTION_ADD_ALLY)
  assert_eq(run.allies.size(), 1, 'the recruit event added a run-scoped ally')
  assert_eq(run.allies[0].board.size(), 1, 'the ally was built from its EnemyDef board')


func test_recruit_event_declined_adds_no_ally() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.player.take_damage(30.0)
  var hurt: int = run.player.hp
  _resolve_event(run, FixtureEncounters.EVENT, FixtureEncounters.OPTION_HEAL)
  assert_eq(run.allies.size(), 0, 'declining recruits no ally')
  assert_gt(run.player.hp, hurt, 'and the decline heals a little (the player-Actor outcome still applies)')


func test_add_ally_respects_the_four_slot_cap() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  for _i in RunManager.MAX_ALLIES:
    run.add_ally(FixtureEnemies.ALLY_ID)
  assert_eq(run.allies.size(), RunManager.MAX_ALLIES, 'the four ally slots fill')
  assert_false(run.can_add_ally(), 'and report full')
  run.add_ally(FixtureEnemies.ALLY_ID)   # one past the cap
  assert_eq(run.allies.size(), RunManager.MAX_ALLIES, 'a 5th recruit is a no-op (the cap holds)')


# --- event options and run effects (docs/plans/encounter_choice.md) ------------

## Add an event under `id` to the catalog with one option per entry of `options`, each
## { 'effects': Array[RunEffect], 'requires': Array[RunCondition] } (either key may be left out).
func _test_event(id: String, options: Array) -> EncounterDef:
  var def := FixtureEncounters.event(id)
  def.event_options = []
  for spec: Dictionary in options:
    var option := EventOptionDef.new()
    option.label_key = 'Option'
    option.effects.assign(spec.get('effects', []))
    option.requires.assign(spec.get('requires', []))
    def.event_options.append(option)
  EncounterCatalog._defs[id] = def
  return def


func test_max_hp_option_grows_max_and_current_hp() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var before_max: int = run.player.max_hp
  var before_hp: int = run.player.hp
  _resolve_event(run, FixtureEncounters.EVENT, FixtureEncounters.OPTION_MAX_HP)
  assert_eq(run.player.max_hp, before_max + FixtureEncounters.EVENT_MAX_HP, 'max HP grew')
  assert_eq(run.player.hp, before_hp + FixtureEncounters.EVENT_MAX_HP, 'and current HP too')


func test_an_option_applies_every_effect() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.gold = 5
  var board_size: int = run.player.board.size()
  _test_event('test_trade', [{ 'effects': [RunEffect.gold(-3), RunEffect.gain_item(FixtureItems.attack().id)] }])
  _resolve_event(run, 'test_trade', 0)
  assert_eq(run.gold, 2, 'the option cost gold')
  assert_eq(run.player.board.size(), board_size + 1, 'and gave an item')


func test_run_effects_change_the_run() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.player.hp = 50
  run._apply_run_effect(RunEffect.heal_fraction(0.1))
  assert_eq(run.player.hp, 50 + roundi(0.1 * run.player.max_hp), 'HEAL_FRACTION heals a fraction of maximum health')
  run._apply_run_effect(RunEffect.damage(7))
  assert_eq(run.player.hp, 43 + roundi(0.1 * run.player.max_hp), 'DAMAGE takes health')
  run._apply_run_effect(RunEffect.add_ally(FixtureEnemies.ALLY_ID))
  assert_eq(run.allies.size(), 1, 'ADD_ALLY adds an ally')
  run._apply_run_effect(RunEffect.set_flag('test_flag', 4))
  assert_eq(run.flag('test_flag'), 4, 'SET_FLAG sets a flag')
  run._apply_run_effect(RunEffect.add_flag('test_flag', 2))
  run._apply_run_effect(RunEffect.add_flag('test_other'))
  assert_eq(run.flag('test_flag'), 6, 'ADD_FLAG adds to a flag')
  assert_eq(run.flag('test_other'), 1, 'and starts an unset one from 0')
  run._apply_run_effect(RunEffect.gain_potion(FixtureKit.POTION_ID))
  assert_eq(run.potions[-1].def.id, FixtureKit.POTION_ID, 'GAIN_POTION adds a potion')


func test_gain_relic_fires_the_relics_pickup_trigger() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var before_max: int = run.player.max_hp
  run._apply_run_effect(RunEffect.gain_relic(FixtureKit.MAX_HP_RELIC_ID))
  assert_eq(run.relics[-1].def.id, FixtureKit.MAX_HP_RELIC_ID, 'the relic is held')
  assert_eq(run.player.max_hp, before_max + FixtureKit.RELIC_MAX_HP, 'and its pickup trigger fired')


func test_a_lethal_option_ends_the_run_died() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  _test_event('test_deathtrap', [{ 'effects': [RunEffect.damage(9999)] }])
  _resolve_event(run, 'test_deathtrap', 0)
  assert_true(run.is_ended(), 'the run ends at once')
  assert_eq(run.outcome(), RunManager.Outcome.DIED, 'as a loss')


func test_an_option_whose_conditions_fail_is_hidden_and_cannot_be_picked() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  _test_event('test_locked', [
    { 'effects': [RunEffect.gold(10)], 'requires': [GoldAtLeast.new(999)] },
    { 'effects': [RunEffect.gold(1)] },
  ])
  _resolve_event(run, 'test_locked', 0)
  assert_eq(run.available_event_options(), [1] as Array[int], 'only the second option is available')
  assert_eq(run.gold, 0, 'the locked option gave nothing')
  var watched: Encounter = run.current_encounter()
  watch_signals(watched)
  run.pick_event_option(1)
  assert_eq(run.gold, 1, 'the available option is picked')
  assert_signal_emitted(watched, 'resolved', 'and the event resolves')


func test_an_event_with_no_available_option_is_never_offered() -> void:
  for option: EventOptionDef in EncounterCatalog.get_def(FixtureEncounters.EVENT).event_options:
    option.requires = [GoldAtLeast.new(999)]
  for run_seed: int in range(10):
    var run := _run()
    run.start(run_seed, FixtureCharacter.ID)
    assert_false(FixtureEncounters.EVENT in run.pending_choice(), 'no option could be picked, so the event is left out')


func test_acting_once_unlocks_a_reward_on_a_later_visit() -> void:
  # The first visit offers to leave an offering (sets a flag, gives nothing); a later visit offers
  # to take it back, which needs the flag and gives a relic. Walking on is always there.
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  _test_event('test_shrine', [
    { 'effects': [RunEffect.set_flag('offering_left')], 'requires': [FlagBelow.new('offering_left')] },
    { 'effects': [RunEffect.gain_relic(FixtureKit.SHIELD_RELIC_ID)], 'requires': [FlagAtLeast.new('offering_left')] },
    {},
  ])
  var relic_count: int = run.relics.size()
  _resolve_event(run, 'test_shrine', 0)
  assert_eq(run.flag('offering_left'), 1, 'the offering is remembered')
  assert_eq(run.relics.size(), relic_count, 'and gave nothing yet')
  run._teardown_current()
  run._current_def_id = 'test_shrine'
  run._create_current_encounter()
  run.begin_current()
  assert_eq(run.available_event_options(), [1, 2] as Array[int], 'a later visit offers to take it back')
  run.pick_event_option(1)
  assert_eq(run.relics.size(), relic_count + 1, 'which gives the relic')


func test_flags_and_times_picked_survive_save_and_resume() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run._apply_run_effect(RunEffect.set_flag('test_flag', 3))
  run.pick_path(FixtureEncounters.CHOICE_REST)
  run.begin_current()
  run.advance()
  var snap: Dictionary = JSON.parse_string(JSON.stringify(run.snapshot()))   # as a save file reads back
  var run_b := _run()
  assert_true(run_b.rehydrate(snap), 'the save is usable')
  assert_eq(run_b.flag('test_flag'), 3, 'the flag is restored')
  assert_eq(run_b.times_picked.get(FixtureEncounters.REST), 1, 'and the pick count')
  assert_eq(typeof(run_b.times_picked[FixtureEncounters.REST]), TYPE_INT, 'as a whole number')
  assert_true(TimesPicked.new(FixtureEncounters.REST).holds(run_b), 'so conditions read it after resume')


# --- the map (docs/plans/encounter_choice.md) ---------------------------------

func test_a_choice_comes_before_every_square() -> void:
  assert_eq(RunMap.BEATS_PER_ACT, RunMap.SQUARES.size() * 2, 'a choice beat and a square for every square')
  assert_eq(RunMap.TOTAL_FIGHTS, RunMap.ACTS * RunMap.SQUARES.size(), 'every square is a fight')
  assert_eq(RunMap.SQUARES[-1], RunMap.Square.BOSS, 'the act ends on the boss')
  for position: int in RunMap.TOTAL_BEATS:
    var beat: int = RunMap.beat_in_act(position)
    if beat % 2 == 0:
      assert_eq(int(RunMap.beat_spec(position)['kind']), RunMap.BeatKind.CHOICE, 'an even beat is a choice')
    else:
      assert_eq(RunMap.square_at(position), floori(beat / 2.0), 'an odd beat is the square after the choice')


func test_fixed_squares_name_their_encounters() -> void:
  for square: int in RunMap.SQUARES.size():
    var spec: Dictionary = RunMap.beat_spec(square * 2 + 1)
    match RunMap.SQUARES[square]:
      RunMap.Square.ELITE:
        assert_eq(spec['id'], RunMap.ELITE_ENCOUNTER_ID, 'an elite square names the elite fight')
      RunMap.Square.BOSS:
        assert_eq(spec['id'], 'fight_boss', 'the boss square names the boss fight')
        assert_eq(square * 2 + 1, RunMap.BOSS_BEAT, 'at the act\'s last beat')
      _:
        assert_eq(int(spec['kind']), RunMap.BeatKind.DRAWN, 'a regular fight is drawn from a pool')
  assert_true(RunMap.is_final_beat(RunMap.TOTAL_BEATS - 1), 'the last beat is the finale')


func test_fight_number_counts_the_fights() -> void:
  assert_eq(RunMap.fight_number(0), 0, 'the choice before the first fight counts as that fight')
  assert_eq(RunMap.fight_number(1), 0, 'the first fight')
  assert_eq(RunMap.fight_number(3), 1, 'the second fight')
  assert_eq(RunMap.fight_number(RunMap.BOSS_BEAT), RunMap.SQUARES.size() - 1, 'the boss is the last fight of the act')


# --- the choice of encounters before each fight (docs/plans/encounter_choice.md) ----------------

func test_the_run_opens_on_a_choice_of_three() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_true(run.has_pending_choice(), 'a choice of encounters comes before the first fight')
  assert_null(run.current_encounter(), 'with no encounter until one is picked')
  var expected: Array[String] = [FixtureEncounters.REST, FixtureEncounters.EVENT, FixtureEncounters.REWARD]
  assert_eq(run.pending_choice(), expected, 'one from each position list, left to right')


func test_picking_an_encounter_makes_it_the_beat() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.pick_path(FixtureEncounters.CHOICE_EVENT)
  assert_false(run.has_pending_choice(), 'the choice is made')
  assert_eq(run.current_encounter().def.id, FixtureEncounters.EVENT, 'the picked encounter is the beat')
  assert_eq(Save.read()['current_def_id'], FixtureEncounters.EVENT, 'and is saved, so a resume re-enters it')


func test_walking_past_banks_gold_and_leads_to_the_fight() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.skip_choice()
  assert_eq(run.gold, Balance.ENCOUNTER_SKIP_GOLD, 'walking past banks the skip gold')
  assert_false(run.has_pending_choice(), 'the choice is over')
  assert_null(run.current_encounter(), 'with no encounter')
  run.advance()
  assert_true(run.current_encounter().is_fight(), 'the next beat is the fight')


func test_an_empty_position_takes_an_encounter_from_the_other_lists() -> void:
  EncounterPools._positions = [[], [FixtureEncounters.EVENT], [FixtureEncounters.REST, FixtureEncounters.REWARD]]
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var offer: Array = run.pending_choice()
  assert_eq(offer[1], FixtureEncounters.EVENT, 'a position with its own list draws from it')
  assert_false('' in offer, 'the empty position is filled from the other lists')
  assert_ne(offer[0], offer[2], 'and no encounter is offered twice')


func test_too_few_encounters_leave_a_position_empty() -> void:
  EncounterPools._positions = [[], [FixtureEncounters.EVENT], []]
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var expected: Array[String] = ['', FixtureEncounters.EVENT, '']
  assert_eq(run.pending_choice(), expected, 'only one encounter can be offered')
  run.pick_path(0)
  assert_true(run.has_pending_choice(), 'an empty position cannot be picked')


func test_with_nothing_to_offer_the_choice_is_skipped() -> void:
  EncounterPools._positions = [[], [], []]
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_false(run.has_pending_choice(), 'no choice is offered')
  assert_null(run.current_encounter(), 'and the beat has no encounter, so the caller advances')


## Add a fixture rest under `id` to the catalog, for a draw test that needs more encounters.
func _extra_encounter(id: String) -> EncounterDef:
  var def := FixtureEncounters.rest(id)
  EncounterCatalog._defs[id] = def
  return def


func test_an_encounter_the_player_cannot_choose_is_never_offered() -> void:
  _extra_encounter('test_extra')
  EncounterCatalog.get_def(FixtureEncounters.EVENT).requires = [GoldAtLeast.new(999)]
  EncounterPools._positions = [[FixtureEncounters.REST], [FixtureEncounters.EVENT, 'test_extra'], [FixtureEncounters.REWARD]]
  for run_seed: int in range(20):
    var run := _run()
    run.start(run_seed, FixtureCharacter.ID)
    assert_false(FixtureEncounters.EVENT in run.pending_choice(), 'the event needs gold the player lacks')
    assert_false('' in run.pending_choice(), 'and the offer is still three')


func test_an_encounter_is_offered_once_its_requirements_hold() -> void:
  EncounterCatalog.get_def(FixtureEncounters.EVENT).requires = [GoldAtLeast.new(5)]
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_false(FixtureEncounters.EVENT in run.pending_choice(), 'not while the player lacks the gold')
  run.gold = 5
  run.skip_choice()
  run.advance()   # the first fight
  run.advance()   # the choice before the second, drawn with the gold in hand
  assert_true(FixtureEncounters.EVENT in run.pending_choice(), 'offered once the requirement holds')


func test_a_rare_encounter_is_offered_less_often_than_a_common_one() -> void:
  var common := _extra_encounter('test_common')
  var rare := _extra_encounter('test_rare')
  rare.rarity = EncounterDef.Rarity.RARE
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var ids: Array[String] = [common.id, rare.id]
  var rare_count: int = 0
  for _i in 400:
    if run._draw_one(ids, []) == rare.id:
      rare_count += 1
  assert_gt(rare_count, 0, 'a rare encounter is still offered')
  assert_lt(rare_count, 200 - 40, 'but clearly less often than the common one')


func test_the_offer_survives_resume() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var offer: Array = run.pending_choice().duplicate()
  var run_b := _run()
  assert_true(run_b.rehydrate(run.snapshot()), 'a save at a choice beat is usable')
  assert_eq(run_b.pending_choice(), offer, 'the offered encounters are restored, not redrawn')
  assert_null(run_b.current_encounter(), 'and no encounter is created until one is picked')


func test_the_drawn_beat_survives_resume() -> void:
  # The current beat's drawn def round-trips the snapshot, so a resumed run re-enters the same
  # encounter (no save-scum).
  var run := _run()
  _start_at_fight(run, 1)
  var def_id: String = run._current_def_id
  var run_b := _run()
  run_b.rehydrate(run.snapshot())
  assert_eq(run_b._current_def_id, def_id, 'the drawn encounter is restored (not redrawn)')


func test_the_reward_encounter_offers_its_stock() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.pick_path(FixtureEncounters.CHOICE_REWARD)
  assert_eq(run._current_def_id, FixtureEncounters.REWARD, 'the reward encounter was picked')
  run.begin_current()
  assert_true(run.has_pending_draft(), 'the reward encounter resolves at once with an offer')
  var offer: Array = run.pending_draft()
  assert_eq(offer.size(), mini(FixtureEncounters.REWARD_RELICS, RelicCatalog.REWARD_POOL.size()), 'up to three relics')
  var picked: RelicDef = offer[1]
  var before: int = run.relics.size()
  run.apply_draft_pick(1)
  assert_eq(run.relics.size(), before + 1, 'the pick adds one relic')
  assert_eq(run.relics[-1].def, picked, 'the one picked')
  assert_false(run.has_pending_draft(), 'and clears the offer')


# --- the shop (docs/systems/encounter.md → Shops) -------------------------------

## Start a run whose opening choice has the fixture shop on the left, and walk into the shop.
func _start_in_shop(run: RunManager, gold: int) -> void:
  EncounterPools._positions = [[FixtureEncounters.SHOP], [FixtureEncounters.EVENT], [FixtureEncounters.REWARD]]
  run.start(1, FixtureCharacter.ID)
  run.gold = gold
  run.pick_path(0)
  run.begin_current()


func test_a_shop_opens_with_goods_from_its_stock() -> void:
  var run := _run()
  _start_in_shop(run, 0)
  assert_true(run.has_open_shop(), 'the shop opens when it begins')
  var goods: Array = run.shop_goods()
  assert_eq(goods.size(), FixtureEncounters.SHOP_ITEMS + 2, 'its items, a relic and a potion')
  assert_true(goods[-2] is RelicDef, 'the relic')
  assert_true(goods[-1] is ConsumableDef, 'the potion')
  assert_false(run.has_pending_draft(), 'a shop is not a draft')


func test_buying_pays_the_price_and_gives_the_good() -> void:
  var run := _run()
  _start_in_shop(run, 100)
  var board: int = run.player.board.size()
  var price: int = RunManager.price_of(run.shop_goods()[0])
  assert_true(run.buy(0), 'an affordable good is bought')
  assert_eq(run.gold, 100 - price, 'its price is paid')
  assert_eq(run.player.board.size(), board + 1, 'the item goes on the board')
  assert_true(run.is_sold(0), 'and is sold')
  assert_false(run.buy(0), 'so it cannot be bought again')
  assert_eq(run.gold, 100 - price, 'and no more gold is taken')


func test_a_good_the_player_cannot_afford_is_not_bought() -> void:
  var run := _run()
  _start_in_shop(run, 0)
  var board: int = run.player.board.size()
  assert_false(run.can_buy(0), 'no gold, no sale')
  assert_false(run.buy(0), 'the purchase is refused')
  assert_eq(run.player.board.size(), board, 'nothing was gained')
  assert_eq(run.gold, 0, 'and nothing paid')


func test_buying_relics_and_potions() -> void:
  var run := _run()
  _start_in_shop(run, 100)
  var relic: RelicDef = run.shop_goods()[-2]
  var potions: int = run.potions.size()
  run.buy(run.shop_goods().size() - 2)
  run.buy(run.shop_goods().size() - 1)
  assert_eq(run.relics[-1].def, relic, 'the relic is held')
  assert_false(relic.id in run.relic_pool(), 'and leaves the relic pool')
  assert_eq(run.potions.size(), potions + 1, 'the potion is added')


func test_leaving_the_shop_closes_it() -> void:
  var run := _run()
  _start_in_shop(run, 0)
  run.leave_shop()
  assert_false(run.has_open_shop(), 'the shop is closed')
  run.advance()
  assert_false(run.is_ended(), 'and the run goes on to the fight')


func test_a_resumed_shop_has_the_same_goods_and_the_gold_unspent() -> void:
  var run := _run()
  EncounterPools._positions = [[FixtureEncounters.SHOP], [FixtureEncounters.EVENT], [FixtureEncounters.REWARD]]
  run.start(1, FixtureCharacter.ID)
  run.gold = 100
  run.pick_path(0)   # saves the picked shop
  var snap: Dictionary = run.snapshot()
  run.begin_current()
  run.buy(0)
  var run_b := _run()
  run_b.rehydrate(snap)
  run_b.begin_current()
  assert_eq(run_b.shop_goods(), run.shop_goods(), 'the same goods')
  assert_eq(run_b.gold, 100, 'with the gold as it was when the shop was picked')
  assert_false(run_b.is_sold(0), 'and nothing sold')


func test_a_reroll_pays_and_draws_every_good_again() -> void:
  var run := _run()
  _start_in_shop(run, 100)
  run.buy(0)
  var gold: int = run.gold
  assert_eq(run.reroll_price(), Balance.SHOP_REROLL_PRICE, 'the first reroll costs the base price')
  assert_true(run.reroll_shop(), 'the reroll is made')
  assert_eq(run.gold, gold - Balance.SHOP_REROLL_PRICE, 'and paid for')
  assert_eq(run.shop_goods().size(), FixtureEncounters.SHOP_ITEMS + 2, 'the stock is drawn again')
  assert_false(run.is_sold(0), 'the bought good is replaced too')
  assert_eq(run.reroll_price(), Balance.SHOP_REROLL_PRICE + Balance.SHOP_REROLL_PRICE_STEP,
    'the next reroll costs one step more')


func test_a_reroll_the_player_cannot_afford_changes_nothing() -> void:
  var run := _run()
  _start_in_shop(run, 0)
  var goods: Array = run.shop_goods().duplicate()
  assert_false(run.can_reroll(), 'no gold, no reroll')
  assert_false(run.reroll_shop(), 'the reroll is refused')
  assert_eq(run.shop_goods(), goods, 'the goods stay')
  assert_eq(run.gold, 0, 'and nothing is paid')


func test_a_shop_stays_open_when_a_reroll_draws_nothing() -> void:
  var run := _run()
  _start_in_shop(run, 100)
  run.current_encounter().def.stock = [StockEntry.relics(1)]
  for id: String in RelicCatalog.REWARD_POOL:
    run.relics.append(Relic.new(RelicCatalog.get_def(id)))   # every reward relic held: the pool is empty
  assert_true(run.reroll_shop(), 'the reroll is made')
  assert_true(run.shop_goods().is_empty(), 'it draws nothing')
  assert_true(run.has_open_shop(), 'and the shop is still open until the player leaves')


func test_leaving_a_shop_resets_its_reroll_price() -> void:
  var run := _run()
  _start_in_shop(run, 100)
  run.reroll_shop()
  run.leave_shop()
  assert_false(run.can_reroll(), 'a closed shop cannot be rerolled')
  assert_eq(run.reroll_price(), Balance.SHOP_REROLL_PRICE, 'and the price is back to the base')


# --- selling items (docs/systems/run_manager.md → Selling) ----------------------

func test_an_item_sells_for_its_share_of_the_shop_price() -> void:
  var def: ItemDef = FixtureItems.attack()
  for rarity: int in [ItemDef.Rarity.COMMON, ItemDef.Rarity.UNCOMMON, ItemDef.Rarity.RARE]:
    def.rarity = rarity
    assert_eq(RunManager.sell_price(Item.new(def)), floori(Balance.SHOP_PRICE_ITEM[rarity] * Balance.SELL_SHARE),
      'half the shop price, rounded down')


func test_selling_an_item_outside_a_fight_pays_and_removes_it() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)   # at the opening choice of encounters
  var item: Item = run.player.board[0]
  var board: int = run.player.board.size()
  var gold: int = run.gold
  assert_true(run.can_sell(item), 'an item can be sold outside a fight')
  assert_true(run.sell_item(item), 'the sale is made')
  assert_eq(run.gold, gold + RunManager.sell_price(item), 'the player is paid')
  assert_eq(run.player.board.size(), board - 1, 'the item leaves the board')
  assert_null(item.owner, 'and is dissolved')
  assert_false(run.sell_item(item), 'so it cannot be sold again')


func test_the_last_item_can_be_sold() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  while not run.player.board.is_empty():
    assert_true(run.sell_item(run.player.board[0]), 'every item sells')
  assert_true(run.player.board.is_empty(), 'leaving the board empty')


func test_items_cannot_be_sold_during_a_fight() -> void:
  var run := _run()
  _start_at_fight(run, 1)
  run.begin_current()
  var item: Item = run.player.board[0]
  assert_false(run.can_sell(item), 'not while the fight is under way')
  assert_false(run.sell_item(item), 'the sale is refused')
  assert_true(item in run.player.board, 'and the item stays')
  run.combat_manager().run_headless()
  assert_true(run.can_sell(item), 'once the fight is over it can be sold')


func test_an_item_not_on_the_board_cannot_be_sold() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var gold: int = run.gold
  assert_false(run.sell_item(Item.new(FixtureItems.attack(), run.player)), 'refused')
  assert_eq(run.gold, gold, 'and nothing is paid')


# --- merging items (decision #61; docs/systems/run_manager.md → Merging items) -------

## Start `run` at the opening choice with an empty board. The fixture character starts with two
## copies of the fixture attack, which would be merge partners in every test.
func _start_with_empty_board(run: RunManager) -> void:
  run.start(1, FixtureCharacter.ID)
  for item: Item in run.player.board:
    item.dissolve()
  run.player.board.clear()


## Put a fresh fixture attack at `level` on the run's board and return it.
func _add_attack(run: RunManager, level: int = 1) -> Item:
  var item := Item.new(FixtureItems.attack(), run.player)
  item.level = level
  run.player.board.append(item)
  return item


func test_two_copies_at_the_same_level_merge_into_the_next_level() -> void:
  var run := _run()
  _start_with_empty_board(run)
  var kept: Item = _add_attack(run)
  var partner: Item = _add_attack(run)
  var board: int = run.player.board.size()
  var index: int = run.player.board.find(kept)
  assert_true(run.can_merge(kept), 'a copy at the same level is on the board')
  assert_true(run.merge_item(kept), 'the merge is made')
  assert_eq(kept.level, 2, 'the selected item goes up a level')
  assert_eq(run.player.board.find(kept), index, 'and keeps its place')
  assert_false(partner in run.player.board, 'the copy leaves the board')
  assert_null(partner.owner, 'and is dissolved')
  assert_eq(run.player.board.size(), board - 1, 'one item fewer')


func test_an_item_cannot_merge_without_a_copy_at_its_level() -> void:
  var run := _run()
  _start_with_empty_board(run)
  var item: Item = _add_attack(run)
  assert_false(run.can_merge(item), 'no copy')
  _add_attack(run, 2)
  assert_false(run.can_merge(item), 'a copy at another level does not count')
  assert_false(run.merge_item(item), 'the merge is refused')
  assert_eq(item.level, 1, 'and nothing changes')


func test_an_item_at_the_top_level_cannot_merge() -> void:
  var run := _run()
  _start_with_empty_board(run)
  var item: Item = _add_attack(run, Balance.ITEM_MAX_LEVEL)
  _add_attack(run, Balance.ITEM_MAX_LEVEL)
  assert_false(run.can_merge(item), 'the top level does not merge')


func test_items_cannot_be_merged_during_a_fight() -> void:
  var run := _run()
  _start_at_fight(run, 1)
  var item: Item = _add_attack(run)
  _add_attack(run)
  run.begin_current()
  assert_false(run.can_merge(item), 'not while the fight is under way')
  run.combat_manager().run_headless()
  assert_true(run.can_merge(item), 'once the fight is over it can be merged')


func test_merging_keeps_the_selected_enchantment_when_both_have_one() -> void:
  var run := _run()
  _start_with_empty_board(run)
  var kept: Item = _add_attack(run)
  var partner: Item = _add_attack(run)
  var own := Enchantment.new(FixtureKit.enchant())
  kept.enchant = own
  partner.enchant = Enchantment.new(FixtureKit.enchant())
  assert_true(run.will_lose_enchantment(kept), 'one enchantment will be lost')
  run.merge_item(kept)
  assert_eq(kept.enchant, own, 'the selected item keeps its own')


func test_merging_keeps_the_only_enchantment_whichever_copy_has_it() -> void:
  var run := _run()
  _start_with_empty_board(run)
  var kept: Item = _add_attack(run)
  var partner: Item = _add_attack(run)
  var theirs := Enchantment.new(FixtureKit.enchant())
  partner.enchant = theirs
  assert_false(run.will_lose_enchantment(kept), 'nothing is lost')
  run.merge_item(kept)
  assert_eq(kept.enchant, theirs, "the selected item takes the copy's enchantment")


func test_the_merge_partner_is_a_copy_without_an_enchantment_when_there_is_one() -> void:
  var run := _run()
  _start_with_empty_board(run)
  var kept: Item = _add_attack(run)
  kept.enchant = Enchantment.new(FixtureKit.enchant())
  var enchanted: Item = _add_attack(run)
  enchanted.enchant = Enchantment.new(FixtureKit.enchant())
  var plain: Item = _add_attack(run)
  assert_eq(run.merge_partner(kept), plain, 'the plain copy is used')
  assert_false(run.will_lose_enchantment(kept), 'so no enchantment is lost')
  run.merge_item(kept)
  assert_true(enchanted in run.player.board, 'the enchanted copy stays')


func test_a_levelled_item_sells_for_the_copies_it_was_made_from() -> void:
  var item := Item.new(FixtureItems.attack())
  var one: int = RunManager.item_price(item)
  item.level = 2
  assert_eq(RunManager.item_price(item), one * 2, 'a level 2 item is worth two level 1 copies')
  assert_eq(RunManager.sell_price(item), floori(one * 2 * Balance.SELL_SHARE), 'and sells for its share of that')


func test_the_level_survives_save_and_resume() -> void:
  var run := _run()
  _start_with_empty_board(run)
  var item: Item = _add_attack(run, 3)
  var index: int = run.player.board.find(item)
  var run_b := _run()
  run_b.rehydrate(run.snapshot())
  assert_eq((run_b.player.board[index] as Item).level, 3, 'the resumed item has its level')


# --- levelled offers (docs/plans/item_levels.md → Stage 2) ------------------

## The first beat whose fight number is the run's last fight.
func _last_fight_position() -> int:
  var pos: int = 0
  while RunMap.fight_number(pos) < RunMap.TOTAL_FIGHTS - 1:
    pos += 1
  return pos


func test_offered_items_are_level_1_at_the_first_fight_and_draw_no_rng() -> void:
  var rng := RandomNumberGenerator.new()
  rng.seed = 7
  var state: int = rng.state
  for i in 20:
    assert_eq(RunManager.draw_offer_level(0, rng), 1, 'level 1 at the first fight')
  assert_eq(rng.state, state, 'and the run RNG does not move')


func test_offered_item_levels_stay_within_the_last_fights_odds() -> void:
  var rng := RandomNumberGenerator.new()
  rng.seed = 7
  var highest: int = Balance.ITEM_OFFER_LEVEL_ODDS[-1].size()
  var seen_above_1: bool = false
  for i in 200:
    var level: int = RunManager.draw_offer_level(RunMap.TOTAL_FIGHTS + 5, rng)   # past the table: the last row
    assert_between(level, 1, highest, 'a level the last row can give')
    seen_above_1 = seen_above_1 or level > 1
  assert_eq(seen_above_1, highest > 1, 'levels above 1 are drawn when the last row allows them')


func test_relics_and_potions_are_offered_at_level_1() -> void:
  var run := _run()
  _start_in_shop(run, 0)
  var goods: Array = [run.shop_goods()[-2], run.shop_goods()[-1]]   # the relic and the potion
  run.position = _last_fight_position()
  var state: int = run.rng.state
  assert_eq(run._draw_offer_levels(goods), [1, 1] as Array[int], 'level 1 even late in the run')
  assert_eq(run.rng.state, state, 'with no level drawn for them')


func test_a_picked_draft_item_keeps_its_offered_level() -> void:
  var run := _run()
  _start_with_empty_board(run)
  run._set_offer([FixtureItems.attack()])
  run._pending_offer_levels.assign([2])
  assert_eq(run.pending_draft_levels(), [2] as Array[int], 'the offer shows its level')
  run.apply_draft_pick(0)
  assert_eq(run.player.board[0].level, 2, 'the picked item joins the board at that level')
  assert_true(run.pending_draft_levels().is_empty(), 'and the levels clear with the offer')


func test_a_levelled_shop_item_costs_and_gives_its_level() -> void:
  var run := _run()
  _start_in_shop(run, 100)
  var good: ItemDef = run.shop_goods()[0]
  run._shop_levels[0] = 2
  var price: int = RunManager.price_of(good) * 2
  assert_eq(RunManager.price_at_level(good, 2), price, 'a level 2 good costs two level 1 copies')
  assert_eq(run.shop_price(0), price, 'and the shop charges that')
  assert_true(run.buy(0), 'it is bought')
  assert_eq(run.gold, 100 - price, 'for its levelled price')
  assert_eq(run.player.board[-1].level, 2, 'and joins the board at its level')


func test_a_shop_with_too_few_items_to_choose_from_is_not_offered() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var shop: EncounterDef = FixtureEncounters.shop('test_shop')
  var pool_size: int = FixtureCharacter.def().item_pool.size()
  shop.min_items = pool_size
  assert_gt(shop.offer_weight(run), 0.0, 'offered when the pool has exactly enough items')
  shop.min_items = pool_size + 1
  assert_eq(shop.offer_weight(run), 0.0, 'not offered with one too few')
  shop.stock = [StockEntry.items_with_mechanic(1, PoisonMechanic.ID)]
  shop.min_items = 2
  assert_eq(shop.offer_weight(run), 0.0, 'a filtered shop counts only the items that pass its filters')


func test_the_cut_off_applies_to_shops_only() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var reward: EncounterDef = FixtureEncounters.reward('test_reward')
  reward.min_items = 100
  assert_gt(reward.offer_weight(run), 0.0, 'a reward encounter is offered however few items match')


func test_prices_follow_the_kind_and_rarity_of_the_goods() -> void:
  var item: ItemDef = FixtureItems.attack()
  assert_eq(RunManager.price_of(item), Balance.SHOP_PRICE_ITEM[item.rarity], 'an item')
  item.rarity = ItemDef.Rarity.RARE
  assert_eq(RunManager.price_of(item), Balance.SHOP_PRICE_ITEM[ItemDef.Rarity.RARE], 'a rare item')
  var relic: RelicDef = FixtureKit.shield_relic()
  assert_eq(RunManager.price_of(relic), Balance.SHOP_PRICE_RELIC[relic.rarity], 'a relic')
  var potion: ConsumableDef = FixtureKit.potion()
  assert_eq(RunManager.price_of(potion), Balance.SHOP_PRICE_POTION[potion.rarity], 'a potion')


func test_the_relic_pool_leaves_out_held_relics() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var held: String = RelicCatalog.REWARD_POOL[0]
  run._apply_run_effect(RunEffect.gain_relic(held))
  assert_false(held in run.relic_pool(), 'a held relic is out of the pool')
  assert_eq(run.relic_pool().size(), RelicCatalog.REWARD_POOL.size() - 1, 'the rest are still in it')


func test_relic_grants_never_repeat_a_relic() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  for _i in RelicCatalog.REWARD_POOL.size() + 1:
    run._grant_relic()
  var ids: Array = run.relics.map(func(relic: Relic) -> String: return relic.def.id)
  assert_eq(ids.size(), RelicCatalog.REWARD_POOL.size(), 'one grant per relic in the pool, then nothing')
  for id: String in ids:
    assert_eq(ids.count(id), 1, 'each relic once')


func test_a_reward_encounter_does_not_offer_a_held_relic() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var held: String = RelicCatalog.REWARD_POOL[0]
  run._apply_run_effect(RunEffect.gain_relic(held))
  run.pick_path(FixtureEncounters.CHOICE_REWARD)
  run.begin_current()
  for def: RelicDef in run.pending_draft():
    assert_ne(def.id, held, 'the held relic is not offered')


func test_a_reward_encounter_with_nothing_to_offer_is_not_offered() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var def: EncounterDef = EncounterCatalog.get_def(FixtureEncounters.REWARD)
  assert_gt(def.offer_weight(run), 0.0, 'offered while relics are left')
  for id: String in RelicCatalog.REWARD_POOL:
    run._apply_run_effect(RunEffect.gain_relic(id))
  assert_eq(def.offer_weight(run), 0.0, 'not offered once every reward relic is held')


func test_the_reward_offer_is_the_same_after_resume() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.pick_path(FixtureEncounters.CHOICE_REWARD)   # saves the picked encounter
  var run_b := _run()
  run_b.rehydrate(run.snapshot())
  run.begin_current()
  run_b.begin_current()
  assert_eq(run_b.pending_draft(), run.pending_draft(), 'the resumed reward draws the same goods')


func test_picking_a_relic_fires_its_pickup_trigger() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var before_max: int = run.player.max_hp
  run._set_offer([FixtureKit.max_hp_relic()])
  run.apply_draft_pick(0)
  assert_eq(run.player.max_hp, before_max + FixtureKit.RELIC_MAX_HP, 'the relic raised maximum health')


func test_picking_a_potion_adds_it_to_the_potions() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var before: int = run.potions.size()
  var board: int = run.player.board.size()
  run._set_offer([FixtureKit.potion()])
  run.apply_draft_pick(0)
  assert_eq(run.potions.size(), before + 1, 'the potion was added')
  assert_eq(run.potions[-1].def.id, FixtureKit.POTION_ID, 'the one offered')
  assert_eq(run.player.board.size(), board, 'and nothing went on the board')


func test_a_reward_encounter_can_be_skipped_for_gold() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.pick_path(FixtureEncounters.CHOICE_REWARD)
  run.begin_current()
  var relic_count: int = run.relics.size()
  run.apply_draft_skip()
  assert_eq(run.gold, Balance.GOLD_SKIP, 'the skip banks gold')
  assert_eq(run.relics.size(), relic_count, 'and takes no relic')
  assert_false(run.has_pending_draft(), 'and clears the offer')


# --- after each fight -------------------------------------------------------

func test_a_won_fight_gives_health_and_gold() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.player.hp = run.player.max_hp - 40
  var gold_before: int = run.gold
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.NONE)
  assert_eq(run.player.hp, run.player.max_hp - 40 + Balance.FIGHT_WON_HEAL, 'the fight-won heal')
  assert_eq(run.gold, gold_before + Balance.FIGHT_WON_GOLD, 'and the fight-won gold')


func test_an_encounter_that_is_not_a_fight_gives_no_fight_gain() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run._on_encounter_resolved(Encounter.Outcome.RESOLVED, EncounterDef.Reward.NONE)
  assert_eq(run.gold, 0, 'no gold')


func test_the_final_fight_gives_no_fight_gain() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.position = RunMap.TOTAL_BEATS - 1
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  assert_true(run.is_ended(), 'beating the final boss ends the run')
  assert_eq(run.gold, 0, 'with no fight-won gold')


# --- HP economy -------------------------------------------------------------

func test_crossing_into_a_new_act_full_heals() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.skip_choice()
  run.position = RunMap.BEATS_PER_ACT - 1   # the act-0 boss beat
  run.player.hp = 10
  run.advance()                              # cross into act 1
  assert_eq(run.player.hp, run.player.max_hp, 'entering a new act restores full HP')
  assert_eq(run.act(), 1, 'and the run is in the next act')


func test_no_full_heal_within_an_act() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  run.player.hp = 10
  run.skip_choice()
  run.advance()                              # beat 0 → 1, same act
  assert_eq(run.player.hp, 10, 'HP persists between beats inside an act')


func test_player_actor_and_board_free_after_run_teardown() -> void:
  # The run-lifetime player + its board must free at run end — the Actor<->Item
  # cycle (board <-> owner) has to be broken and the run's own ref dropped.
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var weak_player: WeakRef = weakref(run.player)
  var weak_item: WeakRef = weakref(run.player.board[0])
  run.teardown()
  assert_null(weak_player.get_ref(), 'the player actor frees at run end')
  assert_null(weak_item.get_ref(), 'and its board items free too')


func test_starting_kit_saves_and_rehydrates() -> void:
  # A relic + an enchant + a potion all round-trip through the snapshot. The fixture character
  # starts with none of them, so this grants them the way a reward would.
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  _grant_enchant_and_potion(run)
  run.relics.append(Relic.new(FixtureKit.shield_relic()))
  assert_not_null(run.player.board[0].enchant, 'the enchant is on the first board item')
  assert_eq(run.potions.size(), 1, 'a potion is held')
  assert_eq(run.relics.size(), 1, 'and a relic')

  var snap: Dictionary = run.snapshot()
  assert_eq(snap['board'][0]['enchant'], FixtureKit.ENCHANT_ID, 'enchant id saved on the board entry')
  assert_eq(snap['potions'].size(), 1, 'potion saved')

  var run_b := _run()
  run_b.rehydrate(snap)
  assert_not_null(run_b.player.board[0].enchant, 'rehydrate rebuilds the enchant on the item')
  assert_eq(run_b.player.board[0].enchant.def.id, FixtureKit.ENCHANT_ID)
  assert_eq(run_b.potions.size(), 1, 'rehydrate rebuilds the potion')


func test_throw_potion_heals_and_empties_the_slot() -> void:
  var run := _run()
  _start_at_fight(run, 1)
  _grant_enchant_and_potion(run)
  run.begin_current()                  # the first fight
  run.player.take_damage(40.0)
  var before: int = run.player.hp
  assert_eq(run.potions.size(), 1)
  assert_true(run.throw_potion(0), 'thrown mid-fight')
  assert_eq(run.potions.size(), 0, 'the potion was consumed from the slot')
  for i in Balance.POTION_TRAVEL_STEPS:
    run.combat_manager().sim_step()
  assert_gt(run.player.hp, before, 'and it healed the player')


func test_throw_potion_outside_a_fight_is_rejected() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)                         # beat created but not begun → no live fight
  _grant_enchant_and_potion(run)
  assert_false(run.throw_potion(0), 'a potion only resolves through a live fight')
  assert_eq(run.potions.size(), 1, 'and stays in the slot')


func test_drafts_draw_from_the_characters_pool() -> void:
  # #27: a reward draft pulls from the chosen character's item pool, not one global pool.
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  _offer_items(run)
  assert_true(run.has_pending_draft(), 'an offer is held')
  for d in run.pending_draft():
    assert_true(run._draft_pool().has(d.id), 'every offered item is from the character pool + colorless (#27)')


func test_draft_pool_is_character_plus_colorless() -> void:
  # The shared colorless pool is appended to the character's own pool at draft time (#27).
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  var pool: Array = run._draft_pool()
  for id in run.character.item_pool:
    assert_true(pool.has(id), 'the draft pool includes the character pool')
  for id in ColorlessPool.ITEMS:
    assert_true(pool.has(id), 'and the shared colorless items')
  assert_eq(pool.size(), run.character.item_pool.size() + ColorlessPool.ITEMS.size(), 'pool = character + colorless')


func test_start_with_a_chosen_character_uses_its_kit() -> void:
  # The character-select pick routes through start(seed, id): the run opens in the chosen
  # character's pool + starting kit, not the default one's. The fixture character is never the
  # default, so starting as it proves the id is used.
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_eq(run.character.id, FixtureCharacter.ID, 'the run opens in the chosen character')
  assert_eq(_board_ids(run.player), FixtureCharacter.def().starting_item_ids,
    'with its starting board')


func test_character_round_trips_through_the_snapshot() -> void:
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  assert_eq(run.character.id, FixtureCharacter.ID, 'the run starts on the chosen character')
  var snap: Dictionary = run.snapshot()
  assert_eq(snap['character'], FixtureCharacter.ID, 'the character id is saved')
  var run_b := _run()
  run_b.rehydrate(snap)
  assert_eq(run_b.character.id, FixtureCharacter.ID, 'and restored on resume (its pool feeds future drafts)')


func test_advance_autosaves_the_entry_point() -> void:
  var run := _run()
  _start_at_fight(run, 3)
  _play_one_beat(run, 0)          # the first fight → begin, fight, advance (saves at entry)
  var saved: Dictionary = Save.read()
  assert_false(saved.is_empty(), 'a save exists at the encounter entry')
  assert_eq(int(saved['position']), 2, 'the save is at the freshly-entered beat')
  assert_eq(saved['board'].size(), run.player.board.size(), 'and holds the board')


func test_rehydrate_refuses_a_truncated_snapshot() -> void:
  # A parsable save with a broken SHAPE (missing keys) is unusable — rehydrate must
  # refuse it (the caller discards to fresh) instead of crashing on a missing index.
  var run := _run()
  assert_false(run.rehydrate({ 'hp': 50.0, 'max_hp': 100.0 }), 'a truncated snapshot is refused')
  var complete := _run()
  complete.start(5, FixtureCharacter.ID)
  assert_true(_run().rehydrate(complete.snapshot()), 'a complete snapshot rehydrates')


func test_advance_past_an_unconsumed_draft_drops_the_offer() -> void:
  # The consume-before-advance invariant: a caller that advances past a pending draft has a flow
  # bug — the offer is dropped (loudly) rather than carried unsaved into the next beat.
  var run := _run()
  _start_at_fight(run, 3)
  var board_size: int = run.player.board.size()
  _offer_items(run)
  assert_true(run.has_pending_draft(), 'a draft is pending')
  run.advance()                   # flow bug: nobody consumed the draft
  assert_false(run.has_pending_draft(), 'the stale offer was dropped, not carried')
  assert_eq(run.player.board.size(), board_size, 'nothing was silently added to the board')
  assert_eq(run.position, 2, 'the run still advanced')


# --- draft skip → bank gold (docs decision #33) ------------------------------

func test_skip_banks_gold_and_clears_offer() -> void:
  # Skipping the draft banks a fixed amount of gold (Balance.GOLD_SKIP) instead of taking a card,
  # leaves the board untouched, clears the offer, and lets the run advance.
  var run := _run()
  _start_at_fight(run, 1)
  _offer_items(run)
  assert_true(run.has_pending_draft(), 'an offer is held')
  var board_size: int = run.player.board.size()
  var gold_before: int = run.gold
  run.apply_draft_skip()
  assert_false(run.has_pending_draft(), 'the offer cleared')
  assert_eq(run.player.board.size(), board_size, 'skipping adds no item to the board')
  assert_eq(run.gold, gold_before + Balance.GOLD_SKIP, 'the fixed gold amount is banked')
  run.advance()
  assert_eq(run.position, 2, 'the run advances after a skip (the offer was consumed)')


func test_gold_survives_save_and_resume() -> void:
  # Gold rides the snapshot and restores exactly; a pre-gold snapshot rehydrates to 0 (no migration).
  var run := _run()
  run.start(1, FixtureCharacter.ID)
  _offer_items(run)
  run.apply_draft_skip()
  var banked: int = run.gold
  assert_gt(banked, 0, 'the skip banked some gold')
  var snap: Dictionary = run.snapshot()
  assert_eq(int(snap['gold']), banked, 'gold is written into the snapshot')
  var run_b := _run()
  run_b.rehydrate(snap)
  assert_eq(run_b.gold, banked, 'and is restored exactly on resume (no save-scum)')
  snap.erase('gold')
  var run_c := _run()
  run_c.rehydrate(snap)
  assert_eq(run_c.gold, 0, 'a pre-gold snapshot rehydrates to 0 (forward-compatible, no migration)')


func test_skip_draws_no_run_rng() -> void:
  # The gold is a fixed amount, so a skip leaves the run RNG where a pick would.
  var run := _run()
  run.start(99, FixtureCharacter.ID)
  _offer_items(run)
  var state_before: int = run.rng.state
  run.apply_draft_skip()
  assert_eq(run.rng.state, state_before, 'skipping does not advance the run RNG')
