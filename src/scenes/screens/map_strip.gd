class_name MapStrip
extends Control
## The 1D progress map (ui_layout_prd): the descent as a horizontal line of beats, the
## player's global position marked, the fixed beats flagged (an act boss at each act end,
## the guaranteed midpoint relic, the per-act rest), and the rest shown as generic beats
## (their type is a choice, not known ahead). Reads RunMap + the position it's handed;
## writes nothing. (The polished track + act dividers are a later content pass.)

const DOT_RADIUS := 10.0
const EDGE_MARGIN := 90.0

var _total: int = 0
var _position: int = 0
var _font: Font


func _ready() -> void:
  _font = ThemeDB.fallback_font


func setup(total_beats: int, position: int) -> void:
  _total = total_beats
  _position = position
  queue_redraw()


func mark_position(position: int) -> void:
  _position = position
  queue_redraw()


func _draw() -> void:
  if _total <= 0:
    return
  var span: float = size.x - EDGE_MARGIN * 2.0
  var y: float = size.y * 0.45
  var spacing: float = span / maxf(float(_total - 1), 1.0)
  draw_line(Vector2(EDGE_MARGIN, y), Vector2(EDGE_MARGIN + span, y), Color(0.45, 0.45, 0.5), 4.0)
  for i in _total:
    var x: float = EDGE_MARGIN + float(i) * spacing
    if i == _position:
      draw_circle(Vector2(x, y), DOT_RADIUS + 7.0, Color(0.95, 0.92, 0.55))   # current-beat halo
    draw_circle(Vector2(x, y), DOT_RADIUS, _beat_color(i))
  # An act label under each act's first beat.
  for a in RunMap.ACTS:
    var x: float = EDGE_MARGIN + float(a * RunMap.BEATS_PER_ACT) * spacing
    draw_string(_font, Vector2(x - 60.0, y + 44.0), tr('Act {0}').format([a + 1]),
      HORIZONTAL_ALIGNMENT_LEFT, 160.0, 24, Color(0.85, 0.85, 0.88))


func _beat_color(i: int) -> Color:
  var spec: Dictionary = RunMap.beat_spec(i)
  if spec['kind'] == RunMap.BeatKind.FIXED:
    match spec['id']:
      EncounterCatalog.FIGHT_BOSS:
        return Color(0.7, 0.4, 0.9)     # boss
      EncounterCatalog.REST:
        return Color(0.4, 0.75, 0.45)   # rest
      EncounterCatalog.FIGHT_RELIC:
        return Color(0.85, 0.7, 0.3)    # guaranteed relic
  return Color(0.65, 0.4, 0.4)          # a choice beat
