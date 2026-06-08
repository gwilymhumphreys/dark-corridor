class_name CombatCorridor
extends SubViewportContainer
## The combat corridor (phase4_plan → enemy-in-corridor): a clipping SubViewportContainer
## hosting the CorridorScaled renderer. Each enemy is a central-axis OCCUPANT sprite (a child
## of the renderer at the vanishing point) — now MULTI-ENEMY: `set_enemy_count(n)` spawns n
## sprites arranged side by side, shrinking + spacing them to fit; `enemy_anchor(i)` is the
## screen point just above occupant i, where the combat view pins that enemy's HUD. The view
## drives the approach via `set_enemy_depth()`; the sprites scale by the renderer's perspective
## law (`CorridorScaled.axis_scale`) so they stay locked to the walls. The renderer is 1:1 with
## the panel (origin = panel centre), so a sprite's local x offset is its on-screen x offset.

const ENEMY_SPRITE: Texture2D = preload('res://assets/sprites/enemies/thorn-demon.png')
const HUD_GAP: float = 36.0    # gap between a sprite's top and the bottom of its HUD
const SPREAD: float = 0.78     # fraction of the corridor width the occupants spread across

@onready var _corridor: CorridorScaled = $SubViewport/CorridorScaled

var enemy_full_scale: float = Balance.ENEMY_FULL_SCALE
var _enemies: Array = []       # Array[Sprite2D] — the occupant sprites, left-to-right
var _depth: float = 0.0


func _ready() -> void:
  set_enemy_count(1)


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: release the occupant textures before free.
  for s in _enemies:
    if is_instance_valid(s):
      s.texture = null
  _enemies.clear()


## Ensure exactly `n` occupant sprites (min 1), arranged side by side.
func set_enemy_count(n: int) -> void:
  n = maxi(n, 1)
  while _enemies.size() < n:
    var s := Sprite2D.new()
    s.texture = ENEMY_SPRITE
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.z_index = 100
    _corridor.add_child(s)
    _enemies.append(s)
  while _enemies.size() > n:
    var extra: Sprite2D = _enemies.pop_back()
    extra.texture = null
    extra.queue_free()
  _arrange()


## Place the occupants at `depth_cells` deep (0 = arrived / full size, larger = deeper /
## smaller); scale follows the wall perspective. They share the depth (walk in together).
func set_enemy_depth(depth_cells: float) -> void:
  _depth = depth_cells
  _arrange()


## Glide the corridor forward (the treadmill) for parallax during the approach.
func set_gliding(on: bool) -> void:
  _corridor.set_forward_held(on)


## The screen point just above occupant `index`'s sprite — where the combat view pins that
## enemy's HUD (bottom-centred there). Uses the arranged slot + the full (depth-0) size, so the
## HUD stays put while the sprites scale on the approach.
func enemy_anchor(index: int) -> Vector2:
  var n: int = _enemies.size()
  if n == 0:
    return global_position + size * 0.5
  index = clampi(index, 0, n - 1)
  var half_h: float = float(ENEMY_SPRITE.get_height()) * _base_scale(n) * 0.5
  var centre: Vector2 = global_position + size * 0.5 + Vector2(_offset_x(index, n), 0.0)
  return centre - Vector2(0.0, half_h + HUD_GAP)


func _arrange() -> void:
  var n: int = _enemies.size()
  var s: float = _base_scale(n) * _corridor.axis_scale(_depth)
  for i in n:
    _enemies[i].position = Vector2(_offset_x(i, n), 0.0)
    _enemies[i].scale = Vector2(s, s)


# Shrink the occupants as their count grows so they fit side by side (1 = the dramatic single
# occupant at full scale).
func _base_scale(n: int) -> float:
  if n <= 1:
    return enemy_full_scale
  return clampf(enemy_full_scale * 1.7 / float(n), 1.0, enemy_full_scale)


# The horizontal offset of occupant i — corridor-local, which is on-screen px (the renderer is
# 1:1 with the panel, origin at panel centre).
func _offset_x(i: int, n: int) -> float:
  var slot: float = (size.x * SPREAD) / float(n)
  return (float(i) - float(n - 1) * 0.5) * slot
