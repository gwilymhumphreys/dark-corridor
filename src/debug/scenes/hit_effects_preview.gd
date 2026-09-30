extends Control
## Dev scene for judging the hit effects (`AttackHitDrawer`, `PoisonDrawer`, `BurnDrawer`,
## `BleedDrawer`, docs/systems/vfx_driver.md) without waiting for the right item to fire in a fight.
## It has one page per mechanic: attack (a dagger's slash and a warhammer's impact), then poison,
## burn and bleed (each applied, then dealing damage). The top half repeats the page's two effects over an enemy image, each hit a
## new delivery so the angles and paths change. The bottom half is a strip of frames through each
## effect, for screenshots. Space or Tab turns the page. Run it directly:
##   <godot> --path . res://src/debug/scenes/hit_effects_preview.tscn -- --page=poison
## `--page` is attack (the default), poison, burn or bleed. The hits travel leftwards and a little up, as
## they do from the board to an enemy in a fight.

const PAGES: Array[String] = ['attack', 'poison', 'burn', 'bleed']
const STRIP_FRAMES: int = 8
const HIT_DIRECTION: Vector2 = Vector2(-1.0, -0.25)
const LIVE_POINTS: Array[Vector2] = [Vector2(700.0, 420.0), Vector2(1860.0, 420.0)]
const STRIP_TOP: float = 900.0
const STRIP_ROW: float = 260.0
const STRIP_LEFT: float = 260.0
const STRIP_STEP: float = 290.0

var _attack_drawer: AttackHitDrawer = AttackHitDrawer.new()
var _poison_drawer: PoisonDrawer = PoisonDrawer.new()
var _burn_drawer: BurnDrawer = BurnDrawer.new()
var _bleed_drawer: BleedDrawer = BleedDrawer.new()
var _attack_items: Array[Item] = []      # the dagger, then the warhammer
var _page: int = 0
var _labels: Array[String] = []           # one per effect on the page
var _live: Array[Delivery] = []           # the current live hit for each effect
var _strip: Array[Delivery] = []          # one fixed hit per effect for the strip of frames
var _time: float = 0.0
var _enemy: Texture2D


func _ready() -> void:
  _page = maxi(PAGES.find(DevArgs.value('--page')), 0)
  var actor: Actor = Actor.new(100.0)
  for id: String in ['dagger', 'warhammer']:
    _attack_items.append(Item.new(ItemCatalog.get_def(id), actor))
  _enemy = MonsterImages.random_texture()
  _build_page()


func _exit_tree() -> void:
  _enemy = null


func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed('ui_accept') or event.is_action_pressed('ui_focus_next'):
    _page = (_page + 1) % PAGES.size()
    _build_page()


func _process(delta: float) -> void:
  var repeat: float = _length() + 0.2
  var before: int = int(_time / repeat)
  _time += delta
  if int(_time / repeat) != before:
    for i in _live.size():
      _live[i] = _make_hit(i)
  queue_redraw()


func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.13, 0.15))
  var font: Font = ThemeDB.fallback_font
  draw_string(font, Vector2(24.0, 48.0), '%s  (space: next page)' % PAGES[_page], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32)
  var age: float = fmod(_time, _length() + 0.2)
  for i in _live.size():
    var point: Vector2 = LIVE_POINTS[i]
    if _enemy != null:
      var height: float = 560.0
      var width: float = height * float(_enemy.get_width()) / float(_enemy.get_height())
      draw_texture_rect(_enemy, Rect2(point - Vector2(width, height) * 0.5, Vector2(width, height)), false, Color(0.45, 0.45, 0.5))
    _draw_hit(_live[i], point, age)
    draw_string(font, point + Vector2(-80.0, 320.0), _labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28)
  for i in _strip.size():
    var y: float = STRIP_TOP + STRIP_ROW * float(i)
    draw_string(font, Vector2(24.0, y + 8.0), _labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24)
    var length: float = _effect_length(_strip[i])
    for frame in STRIP_FRAMES:
      var frame_age: float = length * float(frame) / float(STRIP_FRAMES)
      var point: Vector2 = Vector2(STRIP_LEFT + STRIP_STEP * float(frame), y)
      _draw_hit(_strip[i], point, frame_age)
      draw_string(font, point + Vector2(-40.0, 125.0), '%.2fs' % frame_age, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22)


func _build_page() -> void:
  _labels.clear()
  _live.clear()
  _strip.clear()
  match PAGES[_page]:
    'attack':
      _labels.assign(['dagger', 'warhammer'])
    'poison':
      _labels.assign(['poison applied', 'poison damage'])
    'burn':
      _labels.assign(['burn applied', 'burn damage'])
    'bleed':
      _labels.assign(['bleed applied', 'bleed damage'])
  for i in _labels.size():
    _live.append(_make_hit(i))
    _strip.append(_make_hit(i))
  _time = 0.0


# A fresh delivery for the page's effect at `index`. Each has its own identity, so its angles and
# particle paths differ from the last.
func _make_hit(index: int) -> Delivery:
  var hit: Delivery = Delivery.new()
  match PAGES[_page]:
    'attack':
      hit.mechanic = AttackMechanic.ID
      hit.source = _attack_items[index]
    'poison':
      hit.mechanic = PoisonMechanic.ID
    'burn':
      hit.mechanic = BurnMechanic.ID
    'bleed':
      hit.mechanic = BleedMechanic.ID
  hit.visual_only = index == 1 and PAGES[_page] != 'attack'
  hit.value = 12.0
  hit.color = MechanicRegistry.get_mechanic(hit.mechanic).color()
  return hit


func _draw_hit(hit: Delivery, point: Vector2, age: float) -> void:
  match hit.mechanic:
    AttackMechanic.ID:
      _attack_drawer.draw_hit(self, hit, point, HIT_DIRECTION, age)
    PoisonMechanic.ID:
      _poison_drawer.draw_effect(self, hit, point, age)
    BurnMechanic.ID:
      _burn_drawer.draw_effect(self, hit, point, age)
    BleedMechanic.ID:
      _bleed_drawer.draw_hit(self, hit, point, HIT_DIRECTION, age)
  draw_set_transform_matrix(Transform2D.IDENTITY)


func _effect_length(hit: Delivery) -> float:
  match hit.mechanic:
    AttackMechanic.ID:
      return AttackHitDrawer.SLASH_DURATION if AttackHitDrawer.is_blade(hit) else AttackHitDrawer.IMPACT_DURATION
    PoisonMechanic.ID:
      return PoisonDrawer.TICK_DURATION if hit.visual_only else PoisonDrawer.APPLY_DURATION
    BurnMechanic.ID:
      return BurnDrawer.TICK_DURATION if hit.visual_only else BurnDrawer.APPLY_DURATION
  return BleedDrawer.DURATION


# The longest effect on the page, so the live half repeats only once every effect has finished.
func _length() -> float:
  var longest: float = 0.0
  for hit: Delivery in _strip:
    longest = maxf(longest, _effect_length(hit))
  return longest
