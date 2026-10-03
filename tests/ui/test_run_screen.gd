extends GutTest
## Phase 4 Step 4 — the run-screen state machine drives a full descent in real time,
## mirroring AutoTestMode.run_full. Driven here by manual _physics_process(delta) calls
## (synchronous — no awaited frames), so each fight ticks ~8 sim-steps per call and the
## whole run resolves fast. The autotest remains the broader headless backstop; this
## confirms the screen's FSM glue (enter beat → choice → fight/rest → draft → advance → win).

## One second of delta per step, enough to walk past `Balance.APPROACH_DURATION` however that
## is tuned, so retiming the approach does not break every fight test in this file.
const APPROACH_STEPS: int = int(ceil(Balance.APPROACH_DURATION)) + 1


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_run_screen_drives_a_full_run_to_a_win() -> void:
  Game.start_run(1, FixtureCharacter.ID)
  var screen: Control = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)   # _ready enters the first beat + builds the first fight

  var guard: int = 0
  while Game.phase == GameManagerAutoload.Phase.RUN and guard < 12000:
    if screen._event != null:
      screen._on_event_picked(0)    # the event's first option
    elif screen._rest != null:
      screen._on_rest_continued()   # the rest panel's Continue
    elif screen._state == RunScreen.State.CHOOSING:
      screen._choice.picked.emit(0)   # stand in for the player picking the left encounter card
    elif screen._draft != null:
      screen._draft.picked.emit(0)    # stand in for the player picking the first reward
    elif screen._view != null and screen._view.burning():
      screen._view.finish_burns()   # no frames pass here, so the dead enemies' burns are ended at once
    elif screen.leaving_fight:
      await wait_seconds(Balance.FIGHT_END_PAUSE + 0.05)   # the pause after the burns runs on a timer
    else:
      screen._physics_process(1.0)   # ~8 sim-steps/call; drives fights + advances beats
    guard += 1

  assert_eq(Game.phase, GameManagerAutoload.Phase.WIN, 'the run screen drove the descent to a win')
  assert_lt(guard, 12000, 'the run resolved well within the guard')

  screen.free()


func test_a_finished_fight_offers_its_report_on_the_hud() -> void:
  # A fight no longer parks the run: it resolves straight on to the draft, and its log stays
  # available behind the Report button, which toggles the report panel open and shut.
  var screen := _mount_into_fight(1)
  assert_true(screen._report_button.visible, 'the Report button is up before any fight has finished')
  var guard: int = 0
  while screen._last_log == null and Game.phase == GameManagerAutoload.Phase.RUN and guard < 400:
    screen._physics_process(1.0)
    guard += 1
  assert_not_null(screen._last_log, 'the finished fight left its log for the report')
  assert_true(screen._report_button.visible, 'the Report button stays up once a fight has finished')
  assert_null(screen._summary, 'the report is not raised on its own')
  screen._toggle_report()
  assert_not_null(screen._summary, 'the Report button raises the report')
  screen._toggle_report()
  assert_null(screen._summary, 'pressing it again puts the report away')
  screen.free()


func test_a_won_fight_burns_its_map_square() -> void:
  var screen := _mount_into_fight(1)
  var square: int = screen._map.current_square()[0]
  var guard: int = 0
  while screen._last_log == null and Game.phase == GameManagerAutoload.Phase.RUN and guard < 400:
    screen._physics_process(1.0)
    guard += 1
  assert_eq(Game.phase, GameManagerAutoload.Phase.RUN, 'the fixture fight is won')
  assert_true(screen._map.is_burning(square), 'the square of the won fight is burning away')
  screen.free()


func test_a_won_fight_waits_for_its_last_enemy_to_burn_away() -> void:
  var screen := _mount_into_fight(1)
  var fight_view: CombatView = screen._view
  var guard: int = 0
  while screen._last_log == null and Game.phase == GameManagerAutoload.Phase.RUN and guard < 400:
    screen._physics_process(1.0)
    guard += 1
  assert_true(fight_view.burning(), 'the last enemy is burning away')
  assert_eq(screen._view, fight_view, 'and the run has not moved on yet')
  assert_null(screen._draft, 'nor raised the reward')
  fight_view.finish_burns()
  assert_false(fight_view.burning(), 'the burn is over')
  assert_eq(screen._view, fight_view, 'the run pauses before moving on')
  await wait_seconds(Balance.FIGHT_END_PAUSE + 0.05)
  assert_true(screen._draft != null or screen._view != fight_view, 'then it moves on')
  screen.free()


func test_fight_beat_approaches_then_fights() -> void:
  # A fight beat opens with the corridor approach (combat frozen), then begins on
  # arrival. The clock is not ticked until FIGHTING, so the enemy is unharmed while
  # it walks in.
  var screen := _mount_into_fight(1)
  assert_eq(screen._state, RunScreen.State.APPROACHING, 'a fight beat starts in the approach')
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'combat begins on arrival')
  screen.free()


func test_enemy_readouts_fade_up_before_arrival() -> void:
  # The enemy's name, health and items are revealed over the end of the walk, so they are
  # already up when the fight starts rather than appearing with it.
  var screen := _mount_into_fight(1)
  var view: CombatViewFramed = screen._view as CombatViewFramed
  assert_false(view._enemies_shown, 'the readouts are down when the walk begins')
  # Walk to the moment the reveal is due, a whisker inside it so float error cannot land short.
  screen._physics_process(Balance.APPROACH_DURATION - Balance.ENEMY_REVEAL_DURATION + 0.01)
  assert_true(view._enemies_shown, 'the reveal starts before arrival')
  assert_eq(screen._state, RunScreen.State.APPROACHING, 'the walk is still going')
  screen.free()


func test_a_fight_opens_at_the_current_battle_speed() -> void:
  # The dial is a Game session preference; a fight beginning after it was set inherits
  # it as the Timekeeper's base scale.
  Game.start_run(1, FixtureCharacter.ID)
  Game.set_battle_speed_index(0)   # the slowest notch before the screen mounts
  var screen := _mount_into_fight(-1)   # -1: run already started above
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.BATTLE_SPEEDS[0], 0.00001,
    'the fight inherits the dial set before it began')
  screen.free()


func test_battle_speed_dial_retimes_the_live_fight() -> void:
  var screen := _mount_into_fight(1)
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.TIMESCALE_BASE, 0.00001,
    'opens at ×1 by default')
  Game.set_battle_speed_index(0)   # the slowest notch mid-fight
  assert_almost_eq(screen._cm.timekeeper.base_scale, Balance.BATTLE_SPEEDS[0], 0.00001,
    'changing the dial retimes the live fight at once')
  screen.free()


func _action_press(action: String) -> InputEventAction:
  var event: InputEventAction = InputEventAction.new()
  event.action = action
  event.pressed = true
  return event


func test_speed_keys_step_the_dial_and_stop_at_the_ends() -> void:
  var screen := _mount_into_fight(1)
  var start: int = Game.battle_speed_index
  screen._unhandled_input(_action_press('battle_speed_up'))
  assert_eq(Game.battle_speed_index, start + 1, 'the faster key steps one notch')
  screen._unhandled_input(_action_press('battle_speed_down'))
  assert_eq(Game.battle_speed_index, start, 'the slower key steps back')
  Game.set_battle_speed_index(0)
  screen._unhandled_input(_action_press('battle_speed_down'))
  assert_eq(Game.battle_speed_index, 0, 'the slowest does not wrap')
  screen.free()


func test_speed_keys_do_nothing_while_paused() -> void:
  var screen := _mount_into_fight(1)
  var start: int = Game.battle_speed_index
  screen._pause(false)
  screen._unhandled_input(_action_press('battle_speed_up'))
  assert_eq(Game.battle_speed_index, start, 'paused, the key is ignored')
  screen.free()


func test_throwing_a_potion_in_a_fight_consumes_it() -> void:
  var screen := _mount_into_fight(1)
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  # Granted here: no authored character starts with a potion, and this test is about the throw.
  Game.run.potions.append(Consumable.new(FixtureKit.potion()))
  var before: int = Game.run.potions.size()
  assert_gt(before, 0, 'a potion is held')
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
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'in the fight')
  screen._unhandled_input(_escape())
  assert_true(screen._paused, 'Escape pauses')
  assert_not_null(screen._pause_menu, 'the pause menu is up')
  screen._unhandled_input(_escape())
  assert_false(screen._paused, 'Escape again resumes')
  assert_null(screen._pause_menu, 'the pause menu is gone')
  screen.free()


func test_space_pauses_without_the_menu_and_shows_the_paused_panel() -> void:
  var screen := _mount_into_fight(1)
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  screen._unhandled_input(_space())
  assert_true(screen._paused, 'Space pauses')
  assert_null(screen._pause_menu, 'without the pause menu')
  assert_true(screen._paused_panel.visible, 'the Paused panel shows')
  var frozen: float = screen._cm.timekeeper.sim_time
  screen._physics_process(1.0)
  assert_almost_eq(screen._cm.timekeeper.sim_time, frozen, 0.00001, 'the fight clock is frozen')
  screen._unhandled_input(_space())
  assert_false(screen._paused, 'Space again resumes')
  assert_false(screen._paused_panel.visible, 'the Paused panel hides')
  screen.free()


func test_opening_a_debug_panel_pauses_and_closing_it_resumes() -> void:
  var screen := _mount_into_fight(1)
  DebugPanels.panels_open_changed.emit(true)
  assert_true(screen._paused, 'opening a panel pauses')
  assert_null(screen._pause_menu, 'without the pause menu')
  assert_true(screen._paused_panel.visible, 'the Paused panel shows')
  DebugPanels.panels_open_changed.emit(false)
  assert_false(screen._paused, 'closing the last panel resumes')
  screen.free()


func test_closing_a_debug_panel_keeps_a_pause_the_player_chose() -> void:
  var screen := _mount_into_fight(1)
  screen._unhandled_input(_space())
  DebugPanels.panels_open_changed.emit(true)
  DebugPanels.panels_open_changed.emit(false)
  assert_true(screen._paused, 'a Space pause from before the panel opened stays')
  screen._unhandled_input(_space())
  DebugPanels.panels_open_changed.emit(true)
  screen._unhandled_input(_escape())
  DebugPanels.panels_open_changed.emit(false)
  assert_true(screen._paused, 'the pause menu raised over a panel pause stays up')
  assert_not_null(screen._pause_menu, 'with the menu showing')
  screen.free()


func test_escape_during_a_space_pause_raises_the_menu_and_stays_paused() -> void:
  var screen := _mount_into_fight(1)
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  screen._unhandled_input(_space())
  screen._unhandled_input(_escape())
  assert_true(screen._paused, 'still paused')
  assert_not_null(screen._pause_menu, 'Escape raises the pause menu')
  assert_false(screen._paused_panel.visible, 'the menu replaces the Paused panel')
  screen._unhandled_input(_space())
  assert_not_null(screen._pause_menu, 'Space does nothing while the menu is up')
  screen._pause_menu.resume_pressed.emit()
  assert_false(screen._paused, 'Resume unpauses')
  assert_false(screen._paused_panel.visible, 'and no panel is left showing')
  screen.free()


func test_pause_freezes_the_clock_and_resume_restores_it() -> void:
  var screen := _mount_into_fight(1)
  for _i in APPROACH_STEPS:
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
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  screen._toggle_pause()
  screen._quit_to_menu()
  assert_eq(Game.phase, GameManagerAutoload.Phase.TITLE, 'quit-to-menu lands on Title')
  assert_true(Save.has_save(), 'the run save persists so Title can resume it')
  screen.free()


func test_settings_opens_over_the_pause_menu_and_closes_back() -> void:
  var screen := _mount_into_fight(1)
  for _i in APPROACH_STEPS:
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
# Mount the run screen into the first fight: the run walks past the opening choice of encounters.
func _mount_into_fight(seed_value: int) -> RunScreen:
  if seed_value >= 0:
    Game.start_run(seed_value, FixtureCharacter.ID)
  Game.run.skip_choice()
  Game.run.advance()
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  return screen


# Mount the run screen into an EVENT beat, set directly rather than picked from the choice of
# encounters — the event overlay is the unit under test here.
func _mount_into_event(seed_value: int) -> RunScreen:
  Game.start_run(seed_value, FixtureCharacter.ID)
  Game.run._pending_choice.clear()
  Game.run._teardown_current()
  Game.run._current_def_id = FixtureEncounters.EVENT
  Game.run._create_current_encounter()
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)   # _ready → _enter_beat → _begin_beat → _show_event
  return screen


# --- the choice of encounters before each fight (docs/plans/encounter_choice.md) --------------

func _mount_into_choice() -> RunScreen:
  Game.start_run(1, FixtureCharacter.ID)
  var screen: RunScreen = preload('res://src/scenes/screens/run_screen.tscn').instantiate()
  add_child(screen)
  return screen


func test_a_choice_beat_walks_up_to_the_encounter_cards() -> void:
  var screen := _mount_into_choice()
  assert_eq(screen._state, RunScreen.State.WALKING, 'the choice opens with a walk up the corridor')
  assert_eq(screen._choice.get_parent(), screen._view.corridor_area(), 'the cards stand in the corridor area')
  assert_false(screen._choice.is_revealed(), 'hidden while the walk begins')
  assert_eq(screen._choice.mouse_filter, Control.MOUSE_FILTER_IGNORE, 'the choice does not block the rest of the screen')
  screen._physics_process(Balance.APPROACH_DURATION - 0.01)
  assert_false(screen._choice.is_revealed(), 'still hidden just before the walk ends')
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  assert_true(screen._choice.is_revealed(), 'the cards are dealt once the player stops')
  assert_eq(screen._state, RunScreen.State.CHOOSING, 'then the player chooses')
  assert_eq(screen._choice.get_node('Cards').get_child_count(), EncounterPools.POSITIONS, 'a card per encounter')
  screen.free()


func test_the_cards_stand_side_by_side_in_the_corridor() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  var area: Rect2 = screen._view.corridor_area().get_global_rect()
  var previous_x: float = -INF
  for i in screen._choice.get_node('Cards').get_child_count():
    var centre: Vector2 = screen._choice.rest_point(i)   # where it lands; the deal is still under way
    assert_gt(centre.x, previous_x, 'left to right')
    assert_true(area.has_point(centre), 'inside the corridor')
    previous_x = centre.x
  screen.free()


func test_picking_a_card_begins_its_encounter() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  screen._choice.picked.emit(FixtureEncounters.CHOICE_EVENT)
  assert_null(screen._choice, 'the choice is over')
  assert_eq(screen._state, RunScreen.State.EVENTING, 'and the picked event raises its panel')
  screen.free()


func test_a_rest_shows_its_panel_until_continue() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  Game.run.player.hp = 10
  screen._choice.picked.emit(FixtureEncounters.CHOICE_REST)
  assert_eq(screen._state, RunScreen.State.RESTING, 'the rest raises its panel')
  assert_eq(screen._rest.get_parent(), screen._view.corridor_area(), 'in the corridor area')
  assert_gt(Game.run.player.hp, 10, 'the heal is already applied')
  var position: int = Game.run.position
  screen._on_rest_continued()
  assert_null(screen._rest, 'Continue closes the panel')
  assert_gt(Game.run.position, position, 'and the run moves on')
  screen.free()


func test_restart_encounter_deals_the_same_cards_again() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  var offered: Array = Game.run.pending_choice().duplicate()
  var position: int = Game.run.position
  screen._choice.picked.emit(FixtureEncounters.CHOICE_REST)
  screen.restart_encounter()
  assert_eq(screen._state, RunScreen.State.CHOOSING, 'back to the choice, without the walk')
  assert_null(screen._rest, 'the rest panel is gone')
  assert_null(screen._kept_choice, 'and so is the picked card')
  assert_not_null(screen._choice, 'a new deal is up')
  assert_eq(Game.run.pending_choice(), offered, 'with the same encounters')
  assert_null(Game.run.current_encounter(), 'the picked encounter is dropped')
  assert_eq(Game.run.position, position, 'on the same beat')
  screen.free()


func test_a_shop_raises_its_panel_buys_and_leaves() -> void:
  EncounterPools._positions = [[FixtureEncounters.SHOP], [FixtureEncounters.EVENT], [FixtureEncounters.REWARD]]
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  Game.run.gold = 100
  screen._choice.picked.emit(0)
  assert_eq(screen._state, RunScreen.State.SHOPPING, 'the shop raises its panel')
  assert_eq(screen._shop.get_parent(), screen._view.corridor_area(), 'in the corridor area')
  var board: int = Game.run.player.board.size()
  screen._shop.bought.emit(0)
  assert_eq(Game.run.player.board.size(), board + 1, 'a purchase lands on the board')
  assert_lt(Game.run.gold, 100, 'and is paid for')
  screen._shop.left.emit()
  assert_null(screen._shop, 'leaving closes the panel')
  assert_false(Game.run.has_open_shop(), 'and the shop')
  assert_eq(Game.run.position, 1, 'and the run walks on to the fight')
  screen.free()


func test_a_shop_reroll_pays_and_shows_the_new_goods() -> void:
  EncounterPools._positions = [[FixtureEncounters.SHOP], [FixtureEncounters.EVENT], [FixtureEncounters.REWARD]]
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  Game.run.gold = 100
  screen._choice.picked.emit(0)
  var price: int = Game.run.reroll_price()
  screen._shop.rerolled.emit()
  assert_eq(Game.run.gold, 100 - price, 'the reroll is paid for')
  assert_eq(screen._shop.get_node('Panel/Cards').get_child_count(), Game.run.shop_goods().size(),
    'and the panel shows the new goods')
  screen.free()


# --- selling items -------------------------------------------------------------

# A left click at the centre of `item`'s board cell, as the run screen reads it.
func _click_item(screen: RunScreen, item: Item) -> void:
  _click_at(screen, screen._view.board_item_rect(item).get_center())


func _click_at(screen: RunScreen, point: Vector2) -> void:
  var click := InputEventMouseButton.new()
  click.button_index = MOUSE_BUTTON_LEFT
  click.pressed = true
  click.position = point
  screen._input(click)


func test_clicking_a_board_item_selects_it_and_sell_sells_it() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  await wait_frames(2)   # let the board lay out, so each cell is where it is drawn
  var item: Item = Game.run.player.board[0]
  _click_item(screen, item)
  assert_eq(screen._selected_item, item, 'the click selects the item')
  assert_not_null(screen._item_actions, 'and shows its Sell button')
  assert_eq(screen._item_actions.sell_button.text, 'Sell for %d gold' % RunManager.sell_price(item), 'with the price')
  var gold: int = Game.run.gold
  screen._item_actions.sell_button.pressed.emit()
  assert_false(item in Game.run.player.board, 'the item is sold')
  assert_eq(Game.run.gold, gold + RunManager.sell_price(item), 'for its price')
  assert_null(screen._selected_item, 'and the selection is cleared')
  assert_null(screen._item_actions, 'with its buttons')
  screen.free()


func test_merge_merges_the_selected_item_and_keeps_it_selected() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  await wait_frames(2)
  # The fixture character starts with two copies of the attack item and one shield item.
  var attacks: Array = Game.run.player.board.filter(func(i: Item) -> bool: return i.def.id == FixtureItems.attack().id)
  var lone: Item = Game.run.player.board.filter(func(i: Item) -> bool: return i.def.id == FixtureItems.shield().id)[0]
  _click_item(screen, lone)
  assert_false(screen._item_actions.merge_button.visible, 'Merge is hidden with no copy to merge with')
  var item: Item = attacks[0]
  var copy: Item = attacks[1]
  _click_item(screen, item)
  assert_true(screen._item_actions.merge_button.visible, 'Merge shows when a copy is on the board')
  screen._item_actions.merge_button.pressed.emit()
  assert_eq(item.level, 2, 'the item is merged')
  assert_false(copy in Game.run.player.board, 'the copy is used up')
  assert_eq(screen._selected_item, item, 'the item stays selected')
  assert_eq(screen._item_actions.sell_button.text, 'Sell for %d gold' % RunManager.sell_price(item),
    'with its new price')
  screen.free()


func test_clicking_away_or_escape_clears_the_selection() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  await wait_frames(2)
  var item: Item = Game.run.player.board[0]
  _click_item(screen, item)
  _click_at(screen, Vector2(-10, -10))
  assert_null(screen._selected_item, 'a click off the board clears it')
  _click_item(screen, item)
  var escape := InputEventAction.new()
  escape.action = 'ui_cancel'
  escape.pressed = true
  screen._unhandled_input(escape)
  assert_null(screen._selected_item, 'Escape clears it')
  assert_false(screen._paused, 'without pausing')
  screen.free()


func test_a_click_during_a_fight_selects_nothing() -> void:
  var screen := _mount_into_fight(1)
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  await wait_frames(2)
  assert_eq(screen._state, RunScreen.State.FIGHTING, 'the fight is under way')
  _click_item(screen, Game.run.player.board[0])
  assert_null(screen._selected_item, 'items cannot be sold in a fight')
  assert_null(screen._item_actions, 'so no Sell button shows')
  screen.free()


func test_walking_past_banks_gold_and_approaches_the_fight() -> void:
  var screen := _mount_into_choice()
  for _i in APPROACH_STEPS:
    screen._physics_process(1.0)
  screen._choice.skipped.emit()
  assert_eq(Game.run.gold, Balance.ENCOUNTER_SKIP_GOLD, 'walking past banks the skip gold')
  assert_eq(screen._state, RunScreen.State.APPROACHING, 'and the run walks on to the fight')
  assert_eq(Game.run.position, 1, 'the next beat')
  screen.free()


func test_event_beat_raises_the_event_overlay_and_resolves_on_pick() -> void:
  # An event beat raises the event overlay; an option pick applies its outcome (heal), dismisses
  # the overlay, then advances.
  var screen := _mount_into_event(1)
  Game.run.player.hp = 1   # so the heal outcome is observable
  assert_eq(screen._state, RunScreen.State.EVENTING, 'the event raises its overlay')
  assert_not_null(screen._event, 'the event overlay is up')
  screen._on_event_picked(FixtureEncounters.OPTION_HEAL)
  assert_null(screen._event, 'the pick dismisses the overlay')
  assert_gt(Game.run.player.hp, 1, 'the chosen outcome was applied (healed)')
  screen.free()


func test_event_panel_sits_in_the_corridor_with_the_board_shown() -> void:
  # The event panel is not a separate screen: it is placed in the combat view's corridor area, and
  # the view shows the player's board around it even though there is no fight.
  var screen := _mount_into_event(1)
  assert_not_null(screen._view, 'an event beat shows the combat view')
  assert_eq(screen._event.get_parent(), screen._view.corridor_area(), 'the event panel is in the corridor area')
  assert_eq(screen._view._player_cells.size(), Game.run.player.board.size(), 'the board is shown')
  assert_eq(screen._event.mouse_filter, Control.MOUSE_FILTER_IGNORE, 'the panel does not block the rest of the screen')
  screen.free()


func test_draft_rewards_are_inspectable_in_the_corridor() -> void:
  var screen := _mount_into_event(1)
  screen._event.queue_free()
  screen._event = null
  screen._run._set_offer([FixtureItems.attack()])
  screen._show_draft()
  await get_tree().process_frame   # let the containers place the reward icon
  assert_eq(screen._draft.get_parent(), screen._view.corridor_area(), 'the reward panel is in the corridor area')
  var option: RewardOption = screen._draft.get_node('Panel/Cards').get_child(0)
  var target: Dictionary = screen._inspection_target(option.get_global_rect().get_center())
  assert_eq(target.get('item'), option.item(), 'hovering a reward targets its item for the tooltip')
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


func _space() -> InputEventAction:
  var ev := InputEventAction.new()
  ev.action = 'toggle_pause'
  ev.pressed = true
  return ev
