extends GutTest
## The corridor walk: distance measured off `player_z`, the footfalls it produces and the camera
## bob that shares their phase (docs/systems/corridors/corridor_3d.md, "The walk").
##
## `_update_walk` is called directly with a fixed delta rather than waiting on real frames, so the
## pacing can be asserted exactly. The corridor's own `_process` is turned off in `_corridor()` so
## it cannot add movement of its own between calls.

const CORRIDOR_SCENE: PackedScene = preload('res://src/scenes/corridors/corridor_3d.tscn')
const SECTION_LENGTH: float = 3.0     # the scene's piece source; a metre of walking is this many sections
const DELTA: float = 1.0 / 60.0

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func _corridor(stride: float = 1.0) -> Corridor3D:
  var corridor: Corridor3D = CORRIDOR_SCENE.instantiate()
  corridor.input_enabled = false
  corridor.auto_view_size = false
  corridor.view_size = Vector2(1700.0, 1150.0)
  corridor.stride_length = stride
  add_child(corridor)
  corridor.set_process(false)   # only the explicit _update_walk calls below move the walk on
  _nodes.append(corridor)
  return corridor


# Walk `metres` in steady frames of `per_frame` metres each. A negative `per_frame` walks
# backwards. `metres` must divide by `per_frame` exactly, or the walk lands somewhere else.
func _walk(corridor: Corridor3D, metres: float, per_frame: float = 0.5) -> void:
  var frames: int = int(round(absf(metres) / absf(per_frame)))
  for i: int in frames:
    corridor.player_z += per_frame / SECTION_LENGTH
    corridor._update_walk(DELTA)


func test_a_walk_of_ten_strides_lands_ten_footsteps() -> void:
  var corridor: Corridor3D = _corridor(1.0)
  watch_signals(corridor)
  _walk(corridor, 10.0)
  assert_almost_eq(corridor.walk_distance, 10.0, 0.001, 'ten metres walked')
  assert_signal_emit_count(corridor, 'footstep', 10, 'one footstep per stride')


func test_a_shorter_stride_lands_more_footsteps_over_the_same_distance() -> void:
  var corridor: Corridor3D = _corridor(0.5)
  watch_signals(corridor)
  _walk(corridor, 10.0)
  assert_signal_emit_count(corridor, 'footstep', 20, 'half the stride is twice the footsteps')


func test_walking_backwards_still_lands_footsteps() -> void:
  var corridor: Corridor3D = _corridor(1.0)
  watch_signals(corridor)
  _walk(corridor, 4.0, -0.5)
  assert_almost_eq(corridor.walk_distance, 4.0, 0.001, 'distance counts both directions')
  assert_signal_emit_count(corridor, 'footstep', 4, 'backing up is still walking')


func test_a_host_reseating_the_corridor_is_not_a_walk() -> void:
  var corridor: Corridor3D = _corridor(1.0)
  watch_signals(corridor)
  corridor.player_z += 40.0            # far more than MAX_FRAME_MOVE in one frame
  corridor._update_walk(DELTA)
  assert_eq(corridor.walk_distance, 0.0, 'a jump adds no distance')
  assert_signal_emit_count(corridor, 'footstep', 0, 'a jump lands no footstep')


func test_the_camera_bobs_while_walking_and_levels_when_stopped() -> void:
  var corridor: Corridor3D = _corridor(1.0)
  var camera: Camera3D = corridor.get_node('SubViewport/Camera')
  _walk(corridor, 10.25, 0.25)               # a quarter stride past a footfall, where the bob is off its low point
  assert_ne(camera.position.y, 0.0, 'the camera is displaced while walking')
  for i: int in 60:
    corridor._update_walk(DELTA)       # standing still: player_z does not move
  assert_almost_eq(camera.position.y, 0.0, 0.0005, 'the camera settles level once stopped')
  assert_almost_eq(camera.position.x, 0.0, 0.0005, 'and stops leaning')


func test_the_camera_is_lowest_when_a_foot_lands() -> void:
  var corridor: Corridor3D = _corridor(1.0)
  var camera: Camera3D = corridor.get_node('SubViewport/Camera')
  _walk(corridor, 10.0)                # exactly on a footfall
  var at_footfall: float = camera.position.y
  _walk(corridor, 0.5)                 # half a stride later, mid-step
  assert_lt(at_footfall, camera.position.y, 'the camera is at its lowest as a foot lands')


func test_bob_off_keeps_the_camera_still() -> void:
  var corridor: Corridor3D = _corridor(1.0)
  corridor.bob_on = false
  var camera: Camera3D = corridor.get_node('SubViewport/Camera')
  _walk(corridor, 10.25, 0.25)
  assert_eq(camera.position, Vector3.ZERO, 'the camera does not move with the bob off')


func test_reset_walk_clears_the_walk_and_levels_the_camera() -> void:
  var corridor: Corridor3D = _corridor(1.0)
  var camera: Camera3D = corridor.get_node('SubViewport/Camera')
  _walk(corridor, 10.25, 0.25)
  corridor.reset_walk()
  assert_eq(corridor.walk_distance, 0.0, 'the distance is cleared')
  assert_eq(corridor.walk_speed, 0.0, 'the speed is cleared')
  assert_eq(camera.position, Vector3.ZERO, 'the camera is levelled')
  watch_signals(corridor)
  # Past the first stride rather than exactly on it: adding up a stride's worth of frames can land
  # a hair under the boundary, which only moves the footfall to the next frame.
  _walk(corridor, 1.5)
  assert_signal_emit_count(corridor, 'footstep', 1, 'the next stride is the first footstep again')
