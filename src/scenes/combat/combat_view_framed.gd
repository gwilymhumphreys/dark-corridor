class_name CombatViewFramed
extends Control
## The framed combat view (ui_layout_prd; phase4_plan locked layout): the corridor +
## enemy occupant top-right, the player portrait on the left, both boards, HP and
## potion slots — composed in combat_view_framed.tscn. It binds the live fight (the
## player + enemy Actors + the CombatManager) into the scene and hosts the VFX wall;
## it READS logic and writes nothing. The framed-vs-fullscreen open is isolated HERE
## (a swappable CombatView) — nothing else moves when it is decided.

const POTION_SLOT_SIZE := Vector2(96, 96)
const POTION_COLOR := Color(0.3, 0.7, 0.45, 1)

var _cm: CombatManager
var _player: Actor
var _enemy: Actor

@onready var _corridor: CombatCorridor = $CorridorPanel
@onready var _player_strip: BoardStrip = $PlayerSide/PlayerBoard
@onready var _enemy_strip: BoardStrip = $EnemySide/EnemyBoard
@onready var _portrait: Control = $PlayerSide/Portrait
@onready var _potions: HBoxContainer = $PlayerSide/Potions
@onready var _vfx: VfxDriver = $VfxWall


## Bind the live fight: build both boards, the potion slots, place the enemy at full
## scale (the approach lands in Step 7), and point the VFX wall at this layout.
func bind(cm: CombatManager, player: Actor, enemy: Actor, potions: Array) -> void:
  _cm = cm
  _player = player
  _enemy = enemy
  _player_strip.setup(player)
  _enemy_strip.setup(enemy)
  _build_potions(potions)
  _corridor.set_enemy_depth(0.0)
  _vfx.setup(_cm, self)


func _build_potions(potions: Array) -> void:
  for child in _potions.get_children():
    child.queue_free()
  for _consumable in potions:
    var slot := ColorRect.new()
    slot.custom_minimum_size = POTION_SLOT_SIZE
    slot.color = POTION_COLOR
    _potions.add_child(slot)


## Approach controls (phase4_plan Step 7) — the run screen tweens the enemy from
## depth into full view, gliding the corridor for parallax, before combat begins.
func set_enemy_depth(depth_cells: float) -> void:
  _corridor.set_enemy_depth(depth_cells)


func set_gliding(on: bool) -> void:
  _corridor.set_gliding(on)


## Stop reading the live fight before it is torn down (the run screen calls this
## right before freeing the view + advancing, so the VFX wall never samples a
## CombatManager that's about to free). Render resources free with the view.
func release() -> void:
  _vfx.combat = null


## The hover surface for the slow-mo intent (ui_layout_prd "one verb"): any board
## item (either side), any potion slot, or the enemy in the corridor. Hovering any
## of these asks the Combat manager to slow the clock (both sides) to inspect.
func mouse_over_inspectable(point: Vector2) -> bool:
  if _player_strip.mouse_over(point) or _enemy_strip.mouse_over(point):
    return true
  if _corridor.get_global_rect().has_point(point):   # the enemy, in the corridor
    return true
  for slot in _potions.get_children():
    if (slot as Control).get_global_rect().has_point(point):
      return true
  return false


# --- layout lookups the VFX wall reads (global / screen space) ---------------

func item_pos(item: Item) -> Vector2:
  var centre: Vector2 = _player_strip.cell_centre(item)
  if centre != Vector2.INF:
    return centre
  centre = _enemy_strip.cell_centre(item)
  if centre != Vector2.INF:
    return centre
  return actor_pos(item.owner)


func actor_pos(actor: Actor) -> Vector2:
  if actor == _enemy:
    return _corridor.enemy_screen_centre()
  return _portrait.global_position + _portrait.size * 0.5
