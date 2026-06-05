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

enum State { IDLE, FIGHTING, DRAFTING, ENDED }

var _run: RunManager
var _cm: CombatManager
var _view: CombatViewFramed
var _draft: DraftOverlay
var _state: int = State.IDLE


func _ready() -> void:
  _run = Game.run
  if _run == null:
    return
  _enter_beat()


# --- the run cycle (a polling FSM; mirrors AutoTestMode.run_full) ------------

func _enter_beat() -> void:
  if _run.is_ended():
    return
  _run.begin_current()
  _cm = _run.combat_manager()
  if _cm != null and not _cm.is_resolved():
    _build_combat_view()
    _state = State.FIGHTING
  else:
    # A non-fight beat (rest) resolved synchronously on begin().
    _cm = null
    _after_beat()


# The one real-time tick: advance the active fight off real delta (steps_due ×
# sim_step), then react to resolution OUTSIDE the resolving signal. Nothing in the
# logic tree is mounted — this is the same tick the headless autotest runs directly.
func _physics_process(delta: float) -> void:
  if _state != State.FIGHTING or _cm == null:
    return
  if _cm.is_resolved():
    _state = State.IDLE
    _after_beat()
  else:
    _cm.tick(delta)


# Slow-mo-on-hover intent (ui_layout_prd "one verb"): hovering any inspectable — a
# board item (either side), a potion, or the enemy in the corridor — asks the Combat
# manager to slow the clock (both sides) to read it.
func _process(_delta: float) -> void:
  if _state != State.FIGHTING or _cm == null or _view == null or _cm.is_resolved():
    return
  _cm.request_slowmo(_view.mouse_over_inspectable(get_global_mouse_position()))


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
  _enter_beat()   # TODO Step 7: the corridor approach plays here before the fight


# --- combat view lifetime ----------------------------------------------------

func _build_combat_view() -> void:
  var enemy: Actor = _run.current_encounter().enemies[0]
  _view = COMBAT_VIEW.instantiate()
  add_child(_view)
  move_child(_view, 1)   # above the Background, below the HUD CanvasLayer
  _view.bind(_cm, _run.player, enemy, _run.potions)


func _teardown_combat_view() -> void:
  if _view != null:
    _view.release()      # stop the VFX wall reading the CombatManager we're about to free
    _view.queue_free()   # deferred — the view holds render resources (CLAUDE.md)
    _view = null
