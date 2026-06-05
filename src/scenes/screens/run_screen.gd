extends Control
## The run screen (ui_layout_prd) — the real-time client of the run. It reads
## Game.run + the live CombatManager and emits intents (slow-mo); it never mutates
## game state. The logic tree stays OUT of the scene tree: each physics frame this
## screen calls `cm.tick(delta)` on the active fight — the same one tick the autotest
## runs via sim_step (combat_manager.gd).
##
## STEP 2 scope: drive the FIRST beat's fight and compose the FRAMED combat view over
## it (corridor + enemy occupant top-right, player left, boards, HP, potions). The
## full advance-through-the-map loop arrives in Step 4.

const COMBAT_VIEW: PackedScene = preload('res://src/scenes/combat/combat_view_framed.tscn')

var _run: RunManager
var _cm: CombatManager
var _view: CombatViewFramed
var _result: Label


func _ready() -> void:
  _result = $HUD/Result
  _run = Game.run
  if _run == null:
    return
  _begin_fight()


func _begin_fight() -> void:
  _run.begin_current()
  _cm = _run.combat_manager()
  if _cm == null:
    return   # a non-fight beat (rest) — the Step-4 loop handles these
  _cm.resolved.connect(_on_resolved)
  var enemy: Actor = _run.current_encounter().enemies[0]
  _view = COMBAT_VIEW.instantiate()
  add_child(_view)
  move_child(_view, 1)   # above the Background, below the HUD CanvasLayer
  _view.bind(_cm, _run.player, enemy, _run.potions)


# The one real-time tick: advance the active fight off real delta (steps_due ×
# sim_step). Nothing in the logic tree is mounted — this is the same tick the
# headless autotest runs directly.
func _physics_process(delta: float) -> void:
  if _cm != null and not _cm.is_resolved():
    _cm.tick(delta)


# Slow-mo-on-hover intent (ui_layout_prd "one verb"): hovering any inspectable —
# a board item (either side), a potion, or the enemy in the corridor — asks the
# Combat manager to slow the clock (both sides proportionally) to read it.
func _process(_delta: float) -> void:
  if _cm == null or _cm.is_resolved() or _view == null:
    return
  var mouse: Vector2 = get_global_mouse_position()
  _cm.request_slowmo(_view.mouse_over_inspectable(mouse))


func _on_resolved(player_won: bool) -> void:
  _result.text = tr('Victory') if player_won else tr('Defeat')
