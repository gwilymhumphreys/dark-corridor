class_name StatusIcon
extends ColorRect
## One active status in an enemy HUD's status row (docs/systems/run_screen.md): the status's icon
## on a square of its colour, so the colour shows as a border. Reads the status; writes nothing.

@onready var _icon: TextureRect = $Icon

var _icon_path: String = ''


## Show `status`. Loads the icon only when it differs from the one already shown, because the
## HUD calls this every frame.
func show_status(status: StatusEffect) -> void:
  color = status.color
  if status.icon == _icon_path:
    return
  _icon_path = status.icon
  _icon.texture = load(_icon_path) as Texture2D if _icon_path != '' else null


func _exit_tree() -> void:
  _icon.texture = null
