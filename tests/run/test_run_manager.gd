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
    if s.type == StatusDef.Type.BLOCK:
      return s.count
  return 0.0


## Resolve one beat: begin it, step a fight's CombatManager to a verdict, take the
## draft pick if offered, advance. (Mirrors what the autotest run loop will do.)
func _play_one_beat(run: RunManager, pick: int) -> void:
  run.begin_current()
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
  assert_eq(run.outcome(), RunManager.Outcome.WON, 'the build clears the short map')
  assert_eq(run.player.board.size(), 5, 'two fights granted drafts (+2 items); rest + finale grant none')


func test_draft_pick_lands_on_the_board() -> void:
  var run := _run()
  run.start(1)
  _play_one_beat(run, 0)   # beat 0: fight win → draft → advance
  assert_eq(run.player.board.size(), 4, 'the drafted item was added to the board')
  assert_eq(run.position, 1, 'and the run advanced a beat')


func test_starting_relic_grants_combat_start_block() -> void:
  var run := _run()
  run.start(1)
  run.begin_current()      # beat 0 is a fight — relics apply at start, before any step
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
  var charm := Relic.new(RelicCatalog.get_def(RelicCatalog.Id.VITAL_CHARM))
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
  var granted_id: int = run.relics[-1].def.id
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
  run.begin_current()                 # beat 0 is a fight → a live, seeded CombatManager
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
  assert_eq(int(snap['board'][0]['enchant']), EnchantCatalog.Id.WHETSTONE, 'enchant id saved on the board entry')
  assert_eq(snap['potions'].size(), 1, 'potion saved')

  var run_b := _run()
  run_b.rehydrate(snap)
  assert_not_null(run_b.player.board[0].enchant, 'rehydrate rebuilds the enchant on the item')
  assert_eq(run_b.player.board[0].enchant.def.id, EnchantCatalog.Id.WHETSTONE)
  assert_eq(run_b.potions.size(), 1, 'rehydrate rebuilds the potion')


func test_throw_potion_heals_and_empties_the_slot() -> void:
  var run := _run()
  run.start(1)
  run.begin_current()                  # beat 0 is a fight → a live CombatManager
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


func test_advance_autosaves_the_entry_point() -> void:
  var run := _run()
  run.start(3)
  _play_one_beat(run, 0)          # advance() writes the snapshot at the new beat
  var saved: Dictionary = Save.read()
  assert_false(saved.is_empty(), 'a save exists at the encounter entry')
  assert_eq(int(saved['position']), 1, 'the save is at the freshly-entered beat')
  assert_eq(saved['board'].size(), 4, 'and reflects the drafted item')
