class_name BoardView
extends Node2D
## Placeholder per-actor view: a portrait block, an HP bar + text, and a row of
## ItemIcons. Opaque only. Reads the live Actor each frame; writes nothing.

const PORTRAIT := Vector2(220, 340)
const BAR := Vector2(220, 28)
const ICON_GAP := 144.0

var actor: Actor
var anchor: Vector2
var is_player: bool

var _hp_fill: ColorRect
var _hp_label: Label
var _icons: Dictionary = {}    # Item -> ItemIcon


func setup(target: Actor, at: Vector2, player_side: bool) -> void:
  actor = target
  anchor = at
  is_player = player_side
  _build()


func _build() -> void:
  var portrait := ColorRect.new()
  portrait.size = PORTRAIT
  portrait.position = anchor - PORTRAIT * 0.5
  portrait.color = Color(0.2, 0.3, 0.5) if is_player else Color(0.5, 0.2, 0.22)
  add_child(portrait)

  var bar_top: float = anchor.y + PORTRAIT.y * 0.5 + 14.0
  var bar_x: float = anchor.x - BAR.x * 0.5
  var hp_bg := ColorRect.new()
  hp_bg.size = BAR
  hp_bg.position = Vector2(bar_x, bar_top)
  hp_bg.color = Color(0.12, 0.12, 0.14)
  add_child(hp_bg)

  _hp_fill = ColorRect.new()
  _hp_fill.size = BAR
  _hp_fill.position = Vector2(bar_x, bar_top)
  _hp_fill.color = Color(0.4, 0.75, 0.35)
  add_child(_hp_fill)

  _hp_label = Label.new()
  _hp_label.size = BAR
  _hp_label.position = Vector2(bar_x, bar_top)
  _hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  add_child(_hp_label)

  var n: int = actor.board.size()
  var row_y: float = bar_top + BAR.y + 80.0
  var start_x: float = anchor.x - float(n - 1) * ICON_GAP * 0.5
  for i in n:
    var item: Item = actor.board[i]
    var icon := ItemIcon.new()
    icon.position = Vector2(start_x + float(i) * ICON_GAP, row_y)
    add_child(icon)
    icon.setup(item)
    _icons[item] = icon


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the Item->icon map + the live-actor ref on free.
  _icons.clear()
  actor = null


func _process(_delta: float) -> void:
  var ratio: float = clampf(actor.hp / actor.max_hp, 0.0, 1.0)
  _hp_fill.size.x = BAR.x * ratio
  _hp_label.text = '%d / %d' % [int(round(actor.hp)), int(round(actor.max_hp))]


func icon_center(item: Item) -> Vector2:
  if _icons.has(item):
    return (_icons[item] as ItemIcon).global_position
  return Vector2.INF   # sentinel: not on this board


func mouse_over(p: Vector2) -> bool:
  for icon in _icons.values():
    if (icon as ItemIcon).contains_point(p):
      return true
  return false
