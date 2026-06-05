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


func test_advance_autosaves_the_entry_point() -> void:
  var run := _run()
  run.start(3)
  _play_one_beat(run, 0)          # advance() writes the snapshot at the new beat
  var saved: Dictionary = Save.read()
  assert_false(saved.is_empty(), 'a save exists at the encounter entry')
  assert_eq(int(saved['position']), 1, 'the save is at the freshly-entered beat')
  assert_eq(saved['board'].size(), 4, 'and reflects the drafted item')
