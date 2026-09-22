extends GutTest
## Step 3 — the item + fire pipeline. Payload/shape per effect, self-targeting,
## cooldown reset, the silence gate, duplicate independence, and the trigger
## item's declared subscription. (Target resolution + Deliveries are Step 4.)


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _make(def: ItemDef) -> Item:
  return Item.new(def, Actor.new())


func test_weapon_fires_damage_payload() -> void:
  var it := _make(FixtureItems.attack())
  var payloads := it.fire()
  assert_eq(payloads.size(), 1, 'one effect -> one payload')
  var p: Payload = payloads[0]
  assert_eq(p.kind, Delivery.Kind.MECHANIC)
  assert_eq(p.mechanic, AttackMechanic.ID, 'the weapon fires the attack mechanic')
  assert_eq(p.value, FixtureItems.ATTACK_DAMAGE)
  assert_eq(p.shape, ItemEffect.Shape.OPPONENT_LEFTMOST)
  assert_eq(p.source, it, 'payload is sourced from the firing item')


func test_weak_owner_fires_reduced_damage() -> void:
  # #6 outgoing seam (the Item half): a Weak owner's DAMAGE payload is scaled DOWN at
  # fire time (locked into the payload — a % multiplier, cascade-safe).
  var owner_actor := Actor.new()
  var it := Item.new(FixtureItems.attack(), owner_actor)
  assert_almost_eq(it.fire()[0].value, FixtureItems.ATTACK_DAMAGE, 0.0001, 'unweakened: full damage')
  it.cooldown.reset()
  StatusManager.apply(owner_actor, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)
  var weak_value: float = it.fire()[0].value
  assert_almost_eq(weak_value, FixtureItems.ATTACK_DAMAGE * Balance.STATUS_WEAK_DAMAGE_MULT, 0.0001,
    'a Weak owner fires reduced damage')


func test_vulnerable_applier_applies_vulnerable_to_opponent() -> void:
  var p: Payload = _make(FixtureItems.vulnerable()).fire()[0]
  assert_eq(p.kind, Delivery.Kind.APPLY_STATUS)
  assert_eq(p.status_id, 'vulnerable')
  assert_eq(p.shape, ItemEffect.Shape.OPPONENT_LEFTMOST)
  assert_almost_eq(p.duration, FixtureItems.VULNERABLE_DURATION, 0.0001,
    'the per-application duration rides the payload (effect → payload → delivery → apply)')


func test_armor_applies_shield_to_self() -> void:
  var p: Payload = _make(FixtureItems.shield()).fire()[0]
  assert_eq(p.kind, Delivery.Kind.MECHANIC)
  assert_eq(p.mechanic, ShieldMechanic.ID, 'the armor fires the shield mechanic')
  assert_eq(p.shape, ItemEffect.Shape.SELF)


func test_poison_dagger_applies_poison_to_opponent() -> void:
  var p: Payload = _make(FixtureItems.poison()).fire()[0]
  assert_eq(p.kind, Delivery.Kind.MECHANIC)
  assert_eq(p.mechanic, PoisonMechanic.ID, 'the dagger fires the poison mechanic')
  assert_eq(p.shape, ItemEffect.Shape.OPPONENT_LEFTMOST)


func test_fire_resets_the_cooldown() -> void:
  var it := _make(FixtureItems.attack())
  for _i in int(it.cooldown.threshold):
    it.cooldown.step()
  assert_true(it.cooldown.crossed(), 'ready to fire')
  it.fire()
  assert_false(it.cooldown.crossed(), 'fire resets the cooldown')


func test_silenced_item_does_not_fire() -> void:
  var it := _make(FixtureItems.attack())
  StatusManager.apply(it, 'silence', 1.0)
  assert_eq(it.fire().size(), 0, 'a gate status suppresses the fire')


func test_duplicates_tick_independently() -> void:
  var owner_actor := Actor.new()
  var a := Item.new(FixtureItems.attack(), owner_actor)
  var b := Item.new(FixtureItems.attack(), owner_actor)
  a.cooldown.step()
  assert_almost_eq(a.cooldown.accum, 1.0, 0.0001, 'first instance advanced')
  assert_almost_eq(b.cooldown.accum, 0.0, 0.0001, 'duplicate has its own Ticker')


func test_self_fuel_consume_scales_the_payload_at_fire() -> void:
  # Cap 1 (Self / masochist): an item spends the OWNER's own stacked spore for bonus value,
  # resolved at fire (the owner is known). Spends 3 of 4 poison, +2 damage per stack.
  var owner_actor := Actor.new(100.0)
  StatusManager.apply(owner_actor, 'poison', 4.0)
  var def := ItemDef.new()
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = 5.0
  hit.consume_id = 'poison'
  hit.consume_amount = 3.0
  hit.consume_from_target = false   # self-fuel
  hit.consume_scale = 2.0
  def.effects = [hit]
  var p: Payload = Item.new(def, owner_actor).fire()[0]
  assert_almost_eq(p.value, 5.0 + 3.0 * 2.0, 0.0001, 'base 5 + 3 stacks consumed × 2')
  assert_almost_eq(_status_count(owner_actor, 'poison'), 1.0, 0.0001, 'the owner spent 3 of 4 stacks')


func _status_count(actor: Actor, id: String) -> float:
  for s in actor.statuses:
    if s.id == id:
      return s.count
  return 0.0


func test_trigger_item_declares_its_subscription() -> void:
  var d := FixtureItems.poison_trigger()
  assert_eq(d.trigger_subs.size(), 1, 'the trigger item declares one trigger')
  assert_eq(d.trigger_subs[0]['event'], EventBus.Event.APPLIED)
  assert_eq(d.trigger_subs[0]['filter'], 'poison', 'on poison applied, not shield')
