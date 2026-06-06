extends GutTest
## Step 6 — the session singleton. Start / win / die / resume: phases move, the
## save is written on entry and cleared on death/win, and resume rebuilds a run
## from the slot. Drives Game.run's cycle the way the autotest will.


func before_each() -> void:
  Save.clear()
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()
  Save.clear()


# --- helpers (drive Game.run, mirroring the autotest run loop) ---------------

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

func test_start_run_enters_run_phase() -> void:
  Game.start_run(1)
  assert_eq(Game.phase, GameManagerAutoload.Phase.RUN)
  assert_not_null(Game.run, 'a live run exists')
  assert_eq(Game.run.position, 0)
  assert_true(Save.has_save(), 'the entry snapshot was written')


func test_win_sets_win_phase_and_clears_save() -> void:
  Game.start_run(1)
  _play_to_end(Game.run, 0)
  assert_eq(Game.phase, GameManagerAutoload.Phase.WIN)
  assert_false(Save.has_save(), 'a win clears the run save')
  assert_eq(Game.run.outcome(), RunManager.Outcome.WON, 'the run stays readable after it ends')


func test_death_sets_death_phase_and_clears_save() -> void:
  Game.start_run(1)
  Game.run.relics.clear()
  Game.run.player.hp = 1.0
  _play_one_beat(Game.run, 0)
  assert_eq(Game.phase, GameManagerAutoload.Phase.DEATH)
  assert_false(Save.has_save(), 'a death clears the run save')


func test_resume_rebuilds_from_the_save() -> void:
  Game.start_run(5)
  _play_one_beat(Game.run, 0)        # advance autosaves at the new beat (position 1)
  var resumed := Game.resume_run()
  assert_true(resumed, 'a usable save resumes')
  assert_eq(Game.phase, GameManagerAutoload.Phase.RUN)
  assert_eq(Game.run.position, 1, 'resumed at the saved beat')


func test_resume_with_no_save_returns_false() -> void:
  Save.clear()
  assert_false(Game.resume_run(), 'nothing to resume → stay put')


func test_starting_a_run_replaces_the_previous() -> void:
  Game.start_run(1)
  var first := Game.run
  Game.start_run(2)
  assert_false(is_instance_valid(first), 'the previous run was torn down')
  assert_eq(Game.run.position, 0, 'the new run is fresh')


# --- battle-speed dial (a session preference) --------------------------------

func test_battle_speed_defaults_to_x1() -> void:
  assert_eq(Game.battle_speed_index, 0, 'the dial starts at the first notch')
  assert_almost_eq(Game.battle_speed, Balance.BATTLE_SPEEDS[0], 0.00001, 'and at ×1')


func test_cycle_battle_speed_walks_the_dial_and_wraps() -> void:
  Game.cycle_battle_speed()
  assert_almost_eq(Game.battle_speed, Balance.BATTLE_SPEEDS[1], 0.00001, '×1 → ×2')
  Game.cycle_battle_speed()
  assert_almost_eq(Game.battle_speed, Balance.BATTLE_SPEEDS[2], 0.00001, '×2 → ×3')
  Game.cycle_battle_speed()
  assert_almost_eq(Game.battle_speed, Balance.BATTLE_SPEEDS[0], 0.00001, '×3 wraps back to ×1')


func test_cycle_battle_speed_emits_the_new_scale() -> void:
  watch_signals(Game)
  Game.cycle_battle_speed()
  assert_signal_emitted_with_parameters(Game, 'battle_speed_changed', [Balance.BATTLE_SPEEDS[1]])


func test_reset_restores_the_default_battle_speed() -> void:
  Game.cycle_battle_speed()   # leave the dial off the default
  assert_eq(Game.battle_speed_index, 1, 'dial moved')
  Game.reset()
  assert_eq(Game.battle_speed_index, 0, 'a session reset drops the dial to ×1')
  assert_almost_eq(Game.battle_speed, Balance.TIMESCALE_BASE, 0.00001, 'and back to base scale')
