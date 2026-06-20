class_name ValuePill
extends PanelContainer
## A small value badge straddling the top of an ItemCell (docs/systems/run_screen.md): one per
## value-bearing effect, its background tinted by that effect's family colour. The static look
## (white, black-outlined text) lives in value_pill.tscn; setup() only sets the run-time DATA — the
## per-effect fill (a StyleBoxFlat, the only way to carry a dynamic colour) and the cell-size ratio
## that scales every metric so pills shrink on the smaller enemy HUD / ally cells.

const BASE_FONT_SIZE: int = 22
const BASE_BORDER: float = 2.0
const BASE_RADIUS: float = 4.0
const BASE_PAD_X: float = 7.0
const BASE_PAD_Y: float = 1.0
const BASE_OUTLINE: int = 4

@onready var _label: Label = $Value


## `ratio` scales every metric so pills shrink with the cell (enemy HUDs / ally slots).
func setup(text: String, color: Color, ratio: float = 1.0) -> void:
  _label.text = text
  _label.add_theme_font_size_override('font_size', int(round(BASE_FONT_SIZE * ratio)))
  _label.add_theme_constant_override('outline_size', int(round(BASE_OUTLINE * ratio)))
  var sb := StyleBoxFlat.new()
  sb.bg_color = color
  sb.border_color = Color.BLACK
  sb.set_border_width_all(int(round(BASE_BORDER * ratio)))
  sb.set_corner_radius_all(int(round(BASE_RADIUS * ratio)))
  sb.content_margin_left = BASE_PAD_X * ratio
  sb.content_margin_right = BASE_PAD_X * ratio
  sb.content_margin_top = BASE_PAD_Y * ratio
  sb.content_margin_bottom = BASE_PAD_Y * ratio
  add_theme_stylebox_override('panel', sb)
