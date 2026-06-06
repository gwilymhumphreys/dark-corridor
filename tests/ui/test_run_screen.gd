extends GutTest
## Phase 4 Step 4 — the run-screen state machine drives a full descent in real time,
## mirroring AutoTestMode.run_full. Driven here by manual _physics_process(delta) calls
## (synchronous — no awaited frames), so each fight ticks ~8 sim-steps per call and the
## whole run resolves fast. The autotest remains the broader headless backstop; this
## confirms the screen's FSM glue (enter beat → fight/rest → draft → advance → win).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_run_screen_drives_a_full_run_to_a_win() -> void:
  Game.start_run(1)
  var screen: Control = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)   # _ready enters the first beat + builds the first fight

  var guard: int = 0
  while Game.phase == GameManagerAutoload.Phase.RUN and guard < 8000:
    if screen._draft != null:
      screen._on_draft_picked(0)   # stand in for the player picking the first card
    else:
      screen._physics_process(1.0)   # ~8 sim-steps/call; drives fights + advances beats
    guard += 1

  assert_eq(Game.phase, GameManagerAutoload.Phase.WIN, 'the run screen drove the descent to a win')
  assert_lt(guard, 8000, 'the run resolved well within the guard')
  # Two fight beats granted drafts (picked via the overlay), so the board grew past 3.
  assert_gt(Game.run.player.board.size(), 3, 'drafted picks landed on the board')

  screen.free()


func test_fight_beat_approaches_then_fights() -> void:
  # A fight beat opens with the corridor approach (combat frozen), then begins on
  # arrival. The clock is not ticked until FIGHTING, so the enemy is unharmed while
  # it walks in.
  Game.start_run(1)
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  assert_eq(screen._state, RunScreen.State.APPROACHING, 'a fight beat starts in the approach')
  for i in 4:   # 4s of delta walks past APPROACH_DURATION (2.5s)
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'combat begins on arrival')
  screen.free()


func test_a_fight_opens_at_the_current_battle_speed() -> void:
  # The dial is a Game session preference; a fight beginning after it was set inherits
  # it as the Timekeeper's base scale.
  Game.start_run(1)
  Game.set_battle_speed_index(2)   # ×3 before the screen mounts
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  for i in 4:   # walk the approach into the fight
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.BATTLE_SPEEDS[2], 0.00001,
    'the fight inherits the dial set before it began')
  screen.free()


func test_battle_speed_dial_retimes_the_live_fight() -> void:
  Game.start_run(1)
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  for i in 4:
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.BATTLE_SPEEDS[0], 0.00001,
    'opens at ×1 by default')
  Game.set_battle_speed_index(2)   # ×3 mid-fight
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.BATTLE_SPEEDS[2], 0.00001,
    'changing the dial retimes the live fight at once')
  screen.free()


func test_throwing_a_potion_in_a_fight_consumes_it() -> void:
  Game.start_run(1)
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  for i in 4:   # walk the approach into the fight
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  var before: int = Game.run.potions.size()
  assert_gt(before, 0, 'a starting Healing Draught is held')
  screen._on_potion_thrown(0)
  assert_eq(Game.run.potions.size(), before - 1, 'the thrown potion is consumed')
  screen.free()
