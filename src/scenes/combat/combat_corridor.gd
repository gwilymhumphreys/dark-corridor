class_name CombatCorridor
extends SubViewportContainer
## The combat corridor (phase4_plan → enemy-in-corridor): a resizeable, clipping
## SubViewportContainer hosting the CorridorScaled renderer with the enemy sprite as
## a central-axis OCCUPANT (a child of the renderer at the vanishing point). The combat
## view drives the enemy's approach depth via set_enemy_depth(); the sprite scales by
## the renderer's own perspective law (CorridorScaled.axis_scale) so it stays locked to
## the walls. Reads nothing of game state — it's handed a depth + visibility.

@onready var _corridor: CorridorScaled = $SubViewport/CorridorScaled
@onready var _enemy: Sprite2D = $SubViewport/CorridorScaled/Enemy

var enemy_full_scale: float = Balance.ENEMY_FULL_SCALE


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: release the occupant sprite's texture before free (the
  # CorridorScaled renderer handles its own wall textures).
  if _enemy != null:
    _enemy.texture = null


## Place the enemy at `depth_cells` deep on the central axis (0 = arrived / full
## size, larger = deeper / smaller). Scale follows the wall perspective.
func set_enemy_depth(depth_cells: float) -> void:
  var s: float = enemy_full_scale * _corridor.axis_scale(depth_cells)
  _enemy.scale = Vector2(s, s)


func set_enemy_visible(is_visible: bool) -> void:
  _enemy.visible = is_visible


## Glide the corridor forward (the treadmill) for parallax during the approach, then
## ease to a stop on arrival. Drives the shared CorridorRenderer motion interface.
func set_gliding(on: bool) -> void:
  _corridor.set_forward_held(on)


## The enemy sprite's centre in global (screen) space — the VFX wall's target for
## projectiles flying into the corridor. The occupant is centred on the axis (the
## SubViewport centre), so this is the panel's on-screen centre.
func enemy_screen_centre() -> Vector2:
  return global_position + size * 0.5
