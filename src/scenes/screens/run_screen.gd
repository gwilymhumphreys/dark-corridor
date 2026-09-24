class_name RunScreen
extends Control
## The run screen (docs/systems/ui_layout.md) — the real-time client of the run. It reads
## Game.run + the live CombatManager and emits intents (slow-mo); it never mutates
## game state. The logic tree stays OUT of the scene tree: each physics frame this
## screen calls `cm.tick(delta)` on the active fight — the same one tick the autotest
## runs via sim_step (combat_manager.gd).
##
## A polling state machine that drives the WHOLE descent in real time, mirroring
## AutoTestMode.run_full — enter beat → approach → (fight: tick to resolution | rest:
## resolves on begin | event: overlay) → fulfil reward (draft overlay) → advance →
## repeat, until the run ends (Game then swaps to the win/death screen). The run
## processes each beat's outcome via its own signal chain DURING the resolving tick;
## this screen reacts by POLLING cm.is_resolved() (never from inside the signal), so
## it can safely tear the fight down and advance.

const COMBAT_VIEW: PackedScene = preload('res://src/scenes/combat/combat_view_framed.tscn')
const COMBAT_SUMMARY: PackedScene = preload('res://src/scenes/screens/combat_summary.tscn')
const DRAFT_OVERLAY: PackedScene = preload('res://src/scenes/screens/draft_overlay.tscn')
const CHOICE_OVERLAY: PackedScene = preload('res://src/scenes/screens/choice_overlay.tscn')
const EVENT_OVERLAY: PackedScene = preload('res://src/scenes/screens/event_overlay.tscn')
const PAUSE_MENU: PackedScene = preload('res://src/scenes/screens/pause_menu.tscn')
const SETTINGS_SCREEN: PackedScene = preload('res://src/scenes/screens/settings_screen.tscn')

enum State { IDLE, CHOOSING, EVENTING, APPROACHING, FIGHTING, DRAFTING }

var _run: RunManager
var _cm: CombatManager
var _view: CombatView   # the swappable surface — framed today, full-screen drops in here
var _log: CombatLog       # the live fight's observation log
var _last_log: CombatLog  # the last finished fight's log — what the Report button shows
var _draft: DraftOverlay
var _choice: ChoiceOverlay
var _event: EventOverlay
var _summary: CombatSummary   # the combat report panel while it is open; null while hidden
var _state: int = State.IDLE
var _approach_elapsed: float = 0.0
var _paused: bool = false
var _paused_by_debug_panel: bool = false   # the current pause came from opening a debug panel
var _pause_menu: PauseMenu = null
@onready var _paused_panel: PanelContainer = $HUD/PausedPanel   # shown while paused with Space (no menu)
var _settings: SettingsScreen = null

@onready var _sections: ScreenSections = $HUD/Sections   # the screen's four sections; the combat view places its parts in them
@onready var _map: MapStrip = $HUD/Sections/Info/MapStrip
@onready var _stats: CombatStatsReadout = $HUD/StatsReadout
@onready var _gold: Label = $HUD/Sections/Info/GoldReadout
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
  _map.setup(RunMap.TOTAL_BEATS, _run.position)
  _refresh_gold()       # seed the HUD from run-state (covers a resumed run's banked gold)
  _enter_beat()


func _exit_tree() -> void:
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
  # A CHOICE beat has no encounter until a path is picked: raise the choice overlay and
  # wait. A FIXED beat (boss / midpoint relic / rest) already has a live encounter.
  if _run.has_pending_choice():
    _show_choice()
    return
  _begin_beat()


# The two-tier choice (a choice-point intent): raise the telegraphed 2-3 candidates and
# wait. The loop is parked in CHOOSING until a card is picked (pick_path creates the beat).
func _show_choice() -> void:
  _state = State.CHOOSING
  _choice = CHOICE_OVERLAY.instantiate()
  add_child(_choice)
  _choice.picked.connect(_on_choice_picked)
  _choice.setup(_run.pending_choice())


func _on_choice_picked(index: int) -> void:
  _choice.queue_free()
  _choice = null
  _run.pick_path(index)
  _begin_beat()


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


# An EVENT beat (the tier-2 binary choice): raise the prose + options and wait. The pick
# applies the chosen outcome to run-state and resolves the beat; then advance as usual.
func _show_event(enc: Encounter) -> void:
  _state = State.EVENTING
  _ensure_view()
  _event = EVENT_OVERLAY.instantiate()
  _view.corridor_area().add_child(_event)   # in the corridor; the board, potions and HUD stay live
  _event.option_picked.connect(_on_event_picked)
  _event.setup(enc)


func _on_event_picked(index: int) -> void:
  _event.queue_free()
  _event = null
  _run.pick_event_option(index)   # via the RunManager so an ADD_ALLY option recruits a run-scoped ally
  _after_beat()


# The corridor approach (docs/history/phase4_plan.md Step 7): the enemy stands still at
# APPROACH_DEPTH_START and the player walks up to it, so the corridor moves past while the enemy
# grows to full size and brightens as it comes into the corridor light. The fight clock is NOT
# ticked yet, so combat is frozen until arrival. Driven off _physics_process (not a Tween) so the headless run-screen test advances it
# with the same manual ticks that drive the fights.
func _begin_approach() -> void:
  _state = State.APPROACHING
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
  _stats.update_from(_log)   # seed at 0 before the first tick
  _stats.show()              # the live Dealt / Taken readout is up only during the fight
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
    State.APPROACHING:
      _approach_elapsed += delta
      var t: float = clampf(_approach_elapsed / Balance.APPROACH_DURATION, 0.0, 1.0)
      # Eased so the walk starts and ends softly rather than snapping into motion.
      var eased: float = lerpf(t, smoothstep(0.0, 1.0, t), Balance.APPROACH_EASE)
      _walk(Balance.APPROACH_DEPTH_START * eased)
      # The enemy's readouts start fading up before arrival, so they are there by the first tick.
      # show_enemies only acts the first time, so calling it every frame from here is harmless.
      if Balance.APPROACH_DURATION - _approach_elapsed <= Balance.ENEMY_REVEAL_DURATION:
        _view.show_enemies(Balance.ENEMY_REVEAL_DURATION)
      if t >= 1.0:
        _arrive()
    State.FIGHTING:
      if _cm == null:
        return
      if _cm.is_resolved():
        _cm.request_slowmo(false)   # drop any hover slow-mo left set when the fight resolved
        # The clock stops at resolution, so the last hits' numbers and rings would stay frozen in
        # the corridor under the reward panel. Stop drawing them now.
        _view.release()
        _stats.hide()
        _state = State.IDLE
        # The fight's log becomes the one the Report button shows. Nothing parks here: the
        # run goes straight on to the reward draft, and the player reads the report when
        # they want to (docs/systems/combat_log.md).
        _last_log = _log
        _report_button.show()
        _after_beat()
      else:
        _cm.tick(delta)
        _stats.update_from(_log)


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
  if _view == null:
    return
  if _pause_menu != null:
    _view.stop_inspection()   # the pause menu's layer-100 Catcher covers the screen
    return
  var mouse: Vector2 = get_global_mouse_position()
  _view.update_inspection(_inspection_target(mouse))
  if not _paused and _state == State.FIGHTING and _cm != null and not _cm.is_resolved():
    _cm.request_slowmo(_view.mouse_over_inspectable(mouse))


# The item the tooltip should describe: a reward icon on the draft panel first, otherwise a board
# item — but not one hidden behind the draft panel (in the corridor area) or the combat report.
func _inspection_target(mouse: Vector2) -> Dictionary:
  if _draft != null:
    var reward: Dictionary = _draft.inspectable_at(mouse)
    if not reward.is_empty() or _draft.covers(mouse):
      return reward
  if _summary != null and (_summary.get_node('Panel') as Control).get_global_rect().has_point(mouse):
    return {}
  return _view.inspectable_at(mouse)


# Pause is a run-screen presentation gate (NOT a Game phase): Escape (ui_cancel) toggles
# it during a beat, freezing the screen's tick and raising the pause menu. Space (toggle_pause)
# pauses and resumes without the menu, showing the small Paused panel; Escape during that raises
# the menu, and Space does nothing while the menu is up. The autotest never mounts this screen, so
# pause is invisible to the headless path.
func _unhandled_input(event: InputEvent) -> void:
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
  _resume()
  _teardown_combat_view()
  Game.return_to_title()


# Exit Game: close the application. The save from this beat's entry is kept, so the next
# launch's Title Resume re-enters this beat, the same as quit-to-menu.
func _exit_game() -> void:
  _quit_to_menu()
  get_tree().quit()


# Post-beat: the run already fulfilled the outcome (reward / run-end) via its signal
# chain during the resolving tick. Here we react from OUTSIDE that emission — a pending
# draft raises the overlay (the player picks; the loop pauses), otherwise we advance.
# Win/death route through run_ended → Game → screen swap.
func _after_beat() -> void:
  if _run.is_ended():
    return
  if _run.has_pending_draft():
    _show_draft()
  else:
    _advance()


# The combat report (docs/systems/combat_log.md): the damage report + event log of the last
# finished fight, raised and dismissed by the Report button in the information section. It
# parks nothing — the run carries on behind it. The log is held in _last_log, so the report
# still reads after the CombatManager has been torn down.
func _toggle_report() -> void:
  if _summary != null:
    _hide_report()
  else:
    _show_report()


func _show_report() -> void:
  if _last_log == null:
    return
  _summary = COMBAT_SUMMARY.instantiate()
  add_child(_summary)   # on top of the combat view; the HUD CanvasLayer stays above it
  _summary.close_pressed.connect(_hide_report)
  _summary.setup(_last_log)


func _hide_report() -> void:
  if _summary == null:
    return
  _summary.queue_free()
  _summary = null


# The draft is a player choice (a draft-pick intent): raise the 1-of-3 overlay and
# wait. The loop is paused in DRAFTING until a card is picked.
func _show_draft() -> void:
  _state = State.DRAFTING
  _ensure_view()
  _draft = DRAFT_OVERLAY.instantiate()
  _view.corridor_area().add_child(_draft)   # in the corridor; the board, potions and HUD stay live
  _draft.picked.connect(_on_draft_picked)
  _draft.skipped.connect(_on_draft_skipped)
  _draft.setup(_run.pending_draft())


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


# The banked-gold HUD readout (docs decision #33). Localizable, updated from run-state on entry
# (covers resume) and after each skip. Placeholder placement — the owner can relocate / juice it.
func _refresh_gold() -> void:
  _gold.text = tr('Gold: {0}').format([_run.gold])


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
  add_child(_view)
  move_child(_view, 1)   # above the Background, below the HUD CanvasLayer
  _view.bind(cm, _run.player, _run.potions, _run.allies)   # the rosters come off the CM; with no fight, the run's allies
  _view.potion_thrown.connect(_on_potion_thrown)


# Throw-potion intent: only valid in a live fight (the consumable resolves through the
# Combat manager). On success the reserve shrank, so refresh the slots.
func _on_potion_thrown(index: int) -> void:
  if _state != State.FIGHTING:
    return
  if _run.throw_potion(index):
    _view.refresh_potions(_run.potions)


func _teardown_combat_view() -> void:
  _stats.hide()
  _log = null   # drop the live ref; _last_log keeps the finished fight's numbers for the report
  if _view != null:
    _view.release()      # stop the VFX wall reading the CombatManager we're about to free
    _view.queue_free()   # deferred — the view holds render resources (CLAUDE.md)
    _view = null
