extends GutTest
## FF2 — the minimal consumable (a thrown heal potion). Throwing it through the CombatManager
## spawns a Delivery that lands on the next step and heals the thrower — the manual-fire path (no Ticker), the
## same resolution surface as an item fire.


var _made: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for cm in _made:
    if is_instance_valid(cm):
      cm.teardown()
      cm.free()
  _made.clear()
  TestCleanup.reset_all_managers()


func _spawn(max_hp: float, defs: Array) -> Actor:
  var a := Actor.new(max_hp)
  for def: ItemDef in defs:
    a.board.append(Item.new(def, a))
  return a


func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  return cm


func test_throwing_a_heal_potion_heals_the_thrower() -> void:
  var p := Actor.new(100.0)
  p.take_damage(40.0)   # 60 HP
  var e := _spawn(100.0, [FixtureItems.enemy_attack()])
  var cm := _manager(p, [e])
  cm.start()
  var potion := Consumable.new(FixtureKit.potion())
  cm.throw_consumable(potion, p)
  assert_eq(p.hp, 60, 'the potion lands in the step loop, not during the throw')
  for i in Balance.POTION_TRAVEL_STEPS:
    cm.sim_step()
  assert_eq(p.hp, roundi(60.0 + FixtureKit.POTION_HEAL), 'the thrown potion healed the thrower on the next step')


func test_throw_after_resolution_is_a_noop() -> void:
  var p := Actor.new(100.0)
  p.take_damage(40.0)
  var e := Actor.new(5.0)
  var cm := _manager(p, [e])
  cm.start()
  e.take_damage(5.0)        # enemy dead
  cm._check_resolution()    # fight resolves (player won)
  var potion := Consumable.new(FixtureKit.potion())
  cm.throw_consumable(potion, p)
  assert_eq(p.hp, 60, 'no throw lands once the fight is over')
