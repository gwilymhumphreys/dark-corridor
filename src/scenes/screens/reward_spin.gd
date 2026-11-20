class_name RewardSpin
extends Node
## The slot-machine reveal of offered goods (docs/systems/run_screen.md → Overlays). Each
## `RewardOption` in a row flicks through item icons, slows down and lands on its real good with a
## small bump, one at a time from left to right. The draft panel and the shop panel each hold one.
## While any option is still spinning, `is_spinning()` is true and the panel ignores picks; a mouse
## click or a key press lands every option at once. The timings are print settings on the F7 tab
## (`reward_spin_*` in `PrintLook.PRINT_SETTING_DEFAULTS`); with `reward_spin` off, `start` does
## nothing and the goods show at once. Presentation only: it draws no run random numbers. Reads the
## options; writes nothing.

## Emitted once every option has landed, by time or by a skip.
signal landed()

## How many times longer an icon stays up just before an option lands than at full speed.
const SLOWDOWN: float = 5.0
## The seconds the landing bump takes to grow and settle again.
const BUMP_TIME: float = 0.18

## The panel the options are on. A click on it during the spin only lands the options, so it does
## not also press a button.
@export var panel: Control

var _options: Array[RewardOption] = []
var _faces: Array[Texture2D] = []
var _land_at: Array[float] = []        # seconds into the spin at which each option lands
var _next_face_at: Array[float] = []   # seconds into the spin at which each option shows its next icon
var _last_face: Array[int] = []        # the index in _faces each option shows, so the next one differs
var _elapsed: float = 0.0
var _spin_time: float = 0.0
var _face_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
  _rng.randomize()
  set_process(false)


func _exit_tree() -> void:
  _clear()


## Spin `options`, left to right as given. `faces` are the icons to flick through; empty uses every
## item icon in the item catalog, and failing that the options' own icons. Does nothing when the
## `reward_spin` print setting is off.
func start(options: Array[RewardOption], faces: Array[Texture2D] = []) -> void:
  _clear()
  if not PrintLook.print_setting('reward_spin') or options.is_empty():
    return
  _faces = faces.duplicate()
  if _faces.is_empty():
    _faces = catalog_faces()
  if _faces.is_empty():
    for option: RewardOption in options:
      if option.item() != null and option.item().def.icon != '':
        _faces.append(load(option.item().def.icon) as Texture2D)
  if _faces.is_empty():
    return
  _spin_time = PrintLook.print_setting('reward_spin_time')
  _face_time = maxf(PrintLook.print_setting('reward_spin_face_time'), 0.01)
  var gap: float = PrintLook.print_setting('reward_spin_gap')
  for k in options.size():
    _options.append(options[k])
    _land_at.append(_spin_time + gap * k)
    _next_face_at.append(0.0)
    _last_face.append(-1)
    options[k].start_spin()
  _elapsed = 0.0
  set_process(true)
  advance(0.0)   # every option shows its first icon at once


## True while any option has not landed yet; picks are ignored meanwhile.
func is_spinning() -> bool:
  return not _options.is_empty()


## Land every option at once, as a click or key press during the spin does.
func skip() -> void:
  if not is_spinning():
    return
  for option: RewardOption in _options:
    option.land(PrintLook.print_setting('reward_spin_bump'), BUMP_TIME)
  _finish()


## Move the spin on by `seconds`: show the next icon on each option that is due one and land each
## option whose time has come. The icons change more slowly over the last `reward_spin_time` seconds
## before an option lands.
func advance(seconds: float) -> void:
  if not is_spinning():
    return
  _elapsed += seconds
  var all_landed: bool = true
  for k in _options.size():
    var option: RewardOption = _options[k]
    if not option.is_spinning():
      continue
    if _elapsed >= _land_at[k]:
      option.land(PrintLook.print_setting('reward_spin_bump'), BUMP_TIME)
      continue
    all_landed = false
    if _elapsed < _next_face_at[k]:
      continue
    _last_face[k] = _pick_face(_last_face[k])
    option.show_face(_faces[_last_face[k]])
    var slow: float = 1.0
    if _spin_time > 0.0:
      slow = clampf(1.0 - (_land_at[k] - _elapsed) / _spin_time, 0.0, 1.0)
    _next_face_at[k] = _elapsed + _face_time * lerpf(1.0, SLOWDOWN, slow * slow)
  if all_landed:
    _finish()


## Every item icon in the item catalog, to flick through.
static func catalog_faces() -> Array[Texture2D]:
  var faces: Array[Texture2D] = []
  for id: String in ItemCatalog.all_ids():
    var def: ItemDef = ItemCatalog.get_def(id)
    if def != null and def.icon != '':
      var texture: Texture2D = load(def.icon) as Texture2D
      if texture != null:
        faces.append(texture)
  return faces


func _process(delta: float) -> void:
  advance(delta)


# A mouse click or key press during the spin lands every option. A click on the panel is used up, so
# the button under it is not pressed as well; a key press goes on to whatever else wants it.
func _input(event: InputEvent) -> void:
  if not is_spinning():
    return
  var mouse: InputEventMouseButton = event as InputEventMouseButton
  if mouse != null:
    if not mouse.pressed or mouse.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
      return
    var on_panel: bool = panel != null and panel.get_global_rect().has_point(panel.get_global_mouse_position())
    skip()
    if on_panel and is_inside_tree():
      get_viewport().set_input_as_handled()
    return
  var key: InputEventKey = event as InputEventKey
  if key != null and key.pressed and not key.echo:
    skip()


# A face index other than `last`, unless there is only one face.
func _pick_face(last: int) -> int:
  if last < 0 or _faces.size() == 1:
    return _rng.randi_range(0, _faces.size() - 1)
  var index: int = _rng.randi_range(0, _faces.size() - 2)
  return index + 1 if index >= last else index


func _finish() -> void:
  _clear()
  landed.emit()


func _clear() -> void:
  _options.clear()
  _faces.clear()
  _land_at.clear()
  _next_face_at.clear()
  _last_face.clear()
  set_process(false)
