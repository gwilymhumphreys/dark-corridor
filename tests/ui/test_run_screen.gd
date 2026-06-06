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
  while Game.phase == GameManagerAutoload.Phase.RUN and guard < 12000:
    if screen._choice != null:
      screen._on_choice_picked(0)   # stand in for the player picking a path
    elif screen._event != null:
      screen._on_event_picked(0)    # the event's binary choice
    elif screen._draft != null:
      screen._on_draft_picked(0)    # stand in for the player picking the first card
    else:
      screen._physics_process(1.0)   # ~8 sim-steps/call; drives fights + advances beats
    guard += 1

  assert_eq(Game.phase, GameManagerAutoload.Phase.WIN, 'the run screen drove the descent to a win')
  assert_lt(guard, 12000, 'the run resolved well within the guard')
  # Fight beats granted drafts (picked via the overlay), so the board grew past 3.
  assert_gt(Game.run.player.board.size(), 3, 'drafted picks landed on the board')

  screen.free()


func test_choice_beat_raises_the_choice_overlay() -> void:
  Game.start_run(1)
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  assert_eq(screen._state, RunScreen.State.CHOOSING, 'the opening (choice) beat parks in CHOOSING')
  assert_not_null(screen._choice, 'the choice overlay is up')
  screen._on_choice_picked(0)
  assert_null(screen._choice, 'picking dismisses the overlay')
  assert_eq(screen._state, RunScreen.State.APPROACHING, 'the chosen encounter begins approaching')
  screen.free()


func test_fight_beat_approaches_then_fights() -> void:
  # A fight beat opens with the corridor approach (combat frozen), then begins on
  # arrival. The clock is not ticked until FIGHTING, so the enemy is unharmed while
  # it walks in. (The opening beat is a choice — pick a path to reach the fight.)
  var screen := _mount_into_fight(1)
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
  var screen := _mount_into_fight(-1)   # -1: run already started above
  for i in 4:   # walk the approach into the fight
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.BATTLE_SPEEDS[2], 0.00001,
    'the fight inherits the dial set before it began')
  screen.free()


func test_battle_speed_dial_retimes_the_live_fight() -> void:
  var screen := _mount_into_fight(1)
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
  var screen := _mount_into_fight(1)
  for i in 4:   # walk the approach into the fight
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  var before: int = Game.run.potions.size()
  assert_gt(before, 0, 'a starting Healing Draught is held')
  screen._on_potion_thrown(0)
  assert_eq(Game.run.potions.size(), before - 1, 'the thrown potion is consumed')
  screen.free()
  # The throw rebuilds the potion row: the old slot is detached + queue_free'd (deferred
  # — its own `pressed` signal is still unwinding, so an immediate free would lock-error).
  # This test is otherwise synchronous; flush one frame so that deferred free runs (no orphan).
  await get_tree().process_frame


# --- pause + quit-to-menu ----------------------------------------------------

func test_escape_toggles_pause_during_a_fight() -> void:
  var screen := _mount_into_fight(1)
  for i in 4:   # walk the approach into the fight
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  screen._unhandled_input(_escape())
  assert_true(screen._paused, 'Escape pauses')
  assert_not_null(screen._pause_menu, 'the pause menu is up')
  screen._unhandled_input(_escape())
  assert_false(screen._paused, 'Escape again resumes')
  assert_null(screen._pause_menu, 'the pause menu is gone')
  screen.free()


func test_pause_freezes_the_clock_and_resume_restores_it() -> void:
  var screen := _mount_into_fight(1)
  for i in 4:
    screen._physics_process(1.0)
  screen._toggle_pause()
  var frozen: float = screen._cm.timekeeper.sim_time
  for i in 3:
    screen._physics_process(1.0)   # ignored while paused
  assert_almost_eq(screen._cm.timekeeper.sim_time, frozen, 0.00001, 'paused: the fight clock does not advance')
  screen._toggle_pause()           # resume
  screen._physics_process(1.0)
  assert_gt(screen._cm.timekeeper.sim_time, frozen, 'resumed: the clock advances again')
  screen.free()


func test_quit_to_menu_returns_to_title_with_the_save_intact() -> void:
  var screen := _mount_into_fight(1)
  for i in 4:
    screen._physics_process(1.0)
  screen._toggle_pause()
  screen._quit_to_menu()
  assert_eq(Game.phase, GameManagerAutoload.Phase.TITLE, 'quit-to-menu lands on Title')
  assert_true(Save.has_save(), 'the run save persists so Title can resume it')
  screen.free()


# Mount the run screen and resolve the opening choice beat into a FIGHT (most tests below
# exercise the live fight). The act pool also holds an event, so pick the first fight
# candidate, not blindly index 0. `seed >= 0` starts a fresh run first.
func _mount_into_fight(seed_value: int) -> RunScreen:
  if seed_value >= 0:
    Game.start_run(seed_value)
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  if screen._choice != null:
    screen._on_choice_picked(_first_candidate_of_type(EncounterDef.Type.FIGHT))
  return screen


func _first_candidate_of_type(type: int) -> int:
  var candidates: Array = Game.run.pending_choice()
  for i in candidates.size():
    if EncounterCatalog.get_def(candidates[i]).type == type:
      return i
  return 0


func test_event_beat_raises_the_event_overlay_and_resolves_on_pick() -> void:
  # Find a seed whose opening choice offers the event, pick it → the event overlay; an
  # option pick applies its outcome (heal) and dismisses the overlay, then advances.
  var seed_value: int = _seed_with_opening_event()
  assert_true(seed_value >= 0, 'a seed offering the event at the opening choice exists')
  if seed_value < 0:
    return
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  Game.run.player.hp = 1.0   # so the heal outcome is observable
  screen._on_choice_picked(_first_candidate_of_type(EncounterDef.Type.EVENT))
  assert_eq(screen._state, RunScreen.State.EVENTING, 'the event raises its overlay')
  assert_not_null(screen._event, 'the event overlay is up')
  screen._on_event_picked(0)   # 'Kneel and drink' → heal a fraction of max HP
  assert_null(screen._event, 'the pick dismisses the overlay')
  assert_gt(Game.run.player.hp, 1.0, 'the chosen outcome was applied (healed)')
  screen.free()


func _seed_with_opening_event() -> int:
  for s in 50:
    Game.start_run(s)
    if EncounterCatalog.Id.EVENT_SHRINE in Game.run.pending_choice():
      return s
    Game.reset()
  return -1


func _escape() -> InputEventAction:
  var ev := InputEventAction.new()
  ev.action = 'ui_cancel'
  ev.pressed = true
  return ev
