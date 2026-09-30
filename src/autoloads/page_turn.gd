class_name PageTurnAutoload
extends CanvasLayer
## The page turn between screens (docs/systems/page_turn.md): one side of the screen turns over on the
## fold like a book page and lands on the other side, uncovering the next screen. Forward (into a run)
## turns the right side over onto the left; back (to the title screen) turns the left side over onto
## the right. Registered as the `PageTurn` autoload (`src/scenes/ui/page_turn.tscn`).
##
## `capture()` takes a still image of the screen being left. The caller then swaps the screens and
## calls `play()`. The page shows the still image flat at once, so the swap is never seen, waits until
## the new screen is drawing at an even rate, holds for a moment and turns. The front of the page is the
## still image; its back and everything it uncovers are the new screen, drawn live by
## `page_turn.gdshader`. The settings are the `page_turn_*` print settings, read when a turn starts.

signal finished

const SHADER: Shader = preload('res://src/shaders/page_turn.gdshader')
## Pieces the page is made of, seen from the side. Must match SEGMENTS in page_turn.gdshader.
const SEGMENTS: int = 64
## The sound folder played as the page lifts.
const SOUND: String = 'ui/page_turn'
## The new screen counts as drawing evenly after this many frames in a row no longer than
## STEADY_FRAME_TIME, so shaders compiling on its first frames do not stutter the turn.
const STEADY_FRAMES: int = 3
const STEADY_FRAME_TIME: float = 1.0 / 40.0
## The longest wait for the new screen to draw evenly before turning anyway, in seconds.
const MAX_WAIT: float = 1.0
## The page counts as fully lifted, for the shadow and the edge line, once its highest point is this
## fraction of its width above the screen.
const FULL_LIFT: float = 0.08

enum Direction { FORWARD = 1, BACK = -1 }
enum Stage { IDLE, WAITING, HOLDING, TURNING }

## Stop every turn at this progress (0 to 1) and stay there, for screenshots (`--page-turn-at`).
## Below 0 turns normally.
var held_progress: float = -1.0

var _stage: Stage = Stage.IDLE
var _snapshot: ImageTexture = null
var _direction: Direction = Direction.FORWARD
var _elapsed: float = 0.0
var _steady_frames: int = 0
var _material: ShaderMaterial = ShaderMaterial.new()

@onready var _page: ColorRect = $Page
@onready var _blocker: Control = $Blocker


func _ready() -> void:
  _material.shader = SHADER
  _page.material = _material
  _page.hide()
  _blocker.hide()
  set_process(false)


func _exit_tree() -> void:
  _page.material = null
  _snapshot = null


## Whether turns can play: not in a run with no screen, such as the headless tests and autotest.
func can_turn() -> bool:
  return DisplayServer.get_name() != 'headless'


## Whether a still image is waiting for `play()`.
func has_capture() -> bool:
  return _snapshot != null


## Take a still image of the screen as it is now, without the cursor or the debug panels, for the next
## `play()`. Takes one frame, during which clicks are blocked. Does nothing where turns cannot play.
func capture() -> void:
  if not can_turn():
    return
  _finish()
  _blocker.show()
  var cursor_shown: bool = Cursor.visible
  var panels: CanvasLayer = DebugPanels.get_node('PanelLayer')
  var panels_shown: bool = panels.visible
  Cursor.visible = false
  panels.visible = false
  await RenderingServer.frame_post_draw
  var image: Image = get_viewport().get_texture().get_image()
  Cursor.visible = cursor_shown
  panels.visible = panels_shown
  _snapshot = ImageTexture.create_from_image(image)


## Turn the page over from the image `capture()` took onto the screen now drawn under it. Does nothing
## without a captured image.
func play(direction: Direction) -> void:
  if _snapshot == null:
    _blocker.hide()
    return
  _direction = direction
  _stage = Stage.WAITING
  _elapsed = 0.0
  _steady_frames = 0
  _material.set_shader_parameter('snapshot', _snapshot)
  _read_settings()
  _show_progress(0.0)
  _page.show()
  _blocker.show()
  set_process(true)


## Capture the screen and turn it over onto itself, to try the settings (the Tokens tab's Replay).
func replay() -> void:
  await capture()
  play(Direction.FORWARD)


func _process(delta: float) -> void:
  _elapsed += delta
  match _stage:
    Stage.WAITING:
      _steady_frames = _steady_frames + 1 if delta <= STEADY_FRAME_TIME else 0
      if _steady_frames >= STEADY_FRAMES or _elapsed >= MAX_WAIT:
        _stage = Stage.HOLDING
        _elapsed = 0.0
    Stage.HOLDING:
      if _elapsed >= PrintLook.print_setting('page_turn_hold'):
        _stage = Stage.TURNING
        _elapsed = 0.0
        SfxManager.play_sound(SOUND)
    Stage.TURNING:
      var progress: float = clampf(_elapsed / maxf(PrintLook.print_setting('page_turn_duration'), 0.05), 0.0, 1.0)
      if held_progress >= 0.0:
        progress = minf(progress, held_progress)
      _show_progress(progress)
      if progress >= 1.0:
        _finish()


func _finish() -> void:
  var was_turning: bool = _stage != Stage.IDLE
  _stage = Stage.IDLE
  set_process(false)
  _page.hide()
  _blocker.hide()
  _snapshot = null
  _material.set_shader_parameter('snapshot', null)
  if was_turning:
    finished.emit()


func _read_settings() -> void:
  _material.set_shader_parameter('direction', float(_direction))
  _material.set_shader_parameter('shading', PrintLook.print_setting('page_turn_shading'))
  _material.set_shader_parameter('highlight', PrintLook.print_setting('page_turn_highlight'))
  _material.set_shader_parameter('show_through', PrintLook.print_setting('page_turn_show_through'))
  _material.set_shader_parameter('shadow_darkness', PrintLook.print_setting('page_turn_shadow_darkness'))
  _material.set_shader_parameter('shadow_softness', PrintLook.print_setting('page_turn_shadow_softness'))
  _material.set_shader_parameter('camera_offset', PrintLook.print_setting('page_turn_camera_offset'))
  _material.set_shader_parameter('light_direction', Vector3(
      PrintLook.print_setting('page_turn_light_across'), PrintLook.print_setting('page_turn_light_down'), 1.0))
  _material.set_shader_parameter('edge_colour', Colours.UI_BACKGROUND_WEAR_LIGHT)


# Everything the shader needs for the page at `progress`, in window pixels.
func _show_progress(progress: float) -> void:
  var window: Vector2 = Vector2(get_viewport().get_texture().get_size())
  var hinge: float = ScreenSections.fold_point_on_screen(get_viewport()).x
  if hinge <= 0.0:
    hinge = window.x * 0.5
  var length: float = window.x - hinge if _direction == Direction.FORWARD else hinge
  var landing_side: float = hinge if _direction == Direction.FORWARD else window.x - hinge
  var points: PackedVector2Array = page_curve(progress, length)
  var highest: float = 0.0
  for point: Vector2 in points:
    highest = maxf(highest, point.y)
  var distance: float = maxf(float(PrintLook.print_setting('page_turn_camera_distance')) * window.y, length * 1.3)
  _material.set_shader_parameter('curve', points)
  _material.set_shader_parameter('hinge', hinge)
  _material.set_shader_parameter('page_length', length)
  _material.set_shader_parameter('camera_distance', distance)
  _material.set_shader_parameter('edge_width', float(PrintLook.print_setting('page_turn_edge_width')) * get_viewport().get_final_transform().get_scale().y)
  _material.set_shader_parameter('lift', clampf(highest / maxf(length * FULL_LIFT, 1.0), 0.0, 1.0))
  _material.set_shader_parameter('uncovered_fade', smoothstep(0.7, 1.0, progress) if landing_side > length else 0.0)


## The page seen from the side at `progress` (0 flat where it starts, 1 flat on the other side), as
## SEGMENTS + 1 points from the hinge to the free edge, for a page `length` long: x along the screen
## away from the side it lands on, y its height. Built from each piece's angle, so the page keeps its
## length however it bends. The free edge leads the hinge in the first half of the turn, as when a hand
## lifts the edge, and trails it in the second, as air holds it back; the bend setting decides how
## that difference spreads along the page.
func page_curve(progress: float, length: float) -> PackedVector2Array:
  var eased: float = _ease(progress, PrintLook.print_setting('page_turn_easing'))
  var hinge_angle: float = PI * eased
  var lead: float = float(PrintLook.print_setting('page_turn_lead')) * sin(TAU * eased)
  var bend: float = maxf(PrintLook.print_setting('page_turn_bend'), 0.1)
  var piece: float = length / float(SEGMENTS)
  var point: Vector2 = Vector2.ZERO
  var points: PackedVector2Array = [point]
  for i: int in SEGMENTS:
    var along: float = (float(i) + 0.5) / float(SEGMENTS)
    var angle: float = clampf(hinge_angle + lead * pow(along, bend), 0.0, PI)
    point += Vector2(cos(angle), sin(angle)) * piece
    points.append(point)
  return points


# Slow at both ends: `power` 1 is even speed, higher is slower at the ends and faster in the middle.
static func _ease(progress: float, power: float) -> float:
  var rising: float = pow(progress, power)
  return rising / (rising + pow(1.0 - progress, power))
