class_name RunScreen
extends Control
## The run screen (ui_layout_prd) — the real-time client of the run. It reads
## Game.run + the live CombatManager and emits intents (slow-mo); it never mutates
## game state. The logic tree stays OUT of the scene tree: each physics frame this
## screen calls `cm.tick(delta)` on the active fight — the same one tick the autotest
## runs via sim_step (combat_manager.gd).
##
## STEP 4 scope: a polling state machine that drives the WHOLE descent in real time,
## mirroring AutoTestMode.run_full — enter beat → (fight: tick to resolution | rest:
## resolves on begin) → fulfil reward → advance → repeat, until the run ends (Game
## then swaps to the win/death screen). The run processes each beat's outcome via its
## own signal chain DURING the resolving tick; this screen reacts by POLLING
## cm.is_resolved() (never from inside the signal), so it can safely tear the fight
## down and advance. The draft pick is auto-taken here (the Step-5 overlay supplies it);
## the corridor approach is inserted at _advance in Step 7.

const COMBAT_VIEW: PackedScene = preload('res://src/scenes/combat/combat_view_framed.tscn')
const DRAFT_OVERLAY: PackedScene = preload('res://src/scenes/screens/draft_overlay.tscn')
const PAUSE_MENU: PackedScene = preload('res://src/scenes/screens/pause_menu.tscn')

enum State { IDLE, APPROACHING, FIGHTING, DRAFTING, ENDED }

var _run: RunManager
var _cm: CombatManager
var _view: CombatViewFramed
var _draft: DraftOverlay
var _state: int = State.IDLE
var _approach_elapsed: float = 0.0
var _paused: bool = false
var _pause_menu: PauseMenu = null

@onready var _map: MapStrip = $HUD/MapStrip


func _ready() -> void:
  _run = Game.run
  if _run == null:
    return
  # The player battle-speed dial (a Game session preference): retime the live fight
  # the instant the HUD button changes it. Each new fight also picks it up on entry.
  Game.battle_speed_changed.connect(_on_battle_speed_changed)
  _map.setup(RunMap.TOTAL_BEATS, _run.position)
  _enter_beat()


func _exit_tree() -> void:
  if Game.battle_speed_changed.is_connected(_on_battle_speed_changed):
    Game.battle_speed_changed.disconnect(_on_battle_speed_changed)


# --- the run cycle (a polling FSM; mirrors AutoTestMode.run_full) ------------

func _enter_beat() -> void:
  if _run.is_ended():
    return
  # A CHOICE beat has no encounter until a path is picked. Stage 1: auto-pick the first
  # candidate (Stage 2 raises the choice overlay here and waits for the player's pick).
  if _run.has_pending_choice():
    _run.pick_path(0)
  _run.begin_current()
  _cm = _run.combat_manager()
  if _cm != null and not _cm.is_resolved():
    _apply_battle_speed()   # this fight inherits the current dial setting
    _build_combat_view()
    _begin_approach()
  else:
    # A non-fight beat (rest) resolved synchronously on begin().
    _cm = null
    _after_beat()


# The corridor approach (phase4_plan Step 7): the enemy walks from depth into full
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
        _state = State.IDLE
        _after_beat()
      else:
        _cm.tick(delta)


# Battle-speed (a Game session preference) sets the fight clock's BASE scale; the
# hover slow-mo override still replaces it absolutely while inspecting, returning to
# this base on release (resolved: absolute slow-mo — timekeeper.gd). Applied on fight
# entry and live on the dial signal.
func _apply_battle_speed() -> void:
  _on_battle_speed_changed(Game.battle_speed)


func _on_battle_speed_changed(scale: float) -> void:
  if _cm != null and _cm.timekeeper != null:
    _cm.timekeeper.set_base_scale(scale)


# Slow-mo-on-hover intent (ui_layout_prd "one verb"): hovering any inspectable — a
# board item (either side), a potion, or the enemy in the corridor — asks the Combat
# manager to slow the clock (both sides) to read it.
func _process(_delta: float) -> void:
  if _paused or _state != State.FIGHTING or _cm == null or _view == null or _cm.is_resolved():
    return
  _cm.request_slowmo(_view.mouse_over_inspectable(get_global_mouse_position()))


# Pause is a run-screen presentation gate (NOT a Game phase): Escape (ui_cancel) toggles
# it during a beat, freezing the screen's tick and raising the pause menu. The autotest
# never mounts this screen, so pause is invisible to the headless path.
func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed('ui_cancel') and _can_pause():
    _toggle_pause()
    get_viewport().set_input_as_handled()


func _can_pause() -> bool:
  return _state == State.APPROACHING or _state == State.FIGHTING


func _toggle_pause() -> void:
  if _paused:
    _resume()
  else:
    _pause()


func _pause() -> void:
  _paused = true
  _pause_menu = PAUSE_MENU.instantiate()
  add_child(_pause_menu)
  _pause_menu.resume_pressed.connect(_resume)
  _pause_menu.quit_pressed.connect(_quit_to_menu)


func _resume() -> void:
  _paused = false
  if _pause_menu != null:
    _pause_menu.queue_free()
    _pause_menu = null


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
  _enter_beat()   # TODO Step 7: the corridor approach plays here before the fight


# --- combat view lifetime ----------------------------------------------------

func _build_combat_view() -> void:
  var enemy: Actor = _run.current_encounter().enemies[0]
  _view = COMBAT_VIEW.instantiate()
  add_child(_view)
  move_child(_view, 1)   # above the Background, below the HUD CanvasLayer
  _view.bind(_cm, _run.player, enemy, _run.potions)
  _view.potion_thrown.connect(_on_potion_thrown)


# Throw-potion intent: only valid in a live fight (the consumable resolves through the
# Combat manager). On success the reserve shrank, so refresh the slots.
func _on_potion_thrown(index: int) -> void:
  if _state != State.FIGHTING:
    return
  if _run.throw_potion(index):
    _view.refresh_potions(_run.potions)


func _teardown_combat_view() -> void:
  if _view != null:
    _view.release()      # stop the VFX wall reading the CombatManager we're about to free
    _view.queue_free()   # deferred — the view holds render resources (CLAUDE.md)
    _view = null
