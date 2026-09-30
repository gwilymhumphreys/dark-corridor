extends Control
## Dev scene for judging the hit effects (`AttackHitDrawer`, `PoisonDrawer`, `BurnDrawer`,
## `BleedDrawer`, docs/systems/vfx_driver.md) without waiting for the right item to fire in a fight.
## It has one page per mechanic: attack (a dagger's slash and a warhammer's impact), then poison,
## burn and bleed (each applied, then dealing damage), and projectile (`ProjectileCometDrawer`: comets
## in four mechanic colours flying at an enemy, and a still row comparing each with the old disc). The top half repeats the page's two effects over an enemy image, each hit a
## new delivery so the angles and paths change. The bottom half is a strip of frames through each
## effect, for screenshots. Space or Tab turns the page. Run it directly:
##   <godot> --path . res://src/debug/scenes/hit_effects_preview.tscn -- --page=poison
## `--page` is attack (the default), poison, burn, bleed or projectile. The hits travel leftwards and a little up, as
## they do from the board to an enemy in a fight. The effects are drawn on the `Effects` child through
## `InterfaceLook.effects_material`, as on the combat wall, so `--interface-set=effects_on=true` and the
## other effects settings show here; the background, enemy image and captions are drawn without it.

const PAGES: Array[String] = ['attack', 'poison', 'burn', 'bleed', 'projectile']
const STRIP_FRAMES: int = 8
const HIT_DIRECTION: Vector2 = Vector2(-1.0, -0.25)
const LIVE_POINTS: Array[Vector2] = [Vector2(700.0, 420.0), Vector2(1860.0, 420.0)]
const STRIP_TOP: float = 900.0
const STRIP_ROW: float = 260.0
const STRIP_LEFT: float = 260.0
const STRIP_STEP: float = 290.0
const FLIGHT: float = 0.5                 # seconds a projectile on the projectile page takes to arrive
const FLIGHT_GAP: float = 0.3             # seconds between a projectile arriving and the next launch
const FLIGHT_FROM: Vector2 = Vector2(2250.0, 950.0)
const FLIGHT_TO: Vector2 = Vector2(700.0, 420.0)
const PROJECTILE_MECHANICS: Array[String] = ['attack', 'poison', 'burn', 'heal']

var _attack_drawer: AttackHitDrawer = AttackHitDrawer.new()
var _poison_drawer: PoisonDrawer = PoisonDrawer.new()
var _burn_drawer: BurnDrawer = BurnDrawer.new()
var _comet_drawer: ProjectileCometDrawer = ProjectileCometDrawer.new()
var _disc_drawer: ProjectileDiscDrawer = ProjectileDiscDrawer.new()
var _bleed_drawer: BleedDrawer = BleedDrawer.new()
var _attack_items: Array[Item] = []      # the dagger, then the warhammer
var _page: int = 0
var _labels: Array[String] = []           # one per effect on the page
var _live: Array[Delivery] = []           # the current live hit for each effect
var _strip: Array[Delivery] = []          # one fixed hit per effect for the strip of frames
var _time: float = 0.0
var _enemy: Texture2D

@onready var _effects: Node2D = $Effects


func _ready() -> void:
  _page = maxi(PAGES.find(DevArgs.value('--page')), 0)
  var actor: Actor = Actor.new(100.0)
  for id: String in ['dagger', 'warhammer']:
    _attack_items.append(Item.new(ItemCatalog.get_def(id), actor))
  _enemy = MonsterImages.random_texture()
  _effects.draw.connect(_draw_effects)
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
  _effects.queue_redraw()


func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.13, 0.15))
  var font: Font = ThemeDB.fallback_font
  draw_string(font, Vector2(24.0, 48.0), '%s  (space: next page)' % PAGES[_page], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32)
  if PAGES[_page] == 'projectile':
    _draw_projectile_page(font)
    return
  for i in _live.size():
    var point: Vector2 = LIVE_POINTS[i]
    _draw_enemy(point)
    draw_string(font, point + Vector2(-80.0, 320.0), _labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28)
  for i in _strip.size():
    var y: float = STRIP_TOP + STRIP_ROW * float(i)
    draw_string(font, Vector2(24.0, y + 8.0), _labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24)
    var length: float = _effect_length(_strip[i])
    for frame in STRIP_FRAMES:
      var frame_age: float = length * float(frame) / float(STRIP_FRAMES)
      var point: Vector2 = Vector2(STRIP_LEFT + STRIP_STEP * float(frame), y)
      draw_string(font, point + Vector2(-40.0, 125.0), '%.2fs' % frame_age, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22)


# The effects themselves, on the `Effects` child, at the same places `_draw` puts their captions.
func _draw_effects() -> void:
  if PAGES[_page] == 'projectile':
    _draw_projectiles()
    return
  var age: float = fmod(_time, _length() + 0.2)
  for i in _live.size():
    _draw_hit(_live[i], LIVE_POINTS[i], age)
  for i in _strip.size():
    var y: float = STRIP_TOP + STRIP_ROW * float(i)
    var length: float = _effect_length(_strip[i])
    for frame in STRIP_FRAMES:
      var frame_age: float = length * float(frame) / float(STRIP_FRAMES)
      _draw_hit(_strip[i], Vector2(STRIP_LEFT + STRIP_STEP * float(frame), y), frame_age)


func _draw_enemy(point: Vector2) -> void:
  if _enemy == null:
    return
  var height: float = 560.0
  var width: float = height * float(_enemy.get_width()) / float(_enemy.get_height())
  draw_texture_rect(_enemy, Rect2(point - Vector2(width, height) * 0.5, Vector2(width, height)), false, Color(0.45, 0.45, 0.5))


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
    'projectile':
      _labels.assign(PROJECTILE_MECHANICS)
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
    'projectile':
      hit.mechanic = PROJECTILE_MECHANICS[index]
  hit.visual_only = index == 1 and PAGES[_page] not in ['attack', 'projectile']
  hit.value = 12.0
  hit.color = MechanicRegistry.get_mechanic(hit.mechanic).color()
  return hit


func _draw_hit(hit: Delivery, point: Vector2, age: float) -> void:
  match hit.mechanic:
    AttackMechanic.ID:
      _attack_drawer.draw_hit(_effects, hit, point, HIT_DIRECTION, age)
    PoisonMechanic.ID:
      _poison_drawer.draw_effect(_effects, hit, point, age)
    BurnMechanic.ID:
      _burn_drawer.draw_effect(_effects, hit, point, age)
    BleedMechanic.ID:
      _bleed_drawer.draw_hit(_effects, hit, point, HIT_DIRECTION, age)
  _effects.draw_set_transform_matrix(Transform2D.IDENTITY)


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
  if PAGES[_page] == 'projectile':
    return FLIGHT + FLIGHT_GAP
  var longest: float = 0.0
  for hit: Delivery in _strip:
    longest = maxf(longest, _effect_length(hit))
  return longest


# The projectile page's enemy and captions.
func _draw_projectile_page(font: Font) -> void:
  _draw_enemy(FLIGHT_TO)
  for i in _strip.size():
    var x: float = STRIP_LEFT + 520.0 * float(i)
    draw_string(font, Vector2(x - 20.0, STRIP_TOP + 290.0), _labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24)


# Comets in each colour fly from the board side to the enemy one after another, and a still row
# underneath shows each comet beside the old disc, so their sizes can be compared.
func _draw_projectiles() -> void:
  var cycle: float = FLIGHT + FLIGHT_GAP
  for i in _strip.size():
    var from: Vector2 = FLIGHT_FROM + Vector2(-160.0 * float(i), 60.0 * float(i % 2))
    var age: float = fmod(_time + cycle - float(i) * cycle / float(_strip.size()), cycle)
    if age < FLIGHT:
      var t: float = age / FLIGHT
      _comet_drawer.draw_flight(_effects, _strip[i], VfxDriver.arc_point(from, FLIGHT_TO, t), VfxDriver.arc_direction(from, FLIGHT_TO, t), age)
  for i in _strip.size():
    var x: float = STRIP_LEFT + 520.0 * float(i)
    var y: float = STRIP_TOP + 220.0
    _disc_drawer.draw_effect(_effects, _strip[i], Vector2(x, y), 0.0)
    _comet_drawer.draw_flight(_effects, _strip[i], Vector2(x + 200.0, y), Vector2(-1.0, -0.25), 1.0)
  _effects.draw_set_transform_matrix(Transform2D.IDENTITY)
