class_name MapStrip
extends Control
## The 1D progress map (ui_layout_prd): the descent as a horizontal line of beats, the
## player's global position marked, the fixed beats flagged (an act boss at each act end,
## the guaranteed midpoint relic, the per-act rest), and the rest shown as generic beats
## (their type is a choice, not known ahead). Reads RunMap + the position it's handed;
## writes nothing. (The polished track + act dividers are a later content pass.)

const DOT_RADIUS := 12.0
const EDGE_MARGIN := 70.0
const WINDOW := 11    # beats visible at once — the track scrolls as you advance (compact top-right)
const LEAD := 2       # how many already-cleared beats stay visible behind the position marker

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
  # A sliding window of beats around the current position (the whole 45-beat track won't read
  # in the top-right corner). The marker stays LEAD beats from the left; the window clamps at
  # the ends so the first/last beats sit flush.
  var window: int = mini(WINDOW, _total)
  var start: int = clampi(_position - LEAD, 0, maxi(_total - window, 0))
  var span: float = size.x - EDGE_MARGIN * 2.0
  var y: float = size.y * 0.62
  var spacing: float = span / maxf(float(window - 1), 1.0)
  draw_line(Vector2(EDGE_MARGIN, y), Vector2(EDGE_MARGIN + span, y), Color(0.4, 0.4, 0.45), 4.0)
  for w in window:
    var i: int = start + w
    var p := Vector2(EDGE_MARGIN + float(w) * spacing, y)
    if i == _position:
      draw_circle(p, DOT_RADIUS + 8.0, Color(0.95, 0.92, 0.55))    # current-beat halo
      draw_circle(p, DOT_RADIUS, _beat_color(i))
    elif i < _position:
      draw_circle(p, DOT_RADIUS, Color(0.5, 0.46, 0.3))            # cleared = dim gold
    else:
      draw_arc(p, DOT_RADIUS, 0.0, TAU, 24, _beat_color(i), 3.0)   # upcoming = a type-coloured ring
  # The track scrolls beyond the window — hint with chevrons at the ends.
  if start > 0:
    draw_string(_font, Vector2(EDGE_MARGIN - 46.0, y + 9.0), '<', HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.55, 0.55, 0.6))
  if start + window < _total:
    draw_string(_font, Vector2(EDGE_MARGIN + span + 22.0, y + 9.0), '>', HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.55, 0.55, 0.6))
  # The current act, top-left of the strip.
  draw_string(_font, Vector2(EDGE_MARGIN - 12.0, y - 26.0), tr('Act {0}').format([RunMap.act_of(_position) + 1]),
    HORIZONTAL_ALIGNMENT_LEFT, 200.0, 22, Color(0.85, 0.85, 0.88))


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
