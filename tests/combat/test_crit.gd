extends GutTest
## Crit (docs/systems/mechanics.md → Crit): an item's crit chance rolls once per fire on the
## seeded per-fight RNG; on a crit the fire's mechanic deliveries are multiplied by
## Balance.CRIT_MULTIPLIER and flagged `crit`, and EventBus.Event.CRIT is published. Items
## with no crit chance draw nothing from the RNG (seeded runs stay bit-identical), thrown
## consumables never crit, and display_value never rolls.


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


## An item with the given crit chance and one effect (mechanic or status), instant.
func _crit_item(owner_actor: Actor, crit_chance: float, effect: ItemEffect) -> Item:
  var def := ItemDef.new()
  def.id = 'test_crit_item'
  def.crit_chance = crit_chance
  def.effects = [effect]
  return Item.new(def, owner_actor)


func _attack_effect(value: float) -> ItemEffect:
  var e := ItemEffect.new()
  e.mechanic = AttackMechanic.ID
  e.value = value
  e.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  return e


func _weak_effect(value: float) -> ItemEffect:
  var e := ItemEffect.new()
  e.kind = Delivery.Kind.APPLY_STATUS
  e.status_id = 'weak'
  e.value = value
  e.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  return e


## Fire the item through the Combat manager and land whatever arrives instantly.
func _fire_and_land(cm: CombatManager, it: Item) -> Array:
  var arrived: Array = CombatSteps.fire_and_land(cm, it)
  return arrived


func _status_count(actor: Actor, id: String) -> float:
  for s in actor.statuses:
    if s.id == id:
      return s.count
  return 0.0


# --- tests ------------------------------------------------------------------

func test_crit_doubles_mechanic_values_and_leaves_outside_set_alone() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var def := ItemDef.new()
  def.id = 'test_crit_dual'
  def.crit_chance = 1.0
  def.effects = [_attack_effect(10.0), _weak_effect(3.0)]
  var arrived := _fire_and_land(cm, Item.new(def, p))
  assert_eq(arrived.size(), 2, 'both effects spawned a delivery')
  var attack: Delivery = null
  var weak: Delivery = null
  for d in arrived:
    if d.kind == Delivery.Kind.MECHANIC:
      attack = d
    else:
      weak = d
  assert_not_null(attack, 'the attack delivery')
  assert_not_null(weak, 'the weak delivery')
  assert_true(attack.crit, 'the attack delivery is flagged crit')
  assert_almost_eq(attack.value, 10.0 * Balance.CRIT_MULTIPLIER, 0.0001, 'the attack value is doubled')
  assert_false(weak.crit, 'the outside-set (APPLY_STATUS) delivery is not crit')
  assert_almost_eq(weak.value, 3.0, 0.0001, 'the weak value is unchanged')
  assert_almost_eq(e.hp, 1000.0 - 10.0 * Balance.CRIT_MULTIPLIER, 0.0001, 'the enemy took the doubled damage')


func test_crit_doubles_a_shield_applied() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var shield := ItemEffect.new()
  shield.mechanic = ShieldMechanic.ID
  shield.value = 8.0
  shield.shape = ItemEffect.Shape.SELF
  _fire_and_land(cm, _crit_item(p, 1.0, shield))
  assert_almost_eq(_status_count(p, 'shield'), 8.0 * Balance.CRIT_MULTIPLIER, 0.0001,
      'the shield applied is doubled by the crit')


func test_no_crit_chance_draws_nothing_from_the_rng() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var it := _crit_item(p, 0.0, _attack_effect(10.0))
  var state_before: int = cm.rng.state
  _fire_and_land(cm, it)
  assert_eq(cm.rng.state, state_before, 'a crit chance of 0 draws nothing from the per-fight RNG')


func test_crit_event_published_with_the_def_id_and_not_when_it_does_not_crit() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var seen: Array = []
  cm.bus.add_listener(EventBus.Event.CRIT,
      func(data, source_actor, source_item) -> void:
        seen.append([data, source_actor, source_item]))
  var def := ItemDef.new()
  def.id = 'test_crit_event_item'
  def.crit_chance = 1.0
  def.effects = [_attack_effect(10.0)]
  _fire_and_land(cm, Item.new(def, p))
  assert_eq(seen.size(), 1, 'a crit published CRIT')
  assert_eq(seen[0][0], def.id, 'the event data is the item def id')
  assert_eq(seen[0][1], p, 'the source actor is the owner')
  _fire_and_land(cm, _crit_item(p, 0.0, _attack_effect(10.0)))
  assert_eq(seen.size(), 1, 'a non-crit fire published no CRIT')


func test_crit_applies_after_weak() -> void:
  # Weak scales the attack at fire time (outgoing_bonus); the crit multiplies the
  # weakened value, so the landed value is the weakened value times the multiplier.
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)
  var it := _crit_item(p, 1.0, _attack_effect(10.0))
  var arrived := _fire_and_land(cm, it)
  assert_almost_eq(arrived[0].value, 10.0 * Balance.STATUS_WEAK_DAMAGE_MULT * Balance.CRIT_MULTIPLIER,
      0.0001, 'the crit multiplies the WEAKENED value')
  assert_almost_eq(e.hp, 1000.0 - 10.0 * Balance.STATUS_WEAK_DAMAGE_MULT * Balance.CRIT_MULTIPLIER,
      0.0001, 'the enemy took the weakened-then-crit damage')


func test_display_value_never_rolls() -> void:
  # display_value shows the value without crit: an item with a crit chance of 1 shows the
  # same value as an identical item without one.
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var with_crit := _crit_item(p, 1.0, _attack_effect(10.0))
  var without_crit := _crit_item(p, 0.0, _attack_effect(10.0))
  assert_almost_eq(with_crit.display_value(with_crit.def.effects[0]),
      without_crit.display_value(without_crit.def.effects[0]), 0.0001,
      'display_value is the same with and without a crit chance (it never rolls)')


func test_item_uses_reports_crit_chance() -> void:
  var p := Actor.new(1000.0)
  var with_chance := _crit_item(p, 1.0, _attack_effect(10.0))
  var without_chance := _crit_item(p, 0.0, _attack_effect(10.0))
  assert_true(with_chance.uses(CritMechanic.ID), 'an item with a crit chance uses crit')
  assert_false(without_chance.uses(CritMechanic.ID), 'an item without one does not')
  assert_true(with_chance.uses(AttackMechanic.ID), 'its attack effect is still reported')


func test_thrown_consumable_never_crits() -> void:
  # Potions have no crit chance: a throw resolves its effects without any CRIT event.
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var seen: Array = []
  cm.bus.add_listener(EventBus.Event.CRIT,
      func(_data, _source_actor, _source_item) -> void:
        seen.append(true))
  var def := ConsumableDef.new()
  def.id = 'test_crit_dart'
  def.name_key = 'Test Crit Dart'
  var effect := ItemEffect.new()
  effect.mechanic = AttackMechanic.ID
  effect.value = 10.0
  effect.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  def.effects = [effect]
  cm.throw_consumable(Consumable.new(def), p)
  for i in Balance.TRAVEL_STEPS:
    cm.sim_step()
  assert_eq(seen.size(), 0, 'a thrown consumable never publishes CRIT')
  assert_almost_eq(e.hp, 1000.0 - 10.0, 0.0001, 'and its value is not multiplied')
