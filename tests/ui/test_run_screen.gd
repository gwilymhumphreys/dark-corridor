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
    if screen._event != null:
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


func test_fight_beat_approaches_then_fights() -> void:
  # A fight beat opens with the corridor approach (combat frozen), then begins on
  # arrival. The clock is not ticked until FIGHTING, so the enemy is unharmed while
  # it walks in. (The opening beat auto-rolls to a fight.)
  var screen := _mount_into_fight(1)
  assert_eq(screen._state, RunScreen.State.APPROACHING, 'a fight beat starts in the approach')
  for _i in 4:   # 4s of delta walks past APPROACH_DURATION (2.5s)
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'combat begins on arrival')
  screen.free()


func test_a_fight_opens_at_the_current_battle_speed() -> void:
  # The dial is a Game session preference; a fight beginning after it was set inherits
  # it as the Timekeeper's base scale.
  Game.start_run(1)
  Game.set_battle_speed_index(2)   # ×3 before the screen mounts
  var screen := _mount_into_fight(-1)   # -1: run already started above
  for _i in 4:   # walk the approach into the fight
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.BATTLE_SPEEDS[2], 0.00001,
    'the fight inherits the dial set before it began')
  screen.free()


func test_battle_speed_dial_retimes_the_live_fight() -> void:
  var screen := _mount_into_fight(1)
  for _i in 4:
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
  for _i in 4:   # walk the approach into the fight
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
  for _i in 4:   # walk the approach into the fight
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
  for _i in 4:
    screen._physics_process(1.0)
  screen._toggle_pause()
  var frozen: float = screen._cm.timekeeper.sim_time
  for _i in 3:
    screen._physics_process(1.0)   # ignored while paused
  assert_almost_eq(screen._cm.timekeeper.sim_time, frozen, 0.00001, 'paused: the fight clock does not advance')
  screen._toggle_pause()           # resume
  screen._physics_process(1.0)
  assert_gt(screen._cm.timekeeper.sim_time, frozen, 'resumed: the clock advances again')
  screen.free()


func test_quit_to_menu_returns_to_title_with_the_save_intact() -> void:
  var screen := _mount_into_fight(1)
  for _i in 4:
    screen._physics_process(1.0)
  screen._toggle_pause()
  screen._quit_to_menu()
  assert_eq(Game.phase, GameManagerAutoload.Phase.TITLE, 'quit-to-menu lands on Title')
  assert_true(Save.has_save(), 'the run save persists so Title can resume it')
  screen.free()


func test_settings_opens_over_the_pause_menu_and_closes_back() -> void:
  var screen := _mount_into_fight(1)
  for _i in 4:
    screen._physics_process(1.0)
  screen._toggle_pause()
  assert_not_null(screen._pause_menu, 'paused')
  screen._pause_menu.settings_pressed.emit()    # the pause menu's Settings button
  assert_not_null(screen._settings, 'settings opens over the pause menu')
  assert_eq(screen._settings.get_parent(), screen._pause_menu,
    'inside the pause CanvasLayer (layer 100), so its opaque screen covers the paused panel')
  screen._settings.closed.emit()                # Back
  assert_null(screen._settings, 'Back closes settings')
  assert_true(screen._paused, 'and the run is still paused underneath')
  screen.free()


# Mount the run screen into a live FIGHT. Beats 0 .. EASY_BEATS_END auto-roll to forced (easy)
# combat, so the opening beat is always a fight — _ready begins its approach. `seed >= 0` starts
# a fresh run first.
func _mount_into_fight(seed_value: int) -> RunScreen:
  if seed_value >= 0:
    Game.start_run(seed_value)
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  return screen


# Mount the run screen into an EVENT beat. Beats auto-roll (events are positional + rare), so drive
# the current beat to an event directly — the event overlay is the unit under test here.
func _mount_into_event(seed_value: int) -> RunScreen:
  Game.start_run(seed_value)
  Game.run._teardown_current()
  Game.run._current_def_id = EncounterCatalog.EVENT_SHRINE
  Game.run._create_current_encounter()
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)   # _ready → _enter_beat → _begin_beat → _show_event
  return screen


func test_event_beat_raises_the_event_overlay_and_resolves_on_pick() -> void:
  # An event beat raises the event overlay; an option pick applies its outcome (heal), dismisses
  # the overlay, then advances.
  var screen := _mount_into_event(1)
  Game.run.player.hp = 1.0   # so the heal outcome is observable
  assert_eq(screen._state, RunScreen.State.EVENTING, 'the event raises its overlay')
  assert_not_null(screen._event, 'the event overlay is up')
  screen._on_event_picked(0)   # 'Kneel and drink' → heal a fraction of max HP
  assert_null(screen._event, 'the pick dismisses the overlay')
  assert_gt(Game.run.player.hp, 1.0, 'the chosen outcome was applied (healed)')
  screen.free()


func test_pause_available_during_an_event() -> void:
  var screen := _mount_into_event(1)
  assert_eq(screen._state, RunScreen.State.EVENTING, 'at the event')
  screen._unhandled_input(_escape())
  assert_true(screen._paused, 'Escape pauses during an event')
  screen.free()


func _escape() -> InputEventAction:
  var ev := InputEventAction.new()
  ev.action = 'ui_cancel'
  ev.pressed = true
  return ev
