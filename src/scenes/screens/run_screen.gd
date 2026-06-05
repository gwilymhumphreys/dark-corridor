extends Control
## The run screen (ui_layout_prd) — the real-time client of the run. It reads
## Game.run + the live CombatManager and emits intents (slow-mo); it never mutates
## game state. The logic tree stays OUT of the scene tree: each physics frame this
## screen calls `cm.tick(delta)` on the active fight — the same one tick the autotest
## runs via sim_step (combat_manager.gd).
##
## STEP 1 scope: drive the FIRST beat's fight to a verdict and compose the existing
## placeholder BoardView / VfxDriver over it (the framed scene replaces these in
## Step 2; the full advance-through-the-map loop arrives in Step 4).

# Stopgap board anchors (viewport px); the framed layout (Step 2) supersedes them.
const PLAYER_ANCHOR := Vector2(640, 880)
const ENEMY_ANCHOR := Vector2(1920, 880)

var _run: RunManager
var _cm: CombatManager
var _player_board: BoardView
var _enemy_board: BoardView
var _vfx: VfxDriver
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

  _player_board = BoardView.new()
  add_child(_player_board)
  _player_board.setup(_run.player, PLAYER_ANCHOR, true)

  _enemy_board = BoardView.new()
  add_child(_enemy_board)
  _enemy_board.setup(enemy, ENEMY_ANCHOR, false)

  _vfx = VfxDriver.new()
  add_child(_vfx)
  _vfx.setup(_cm, self)


# The one real-time tick: advance the active fight off real delta (steps_due ×
# sim_step). Nothing in the logic tree is mounted — this is the same tick the
# headless autotest runs directly.
func _physics_process(delta: float) -> void:
  if _cm != null and not _cm.is_resolved():
    _cm.tick(delta)


# Slow-mo-on-hover intent: hovering a board item asks the Combat manager to slow the
# clock (both sides). The full hover surface (potions, enemy) lands in Step 3.
func _process(_delta: float) -> void:
  if _cm == null or _cm.is_resolved():
    return
  var mouse: Vector2 = get_global_mouse_position()
  var over: bool = _player_board.mouse_over(mouse) or _enemy_board.mouse_over(mouse)
  _cm.request_slowmo(over)


func _on_resolved(player_won: bool) -> void:
  _result.text = tr('Victory') if player_won else tr('Defeat')


# --- layout lookups the VFX wall reads (the same surface the sandbox exposes) ----

func item_pos(item: Item) -> Vector2:
  var pos: Vector2 = _player_board.icon_center(item)
  if pos != Vector2.INF:
    return pos
  pos = _enemy_board.icon_center(item)
  if pos != Vector2.INF:
    return pos
  return actor_pos(item.owner)


func actor_pos(actor: Actor) -> Vector2:
  return PLAYER_ANCHOR if actor == _run.player else ENEMY_ANCHOR
