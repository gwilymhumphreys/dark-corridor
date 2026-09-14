class_name CombatCorridor
extends SubViewportContainer
## The combat corridor (docs/systems/run_screen.md → Enemy-in-corridor occupant): a clipping
## SubViewportContainer hosting the corridor renderer chosen in the debug panel
## (`DebugPanels.corridor_scene()`, read once when the combat view is built). Each enemy is a
## central-axis OCCUPANT sprite (a child of the renderer at the vanishing point).
## `set_enemy_count(n)` spawns n sprites arranged side by side, shrinking + spacing them to fit;
## `enemy_anchor(i)` is the screen point just above occupant i, where the combat view pins that
## enemy's HUD. The view drives the approach via `set_enemy_depth()`; the sprites scale by the
## renderer's perspective law (`CorridorRenderer.axis_scale`) so they stay locked to the walls. The
## renderer is 1:1 with the panel (origin = panel centre), so a sprite's local x offset is its
## on-screen x offset.
##
## Enemy images: a random painted sample, cut out of its black background by default (scaled to
## `Balance.ENEMY_PAINTED_HEIGHT`, mipmapped Linear filter), or the original pixel sprite (scaled
## by `enemy_full_scale`).

const ENEMY_SPRITE: Texture2D = preload('res://assets/sprites/enemies/thorn-demon.png')
const HUD_GAP: float = 36.0    # gap between a sprite's top and the bottom of its HUD
const SPREAD: float = 0.78     # fraction of the corridor width the occupants spread across

var enemy_full_scale: float = Balance.ENEMY_FULL_SCALE
var _corridor: CorridorRenderer
var _painted: bool = false
var _enemies: Array = []       # Array[Sprite2D] — the occupant sprites, left-to-right
var _depth: float = 0.0


func _ready() -> void:
  _painted = DebugPanels.enemy_images != DebugPanelsAutoload.EnemyImages.PIXEL
  _corridor = DebugPanels.corridor_scene().instantiate() as CorridorRenderer
  _corridor.input_enabled = false   # the view drives the glide; W/S must not scroll the fight
  $SubViewport.add_child(_corridor)
  set_enemy_count(1)


func _process(_delta: float) -> void:
  _apply_brightness()   # every frame, so a flickering light reaches the enemies


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: release the occupant textures before free.
  for s in _enemies:
    if is_instance_valid(s):
      s.texture = null
  _enemies.clear()


## The hosted renderer (whichever kind the debug panel chose).
func renderer() -> CorridorRenderer:
  return _corridor


## Ensure exactly `n` occupant sprites, arranged side by side (0 once the last enemy is reaped —
## the fight resolves that same step, so the empty corridor is only ever a teardown frame away).
func set_enemy_count(n: int) -> void:
  n = maxi(n, 0)
  while _enemies.size() < n:
    var s := Sprite2D.new()
    var texture: Texture2D = MonsterImages.random_texture(MonsterImages.folder_for_choice()) if _painted else null
    if texture != null:
      s.texture = texture
      s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    else:
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
## enemy's HUD (bottom-centred there). Uses the arranged slot + the sprite's own image height at
## full (depth-0) size, so the HUD stays put while the sprites scale on the approach.
func enemy_anchor(index: int) -> Vector2:
  var n: int = _enemies.size()
  if n == 0:
    return global_position + size * 0.5
  index = clampi(index, 0, n - 1)
  var sprite: Sprite2D = _enemies[index]
  var half_h: float = float(sprite.texture.get_height()) * _arrived_scale(sprite, n) * 0.5
  var centre: Vector2 = global_position + size * 0.5 + Vector2(_offset_x(index, n), 0.0)
  return centre - Vector2(0.0, half_h + HUD_GAP)


func _arrange() -> void:
  var n: int = _enemies.size()
  var depth_scale: float = _corridor.axis_scale(_depth)
  for i in n:
    var sprite: Sprite2D = _enemies[i]
    var s: float = _arrived_scale(sprite, n) * depth_scale
    sprite.position = Vector2(_offset_x(i, n), 0.0)
    sprite.scale = Vector2(s, s)
  _apply_brightness()


# Darken the enemy images with the corridor's light at their depth (a colour multiply; the black
# backgrounds stay black).
func _apply_brightness() -> void:
  var level: float = _corridor.enemy_brightness(_depth)
  for sprite: Sprite2D in _enemies:
    sprite.modulate = Color(level, level, level)


# A sprite's scale when arrived (depth 0) with `n` occupants: its full size, shrunk as the count
# grows so they fit side by side. Painted images are sized to a target height; the pixel sprite
# uses enemy_full_scale.
func _arrived_scale(sprite: Sprite2D, n: int) -> float:
  var full: float = enemy_full_scale
  if sprite.texture != ENEMY_SPRITE and sprite.texture.get_height() > 0:
    full = Balance.ENEMY_PAINTED_HEIGHT / float(sprite.texture.get_height())
  return full * _count_shrink(n)


# The fraction of full size each occupant keeps with `n` side by side (1 = the dramatic single
# occupant at full scale). For the pixel sprite this never goes below a scale of 1.
func _count_shrink(n: int) -> float:
  if n <= 1:
    return 1.0
  return clampf(1.7 / float(n), 1.0 / enemy_full_scale, 1.0)


# The horizontal offset of occupant i — corridor-local, which is on-screen px (the renderer is
# 1:1 with the panel, origin at panel centre).
func _offset_x(i: int, n: int) -> float:
  var slot: float = (size.x * SPREAD) / float(n)
  return (float(i) - float(n - 1) * 0.5) * slot
