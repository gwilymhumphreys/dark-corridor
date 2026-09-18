class_name InterfaceGlowAutoload
extends Node
## Interface glow (docs/systems/interface_glow.md): any interface node glows while its `self_modulate`
## is brighter than white, for example `Color(3, 3, 3)`. 2D HDR is on (`rendering/viewport/hdr_2d`), so
## colours can go above white, and this autoload adds a screen glow that only picks up pixels brighter
## than white. Text and nodes at normal brightness do not glow. Registered as the `InterfaceGlow` autoload.
##
## The screen glow is only switched on while a node set through this autoload is glowing, because the
## glow pass darkens the whole screen slightly even when nothing is brighter than white.

## Environment glow properties (property -> default). The threshold keeps normal white from glowing.
const DEFAULTS: Dictionary = {
  'glow_intensity': 1.0,
  'glow_strength': 1.0,
  'glow_hdr_threshold': 1.0,
  'glow_blend_mode': Environment.GLOW_BLEND_MODE_ADDITIVE,
}
## Canvas layers up to this one glow; the debug panels' layer is above it.
const MAX_GLOW_LAYER: int = 126

## Glow properties changed from `DEFAULTS` (property -> value), from the Interface tab and presets.
var settings: Dictionary = {}

var _environment: Environment = Environment.new()
var _world_environment: WorldEnvironment = WorldEnvironment.new()
var _tweens: Dictionary = {}   # CanvasItem instance id -> the Tween flashing it
var _glowing: Dictionary = {}   # CanvasItem instance id -> the item, for every item glowing now
var _demo_brightness: float = 0.0   # from `--glow-demo=`; 0 when off


func _ready() -> void:
  _environment.background_mode = Environment.BG_CANVAS
  _environment.background_canvas_max_layer = MAX_GLOW_LAYER
  _environment.glow_enabled = false
  _environment.glow_bloom = 0.0
  apply_settings()
  _world_environment.environment = _environment
  add_child(_world_environment)
  for arg: String in OS.get_cmdline_user_args():
    if arg.begins_with('--glow-demo='):
      _demo_brightness = arg.substr(12).to_float()


# `--glow-demo=<brightness>` (dev, for screenshots): every node drawn through the interface look material
# glows, including nodes built later.
func _process(_delta: float) -> void:
  # A node freed mid-flash takes its tween with it, so `_on_flash_finished` never runs; drop it here.
  if _environment.glow_enabled:
    _update_enabled()
  if _demo_brightness <= 0.0 or Engine.get_process_frames() % 30 != 0:
    return
  for node: Node in get_tree().root.find_children('*', 'CanvasItem', true, false):
    var item: CanvasItem = node as CanvasItem
    if item.material == InterfaceLook.material and not _glowing.has(item.get_instance_id()):
      set_glow(item, _demo_brightness)


func _exit_tree() -> void:
  for tween: Tween in _tweens.values():
    if tween.is_valid():
      tween.kill()
  _tweens.clear()
  _glowing.clear()


## Make `item` glow at `brightness` (1.0 is no glow) until changed again.
func set_glow(item: CanvasItem, brightness: float) -> void:
  _stop_flash(item)
  item.self_modulate = Color(brightness, brightness, brightness, item.self_modulate.a)
  if brightness > 1.0:
    _glowing[item.get_instance_id()] = item
  else:
    _glowing.erase(item.get_instance_id())
  _update_enabled()


## Brighten `item` to `brightness` and back to normal over `duration` seconds. A new flash on the same
## item replaces the one running.
func flash(item: CanvasItem, brightness: float, duration: float) -> void:
  _stop_flash(item)
  var alpha: float = item.self_modulate.a
  var tween: Tween = item.create_tween()
  tween.tween_property(item, 'self_modulate', Color(brightness, brightness, brightness, alpha), duration * 0.25)
  tween.tween_property(item, 'self_modulate', Color(1.0, 1.0, 1.0, alpha), duration * 0.75)
  tween.finished.connect(_on_flash_finished.bind(item.get_instance_id()))
  _tweens[item.get_instance_id()] = tween
  _glowing[item.get_instance_id()] = item
  _update_enabled()


## Whether the screen glow is on: while at least one item is glowing.
func is_enabled() -> bool:
  return _environment.glow_enabled


## A glow property's current value: changed in `settings`, otherwise its default.
func setting(property: String) -> Variant:
  return settings.get(property, DEFAULTS[property])


## Apply `settings` over `DEFAULTS` to the screen glow.
func apply_settings() -> void:
  for property: String in DEFAULTS:
    _environment.set(property, setting(property))


## Back to the default glow settings, with nothing glowing.
func reset() -> void:
  for tween: Tween in _tweens.values():
    if tween.is_valid():
      tween.kill()
  _tweens.clear()
  for item: Variant in _glowing.values():
    if is_instance_valid(item):
      (item as CanvasItem).self_modulate = Color(1.0, 1.0, 1.0, (item as CanvasItem).self_modulate.a)
  _glowing.clear()
  settings.clear()
  apply_settings()
  _update_enabled()


# Freed items stop counting as glowing.
func _update_enabled() -> void:
  for id: int in _glowing.keys():
    if not is_instance_valid(_glowing[id]):
      _glowing.erase(id)
  _environment.glow_enabled = not _glowing.is_empty()


func _on_flash_finished(id: int) -> void:
  _tweens.erase(id)
  _glowing.erase(id)
  _update_enabled()


func _stop_flash(item: CanvasItem) -> void:
  var tween: Tween = _tweens.get(item.get_instance_id())
  if tween != null and tween.is_valid():
    tween.kill()
  _tweens.erase(item.get_instance_id())
  _glowing.erase(item.get_instance_id())
