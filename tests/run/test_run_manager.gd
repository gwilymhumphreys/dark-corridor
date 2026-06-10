extends GutTest
## Step 5 — the descent. A full short run reaches WON, drafts land on the board, a
## starting relic grants combat-start block, a loss ends the run DIED, and a
## save-mid-run + rehydrate reproduces the exact continuation (deterministic
## resume — the no-save-scum property end to end).


var _runs: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
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


func _board_ids(actor: Actor) -> Array:
  var ids: Array = []
  for it in actor.board:
    ids.append(it.def.id)
  return ids


func _block_count(actor: Actor) -> float:
  for s in actor.statuses:
    if s.id == 'block':
      return s.count
  return 0.0


## Resolve one beat (auto-roll: the beat already has a live encounter). Begin it; resolve an
## event's binary choice; step a fight's CombatManager to a verdict; take the draft if offered;
## advance. (Mirrors the autotest run loop.) `pick` indexes the draft card + the event option.
func _play_one_beat(run: RunManager, pick: int) -> void:
  run.begin_current()
  var enc: Encounter = run.current_encounter()
  if enc != null and enc.is_event():
    run.pick_event_option(0)   # resolve the event's binary choice (option 0)
  var cm: CombatManager = run.combat_manager()
  if cm != null:
    cm.run_headless()
  if run.is_ended():
    return
  if run.has_pending_draft():
    run.apply_draft_pick(pick)
  run.advance()


func _play_to_end(run: RunManager, pick: int) -> void:
  var guard: int = 0
  while not run.is_ended() and guard < 100:
    _play_one_beat(run, pick)
    guard += 1


# --- tests ------------------------------------------------------------------

func test_full_run_reaches_won_and_grows_the_board() -> void:
  var run := _run()
  run.start(1)
  assert_eq(run.player.board.size(), 3, 'starting board: weapon, armor, poison dagger')
  _play_to_end(run, 0)
  assert_true(run.is_ended(), 'the run resolved')
  assert_eq(run.outcome(), RunManager.Outcome.WON, 'the compounding build clears the multi-act map')
  assert_gt(run.player.board.size(), 3, 'fight drafts grew the board across the run')


func test_draft_pick_lands_on_the_board() -> void:
  var run := _run()
  run.start(1)
  _play_one_beat(run, 0)   # beat 0: fight win → draft → advance
  assert_eq(run.player.board.size(), 4, 'the drafted item was added to the board')
  assert_eq(run.position, 1, 'and the run advanced a beat')


func test_starting_relic_grants_combat_start_block() -> void:
  var run := _run()
  run.start(1)
  # beat 0 auto-rolls to a live (easy) fight — begin it; relics apply at fight start, before any step
  run.begin_current()
  assert_almost_eq(_block_count(run.player), Balance.RELIC_STONE_WARD_BLOCK, 0.0001,
    'Stone Ward applies its block when the fight begins')


func test_loss_ends_run_died() -> void:
  var run := _run()
  run.start(1)
  run.relics.clear()       # drop the protective relic so the glass player actually dies
  run.player.hp = 1.0
  watch_signals(run)
  _play_one_beat(run, 0)
  assert_true(run.is_ended())
  assert_eq(run.outcome(), RunManager.Outcome.DIED)
  assert_signal_emitted_with_parameters(run, 'run_ended', [RunManager.Outcome.DIED])


func test_save_and_rehydrate_reproduces_the_continuation() -> void:
  var run_a := _run()
  run_a.start(7)
  _play_one_beat(run_a, 0)        # clear beat 0; position now 1 (a draft still ahead at beat 1)
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
  run.start(1)
  var before: int = run.relics.size()
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  assert_eq(run.relics.size(), before + 1, 'a relic was granted')
  assert_true(run.relics[-1].def.id in RelicCatalog.REWARD_POOL, 'and it came from the reward pool')
  assert_false(run.has_pending_draft(), 'a relic-only beat offers no draft')


func test_elite_reward_grants_a_relic_and_a_draft() -> void:
  # An elite is richer than a regular fight: a relic AND a draft (reward asymmetry, #2).
  var run := _run()
  run.start(1)
  var before: int = run.relics.size()
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.ELITE)
  assert_eq(run.relics.size(), before + 1, 'an elite grants a relic')
  assert_true(run.has_pending_draft(), 'AND offers a draft')


func test_max_hp_relic_grant_raises_max_and_current_hp() -> void:
  var run := _run()
  run.start(1)
  var before_max: float = run.player.max_hp
  var before_hp: float = run.player.hp
  var charm := Relic.new(RelicCatalog.get_def(RelicCatalog.VITAL_CHARM))
  run.relics.append(charm)
  run._apply_relic_grant(charm)
  assert_almost_eq(run.player.max_hp, before_max + Balance.RELIC_VITAL_CHARM_MAX_HP, 0.0001, 'max HP grew')
  assert_almost_eq(run.player.hp, before_hp + Balance.RELIC_VITAL_CHARM_MAX_HP, 0.0001, 'and current HP too')


func test_relic_grant_is_deterministic_by_seed() -> void:
  var run_a := _run()
  run_a.start(99)
  run_a._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  var run_b := _run()
  run_b.start(99)
  run_b._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  assert_eq(run_a.relics[-1].def.id, run_b.relics[-1].def.id, 'same seed grants the same relic (no save-scum)')


func test_granted_relic_survives_save_and_resume() -> void:
  var run := _run()
  run.start(1)
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.RELIC)
  var granted_id: String = run.relics[-1].def.id
  var max_after: float = run.player.max_hp
  var snap: Dictionary = run.snapshot()

  var run_b := _run()
  run_b.rehydrate(snap)
  var ids: Array = []
  for r in run_b.relics:
    ids.append(r.def.id)
  assert_true(granted_id in ids, 'the granted relic is restored on resume')
  assert_almost_eq(run_b.player.max_hp, max_after, 0.0001, 'a max-HP grant is baked into the snapshot, not re-applied')


func test_per_fight_seed_is_seed_based_not_stream_based() -> void:
  # The per-fight combat seed derives from the run SEED (constant, saved), not the
  # evolving run stream — so it is resume-stable and doesn't shift as draft draws consume
  # the stream (decision #20).
  var run := _run()
  run.start(42)
  var s0: int = run._combat_seed_for(2)
  run.rng.randi()
  run.rng.randi()                     # advance the run stream
  assert_eq(run._combat_seed_for(2), s0, 'deriving the per-fight seed ignores the run stream state')


func test_per_fight_seeds_differ_by_beat() -> void:
  var run := _run()
  run.start(42)
  assert_ne(run._combat_seed_for(0), run._combat_seed_for(1), 'each beat gets its own combat stream')


func test_fight_rng_is_seeded_from_the_beat_seed() -> void:
  var run := _run()
  run.start(5)
  run.begin_current()                 # beat 0 auto-rolls to a live, seeded fight
  assert_eq(run.combat_manager().rng.seed, run._combat_seed_for(0),
    'the fight RNG is seeded from the derived per-beat seed')


func test_resumed_run_derives_the_same_per_fight_seed() -> void:
  # End to end: a fight re-entered from a save uses the identical combat seed, so its
  # random targeting replays exactly (no save-scumming a bad random outcome).
  var run := _run()
  run.start(7)
  _play_one_beat(run, 0)              # advance to beat 1
  var seed_a: int = run._combat_seed_for(run.position)
  var snap: Dictionary = run.snapshot()

  var run_b := _run()
  run_b.rehydrate(snap)
  assert_eq(run_b.position, run.position, 'resumed at the same beat')
  assert_eq(run_b._combat_seed_for(run_b.position), seed_a, 'and derives the identical per-fight seed')


# --- run-scoped allies (spore_engine_prd Cap 3, Stage B) ---------------------

func test_ally_persists_through_save_and_resume() -> void:
  var run := _run()
  run.start(1)
  run.add_ally(EnemyCatalog.SPORE_THRALL)
  run.allies[0].take_damage(5.0)   # so its HP isn't full
  var hp: float = run.allies[0].hp
  var run_b := _run()
  run_b.rehydrate(run.snapshot())
  assert_eq(run_b.allies.size(), 1, 'the ally is restored on resume')
  assert_almost_eq(run_b.allies[0].hp, hp, 0.0001, 'with its persisted HP')
  assert_eq(run_b.allies[0].board.size(), 1, 'and its board (rebuilt from the def)')


func test_between_act_full_heal_revives_allies() -> void:
  var run := _run()
  run.start(1)
  run.add_ally(EnemyCatalog.SPORE_THRALL)
  run.allies[0].take_damage(10.0)
  run.position = RunMap.BEATS_PER_ACT - 1
  run.advance()                    # cross into the next act
  assert_almost_eq(run.allies[0].hp, run.allies[0].max_hp, 0.0001, 'the between-act restore heals allies too')


func test_run_scoped_allies_revive_to_full_each_fight() -> void:
  # Allies revive between combats (only the player carries HP attrition) — a downed ally enters
  # the next fight at full HP.
  var run := _run()
  run.start(5)
  run.add_ally(EnemyCatalog.SPORE_THRALL)
  run.allies[0].take_damage(run.allies[0].max_hp)   # down it
  assert_false(run.allies[0].is_alive(), 'the ally is downed')
  run.begin_current()                               # beat 0 auto-rolls to a fight
  assert_almost_eq(run.allies[0].hp, run.allies[0].max_hp, 0.0001, 'the ally enters the fight revived to full')


func test_add_ally_mid_fight_joins_the_live_combat() -> void:
  var run := _run()
  run.start(5)
  run.begin_current()                     # beat 0 auto-rolls to a fight
  var cm: CombatManager = run.combat_manager()
  assert_not_null(cm, 'a live fight is running')
  run.add_ally(EnemyCatalog.SPORE_THRALL)
  assert_true(run.allies[0] in cm.allies, 'the ally joined the live fight (shared roster)')
  for _i in 3:
    cm.sim_step()
  assert_gt(run.allies[0].board[0].cooldown.accum, 0.0, 'and its items fight (registered mid-fight)')


func test_run_scoped_ally_dissolved_at_run_teardown() -> void:
  var run := _run()
  run.start(1)
  run.add_ally(EnemyCatalog.SPORE_THRALL)
  var weak_ally: WeakRef = weakref(run.allies[0])
  var weak_item: WeakRef = weakref(run.allies[0].board[0])
  run.teardown()
  assert_null(weak_ally.get_ref(), 'a run-scoped ally frees at run end (its cycle is broken)')
  assert_null(weak_item.get_ref(), 'and its board items free')


# --- ally acquisition via a recruit EVENT (the event-driven path) ------------

## Drive a freshly-created EVENT beat to a chosen option (deterministic, seed-independent):
## set the current def + create the encounter, begin it, pick the option through the RunManager.
func _resolve_event(run: RunManager, def_id: String, option: int) -> void:
  run._teardown_current()   # drop the auto-rolled opening fight before swapping in the event
  run._current_def_id = def_id
  run._create_current_encounter()
  run.begin_current()
  run.pick_event_option(option)


func test_recruit_event_adds_a_run_scoped_ally() -> void:
  # The ADD_ALLY option, routed through RunManager.pick_event_option, recruits a run-scoped
  # ally (the event-driven acquisition path) — it then joins every later fight + persists.
  var run := _run()
  run.start(1)
  assert_eq(run.allies.size(), 0, 'no allies before the event')
  _resolve_event(run, EncounterCatalog.EVENT_WANDERER, 0)   # 'Let it join you'
  assert_eq(run.allies.size(), 1, 'the recruit event added a run-scoped ally')
  assert_eq(run.allies[0].board.size(), 1, 'the ally was built from its EnemyDef board')


func test_recruit_event_declined_adds_no_ally() -> void:
  var run := _run()
  run.start(1)
  run.player.take_damage(30.0)
  var hurt: float = run.player.hp
  _resolve_event(run, EncounterCatalog.EVENT_WANDERER, 1)   # 'Walk on alone'
  assert_eq(run.allies.size(), 0, 'declining recruits no ally')
  assert_gt(run.player.hp, hurt, 'and the decline heals a little (the player-Actor outcome still applies)')


func test_add_ally_respects_the_four_slot_cap() -> void:
  var run := _run()
  run.start(1)
  for _i in RunManager.MAX_ALLIES:
    run.add_ally(EnemyCatalog.SPORE_THRALL)
  assert_eq(run.allies.size(), RunManager.MAX_ALLIES, 'the four ally slots fill')
  assert_false(run.can_add_ally(), 'and report full')
  run.add_ally(EnemyCatalog.SPORE_THRALL)   # one past the cap
  assert_eq(run.allies.size(), RunManager.MAX_ALLIES, 'a 5th recruit is a no-op (the cap holds)')


# --- multi-act structure + HP economy + the auto-roll map (#1) ---------------

func test_opening_beat_auto_rolls_a_live_fight() -> void:
  # Beats auto-roll their content — no player choice. The easy opener (0 .. EASY_BEATS_END) is
  # forced combat, so the run opens straight into a live fight.
  var run := _run()
  run.start(1)
  assert_false(run.has_pending_choice(), 'no choice — beats auto-roll')
  assert_not_null(run.current_encounter(), 'the opening beat has a live encounter at once')
  assert_true(run.current_encounter().is_fight(), 'the easy opener is forced combat')


func test_rolled_beat_and_streak_survive_resume() -> void:
  # The current beat's rolled def + the COMBAT/EVENT streak round-trip the snapshot, so a resumed
  # run re-enters the same encounter and reproduces the next beat's roll (no save-scum).
  var run := _run()
  run.start(1)
  run._roll_streak = RunManager.RollType.EVENT
  run._roll_streak_count = 2
  var def_id: String = run._current_def_id
  var run_b := _run()
  run_b.rehydrate(run.snapshot())
  assert_eq(run_b._current_def_id, def_id, 'the rolled encounter is restored (not re-rolled)')
  assert_eq(run_b._roll_streak, RunManager.RollType.EVENT, 'the streak type round-trips')
  assert_eq(run_b._roll_streak_count, 2, 'and the streak count')


func test_roll_bias_force_breaks_a_maxed_streak() -> void:
  # The −ROLL_BIAS_STEP-per-repeat bias: after 5 straight rolls the streaking type's chance floors
  # at 0 (50 − 10×5), so the next roll MUST land the other type and reset the streak (count 1).
  var run := _run()
  run.start(1)
  run._roll_streak = RunManager.RollType.COMBAT
  run._roll_streak_count = 5
  assert_eq(run._roll_type(), RunManager.RollType.EVENT, 'a maxed combat streak forces an event')
  assert_eq(run._roll_streak, RunManager.RollType.EVENT, 'and the streak switches to event')
  assert_eq(run._roll_streak_count, 1, 'reset to a fresh count')
  run._roll_streak_count = 5   # now a maxed EVENT streak forces a combat (the other direction)
  assert_eq(run._roll_type(), RunManager.RollType.COMBAT, 'a maxed event streak forces a combat')


func test_fixed_beats_are_boss_and_relic_others_roll() -> void:
  assert_eq(RunMap.beat_spec(RunMap.BOSS_BEAT)['id'], EncounterCatalog.FIGHT_BOSS, 'act end = boss')
  assert_eq(RunMap.beat_spec(RunMap.RELIC_BEAT)['id'], EncounterCatalog.FIGHT_RELIC, 'midpoint = relic')
  assert_eq(int(RunMap.beat_spec(0)['kind']), RunMap.BeatKind.ROLL, 'other beats auto-roll')
  assert_true(RunMap.beat_spec(0)['event_pool'].is_empty(), 'the easy opener forces combat (no events)')
  assert_false(RunMap.beat_spec(RunMap.EASY_BEATS_END + 1)['event_pool'].is_empty(),
    'events become possible after the opener')
  assert_true(EncounterCatalog.FIGHT_ELITE in RunMap.beat_spec(RunMap.ELITE_FROM_BEAT)['combat_pool'],
    'an elite is possible in the combat pool from ELITE_FROM_BEAT on')
  assert_true(RunMap.is_final_beat(RunMap.TOTAL_BEATS - 1), 'the last beat is the finale')


func test_crossing_into_a_new_act_full_heals() -> void:
  var run := _run()
  run.start(1)
  run.position = RunMap.BEATS_PER_ACT - 1   # the act-0 boss beat
  run.player.hp = 10.0
  run.advance()                              # cross into act 1
  assert_almost_eq(run.player.hp, run.player.max_hp, 0.0001, 'entering a new act restores full HP')
  assert_eq(run.act(), 1, 'and the run is in the next act')


func test_no_full_heal_within_an_act() -> void:
  var run := _run()
  run.start(1)
  run.player.hp = 10.0
  run.advance()                              # beat 0 → 1, same act
  assert_almost_eq(run.player.hp, 10.0, 0.0001, 'HP persists between beats inside an act')


func test_player_actor_and_board_free_after_run_teardown() -> void:
  # The run-lifetime player + its board must free at run end — the Actor<->Item
  # cycle (board <-> owner) has to be broken and the run's own ref dropped.
  var run := _run()
  run.start(1)
  var weak_player: WeakRef = weakref(run.player)
  var weak_item: WeakRef = weakref(run.player.board[0])
  run.teardown()
  assert_null(weak_player.get_ref(), 'the player actor frees at run end')
  assert_null(weak_item.get_ref(), 'and its board items free too')


func test_starting_kit_saves_and_rehydrates() -> void:
  # The starting relic + enchant + potion all round-trip through the snapshot.
  var run := _run()
  run.start(1)
  assert_not_null(run.player.board[0].enchant, 'Whetstone is on the starting weapon')
  assert_eq(run.potions.size(), 1, 'a starting Healing Draught')
  assert_eq(run.relics.size(), 1, 'the Stone Ward relic')

  var snap: Dictionary = run.snapshot()
  assert_eq(snap['board'][0]['enchant'], EnchantCatalog.WHETSTONE, 'enchant id saved on the board entry')
  assert_eq(snap['potions'].size(), 1, 'potion saved')

  var run_b := _run()
  run_b.rehydrate(snap)
  assert_not_null(run_b.player.board[0].enchant, 'rehydrate rebuilds the enchant on the item')
  assert_eq(run_b.player.board[0].enchant.def.id, EnchantCatalog.WHETSTONE)
  assert_eq(run_b.potions.size(), 1, 'rehydrate rebuilds the potion')


func test_throw_potion_heals_and_empties_the_slot() -> void:
  var run := _run()
  run.start(1)
  run.begin_current()                  # beat 0 auto-rolls to a live fight
  run.player.take_damage(40.0)
  var before: float = run.player.hp
  assert_eq(run.potions.size(), 1)
  assert_true(run.throw_potion(0), 'thrown mid-fight')
  assert_eq(run.potions.size(), 0, 'the potion was consumed from the slot')
  assert_gt(run.player.hp, before, 'and it healed the player')


func test_throw_potion_outside_a_fight_is_rejected() -> void:
  var run := _run()
  run.start(1)                         # beat created but not begun → no live fight
  assert_false(run.throw_potion(0), 'a potion only resolves through a live fight')
  assert_eq(run.potions.size(), 1, 'and stays in the slot')


func test_drafts_draw_from_the_characters_pool() -> void:
  # #27: a reward draft pulls from the chosen character's item pool, not one global pool.
  var run := _run()
  run.start(1)
  run._on_encounter_resolved(Encounter.Outcome.WON, EncounterDef.Reward.DRAFT)
  assert_true(run.has_pending_draft(), 'a fight win offers a draft')
  for d in run.pending_draft():
    assert_true(run._draft_pool().has(d.id), 'every offered item is from the character pool + colorless (#27)')


func test_draft_pool_is_character_plus_colorless() -> void:
  # The shared colorless pool is appended to the character's own pool at draft time (#27).
  var run := _run()
  run.start(1)
  var pool: Array = run._draft_pool()
  for id in run.character.item_pool:
    assert_true(pool.has(id), 'the draft pool includes the character pool')
  for id in ColorlessPool.ITEMS:
    assert_true(pool.has(id), 'and the shared colorless items')
  assert_eq(pool.size(), run.character.item_pool.size() + ColorlessPool.ITEMS.size(), 'pool = character + colorless')


func test_start_with_a_chosen_character_uses_its_kit() -> void:
  # The character-select pick routes through start(seed, id): the run opens in the chosen
  # character's pool + starting kit (the Duelist's distinct no-relic loadout proves it).
  var run := _run()
  run.start(1, CharacterCatalog.DUELIST)
  assert_eq(run.character.id, CharacterCatalog.DUELIST, 'the run opens in the chosen character')
  assert_eq(run.relics.size(), 0, 'the Duelist starts with no relic (a distinct kit from the Wanderer)')
  assert_eq(_board_ids(run.player), [ItemCatalog.WEAPON, ItemCatalog.WEAPON, ItemCatalog.POISON_DAGGER],
    'and its own starting board')


func test_character_round_trips_through_the_snapshot() -> void:
  var run := _run()
  run.start(1)
  assert_eq(run.character.id, CharacterCatalog.DEFAULT, 'the run starts on the chosen character')
  var snap: Dictionary = run.snapshot()
  assert_eq(snap['character'], CharacterCatalog.DEFAULT, 'the character id is saved')
  var run_b := _run()
  run_b.rehydrate(snap)
  assert_eq(run_b.character.id, CharacterCatalog.DEFAULT, 'and restored on resume (its pool feeds future drafts)')


func test_advance_autosaves_the_entry_point() -> void:
  var run := _run()
  run.start(3)
  _play_one_beat(run, 0)          # beat 0 is a fight (draft) → begin, fight, draft, advance (saves at entry)
  var saved: Dictionary = Save.read()
  assert_false(saved.is_empty(), 'a save exists at the encounter entry')
  assert_eq(int(saved['position']), 1, 'the save is at the freshly-entered beat')
  assert_eq(saved['board'].size(), 4, 'and reflects the drafted item')
