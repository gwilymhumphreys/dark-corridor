class_name RunScreen
extends Control
## The run screen (docs/systems/ui_layout.md) — the real-time client of the run. It reads
## Game.run + the live CombatManager and emits intents (slow-mo); it never mutates
## game state. The logic tree stays OUT of the scene tree: each physics frame this
## screen calls `cm.tick(delta)` on the active fight — the same one tick the autotest
## runs via sim_step (combat_manager.gd).
##
## A polling state machine that drives the WHOLE descent in real time, mirroring
## AutoTestMode.run_full — enter beat → (choice: walk up to the encounter cards, pick one or walk
## past) → approach → (fight: tick to resolution | rest: resolves on begin | event: overlay) →
## fulfil reward (draft overlay, or the shop panel for a shop) → advance →
## repeat, until the run ends (Game then swaps to the win/death screen). The run
## processes each beat's outcome via its own signal chain DURING the resolving tick;
## this screen reacts by POLLING cm.is_resolved() (never from inside the signal), so
## it can safely tear the fight down and advance.

const COMBAT_VIEW: PackedScene = preload('res://src/scenes/combat/combat_view_framed.tscn')
const COMBAT_SUMMARY: PackedScene = preload('res://src/scenes/screens/combat_summary.tscn')
const DRAFT_OVERLAY: PackedScene = preload('res://src/scenes/screens/draft_overlay.tscn')
const ENCOUNTER_CHOICE: PackedScene = preload('res://src/scenes/screens/encounter_choice.tscn')
const EVENT_OVERLAY: PackedScene = preload('res://src/scenes/screens/event_overlay.tscn')
const PAUSE_MENU: PackedScene = preload('res://src/scenes/screens/pause_menu.tscn')
const SETTINGS_SCREEN: PackedScene = preload('res://src/scenes/screens/settings_screen.tscn')
const SHOP_OVERLAY: PackedScene = preload('res://src/scenes/screens/shop_overlay.tscn')
const ITEM_ACTIONS: PackedScene = preload('res://src/scenes/screens/item_actions.tscn')
const PURCHASE_SOUND: String = 'run/purchase'   # a good bought from a shop

enum State { IDLE, WALKING, CHOOSING, EVENTING, APPROACHING, FIGHTING, DRAFTING, SHOPPING }

var _run: RunManager
var _cm: CombatManager
## True while a won fight waits for its last enemies to burn away and the pause after them.
var leaving_fight: bool = false
var _view: CombatView   # the swappable surface — framed today, full-screen drops in here
var _log: CombatLog       # the live fight's observation log
var _last_log: CombatLog  # the last finished fight's log — what the Report button shows between fights
var _draft: DraftOverlay
var _choice: EncounterChoice
var _event: EventOverlay
var _shop: ShopOverlay
var _selected_item: Item          # the board item selected to sell or merge; null when none is
var _item_actions: ItemActions    # the Sell and Merge buttons below the selected item; null when none is
var _summary: CombatSummary   # the combat report panel while it is open; null while hidden
var _gold_on_screen: int = -1   # the gold the last torn-down view showed; -1 before the first view
var _state: int = State.IDLE
var _approach_elapsed: float = 0.0
var _paused: bool = false
var _paused_by_debug_panel: bool = false   # the current pause came from opening a debug panel
var _pause_menu: PauseMenu = null
@onready var _paused_panel: PanelContainer = $HUD/PausedPanel   # shown while paused with Space (no menu)
var _settings: SettingsScreen = null

@onready var _sections: ScreenSections = $HUD/Sections   # the screen's sections; the combat view places its parts in them
@onready var _map: MapStrip = $HUD/Sections/Items/MapStrip
@onready var _report_button: Button = $HUD/Sections/Info/ReportButton


func _ready() -> void:
  _run = Game.run
  if _run == null:
    return
  # The player battle-speed dial (a Game session preference): retime the live fight
  # the instant the HUD button changes it. Each new fight also picks it up on entry.
  Game.battle_speed_changed.connect(_on_battle_speed_changed)
  DebugPanels.panels_open_changed.connect(_on_debug_panels_open_changed)
  _report_button.pressed.connect(_toggle_report)
  _map.setup(_run.position)
  _enter_beat()


func _exit_tree() -> void:
  _selected_item = null
  _log = null
  _last_log = null   # CLAUDE.md runtime cleanup: the report's data goes with the screen
  if Game.battle_speed_changed.is_connected(_on_battle_speed_changed):
    Game.battle_speed_changed.disconnect(_on_battle_speed_changed)
  if DebugPanels.panels_open_changed.is_connected(_on_debug_panels_open_changed):
    DebugPanels.panels_open_changed.disconnect(_on_debug_panels_open_changed)


# --- the run cycle (a polling FSM; mirrors AutoTestMode.run_full) ------------

func _enter_beat() -> void:
  if _run.is_ended():
    return
  # A CHOICE beat has no encounter until one is picked: walk up to the encounter cards and wait.
  # A fight beat already has a live encounter.
  if _run.has_pending_choice():
    _show_choice()
    return
  _begin_beat()


# The choice of encounters before a fight (docs/plans/encounter_choice.md): the corridor with no
# enemy and a walk up it like a fight approach. The encounter cards are dealt over the corridor at the
# end of the walk (docs/plans/encounter_cards.md); the loop is parked in CHOOSING until a card is
# picked (pick_path creates the beat) or the player walks past.
func _show_choice() -> void:
  _ensure_view()
  _view.clear_enemies()
  _choice = ENCOUNTER_CHOICE.instantiate()
  _view.corridor_area().add_child(_choice)
  _choice.picked.connect(_on_choice_picked)
  _choice.skipped.connect(_on_choice_skipped)
  _choice.setup(_run.pending_choice())
  _begin_approach(State.WALKING)


func _arrive_at_choice() -> void:
  _walk(Balance.APPROACH_DEPTH_START)
  _choice.reveal()   # a backstop: normally the deal already started during the walk
  _state = State.CHOOSING


func _on_choice_picked(index: int) -> void:
  if _state != State.CHOOSING and _state != State.WALKING:
    return
  _choice.queue_free()
  _choice = null
  _run.pick_path(index)
  _begin_beat()


# Walk past the encounters: bank the skip gold and go straight on to the fight.
func _on_choice_skipped() -> void:
  if _state != State.CHOOSING and _state != State.WALKING:
    return
  _choice.queue_free()
  _choice = null
  _run.skip_choice()
  _refresh_gold()
  _advance()


# Begin resolving the (now-chosen or fixed) beat: a fight readies its CombatManager + the
# approach; an event raises its prose + choice; a rest resolved synchronously on begin().
func _begin_beat() -> void:
  _run.begin_current()
  var enc: Encounter = _run.current_encounter()
  if enc != null and enc.is_event():
    _show_event(enc)
    return
  _cm = _run.combat_manager()
  if _cm != null and not _cm.is_resolved():
    _apply_battle_speed()   # this fight inherits the current dial setting
    _build_combat_view()
    _begin_approach()
  else:
    _cm = null
    _after_beat()


# An EVENT beat: raise the prose + the available options and wait. The pick
# applies the chosen outcome to run-state and resolves the beat; then advance as usual.
func _show_event(enc: Encounter) -> void:
  _state = State.EVENTING
  _ensure_view()
  _event = EVENT_OVERLAY.instantiate()
  _view.corridor_area().add_child(_event)   # in the corridor; the board, potions and HUD stay live
  _event.option_picked.connect(_on_event_picked)
  _event.setup(enc, _run.available_event_options())


func _on_event_picked(index: int) -> void:
  _event.queue_free()
  _event = null
  _run.pick_event_option(index)   # the RunManager applies the option's effects, then resolves the event
  _after_beat()


# The corridor approach (docs/history/phase4_plan.md Step 7): the enemy stands still at
# APPROACH_DEPTH_START and the player walks up to it, so the corridor moves past while the enemy
# grows to full size and brightens as it comes into the corridor light. The fight clock is NOT
# ticked yet, so combat is frozen until arrival. Driven off _physics_process (not a Tween) so the headless run-screen test advances it
# with the same manual ticks that drive the fights.
func _begin_approach(state: State = State.APPROACHING) -> void:
  _state = state
  _approach_elapsed = 0.0
  _walk(0.0)


# Put the player `travelled` sections along the approach: the corridor moves that far forward and
# the enemy, standing still, is that much less deep. At APPROACH_DEPTH_START the player has arrived.
func _walk(travelled: float) -> void:
  _view.set_walk_distance(travelled)
  _view.set_enemy_depth(Balance.APPROACH_DEPTH_START - travelled)


func _arrive() -> void:
  _walk(Balance.APPROACH_DEPTH_START)
  _view.show_enemies()       # a backstop: normally the fade already started during the walk
  _view.begin_fight()        # the clock starts, so the boards' cooldown fills come on
  _state = State.FIGHTING   # boards activate — the clock starts ticking next frame


# The one real-time tick: walk the approach in, then advance the active fight off
# real delta (steps_due × sim_step) and react to resolution OUTSIDE the resolving
# signal. Nothing in the logic tree is mounted — this is the same tick the headless
# autotest runs directly.
func _physics_process(delta: float) -> void:
  if _paused:
    return   # pause freezes BOTH the approach walk and the fight clock
  if _view == null:
    return   # the view was torn down under us (quit to menu, run end) — nothing to drive
  match _state:
    State.APPROACHING, State.WALKING:
      _approach_elapsed += delta
      var t: float = clampf(_approach_elapsed / Balance.APPROACH_DURATION, 0.0, 1.0)
      # Eased so the walk starts and ends softly rather than snapping into motion.
      var eased: float = lerpf(t, smoothstep(0.0, 1.0, t), Balance.APPROACH_EASE)
      _walk(Balance.APPROACH_DEPTH_START * eased)
      # The enemy's readouts start fading up (or the encounter cards start being dealt) before arrival, so they are
      # there when the walk ends. Both only act the first time, so calling them every frame is harmless.
      if Balance.APPROACH_DURATION - _approach_elapsed <= Balance.ENEMY_REVEAL_DURATION:
        if _state == State.WALKING:
          _choice.reveal()
        else:
          _view.show_enemies(Balance.ENEMY_REVEAL_DURATION)
      if t >= 1.0:
        if _state == State.WALKING:
          _arrive_at_choice()
        else:
          _arrive()
    State.FIGHTING:
      if _cm == null:
        return
      if _cm.is_resolved():
        _cm.request_slowmo(false)   # drop any hover slow-mo left set when the fight resolved
        # The clock stops at resolution, so the last hits' numbers and rings would stay frozen in
        # the corridor under the reward panel. Stop drawing them now.
        _view.release()
        _state = State.IDLE
        # The fight's log stays the one the Report button shows until the next fight starts.
        # Nothing parks here: the run goes straight on to the reward draft, and the player
        # reads the report when they want to (docs/systems/combat_log.md).
        _last_log = _log
        if not _run.is_ended():
          _map.burn_current_square()   # the fight was won: its square's token burns away
        _leave_won_fight()
      else:
        _cm.tick(delta)


# Battle-speed (a Game session preference) sets the fight clock's BASE scale; the
# hover slow-mo override still replaces it absolutely while inspecting, returning to
# this base on release (resolved: absolute slow-mo — timekeeper.gd). Applied on fight
# entry and live on the dial signal.
func _apply_battle_speed() -> void:
  _on_battle_speed_changed(Game.battle_speed)


func _on_battle_speed_changed(speed: float) -> void:
  if _cm != null and _cm.timekeeper != null:
    _cm.timekeeper.set_base_scale(speed)


# Item tooltips are shown whenever a combat view is up: during the approach, the fight, the combat
# report, the reward draft and events (docs/systems/tooltips.md). They are hidden only while the pause menu is open.
# Slow-mo-on-hover intent (docs/systems/ui_layout.md "one verb"): while fighting, hovering any
# inspectable — a board item (either side) or a potion — asks the Combat manager to slow the clock
# (both sides) to read it.
func _process(_delta: float) -> void:
  _update_selection()
  if _view == null:
    return
  if _pause_menu != null:
    _view.stop_inspection()   # the pause menu's layer-100 Catcher covers the screen
    return
  var mouse: Vector2 = get_global_mouse_position()
  _view.update_inspection(_inspection_target(mouse))
  if not _paused and _state == State.FIGHTING and _cm != null and not _cm.is_resolved():
    _cm.request_slowmo(_view.mouse_over_inspectable(mouse))


# The item the tooltip should describe: a reward icon on the draft or shop panel first, otherwise a
# board item — but not one hidden behind either panel (in the corridor area) or the combat report.
func _inspection_target(mouse: Vector2) -> Dictionary:
  if _draft != null:
    var reward: Dictionary = _draft.inspectable_at(mouse)
    if not reward.is_empty() or _draft.covers(mouse):
      return reward
  if _shop != null:
    var good: Dictionary = _shop.inspectable_at(mouse)
    if not good.is_empty() or _shop.covers(mouse):
      return good
  if _summary != null and (_summary.get_node('Panel') as Control).get_global_rect().has_point(mouse):
    return {}
  return _view.inspectable_at(mouse)


# Pause is a run-screen presentation gate (NOT a Game phase): Escape (ui_cancel) toggles
# it during a beat, freezing the screen's tick and raising the pause menu. Space (toggle_pause)
# pauses and resumes without the menu, showing the small Paused panel; Escape during that raises
# the menu, and Space does nothing while the menu is up. The autotest never mounts this screen, so
# pause is invisible to the headless path. The battle speed keys step the dial while the run is not
# paused, stopping at either end; between fights that only changes what the next fight starts at.
func _unhandled_input(event: InputEvent) -> void:
  if _selected_item != null and event.is_action_pressed('ui_cancel'):
    _clear_selection()   # Escape drops the selection before it pauses
    get_viewport().set_input_as_handled()
    return
  if not _can_pause():
    return
  if event.is_action_pressed('ui_cancel'):
    if _paused and _pause_menu == null:
      _show_pause_menu()
    else:
      _toggle_pause()
    get_viewport().set_input_as_handled()
  elif event.is_action_pressed('toggle_pause') and _pause_menu == null:
    if _paused:
      _resume()
    else:
      _pause(false)
    get_viewport().set_input_as_handled()
  elif not _paused and event.is_action_pressed('battle_speed_down'):
    Game.step_battle_speed(-1, false)
    get_viewport().set_input_as_handled()
  elif not _paused and event.is_action_pressed('battle_speed_up'):
    Game.step_battle_speed(1, false)
    get_viewport().set_input_as_handled()


func _can_pause() -> bool:
  # Pause is available at ANY point in a live run — including while a choice / event / draft
  # overlay is up. The pause menu's full-rect Catcher (layer 100) blocks input to whatever is
  # underneath, and quit-to-menu resumes from the beat's entry save (a clean re-do).
  return _run != null


# Opening a debug panel pauses like Space. Closing the last one resumes only if a panel caused the
# pause and the pause menu is not up, so a pause the player chose stays.
func _on_debug_panels_open_changed(open: bool) -> void:
  if not _can_pause():
    return
  if open and not _paused:
    _pause(false)
    _paused_by_debug_panel = true
  elif not open and _paused_by_debug_panel and _pause_menu == null:
    _resume()


func _toggle_pause() -> void:
  if _paused:
    _resume()
  else:
    _pause()


## Pause the run, raising the pause menu, or with `show_menu` false only the small Paused panel.
func _pause(show_menu: bool = true) -> void:
  _paused = true
  if show_menu:
    _show_pause_menu()
  else:
    _paused_panel.show()


func _show_pause_menu() -> void:
  _paused_panel.hide()
  _pause_menu = PAUSE_MENU.instantiate()
  add_child(_pause_menu)
  _pause_menu.resume_pressed.connect(_resume)
  _pause_menu.settings_pressed.connect(_open_settings)
  _pause_menu.quit_pressed.connect(_quit_to_menu)
  _pause_menu.exit_pressed.connect(_exit_game)


func _resume() -> void:
  _paused = false
  _paused_by_debug_panel = false
  _paused_panel.hide()
  _close_settings()
  if _pause_menu != null:
    _pause_menu.queue_free()
    _pause_menu = null


# Settings, raised from the pause menu — added INSIDE the pause menu's CanvasLayer (layer 100)
# so its opaque screen covers the pause panel; Close frees it back to the pause menu. Volume
# changes apply + persist live via Prefs (the run stays paused throughout).
func _open_settings() -> void:
  if _settings != null or _pause_menu == null:
    return
  _settings = SETTINGS_SCREEN.instantiate()
  _pause_menu.add_child(_settings)
  _settings.closed.connect(_close_settings)


func _close_settings() -> void:
  if _settings != null:
    _settings.queue_free()
    _settings = null


# Quit-to-menu: release the combat view BEFORE the run (and its CombatManager) is freed,
# then return to Title. The save persists (Game.return_to_title does NOT clear it), so the
# Title's Resume re-enters this beat. Game swaps the screen; our _exit_tree disconnects.
func _quit_to_menu() -> void:
  # The page turn back to the title screen shows this screen on its front, so it is captured while
  # the combat view is still here and the pause menu is hidden.
  if PageTurn.can_turn():
    if _pause_menu != null:
      _pause_menu.hide()
    await PageTurn.capture()
  _leave_run()


func _leave_run() -> void:
  _resume()
  _teardown_combat_view()
  Game.return_to_title()


# Exit Game: close the application. The save from this beat's entry is kept, so the next
# launch's Title Resume re-enters this beat, the same as quit-to-menu.
func _exit_game() -> void:
  _leave_run()
  get_tree().quit()


# The last enemies burn away, then a short pause, before the run moves on, because moving on to
# the next beat frees the combat view and everything burning in it (docs/systems/paper_burn.md).
# The state is IDLE while it waits, so nothing else starts.
func _leave_won_fight() -> void:
  var view: CombatView = _view
  if not _run.is_ended() and view.start_burns():
    leaving_fight = true
    await view.burns_finished
    if view == _view and is_inside_tree():
      await get_tree().create_timer(Balance.FIGHT_END_PAUSE).timeout
    leaving_fight = false
    if view != _view or not is_inside_tree():
      return
  _after_beat()


# Post-beat: the run already fulfilled the outcome (reward / run-end) via its signal
# chain during the resolving tick. Here we react from OUTSIDE that emission — a pending
# draft raises the overlay (the player picks; the loop pauses), otherwise we advance.
# Win/death route through run_ended → Game → screen swap.
func _after_beat() -> void:
  if _run.is_ended():
    return
  _refresh_gold()   # a relic's fight-won trigger may have added gold
  if _run.has_open_shop():
    _show_shop()
  elif _run.has_pending_draft():
    _show_draft()
  else:
    _advance()


# The combat report (docs/systems/combat_log.md): the damage report + event log of the current
# fight, or of the last finished fight between fights, raised and dismissed by the Report button
# in the information section. It parks nothing — the run carries on behind it. The finished
# fight's log is held in _last_log, so the report still reads after the CombatManager has been
# torn down. Before the first fight there is no log and the report opens empty.
func _toggle_report() -> void:
  if _summary != null:
    _hide_report()
  else:
    _show_report()


func _show_report() -> void:
  _summary = COMBAT_SUMMARY.instantiate()
  add_child(_summary)   # on top of the combat view; the HUD CanvasLayer stays above it
  _summary.close_pressed.connect(_hide_report)
  _summary.setup(_log if _log != null else _last_log)


func _hide_report() -> void:
  if _summary == null:
    return
  _summary.queue_free()
  _summary = null


# The draft is a player choice (a draft-pick intent): raise the overlay with a reward encounter's
# goods and wait. The loop is paused in DRAFTING until a card is picked.
func _show_draft() -> void:
  _state = State.DRAFTING
  _ensure_view()
  _draft = DRAFT_OVERLAY.instantiate()
  _view.corridor_area().add_child(_draft)   # in the corridor; the board, potions and HUD stay live
  _draft.picked.connect(_on_draft_picked)
  _draft.skipped.connect(_on_draft_skipped)
  _draft.setup(_run.pending_draft(), _run.pending_draft_levels())


func _on_draft_picked(index: int) -> void:
  _draft.queue_free()
  _draft = null
  _run.apply_draft_pick(index)
  _advance()


# Skip the draft (a draft-skip intent, docs decision #33): bank gold instead of an item, refresh
# the HUD, then advance — the sibling of _on_draft_picked.
func _on_draft_skipped() -> void:
  _draft.queue_free()
  _draft = null
  _run.apply_draft_skip()
  _refresh_gold()
  _advance()


# A shop: raise its panel and wait while the player buys. The loop is paused in SHOPPING until Leave.
func _show_shop() -> void:
  _state = State.SHOPPING
  _ensure_view()
  _shop = SHOP_OVERLAY.instantiate()
  _view.corridor_area().add_child(_shop)   # in the corridor; the board, potions and HUD stay live
  _shop.bought.connect(_on_shop_bought)
  _shop.rerolled.connect(_on_shop_rerolled)
  _shop.left.connect(_on_shop_left)
  _shop.setup(tr(_run.current_encounter().def.name_key), _run)


# A purchase: the RunManager takes the gold and gives the good; the panel, the gold box, the potions
# and the relics show it at once (the board follows the player's items on its own).
func _on_shop_bought(index: int) -> void:
  if not _run.buy(index):
    return
  SfxManager.play_sound(PURCHASE_SOUND)
  _shop.refresh(_run)
  _refresh_gold()
  _view.refresh_potions(_run.potions)
  _view.show_relics(_run.relics)


func _on_shop_rerolled() -> void:
  if not _run.reroll_shop():
    return
  _shop.show_goods(_run)
  _refresh_gold()


func _on_shop_left() -> void:
  _shop.queue_free()
  _shop = null
  _run.leave_shop()
  _advance()


# The banked gold in the combat view's gold box (docs decision #33): written when the view is built
# (covers a resumed run's gold and a relic picked from an offer), after each beat and after each skip.
func _refresh_gold() -> void:
  if _view != null:
    _view.show_gold(_run.gold)


func _advance() -> void:
  _hide_report()   # the next beat is starting; the report is back behind its button
  _teardown_combat_view()
  _run.advance()
  _map.mark_position(_run.position)
  _enter_beat()


# --- combat view lifetime ----------------------------------------------------

func _build_combat_view() -> void:
  # Attach a fresh observation log to the fight (docs/systems/combat_log.md). We hold our own
  # ref so the combat report can read it after the CombatManager teardown nulls its side.
  _log = CombatLog.new()
  _cm.combat_log = _log
  _mount_view(_cm)


# A beat with no fight (an event, or a draft after one) still shows the combat view — the corridor
# with the player's board, potions and portrait — so its panel can sit in the corridor area.
func _ensure_view() -> void:
  if _view == null:
    _mount_view(null)


func _mount_view(cm: CombatManager) -> void:
  _view = COMBAT_VIEW.instantiate()
  _view.sections = _sections
  _view.map = _map
  add_child(_view)
  move_child(_view, 1)   # above the Background, below the HUD CanvasLayer
  _view.bind(cm, _run.player, _run.potions, _run.allies)   # the rosters come off the CM; with no fight, the run's allies
  var character: CharacterDef = _run.character
  _view.show_character(tr(character.name_key), tr(character.class_key) if character.class_key != '' else '')
  # The view is rebuilt every beat, so it starts from the gold the last one showed and counts any
  # change from there (gold won by a fight is banked just before its view is torn down).
  _view.snap_gold(_gold_on_screen if _gold_on_screen >= 0 else _run.gold)
  _refresh_gold()
  _view.show_relics(_run.relics)
  _view.potion_thrown.connect(_on_potion_thrown)


# Throw-potion intent: only valid in a live fight (the consumable resolves through the
# Combat manager). On success the reserve shrank, so refresh the slots.
func _on_potion_thrown(index: int) -> void:
  if _state != State.FIGHTING:
    return
  if _run.throw_potion(index):
    _view.refresh_potions(_run.potions)


func _teardown_combat_view() -> void:
  _clear_selection()
  _choice = null   # the cards live in the view's corridor area and go with it
  _log = null   # drop the live ref; _last_log keeps the finished fight's numbers for the report
  if _view != null:
    _gold_on_screen = _view.gold_on_screen()
    _view.release()      # stop the VFX wall reading the CombatManager we're about to free
    _view.queue_free()   # deferred — the view holds render resources (CLAUDE.md)
    _view = null


# --- selling and merging items (docs/systems/run_screen.md → Selling and merging items) --

# A left click on a board item the player can sell selects it; any other click drops the selection.
# Read in _input, before the GUI, because a board item's cell stops the mouse itself, so the click
# would never reach this screen's _gui_input. Clicks on the Sell and Merge buttons are left to them.
func _input(event: InputEvent) -> void:
  var click := event as InputEventMouseButton
  if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
    return
  if _item_actions != null and _item_actions.get_global_rect().has_point(click.position):
    return
  var item: Item = _sellable_item_at(click.position)
  if item == null:
    _clear_selection()
    return
  _select(item)
  get_viewport().set_input_as_handled()


# The board item under `point` that can be sold now, or null: none while paused or in the settings,
# or where the draft, shop or combat report panel covers the point.
func _sellable_item_at(point: Vector2) -> Item:
  if _view == null or _paused or _pause_menu != null or _settings != null:
    return null
  if (_draft != null and _draft.covers(point)) or (_shop != null and _shop.covers(point)):
    return null
  if _summary != null and (_summary.get_node('Panel') as Control).get_global_rect().has_point(point):
    return null
  var item: Item = _view.board_item_at(point)
  return item if item != null and _run.can_sell(item) else null


func _select(item: Item) -> void:
  if item == _selected_item:
    return
  _clear_selection()
  _selected_item = item
  _view.mark_board_item(item, true)
  _item_actions = ITEM_ACTIONS.instantiate()
  $HUD.add_child(_item_actions)
  _item_actions.setup(item, RunManager.sell_price(item), _run.can_merge(item), _run.will_lose_enchantment(item))
  _item_actions.sell_requested.connect(_on_sell_requested)
  _item_actions.merge_requested.connect(_on_merge_requested)
  _place_item_actions()


func _clear_selection() -> void:
  if _selected_item != null and _view != null:
    _view.mark_board_item(_selected_item, false)
  _selected_item = null
  if _item_actions != null:
    _item_actions.queue_free()
    _item_actions = null


# Each frame: drop the selection once the item cannot be sold (it left the board, or a fight's
# approach began), otherwise keep the buttons under the item's cell as the board reflows.
func _update_selection() -> void:
  if _selected_item == null:
    return
  if _view == null or not _run.can_sell(_selected_item):
    _clear_selection()
    return
  _place_item_actions()


func _place_item_actions() -> void:
  _item_actions.place_below(_view.board_item_rect(_selected_item), get_viewport_rect())


func _on_sell_requested(item: Item) -> void:
  _clear_selection()
  if not _run.sell_item(item):
    return
  _refresh_gold()
  if _shop != null:
    _shop.refresh(_run)   # the gold changed what the player can afford


# Merge the item and keep it selected, so its buttons show the new sell price and whether it can
# merge again.
func _on_merge_requested(item: Item) -> void:
  _clear_selection()
  if _run.merge_item(item):
    _select(item)
