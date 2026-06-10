class_name ItemCell
extends Control
## One board item in the framed combat view (ui_layout_prd): an opaque effect-family
## colour panel + its value, a Bazaar-style radial cooldown ring, and a scale-punch
## recoil when it fires. Structure is authored in item_cell.tscn; this binds the data
## and draws the ring + recoil. Reads the live Item; writes nothing. No alpha.

const CELL_SIZE := Vector2(120, 120)   # the default (the player's prominent board); HUDs shrink it

var item: Item
var cell_size: Vector2 = CELL_SIZE

@onready var _panel: ColorRect = $Panel
@onready var _value: Label = $Value

var _last_progress: float = 1.0
var _scale_tween: Tween


func _ready() -> void:
  pivot_offset = cell_size * 0.5   # recoil / hover scale from the centre


## Shrink the cell (the enemy HUDs / ally slots use smaller cells than the player's board).
## Call after the cell is in the tree, before setup(). Scales the value font to match.
func set_cell_size(px: float) -> void:
  cell_size = Vector2(px, px)
  custom_minimum_size = cell_size
  size = cell_size
  pivot_offset = cell_size * 0.5
  _value.add_theme_font_size_override('font_size', int(round(44.0 * px / CELL_SIZE.x)))


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: stop the recoil tween + drop the live-item ref on free.
  if _scale_tween != null and _scale_tween.is_valid():
    _scale_tween.kill()
  _scale_tween = null
  item = null


## Bind to an item. Call after the cell is in the tree (so the node refs exist).
func setup(target_item: Item) -> void:
  item = target_item
  _panel.color = item.def.panel_color
  _value.text = _value_text()
  queue_redraw()


func _value_text() -> String:
  if item == null or item.def.effects.is_empty():
    return ''
  return str(int(item.def.effects[0].value))


func _process(_delta: float) -> void:
  if item == null:
    return
  var progress: float = item.cooldown.progress()
  if progress < _last_progress - 0.2:   # cooldown reset -> it just fired
    _recoil()
  _last_progress = progress
  queue_redraw()


func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO, cell_size), Color.BLACK, false, Consts.PANEL_BORDER_WIDTH)
  if item == null:
    return
  var progress: float = item.cooldown.progress()
  if progress < 1.0:
    var centre: Vector2 = cell_size * 0.5
    draw_arc(centre, cell_size.x * 0.5 + 8.0, -PI * 0.5, -PI * 0.5 + progress * TAU, Consts.COOLDOWN_RING_SEGMENTS, Colours.COOLDOWN_RING, Consts.COOLDOWN_RING_WIDTH)


func _recoil() -> void:
  if _scale_tween != null and _scale_tween.is_valid():
    _scale_tween.kill()
  scale = Vector2(1.3, 1.3)
  _scale_tween = create_tween()
  _scale_tween.tween_property(self, 'scale', Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Centre of the cell in global (screen) space — the VFX wall reads it.
func cell_centre() -> Vector2:
  return global_position + cell_size * 0.5 * scale
