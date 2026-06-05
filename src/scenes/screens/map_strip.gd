class_name MapStrip
extends Control
## The 1D progress map (ui_layout_prd): a horizontal line of the run's beats, each a
## dot coloured + labelled by type (Fight / Rest / Boss-finale), with the player's
## position marked. Simple + readable (the polished track is a later content pass).
## Reads the map + position it's handed; writes nothing.

const DOT_RADIUS := 16.0
const EDGE_MARGIN := 90.0

var _types: Array = []      # Array[int] — EncounterDef.Type per beat
var _final: int = -1
var _position: int = 0
var _font: Font


func _ready() -> void:
  _font = ThemeDB.fallback_font


func setup(map: Array, position: int) -> void:
  _types = []
  for id in map:
    _types.append(EncounterCatalog.get_def(id).type)
  _final = map.size() - 1
  _position = position
  queue_redraw()


func mark_position(position: int) -> void:
  _position = position
  queue_redraw()


func _draw() -> void:
  var n: int = _types.size()
  if n == 0:
    return
  var span: float = size.x - EDGE_MARGIN * 2.0
  var y: float = size.y * 0.42
  var spacing: float = span / maxf(float(n - 1), 1.0)
  draw_line(Vector2(EDGE_MARGIN, y), Vector2(EDGE_MARGIN + span, y), Color(0.45, 0.45, 0.5), 4.0)
  for i in n:
    var x: float = EDGE_MARGIN + float(i) * spacing
    if i == _position:
      draw_circle(Vector2(x, y), DOT_RADIUS + 7.0, Color(0.95, 0.92, 0.55))   # current-beat halo
    draw_circle(Vector2(x, y), DOT_RADIUS, _beat_color(i))
    draw_string(_font, Vector2(x - 70.0, y + 46.0), _beat_label(i),
      HORIZONTAL_ALIGNMENT_CENTER, 140.0, 24, Color(0.85, 0.85, 0.88))


func _is_boss(i: int) -> bool:
  return i == _final and _types[i] == EncounterDef.Type.FIGHT


func _beat_color(i: int) -> Color:
  if _is_boss(i):
    return Color(0.7, 0.4, 0.9)
  if _types[i] == EncounterDef.Type.REST:
    return Color(0.4, 0.75, 0.45)
  return Color(0.8, 0.35, 0.35)


func _beat_label(i: int) -> String:
  if _is_boss(i):
    return tr('Boss')
  if _types[i] == EncounterDef.Type.REST:
    return tr('Rest')
  return tr('Fight')
