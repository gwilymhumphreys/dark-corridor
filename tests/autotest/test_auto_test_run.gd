extends GutTest
## Step 7 — the autotest driving a whole run (Game → Run → Encounter → Combat).
## The default map clears to a win, the run is deterministic by seed, drafts are
## taken + logged, the --encounters cap stops early, and a mid-run save/reload
## finishes the descent (resume smoke).


var _modes: Array = []


func before_each() -> void:
  Save.clear()
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for m in _modes:
    if is_instance_valid(m):
      m.free()
  _modes.clear()
  TestCleanup.reset_all_managers()
  Save.clear()


func _mode(seed_value: int = 1) -> AutoTestMode:
  var m := AutoTestMode.new()   # never added to the tree → _ready/quit don't fire
  m.seed_value = seed_value
  _modes.append(m)
  return m


func _draft_events(logger: AutoTestLogger) -> int:
  var n: int = 0
  for ev in logger.events:
    if ev['type'] == 'draft':
      n += 1
  return n


# --- tests ------------------------------------------------------------------

func test_run_full_clears_the_map_as_a_win() -> void:
  var r := _mode(1).run_full()
  assert_eq(r['outcome'], 'WON', 'the compounding build clears the multi-act map')
  assert_true(r['resolved'])
  assert_eq(r['exit_code'], 0)
  assert_eq(r['beats_cleared'], RunMap.TOTAL_BEATS, 'every beat of the descent cleared')
  assert_gt(r['board_size'], 3, 'fight drafts grew the board across the run')
  assert_gt(r['summary']['total_damage'], 0.0, 'damage was tallied across the run')


func test_run_full_is_deterministic() -> void:
  var a := _mode(7).run_full()
  var b := _mode(7).run_full()
  assert_eq(a['outcome'], b['outcome'])
  assert_eq(a['beats_cleared'], b['beats_cleared'])
  assert_eq(a['board_size'], b['board_size'])
  assert_almost_eq(a['player_hp'], b['player_hp'], 0.0001, 'same seed ⇒ identical run')
  assert_almost_eq(a['summary']['total_damage'], b['summary']['total_damage'], 0.0001)


func test_run_full_takes_and_logs_drafts() -> void:
  var m := _mode(1)
  m.run_full()
  assert_gt(_draft_events(m.logger), 5, 'the run\'s many fight beats each offered a draft, picked')


func test_run_full_throws_the_starting_potion() -> void:
  var m := _mode(1)
  m.run_full()
  var thrown: int = 0
  for ev in m.logger.events:
    if ev['type'] == 'potion_thrown':
      thrown += 1
  assert_eq(thrown, 1, 'the Driver throws the starting potion once over the run')


func test_encounters_cap_stops_early() -> void:
  var m := _mode(1)
  m.encounters = 1
  var r := m.run_full()
  assert_eq(r['outcome'], 'CAP')
  assert_eq(r['beats_cleared'], 1, 'only the first beat was played')
  assert_eq(r['exit_code'], 0, 'a deliberate cap is not a failure')


func test_run_full_works_across_strategies() -> void:
  # --strategy is live: each seeded strategy plays its own build to a clean verdict.
  for strat in ['greedy-synergy', 'damage', 'random']:
    var m := _mode(3)
    m.strategy = strat
    var r := m.run_full()
    assert_eq(r['exit_code'], 0, '%s reaches a clean verdict' % strat)
    assert_true(r['resolved'], '%s resolved' % strat)


func test_run_full_report_has_per_encounter_and_contribution() -> void:
  var m := _mode(1)
  var r := m.run_full()
  var s: Dictionary = r['summary']
  assert_gt(s['encounters'].size(), 0, 'per-encounter records captured')
  assert_eq(s['encounters'][0]['type'], 'Fight', 'the first beat is a fight')
  assert_gt(float(s['encounters'][0]['duration']), 0.0, 'fight duration recorded')
  assert_false(s['fires_by_item'].is_empty(), 'player item fires tallied')
  assert_eq(s['strategy'], 'first-viable', 'the strategy is recorded')


func test_run_full_credits_poison_to_its_applier_in_the_contribution_table() -> void:
  # The starting board holds Venom Fang; its poison ticks must show as ITS damage in
  # the contribution table — not lumped under a generic Poison channel (it read 0 before).
  var m := _mode(1)
  var r := m.run_full()
  var venom: Dictionary = {}
  for row in m.logger._item_contribution_rows(r['summary']):
    if row['name'] == 'Venom Fang':
      venom = row
  assert_false(venom.is_empty(), 'Venom Fang is on the board')
  assert_gt(float(venom['damage']), 0.0, 'its poison damage is credited to it')
  assert_false(venom['trap'], 'so a working poison item is never mis-flagged a trap')


func test_run_full_honors_nosave_writes_nothing() -> void:
  # The headless autotest forces nosave, so it must NOT touch the real run slot.
  # Cap at one beat so the run is left CAPPED (not won) — a win would end-clear the
  # save and hide whether anything was written. nosave defaults true.
  Save.clear()
  var m := _mode(1)
  m.encounters = 1
  m.run_full()
  assert_false(Save.has_save(), 'a nosave autotest run writes no save, even mid-run')


func test_run_full_with_saving_on_autosaves() -> void:
  Save.clear()
  var m := _mode(1)
  m.encounters = 1
  m.nosave = false
  m.run_full()
  assert_true(Save.has_save(), 'with saving on, the autotest autosaves at encounter entry')


func test_resume_mid_run_finishes_the_descent() -> void:
  # Resume smoke: play part of a run, reload from the autosave, and finish it.
  Game.start_run(3)
  _play_one_beat(Game.run, 0)            # beat 0 cleared; autosaved at the next beat
  assert_eq(Game.run.position, 1)
  assert_true(Game.resume_run(), 'the autosave is resumable')
  _play_to_end(Game.run, 0)
  assert_true(Game.run.is_ended())
  assert_eq(Game.run.outcome(), RunManager.Outcome.WON, 'the resumed descent still wins')


# --- tune-report fidelity ----------------------------------------------------

func test_block_is_tallied_per_item_for_the_report() -> void:
  # Defensive items must be RANKABLE, not just trap-cleared by firing: the run summary
  # carries block-applied per item (Iron Guard is in the Wanderer's starting kit).
  var r := _mode(1).run_full()
  var armor_name: String = ItemCatalog.get_def(ItemCatalog.ARMOR).name_key
  assert_gt(float(r['summary']['block_by_item'].get(armor_name, 0.0)), 0.0,
      'the block item shows its applied block in the summary')


func test_summary_carries_seed_and_strategy() -> void:
  var m := _mode(7)
  m.strategy = 'damage'
  var r := m.run_full()
  assert_eq(int(r['summary']['seed']), 7, 'the seed rides the summary into the report')
  assert_eq(r['summary']['strategy'], 'damage', 'and so does the strategy')


func test_body_block_fight_is_not_falsely_stuck() -> void:
  # Observation + the stuck guard read the LIVE rosters: a summon token tanking the
  # enemy is progress (its HP moves), not a stall — previously only the fight-start
  # pair was watched and this exact shape tripped a false STUCK.
  var m := _mode(1)
  m.logger = AutoTestLogger.new()
  m.stuck_threshold_seconds = 2.0
  var player := Actor.new(30.0)            # no items — contributes nothing itself
  var enemy := Actor.new(20.0)
  enemy.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.ENEMY_CLAW), enemy))
  var cm := CombatManager.new(player, [enemy])
  cm.start()
  var token := Actor.new(40.0)             # a pure body-block token, leftmost
  cm.add_actor(token, true, true)
  var fr: Dictionary = m._drive_fight(
      cm, player, Time.get_ticks_msec(), 30000, AutoTestMode.seconds_to_steps(60.0))
  assert_ne(fr['outcome'], 'STUCK', "the token's HP movement counts as progress")
  cm.teardown()
  cm.free()


# --- helpers (drive Game.run as the autotest loop does) ---------------------

func _play_one_beat(run: RunManager, pick: int) -> void:
  if run.has_pending_choice():
    run.pick_path(pick)
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
