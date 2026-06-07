extends GutTest
## FF2 — the minimal consumable (a thrown heal potion). The catalog builds it, and
## throwing it through the CombatManager resolves a travel-0 Delivery that heals the
## thrower — the manual-fire path (no Ticker), the same resolution surface as an
## item fire.


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


func _spawn(max_hp: float, item_ids: Array) -> Actor:
  var a := Actor.new(max_hp)
  for id in item_ids:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  return a


func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  return cm


func test_catalog_builds_the_heal_potion() -> void:
  var d := ConsumableCatalog.get_def(ConsumableCatalog.HEALING_DRAUGHT)
  assert_eq(d.name_key, 'Healing Draught')
  assert_eq(d.effects.size(), 1)
  assert_eq(d.effects[0].kind, Delivery.Kind.HEAL, 'it heals')
  assert_eq(d.effects[0].shape, ItemEffect.Shape.SELF, 'the thrower')


func test_throwing_a_heal_potion_heals_the_thrower() -> void:
  var p := Actor.new(100.0)
  p.take_damage(40.0)   # 60 HP
  var e := _spawn(100.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var potion := Consumable.new(ConsumableCatalog.get_def(ConsumableCatalog.HEALING_DRAUGHT))
  cm.throw_consumable(potion, p)
  assert_almost_eq(p.hp, 60.0 + Balance.POTION_HEAL, 0.0001, 'the thrown potion healed the thrower instantly')


func test_throw_after_resolution_is_a_noop() -> void:
  var p := Actor.new(100.0)
  p.take_damage(40.0)
  var e := Actor.new(5.0)
  var cm := _manager(p, [e])
  cm.start()
  e.take_damage(5.0)        # enemy dead
  cm._check_resolution()    # fight resolves (player won)
  var potion := Consumable.new(ConsumableCatalog.get_def(ConsumableCatalog.HEALING_DRAUGHT))
  cm.throw_consumable(potion, p)
  assert_eq(p.hp, 60.0, 'no throw lands once the fight is over')
