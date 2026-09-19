class_name PortraitBreath
extends Node

## Drop-in slow zoom for a portrait image.
##
## Add this as a child of the portrait's TextureRect and the picture scales gently
## up and down forever, like slow breathing. The parent's frame should have
## `clip_contents` on so the picture never spills past it.
##
## The scale runs on the Godot 4.7 visual-only `offset_transform_scale`, so it
## never fights the container that lays the portrait out. Each node picks a random
## starting point in the cycle, so several portraits on screen do not breathe in
## unison.

## How much larger the picture gets at the top of the breath. 0.02 is a 2% zoom.
@export_range(0.0, 0.2, 0.001) var amount: float = 0.02
## Seconds for one full breath, in and back out again.
@export_range(0.5, 30.0, 0.1) var period: float = 6.0

var _target: Control
var _phase: float = 0.0


func _ready() -> void:
  var parent: Node = get_parent()
  if not (parent is Control):
    push_warning('PortraitBreath: parent is not a Control; breathing disabled. Parent=%s' % str(parent))
    set_process(false)
    return
  _target = parent as Control
  _target.offset_transform_enabled = true
  _phase = randf() * TAU


func _process(delta: float) -> void:
  if not is_instance_valid(_target):
    return
  _phase = fposmod(_phase + TAU * delta / maxf(period, 0.001), TAU)
  # cos runs from 1 to -1 and back, so this rises from the resting size to
  # `amount` above it and returns, with no jump at the ends of the cycle.
  var factor: float = 1.0 + amount * 0.5 * (1.0 - cos(_phase))
  _target.offset_transform_scale = Vector2.ONE * factor


func _exit_tree() -> void:
  if is_instance_valid(_target):
    _target.offset_transform_scale = Vector2.ONE
