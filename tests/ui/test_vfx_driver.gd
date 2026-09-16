extends GutTest
## The VFX wall's impact burst and its one-sound-per-landing bookkeeping
## (docs/systems/vfx_driver.md). How the burst looks is judged in screenshots; what is tested here
## is the timing function it draws from and that a landing is sounded once, not once per frame.

var _nodes: Array = []
var _actors: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  for a in _actors:
    if is_instance_valid(a):
      a.dissolve()
  _actors.clear()
  TestCleanup.reset_all_managers()


func _spawn(hp: float, ids: Array) -> Actor:
  var a := Actor.new(hp)
  for id in ids:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  _actors.append(a)
  return a


func _driver(cm: CombatManager) -> VfxDriver:
  # The base surface is enough here: the sounding path never asks the layout for a position, and
  # the full framed scene is the `--shot` check, not this one.
  var view := CombatView.new()
  add_child(view)
  _nodes.append(view)
  var vfx := VfxDriver.new()
  add_child(vfx)
  _nodes.append(vfx)
  vfx.setup(cm, view)
  return vfx


func _landed_delivery() -> Delivery:
  var d := Delivery.new()
  d.landed = true
  d.impact_time = 1.0
  return d


func test_impact_burst_runs_for_its_duration_then_stops() -> void:
  var drawer := ImpactRingDrawer.new()
  assert_eq(drawer.progress(-0.01), -1.0, 'nothing before the hit lands')
  assert_eq(drawer.progress(0.0), 0.0, 'the burst starts at the moment of the hit')
  assert_almost_eq(drawer.progress(ImpactRingDrawer.IMPACT_DURATION * 0.5), 0.5, 0.001, 'halfway through')
  assert_eq(drawer.progress(ImpactRingDrawer.IMPACT_DURATION), -1.0, 'gone once its duration has passed')


func test_a_landing_is_scattered_a_little_and_stays_put() -> void:
  var first: Delivery = _landed_delivery()
  var second: Delivery = _landed_delivery()
  var offset: Vector2 = VfxDriver.scatter_offset(first)
  assert_lt(offset.length(), VfxDriver.SCATTER_RADIUS, 'the nudge is small')
  assert_eq(VfxDriver.scatter_offset(first), offset, 'the same landing is nudged the same way each frame')
  assert_ne(VfxDriver.scatter_offset(second), offset, 'a second landing goes somewhere else')


func test_each_landing_is_sounded_once() -> void:
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  var vfx: VfxDriver = _driver(cm)
  var hit: Delivery = _landed_delivery()
  cm.deliveries().append(hit)
  vfx._sound_new_impacts()
  vfx._sound_new_impacts()   # the next frame: the same landing must not sound again
  assert_eq(vfx._sounded.size(), 1, 'the landing was sounded once, not once per frame')
  assert_true(vfx._sounded.has(hit.get_instance_id()), 'and it was that landing')
  cm.deliveries().clear()    # the manager drops a resolved delivery after its visual hold
  vfx._sound_new_impacts()
  assert_eq(vfx._sounded.size(), 0, 'a dropped delivery is forgotten, so the set stays small')
  cm.free()


func test_a_summon_landing_is_not_sounded() -> void:
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  var vfx: VfxDriver = _driver(cm)
  var summon: Delivery = _landed_delivery()
  summon.kind = Delivery.Kind.SUMMON
  cm.deliveries().append(summon)
  vfx._sound_new_impacts()
  assert_eq(vfx._sounded.size(), 0, 'a summon has no impact, so it makes no impact sound')
  cm.free()


func test_a_delivery_in_flight_is_not_sounded() -> void:
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  var vfx: VfxDriver = _driver(cm)
  var in_flight := Delivery.new()
  var fizzled: Delivery = _landed_delivery()
  fizzled.fizzled = true
  cm.deliveries().append(in_flight)
  cm.deliveries().append(fizzled)
  vfx._sound_new_impacts()
  assert_eq(vfx._sounded.size(), 0, 'only a landing that actually happened makes a sound')
  cm.free()
