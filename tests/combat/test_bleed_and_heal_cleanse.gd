extends GutTest
## Step 4 of docs/systems/mechanics.md — bleed as a mechanic with its new trigger (an attack
## landing on the holder, via on_holder_attacked) and heal removing poison / burn / bleed
## stacks (StatusManager.reduce). Each bullet of the plan's Bleed list, plus the heal-cleanse
## cases. Uses a running CombatManager, like test_combat_manager.gd.


var _made: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for cm in _made:
    if is_instance_valid(cm):
      TestCleanup.dissolve_at_reset(cm.player)
      for ally in cm.allies:
        TestCleanup.dissolve_at_reset(ally)
      cm.teardown()
      cm.free()
  _made.clear()
  TestCleanup.reset_all_managers()


# --- helpers ----------------------------------------------------------------

func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  TestCleanup.dissolve_at_reset(p)
  return cm


func _spawn(max_hp: float, item_defs: Array) -> Actor:
  var a := Actor.new(max_hp)
  for def in item_defs:
    a.board.append(Item.new(def, a))
  TestCleanup.dissolve_at_reset(a)
  return a


## An instant attack item of `value` (no weapon type tag unless `weapon` is true).
func _attack_item(owner_actor: Actor, value: float, shape: int = ItemEffect.Shape.OPPONENT_LEFTMOST, weapon: bool = false) -> Item:
  var def := ItemDef.new()
  if weapon:
    def.types = [ItemType.WEAPON]
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = value
  hit.shape = shape
  hit.travel = 0.0
  def.effects = [hit]
  return Item.new(def, owner_actor)


## An instant heal item of `value` (shape SELF).
func _heal_item(owner_actor: Actor, value: float) -> Item:
  var def := ItemDef.new()
  var heal := ItemEffect.new()
  heal.mechanic = HealMechanic.ID
  heal.value = value
  heal.shape = ItemEffect.Shape.SELF
  heal.travel = 0.0
  def.effects = [heal]
  return Item.new(def, owner_actor)


## Fire `it` and land everything it spawns (instant travel lands the same call).
func _fire_and_land(cm: CombatManager, it: Item) -> void:
  var arrived: Array = []
  cm._fire_item(it, arrived)
  for d in arrived:
    cm._land(d)


func _status_count(actor: Actor, id: String) -> float:
  for s in actor.statuses:
    if s.id == id:
      return s.count
  return 0.0


func _has_status(actor: Actor, id: String) -> bool:
  for s in actor.statuses:
    if s.id == id:
      return true
  return false


# --- Bleed: the trigger ------------------------------------------------------

func test_attack_on_a_bleeding_actor_deals_attack_plus_bleed_and_loses_a_stack() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'bleed', 3.0)
  var before: float = e.hp
  _fire_and_land(cm, _attack_item(p, 10.0))
  assert_almost_eq(before - e.hp, 10.0 + 3.0, 0.0001, 'the attack plus the bleed bite (3 stacks)')
  assert_almost_eq(_status_count(e, 'bleed'), 2.0, 0.0001, 'bleed lost one stack')


func test_attack_triggers_bleed_even_when_shield_absorbs_the_whole_attack() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'shield', 100.0)
  StatusManager.apply(e, 'bleed', 3.0)
  _fire_and_land(cm, _attack_item(p, 10.0))
  assert_almost_eq(e.hp, 1000.0, 0.0001, 'the shield soaked the attack and the bleed bite')
  assert_almost_eq(_status_count(e, 'bleed'), 2.0, 0.0001, 'the bleed still triggered and lost a stack')


func test_poison_tick_and_own_item_fire_do_not_trigger_bleed() -> void:
  var p := Actor.new(1000.0)
  var e := _spawn(1000.0, [FixtureItems.attack()])
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'bleed', 3.0)
  # A poison tick (a non-attack damage source) must not trigger the bleed.
  var pois: StatusEffect = StatusManager.apply(e, 'poison', 2.0)
  pois.ticker.accum = pois.ticker.threshold - 1.0   # ticks on the next advance
  cm._advance_statuses_on(e)
  assert_almost_eq(_status_count(e, 'bleed'), 3.0, 0.0001, 'a poison tick did not trigger the bleed')
  # The holder firing its OWN item must not trigger it either (the old trigger).
  _fire_and_land(cm, e.board[0])
  assert_almost_eq(_status_count(e, 'bleed'), 3.0, 0.0001, 'the holder firing its own item did not trigger the bleed')


func test_evaded_attack_does_not_trigger_bleed() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'blind', 1.0)
  StatusManager.apply(e, 'bleed', 3.0)
  _fire_and_land(cm, _attack_item(p, 10.0))
  assert_almost_eq(e.hp, 1000.0, 0.0001, 'the blinded swing whiffed')
  assert_almost_eq(_status_count(e, 'bleed'), 3.0, 0.0001, 'an evaded attack does not trigger the bleed')


func test_lethal_attack_does_not_trigger_bleed() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(5.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'bleed', 3.0)
  _fire_and_land(cm, _attack_item(p, 10.0))
  assert_false(e.is_alive(), 'the attack killed the holder')
  assert_almost_eq(_status_count(e, 'bleed'), 3.0, 0.0001, 'a killing attack does not trigger the bleed (stacks unchanged)')


func test_all_opponents_attack_triggers_each_targets_bleed_once() -> void:
  var p := Actor.new(1000.0)
  var e1 := Actor.new(1000.0)
  var e2 := Actor.new(1000.0)
  var cm := _manager(p, [e1, e2])
  cm.start()
  StatusManager.apply(e1, 'bleed', 2.0)
  StatusManager.apply(e2, 'bleed', 4.0)
  _fire_and_land(cm, _attack_item(p, 5.0, ItemEffect.Shape.ALL_OPPONENTS))
  assert_almost_eq(_status_count(e1, 'bleed'), 1.0, 0.0001, 'the first target lost one stack')
  assert_almost_eq(_status_count(e2, 'bleed'), 3.0, 0.0001, 'the second target lost one stack')


func test_attack_from_a_non_weapon_item_still_triggers_bleed() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'bleed', 3.0)
  _fire_and_land(cm, _attack_item(p, 10.0, ItemEffect.Shape.OPPONENT_LEFTMOST, false))
  assert_almost_eq(_status_count(e, 'bleed'), 2.0, 0.0001, 'item type tags play no part — a non-weapon attack triggers the bleed')


func test_unblockable_bleed_skips_the_holders_shield() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'shield', 100.0)
  StatusManager.apply(e, 'bleed', 3.0, 0.0, null, Delivery.Flag.UNBLOCKABLE)
  _fire_and_land(cm, _attack_item(p, 10.0))
  assert_almost_eq(e.hp, 1000.0 - 3.0, 0.0001, 'the unblockable bleed bite skipped the holder\'s shield')
  assert_almost_eq(_status_count(e, 'shield'), 100.0 - 10.0, 0.0001, 'the shield only spent the attack')


# --- Heal removing poison, burn and bleed -------------------------------------

func test_heal_removes_a_fraction_of_each_of_poison_burn_and_bleed() -> void:
  var p := Actor.new(100.0)
  p.take_damage(40.0)   # at 60 / 100
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'poison', 5.0)
  StatusManager.apply(p, 'burn', 5.0)
  StatusManager.apply(p, 'bleed', 5.0)
  _fire_and_land(cm, _heal_item(p, 30.0))
  # A heal of 30 removes floor(30 × 0.1) = 3 of each.
  assert_almost_eq(_status_count(p, 'poison'), 2.0, 0.0001, 'poison lost 3 stacks')
  assert_almost_eq(_status_count(p, 'burn'), 2.0, 0.0001, 'burn lost 3 stacks')
  assert_almost_eq(_status_count(p, 'bleed'), 2.0, 0.0001, 'bleed lost 3 stacks')


func test_heal_removes_a_status_reduced_to_zero() -> void:
  var p := Actor.new(100.0)
  p.take_damage(40.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'poison', 2.0)
  StatusManager.apply(p, 'bleed', 5.0)
  _fire_and_land(cm, _heal_item(p, 30.0))
  assert_false(_has_status(p, 'poison'), 'poison (2 stacks) was removed by the heal')
  assert_almost_eq(_status_count(p, 'bleed'), 2.0, 0.0001, 'bleed (5 stacks) only lost 3')


func test_reduce_removes_a_non_fuel_status_and_ignores_an_absent_id() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'bleed', 5.0)
  StatusManager.reduce(p, 'bleed', 2.0)
  assert_almost_eq(_status_count(p, 'bleed'), 3.0, 0.0001, 'reduce works on a non-fuel status (bleed)')
  StatusManager.reduce(p, 'bleed', 3.0)
  assert_false(_has_status(p, 'bleed'), 'reduce removed the status at zero')
  StatusManager.reduce(p, 'poison', 5.0)
  assert_false(_has_status(p, 'poison'), 'reducing an absent id does nothing')
  StatusManager.reduce(p, 'bleed', -1.0)
  assert_false(_has_status(p, 'bleed'), 'a non-positive amount does nothing')
