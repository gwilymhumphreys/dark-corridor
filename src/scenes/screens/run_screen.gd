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

enum State { IDLE, CHOOSING, EVENTING, APPROACHING, FIGHTING, SUMMARY, DRAFTING }

var _run: RunManager
var _cm: CombatManager
var _view: CombatView   # the swappable surface — framed today, full-screen drops in here
var _log: CombatLog     # the live fight's observation log; retained past teardown for the summary
var _draft: DraftOverlay
var _choice: ChoiceOverlay
var _event: EventOverlay
var _summary: CombatSummary
var _state: int = State.IDLE
var _approach_elapsed: float = 0.0
var _paused: bool = false
var _pause_menu: PauseMenu = null
var _settings: SettingsScreen = null

@onready var _map: MapStrip = $HUD/MapStrip
@onready var _stats: CombatStatsReadout = $HUD/StatsReadout


func _ready() -> void:
  _run = Game.run
  if _run == null:
    return
  # The player battle-speed dial (a Game session preference): retime the live fight
  # the instant the HUD button changes it. Each new fight also picks it up on entry.
  Game.battle_speed_changed.connect(_on_battle_speed_changed)
  _seed_demo_allies()   # dev hook (`--allies N`): populate the ally slots for inspection
  _map.setup(RunMap.TOTAL_BEATS, _run.position)
  _enter_beat()


# Dev hook (`--allies N`, pairs with `--autofight --shot`): recruit N placeholder allies so the
# flanking ally slots can be inspected. Inert without the flag. Presentation/screenshot only.
func _seed_demo_allies() -> void:
  var args: Array = []
  args.append_array(OS.get_cmdline_args())
  args.append_array(OS.get_cmdline_user_args())
  var i: int = args.find('--allies')
  if i < 0 or i + 1 >= args.size():
    return
  for _n in int(args[i + 1]):
    _run.add_ally(EnemyCatalog.SPORE_THRALL)


func _exit_tree() -> void:
  if Game.battle_speed_changed.is_connected(_on_battle_speed_changed):
    Game.battle_speed_changed.disconnect(_on_battle_speed_changed)


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
  # Dev hook (`--autofight`, pairs with `--shot`): auto-pick the first fight so a live combat
  # view can be captured — the choice layer otherwise parks here. Presentation-only.
  if '--autofight' in OS.get_cmdline_args() or '--autofight' in OS.get_cmdline_user_args():
    _on_choice_picked.call_deferred(_first_fight_candidate())


func _first_fight_candidate() -> int:
  var candidates: Array = _run.pending_choice()
  for i in candidates.size():
    if EncounterCatalog.get_def(candidates[i]).type == EncounterDef.Type.FIGHT:
      return i
  return 0


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
  _event = EVENT_OVERLAY.instantiate()
  add_child(_event)
  _event.option_picked.connect(_on_event_picked)
  _event.setup(enc)


func _on_event_picked(index: int) -> void:
  _event.queue_free()
  _event = null
  _run.pick_event_option(index)   # via the RunManager so an ADD_ALLY option recruits a run-scoped ally
  _after_beat()


# The corridor approach (docs/history/phase4_plan.md Step 7): the enemy walks from depth into full
# view while the corridor glides; the fight clock is NOT ticked yet, so combat is
# frozen until arrival. Driven off _physics_process (not a Tween) so the headless
# run-screen test advances it with the same manual ticks that drive the fights.
func _begin_approach() -> void:
  _state = State.APPROACHING
  _approach_elapsed = 0.0
  _view.set_enemy_depth(Balance.APPROACH_DEPTH_START)
  _view.set_gliding(true)


func _arrive() -> void:
  _view.set_enemy_depth(0.0)
  _view.set_gliding(false)
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
  match _state:
    State.APPROACHING:
      _approach_elapsed += delta
      var t: float = clampf(_approach_elapsed / Balance.APPROACH_DURATION, 0.0, 1.0)
      _view.set_enemy_depth(lerpf(Balance.APPROACH_DEPTH_START, 0.0, t))
      if t >= 1.0:
        _arrive()
    State.FIGHTING:
      if _cm == null:
        return
      if _cm.is_resolved():
        _cm.request_slowmo(false)   # drop any hover slow-mo left set when the fight resolved
        _stats.hide()
        var won: bool = _cm.player_won()
        _state = State.IDLE
        # On a WON fight that isn't the run's last beat, show the post-fight summary before the
        # draft (it parks the FSM, like the draft/event overlays). On a loss — or the final
        # win — the run has ended; skip straight on (Game swaps to the death/win screen).
        if won and not _run.is_ended():
          _show_summary()
        else:
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


# Slow-mo-on-hover intent (docs/systems/ui_layout.md "one verb"): hovering any inspectable — a
# board item (either side), a potion, or the enemy in the corridor — asks the Combat
# manager to slow the clock (both sides) to read it.
func _process(_delta: float) -> void:
  if _paused or _state != State.FIGHTING or _cm == null or _view == null or _cm.is_resolved():
    # Suppressed while paused / between fights — hide the tooltip cluster (pause is also blocked by
    # the pause menu's layer-100 Catcher, but this is the explicit off-switch). No-op if already hidden.
    if _view != null:
      _view.stop_inspection()
    return
  var mouse: Vector2 = get_global_mouse_position()
  _cm.request_slowmo(_view.mouse_over_inspectable(mouse))
  _view.update_inspection(mouse)   # feed the cluster the current hover target (the hide-bridge ticks here)


# Pause is a run-screen presentation gate (NOT a Game phase): Escape (ui_cancel) toggles
# it during a beat, freezing the screen's tick and raising the pause menu. The autotest
# never mounts this screen, so pause is invisible to the headless path.
func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed('ui_cancel') and _can_pause():
    _toggle_pause()
    get_viewport().set_input_as_handled()


func _can_pause() -> bool:
  # Pause is available at ANY point in a live run — including while a choice / event / draft
  # overlay is up. The pause menu's full-rect Catcher (layer 100) blocks input to whatever is
  # underneath, and quit-to-menu resumes from the beat's entry save (a clean re-do).
  return _run != null


func _toggle_pause() -> void:
  if _paused:
    _resume()
  else:
    _pause()


func _pause() -> void:
  _paused = true
  # The corridor renderer self-animates (the one allowed cosmetic _process), so the
  # paused approach must also halt the treadmill — not just the depth lerp.
  if _view != null and _state == State.APPROACHING:
    _view.set_gliding(false)
  _pause_menu = PAUSE_MENU.instantiate()
  add_child(_pause_menu)
  _pause_menu.resume_pressed.connect(_resume)
  _pause_menu.settings_pressed.connect(_open_settings)
  _pause_menu.quit_pressed.connect(_quit_to_menu)


func _resume() -> void:
  _paused = false
  if _view != null and _state == State.APPROACHING:
    _view.set_gliding(true)   # the treadmill resumes with the walk
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


# The post-fight summary (docs/systems/combat_log.md): raise the damage report + event log
# and park until Continue. Reads the retained _log (the CombatManager may already be torn
# down — our ref keeps the data alive). Only reached on a won, non-final fight.
func _show_summary() -> void:
  _state = State.SUMMARY
  _summary = COMBAT_SUMMARY.instantiate()
  add_child(_summary)   # on top of the combat view
  _summary.continue_pressed.connect(_on_summary_continued)
  _summary.setup(_log)


func _on_summary_continued() -> void:
  _summary.queue_free()
  _summary = null
  _after_beat()


# The draft is a player choice (a draft-pick intent): raise the 1-of-3 overlay and
# wait. The loop is paused in DRAFTING until a card is picked.
func _show_draft() -> void:
  _state = State.DRAFTING
  _draft = DRAFT_OVERLAY.instantiate()
  add_child(_draft)   # on top of the combat view
  _draft.picked.connect(_on_draft_picked)
  _draft.setup(_run.pending_draft())


func _on_draft_picked(index: int) -> void:
  _draft.queue_free()
  _draft = null
  _run.apply_draft_pick(index)
  _advance()


func _advance() -> void:
  _teardown_combat_view()
  _run.advance()
  _map.mark_position(_run.position)
  _enter_beat()


# --- combat view lifetime ----------------------------------------------------

func _build_combat_view() -> void:
  # Attach a fresh observation log to the fight (docs/systems/combat_log.md). We hold our own
  # ref so the post-fight summary can read it after the CombatManager teardown nulls its side.
  _log = CombatLog.new()
  _cm.combat_log = _log
  _view = COMBAT_VIEW.instantiate()
  add_child(_view)
  move_child(_view, 1)   # above the Background, below the HUD CanvasLayer
  _view.bind(_cm, _run.player, _run.potions)   # the view reads the full rosters off the CM
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
  _log = null   # drop our ref; the summary (if any) is done, so the log can free
  if _view != null:
    _view.release()      # stop the VFX wall reading the CombatManager we're about to free
    _view.queue_free()   # deferred — the view holds render resources (CLAUDE.md)
    _view = null
