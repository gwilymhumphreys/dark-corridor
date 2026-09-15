class_name CombatCorridor
extends SubViewportContainer
## The combat corridor (docs/systems/run_screen.md → Enemies in the corridor): a clipping
## SubViewportContainer hosting a `Corridor3D`. Each enemy is a lit `Sprite3D` in the corridor's
## 3D scene. `set_enemies(actors)` keeps one sprite per enemy, side by side, shrinking and spacing
## them to fit; `enemy_anchor(i)` is the screen point just above sprite i, where the combat view pins
## that enemy's HUD. The view drives the approach via `set_enemy_depth()`; perspective makes the
## sprites smaller with depth and the corridor's light darkens them.
##
## Enemy images are random cut-out painted samples (`MonsterImages`), sized to
## `Balance.ENEMY_PAINTED_HEIGHT` on screen at depth 0. A sprite keeps its image for as long as its
## enemy is in the fight.
##
## The container is drawn through `DebugPanels.world_material`, the corridor look shader (effects
## and the world palette clamp), which covers the walls and enemy images only. With every effect off
## and no world palette it passes colours through.

const CORRIDOR_SCENE: PackedScene = preload('res://src/scenes/corridors/corridor_3d.tscn')
const HUD_GAP: float = 36.0    # gap between a sprite's top and the bottom of its HUD
const SPREAD: float = 0.78     # fraction of the corridor width the enemies spread across
const MIN_COUNT_SHRINK: float = 1.0 / 3.0   # the smallest fraction of full size with many enemies
## Metres between enemies that share a depth, so overlapping sprites are never drawn at the same
## distance.
const DEPTH_STEP: float = 0.05

var _corridor: Corridor3D
var _enemies: Array = []       # Array[Sprite3D], left to right
## The enemy each sprite in `_enemies` belongs to, at the same index. null marks the placeholder
## sprite shown before a fight's enemies are known; the first enemy takes it over.
var _actors: Array = []
var _depth: float = 0.0


func _ready() -> void:
  material = DebugPanels.world_material
  _corridor = CORRIDOR_SCENE.instantiate() as Corridor3D
  _corridor.input_enabled = false   # the view drives the glide; W/S must not scroll the fight
  $SubViewport.add_child(_corridor)
  _corridor.apply_settings(DebugPanels.corridor_settings, DebugPanels.environment_settings)
  _enemies.append(_corridor.add_enemy(MonsterImages.random_texture()))
  _actors.append(null)
  _arrange()


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: release the sprite textures before free.
  for sprite: Sprite3D in _enemies:
    if is_instance_valid(sprite):
      sprite.texture = null
  _enemies.clear()
  _actors.clear()
  material = null


## The hosted corridor.
func corridor() -> Corridor3D:
  return _corridor


## Keep one sprite per enemy in `actors`, in that order (empty once the last enemy is reaped; the
## fight resolves that same step, so the empty corridor is only ever a teardown frame away). An
## enemy that stays keeps its sprite and image; a removed enemy's sprite is freed; a new enemy takes
## over a placeholder sprite if there is one, otherwise gets a new random image.
func set_enemies(actors: Array) -> void:
  if actors == _actors:
    return
  var kept: Dictionary = {}   # actor -> Sprite3D
  var spare: Array = []       # placeholder sprites not yet given to an enemy
  for i in _enemies.size():
    if _actors[i] == null:
      spare.append(_enemies[i])
    elif _actors[i] in actors:
      kept[_actors[i]] = _enemies[i]
    else:
      _corridor.remove_enemy(_enemies[i])
  _enemies.clear()
  _actors.clear()
  for actor: Object in actors:
    var sprite: Sprite3D = kept.get(actor)
    if sprite == null:
      sprite = spare.pop_front() if not spare.is_empty() else _corridor.add_enemy(MonsterImages.random_texture())
    _enemies.append(sprite)
    _actors.append(actor)
  for sprite: Sprite3D in spare:
    _corridor.remove_enemy(sprite)
  _arrange()


## Place the enemies at `depth_cells` sections deep (0 = arrived, larger = further away). They
## share the depth (walk in together).
func set_enemy_depth(depth_cells: float) -> void:
  _depth = depth_cells
  _arrange()


## Glide the corridor forward (the treadmill) for parallax during the approach.
func set_gliding(on: bool) -> void:
  _corridor.set_forward_held(on)


## The global screen point just above enemy `index`'s sprite at its arrived depth, where the combat
## view pins that enemy's HUD (bottom-centred there). It does not move during the approach.
func enemy_anchor(index: int) -> Vector2:
  var n: int = _enemies.size()
  if n == 0:
    return global_position + size * 0.5
  index = clampi(index, 0, n - 1)
  var sprite: Sprite3D = _enemies[index]
  var top: Vector3 = _enemy_position(index, n, 0.0) + Vector3(0.0, _half_height(sprite), 0.0)
  return global_position + size * 0.5 + _corridor.unproject(top) - Vector2(0.0, HUD_GAP)


## Light each enemy hit by a delivery that landed less than the corridor's `hit_light_duration` before
## `now` (render time), in the delivery's colour, fading out. Each enemy gets one light, from its
## newest hit; the newest hits come first. Hits on items or the player's side are not lit. An empty
## array clears the lights.
func show_hits(deliveries: Array, now: float) -> void:
  var duration: float = maxf(_corridor.hit_light_duration, 0.001)
  var newest: Dictionary = {}   # enemy -> [age, colour]
  for d: Delivery in deliveries:
    if not d.landed or d.fizzled or d.target == null or not d.target in _actors:
      continue
    var age: float = now - d.impact_time
    if age < 0.0 or age >= duration:
      continue
    if not newest.has(d.target) or age < newest[d.target][0]:
      newest[d.target] = [age, d.color]
  var enemies: Array = newest.keys()
  enemies.sort_custom(func(a: Object, b: Object) -> bool: return newest[a][0] < newest[b][0])
  var lights: Array = []
  for enemy: Object in enemies:
    var sprite: Sprite3D = _enemies[_actors.find(enemy)]
    var light_position: Vector3 = sprite.position + Vector3(0.0, 0.0, _corridor.hit_light_distance)
    lights.append([light_position, newest[enemy][1], 1.0 - float(newest[enemy][0]) / duration])
  _corridor.set_hit_lights(lights)


func _arrange() -> void:
  var n: int = _enemies.size()
  for i in n:
    var sprite: Sprite3D = _enemies[i]
    _corridor.size_enemy(sprite, Balance.ENEMY_PAINTED_HEIGHT * _count_shrink(n))
    sprite.position = _enemy_position(i, n, _depth)


# Enemy i of n at `depth_cells`, each one DEPTH_STEP further than the one before.
func _enemy_position(i: int, n: int, depth_cells: float) -> Vector3:
  return _corridor.enemy_position(depth_cells, _offset_x(i, n)) - Vector3(0.0, 0.0, DEPTH_STEP * float(i))


func _half_height(sprite: Sprite3D) -> float:
  if sprite.texture == null:
    return 0.0
  return sprite.pixel_size * float(sprite.texture.get_height()) * 0.5


# The fraction of full size each enemy keeps with `n` side by side (1 = a single enemy at full
# size).
func _count_shrink(n: int) -> float:
  if n <= 1:
    return 1.0
  return clampf(1.7 / float(n), MIN_COUNT_SHRINK, 1.0)


# The horizontal screen offset of enemy i at depth 0, from the panel centre.
func _offset_x(i: int, n: int) -> float:
  var slot: float = (size.x * SPREAD) / float(n)
  return (float(i) - float(n - 1) * 0.5) * slot
