extends Control
## Dev scene for judging the attack hit effects (`AttackHitDrawer`, docs/systems/vfx_driver.md)
## without waiting for the right item to fire in a fight. The top half repeats a dagger's slash and a
## warhammer's impact over an enemy image, each hit a new delivery so the angle and mirroring change.
## The bottom half is a strip of frames through each effect, for screenshots. Run it directly:
##   <godot> --path . res://src/debug/scenes/hit_effects_preview.tscn
## The hits travel leftwards and a little up, as they do from the board to an enemy in a fight.

const REPEAT: float = 0.7                 # seconds between hits in the live half
const STRIP_FRAMES: int = 8
const HIT_DIRECTION: Vector2 = Vector2(-1.0, -0.25)
const LIVE_POINTS: Array[Vector2] = [Vector2(700.0, 420.0), Vector2(1860.0, 420.0)]
const STRIP_TOP: float = 900.0
const STRIP_ROW: float = 260.0
const STRIP_LEFT: float = 260.0
const STRIP_STEP: float = 290.0

var _drawer: AttackHitDrawer = AttackHitDrawer.new()
var _items: Array[Item] = []              # the dagger, then the warhammer
var _live: Array[Delivery] = []           # the current live hit for each item
var _strip: Array[Delivery] = []          # one fixed hit per item for the strip of frames
var _time: float = 0.0
var _enemy: Texture2D


func _ready() -> void:
  var actor: Actor = Actor.new(100.0)
  for id: String in ['dagger', 'warhammer']:
    _items.append(Item.new(ItemCatalog.get_def(id), actor))
  for item: Item in _items:
    _live.append(_make_hit(item))
    _strip.append(_make_hit(item))
  _enemy = MonsterImages.random_texture()


func _exit_tree() -> void:
  _enemy = null


func _process(delta: float) -> void:
  var before: int = int(_time / REPEAT)
  _time += delta
  if int(_time / REPEAT) != before:
    for i in _items.size():
      _live[i] = _make_hit(_items[i])
  queue_redraw()


func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.13, 0.15))
  var age: float = fmod(_time, REPEAT)
  for i in _items.size():
    var point: Vector2 = LIVE_POINTS[i]
    if _enemy != null:
      var height: float = 560.0
      var width: float = height * float(_enemy.get_width()) / float(_enemy.get_height())
      draw_texture_rect(_enemy, Rect2(point - Vector2(width, height) * 0.5, Vector2(width, height)), false, Color(0.45, 0.45, 0.5))
    _drawer.draw_hit(self, _live[i], point, HIT_DIRECTION, age)
  var font: Font = ThemeDB.fallback_font
  for i in _items.size():
    var y: float = STRIP_TOP + STRIP_ROW * float(i)
    draw_string(font, Vector2(24.0, y + 8.0), _items[i].def.id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28)
    var length: float = AttackHitDrawer.SLASH_DURATION if AttackHitDrawer.is_blade(_strip[i]) else AttackHitDrawer.IMPACT_DURATION
    for frame in STRIP_FRAMES:
      var frame_age: float = length * float(frame) / float(STRIP_FRAMES)
      var point: Vector2 = Vector2(STRIP_LEFT + STRIP_STEP * float(frame), y)
      _drawer.draw_hit(self, _strip[i], point, HIT_DIRECTION, frame_age)
      draw_string(font, point + Vector2(-40.0, 125.0), '%.2fs' % frame_age, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22)


func _make_hit(item: Item) -> Delivery:
  var hit: Delivery = Delivery.new()
  hit.mechanic = AttackMechanic.ID
  hit.source = item
  hit.color = MechanicRegistry.get_mechanic(AttackMechanic.ID).color()
  return hit
