class_name Corridor3D
extends Node2D
## The corridor (docs/systems/corridors/corridor_3d.md). A SubViewport with its own 3D world holds
## the camera, the light, the corridor sections and the enemy sprites; its image is drawn at
## `view_size`, centred on this node's origin.
##
## The camera stays at the origin. Each frame the sections are placed from `player_z`, so
## positions stay small however long the run is. Sections are created ahead up to the light's
## reach and removed behind.
##
## One OmniLight3D at the camera lights the pieces and the enemy sprites, and there is no ambient
## light, so everything past `light_range` is black.

## Every built corridor is in this group, so the debug panel's Corridor tab can change the ones on screen.
const GROUP: StringName = &'corridors'

## When true (default), `view_size` is set to the size of the viewport this corridor is in (the
## main viewport, or a SubViewport sized by its container), and re-synced on resize. Turn off to
## set `view_size` yourself. Requires this node's parent to sit at the viewport origin.
@export var auto_view_size: bool = true
## The on-screen rectangle the corridor fills, in local pixels, centred on this node's origin.
@export var view_size: Vector2 = Vector2(1280.0, 1280.0)
## Sections per second at full glide: a cautious walking pace, about 0.7 metres per second with a
## 3 metre section.
@export var speed: float = 0.233
## Seconds to ease the speed in and out.
@export var ramp_time: float = 0.3
## Whether the corridor polls the move_forward / move_back actions itself (the testbed). Hosts
## that drive the corridor (the combat view) turn this off, or W/S would scroll the fight's
## corridor at any time.
@export var input_enabled: bool = true
## Where the section pieces come from. Any CorridorPieceSource can be used.
@export var piece_source: CorridorPieceSource
## The camera's vertical field of view, in degrees.
@export var fov: float = 70.0

@export_group('Walk')
## Metres covered per footstep. `CombatCorridor` overwrites it from the run's character; the
## default is what the testbed and the tests use.
@export var stride_length: float = 0.65
## Whether a footfall plays a sound.
@export var footsteps_on: bool = true
## Whether the camera bobs with the walk.
@export var bob_on: bool = true
## Metres the camera drops at a footfall.
@export var bob_height: float = 0.04
## Metres the camera leans to the side, one full lean every two steps.
@export var bob_sway: float = 0.02

@export_group('Light')
## The distance from the camera, in metres, where the light reaches black. Sections are built a
## little past it, so the end of the corridor is always in darkness.
@export var light_range: float = 8.0
## The light's `light_energy`.
@export_range(0.0, 16.0) var light_energy: float = 0.25
## The light's `omni_attenuation`. Higher values make the nearest surface brighter and the fade
## sooner.
@export var light_attenuation: float = 1.5
## How much the light dims at the bottom of a flicker, 0 to 1. 0 is a steady light.
@export_range(0.0, 1.0) var flicker_amount: float = 0.0
## How fast the flicker changes. Higher is faster.
@export var flicker_speed: float = 8.0

@export_group('Hit lights')
## A short light at an enemy when a delivery lands on it, in the delivery's colour (so it follows the
## interface palette). The host passes the lights each frame to `set_hit_lights`. A look setting,
## kept until the effects pass decides on hit visuals.
@export var hit_lights_on: bool = true
## A hit light's `light_energy` at the moment of the hit. It fades to 0 over `hit_light_duration`.
@export_range(0.0, 16.0) var hit_light_energy: float = 0.25
## A hit light's `omni_range`, in metres.
@export var hit_light_range: float = 2.0
## Seconds of render time a hit light lasts. A landed delivery is only kept for
## `Balance.DELIVERY_VISUAL_HOLD`, so a longer duration is cut short.
@export var hit_light_duration: float = 0.3
## How far in front of the enemy sprite, towards the camera, a hit light sits, in metres.
@export var hit_light_distance: float = 0.5

@export_group('Enemies')
## Enemy image pixels with an alpha below this are not drawn; the rest are drawn fully opaque.
@export_range(0.0, 1.0) var alpha_scissor_threshold: float = 0.1

## The most hit lights shown at once. Each extra light costs another draw of every object it reaches in
## the Compatibility renderer.
const MAX_HIT_LIGHTS: int = 4
## More movement than this in one frame, in metres, is a host reseating the corridor, not a walk.
const MAX_FRAME_MOVE: float = 2.0
## Walking speed, in metres per second, below which the corridor counts as stopped.
const MIN_WALK_SPEED: float = 0.05
## Seconds over which `walk_speed` eases toward what was measured this frame.
const SPEED_EASE_TIME: float = 0.12

signal footstep(index: int)   ## each time a foot lands, with the running count since the walk was last reset

var player_z: float = 0.0               ## continuous forward position, in sections
var velocity: float = 0.0               ## eased sections per second; ramps over ramp_time
## Metres walked, counting movement in both directions.
var walk_distance: float = 0.0
## Current walking speed, in metres per second.
var walk_speed: float = 0.0
var forward_held: bool = false
var back_held: bool = false

var _sections: Dictionary = {}   # absolute section index -> Node3D
var _flicker_noise: FastNoiseLite = FastNoiseLite.new()
var _flicker_time: float = 0.0
var _last_player_z: float = 0.0
var _step_count: int = 0

@onready var _viewport: SubViewport = $SubViewport
@onready var _camera: Camera3D = $SubViewport/Camera
@onready var _light: OmniLight3D = $SubViewport/Light
@onready var _section_root: Node3D = $SubViewport/Sections
@onready var _enemy_root: Node3D = $SubViewport/Enemies
@onready var _hit_light_root: Node3D = $SubViewport/HitLights
@onready var _display: Sprite2D = $Display


func _init() -> void:
  _flicker_noise.frequency = 1.0


func _ready() -> void:
  add_to_group(GROUP)
  # Each corridor gets its own copy, so changing one corridor's environment does not change the
  # scene resource the others share.
  _camera.environment = _camera.environment.duplicate()
  if auto_view_size:
    _sync_view_size()
    get_viewport().size_changed.connect(_on_viewport_resized)
  _build()


func _exit_tree() -> void:
  if auto_view_size and get_viewport().size_changed.is_connected(_on_viewport_resized):
    get_viewport().size_changed.disconnect(_on_viewport_resized)
  _display.texture = null
  for sprite: Sprite3D in _enemy_root.get_children():
    sprite.texture = null
  _clear_sections()


# Fill (and centre in) the current viewport. The parent must be at the origin.
func _sync_view_size() -> void:
  var size: Vector2 = get_viewport_rect().size
  view_size = size
  position = size * 0.5


func _on_viewport_resized() -> void:
  _sync_view_size()
  rebuild()


## Rebuild after a `view_size` change.
func rebuild() -> void:
  _build()


func _build() -> void:
  if piece_source == null:
    piece_source = CodeBuiltPieceSource.new()
  _viewport.size = Vector2i(maxi(int(view_size.x), 1), maxi(int(view_size.y), 1))
  _camera.fov = fov
  _camera.far = light_range + piece_source.section_length
  _apply_light()
  _display.texture = _viewport.get_texture()
  _display.centered = true
  _display.position = Vector2.ZERO
  _last_player_z = player_z
  _layout()


func _process(delta: float) -> void:
  var direction: float = 0.0
  if forward_held or (input_enabled and Input.is_action_pressed('move_forward')):
    direction += 1.0
  if back_held or (input_enabled and Input.is_action_pressed('move_back')):
    direction -= 1.0
  # Ease the velocity toward the target over ramp_time, so starting and stopping do not snap.
  var acceleration: float = speed / maxf(ramp_time, 0.001)
  velocity = move_toward(velocity, direction * speed, acceleration * delta)
  player_z += velocity * delta

  _flicker_time += delta
  _light.light_energy = light_energy * flicker_level(_flicker_time)
  _layout()
  _update_walk(delta)


## Measure how far `player_z` actually moved this frame and, from that distance, fire a footstep
## and bob the camera. Reads `player_z`, not `velocity`, so it works whichever host moved the
## corridor (the testbed eases `velocity`; the fight approach writes `player_z` straight).
func _update_walk(delta: float) -> void:
  var section_length: float = piece_source.section_length if piece_source != null else 3.0
  var moved: float = absf(player_z - _last_player_z) * section_length
  _last_player_z = player_z
  # A jump this big is a host reseating the corridor, not a walk; it must not count as distance
  # or fire a footstep.
  if moved > MAX_FRAME_MOVE:
    return
  walk_distance += moved
  # A host moves the corridor from _physics_process while this runs in _process, so one frame may
  # see two physics ticks of movement and the next none; easing keeps the bob steady.
  var measured: float = moved / maxf(delta, 0.0001)
  var ease_rate: float = maxf(walk_speed, measured) / SPEED_EASE_TIME
  walk_speed = move_toward(walk_speed, measured, ease_rate * delta)
  var phase: float = walk_distance / maxf(stride_length, 0.01)
  if floori(phase) > _step_count and walk_speed >= MIN_WALK_SPEED:
    _step_count = floori(phase)
    footstep.emit(_step_count)
    if footsteps_on:
      SfxManager.play_footstep()
  if not bob_on:
    _camera.position = Vector3.ZERO
    return
  # Steps per second, capped at one, so the camera settles level as a walk stops.
  var weight: float = clampf(walk_speed / maxf(stride_length, 0.01), 0.0, 1.0)
  _camera.position.y = -bob_height * (0.5 + 0.5 * cos(TAU * phase)) * weight
  _camera.position.x = bob_sway * sin(PI * phase) * weight


## Put the walk back to nothing: for a host reseating the corridor (a new fight, a jump). The
## camera is levelled too, so the corridor opens standing still.
func reset_walk() -> void:
  walk_distance = 0.0
  walk_speed = 0.0
  _step_count = 0
  _last_player_z = player_z
  _camera.position = Vector3.ZERO


func set_forward_held(held: bool) -> void:
  forward_held = held


func set_back_held(held: bool) -> void:
  back_held = held


## Set corridor exports (`corridor_values`: property -> value) and properties of the camera's
## Environment (`environment_values`: property -> value), then rebuild. Names that do not exist are
## skipped. Used by the debug panel's Corridor tab and look presets.
func apply_settings(corridor_values: Dictionary, environment_values: Dictionary) -> void:
  for property: String in corridor_values:
    if property in self:
      set(property, corridor_values[property])
  for property: String in environment_values:
    if property in _camera.environment:
      _camera.environment.set(property, environment_values[property])
  for sprite: Sprite3D in _enemy_root.get_children():
    sprite.alpha_scissor_threshold = alpha_scissor_threshold
  _build()


## The camera's Environment (this corridor's own copy).
func environment() -> Environment:
  return _camera.environment


## Push the light exports to the light. Call after changing them at runtime.
func _apply_light() -> void:
  _light.omni_range = light_range
  _light.omni_attenuation = light_attenuation
  _light.light_energy = light_energy * flicker_level(_flicker_time)


## The flicker's brightness multiplier at `time` seconds: between 1 - `flicker_amount` and 1.
func flicker_level(time: float) -> float:
  if flicker_amount <= 0.0:
    return 1.0
  # Simplex noise mostly stays within about -0.6..0.6, so it is stretched to reach the full dip.
  var wave: float = clampf(_flicker_noise.get_noise_1d(time * flicker_speed) * 0.8 + 0.5, 0.0, 1.0)
  return 1.0 - flicker_amount * wave


## Show hit lights. Each entry of `lights` is [position: Vector3, colour: Color, strength from 0 to 1].
## The first `MAX_HIT_LIGHTS` entries are shown and the rest ignored. None show while `hit_lights_on`
## is off. Light nodes are made when first needed and hidden when unused.
func set_hit_lights(lights: Array) -> void:
  var count: int = mini(lights.size(), MAX_HIT_LIGHTS) if hit_lights_on else 0
  while _hit_light_root.get_child_count() < count:
    var new_light: OmniLight3D = OmniLight3D.new()
    new_light.light_specular = 0.0
    _hit_light_root.add_child(new_light)
  for i in _hit_light_root.get_child_count():
    var light: OmniLight3D = _hit_light_root.get_child(i) as OmniLight3D
    light.visible = i < count
    if i < count:
      var entry: Array = lights[i]
      light.position = entry[0]
      light.light_color = entry[1]
      light.light_energy = hit_light_energy * float(entry[2])
      light.omni_range = hit_light_range


func _layout() -> void:
  var length: float = piece_source.section_length
  var base_index: int = floori(player_z)
  var first: int = base_index - _sections_behind()
  var last: int = base_index + _sections_ahead()
  for index: int in _sections.keys():
    if index < first or index > last:
      (_sections[index] as Node3D).queue_free()
      _sections.erase(index)
  for index in range(first, last + 1):
    if not _sections.has(index):
      var section: Node3D = piece_source.build_section(index)
      _section_root.add_child(section)
      _sections[index] = section
    # Section `index` has its near edge (index - player_z) sections past depth 0.
    (_sections[index] as Node3D).position = Vector3(0.0, 0.0, -(depth_zero_distance() + (float(index) - player_z) * length))


## The camera's distance to depth 0: where the corridor's height exactly fills the view.
func depth_zero_distance() -> float:
  var height: float = piece_source.section_height if piece_source != null else 3.0
  return (height * 0.5) / tan(deg_to_rad(fov) * 0.5)


# --- Enemies ------------------------------------------------------------------

## Add a lit enemy sprite showing `texture` under the Enemies node. Size it with `size_enemy` and
## place it with `enemy_position`; free it with `remove_enemy`.
func add_enemy(texture: Texture2D) -> Sprite3D:
  var sprite: Sprite3D = Sprite3D.new()
  sprite.texture = texture
  sprite.shaded = true
  sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
  sprite.alpha_scissor_threshold = alpha_scissor_threshold
  sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  _enemy_root.add_child(sprite)
  return sprite


func remove_enemy(sprite: Sprite3D) -> void:
  if not is_instance_valid(sprite):
    return
  sprite.texture = null
  sprite.queue_free()


## Size `sprite` so that at depth 0 it is `height_pixels` tall on screen.
func size_enemy(sprite: Sprite3D, height_pixels: float) -> void:
  if sprite.texture == null or sprite.texture.get_height() <= 0:
    return
  sprite.pixel_size = pixels_to_metres(height_pixels) / float(sprite.texture.get_height())


## The 3D position of an enemy centred `depth_cells` sections past depth 0, `offset_pixels` to the
## right of the view's centre (measured at depth 0).
func enemy_position(depth_cells: float, offset_pixels: float) -> Vector3:
  var distance: float = depth_zero_distance() + depth_cells * piece_source.section_length
  return Vector3(pixels_to_metres(offset_pixels), 0.0, -distance)


## A screen distance at depth 0 in metres. The corridor's height fills the view's height there.
func pixels_to_metres(pixels: float) -> float:
  var height: float = piece_source.section_height if piece_source != null else 3.0
  return pixels / maxf(view_size.y, 1.0) * height


## Where the 3D `point` appears on screen, in this node's local coordinates (origin at the view's
## centre).
func unproject(point: Vector3) -> Vector2:
  return _camera.unproject_position(point) - Vector2(_viewport.size) * 0.5


# Sections behind depth 0 still in front of the camera (plus one so the nearest is never missing).
func _sections_behind() -> int:
  return ceili(depth_zero_distance() / piece_source.section_length) + 1


func _sections_ahead() -> int:
  return ceili(light_range / piece_source.section_length) + 1


func _clear_sections() -> void:
  for section: Node3D in _sections.values():
    if is_instance_valid(section):
      section.queue_free()
  _sections.clear()
