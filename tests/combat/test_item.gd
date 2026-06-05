extends GutTest
## Step 3 — the item + fire pipeline. Payload/shape per effect, self-targeting,
## cooldown reset, the silence gate, duplicate independence, and the trigger
## item's declared subscription. (Target resolution + Deliveries are Step 4.)


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _make(id: int) -> Item:
  return Item.new(ItemCatalog.get_def(id), Actor.new())


func test_weapon_fires_damage_payload() -> void:
  var it := _make(ItemCatalog.Id.WEAPON)
  var payloads := it.fire()
  assert_eq(payloads.size(), 1, 'one effect -> one payload')
  var p: Payload = payloads[0]
  assert_eq(p.kind, Delivery.Kind.DAMAGE)
  assert_eq(p.value, Balance.WEAPON_DAMAGE)
  assert_eq(p.shape, ItemEffect.Shape.OPPONENT_LEFTMOST)
  assert_eq(p.source, it, 'payload is sourced from the firing item')


func test_armor_applies_block_to_self() -> void:
  var p: Payload = _make(ItemCatalog.Id.ARMOR).fire()[0]
  assert_eq(p.kind, Delivery.Kind.APPLY_STATUS)
  assert_eq(p.status_type, StatusDef.Type.BLOCK)
  assert_eq(p.shape, ItemEffect.Shape.SELF)


func test_poison_dagger_applies_poison_to_opponent() -> void:
  var p: Payload = _make(ItemCatalog.Id.POISON_DAGGER).fire()[0]
  assert_eq(p.kind, Delivery.Kind.APPLY_STATUS)
  assert_eq(p.status_type, StatusDef.Type.POISON)
  assert_eq(p.shape, ItemEffect.Shape.OPPONENT_LEFTMOST)


func test_fire_resets_the_cooldown() -> void:
  var it := _make(ItemCatalog.Id.WEAPON)
  for i in int(it.cooldown.threshold):
    it.cooldown.step()
  assert_true(it.cooldown.crossed(), 'ready to fire')
  it.fire()
  assert_false(it.cooldown.crossed(), 'fire resets the cooldown')


func test_silenced_item_does_not_fire() -> void:
  var it := _make(ItemCatalog.Id.WEAPON)
  StatusManager.apply(it, StatusDef.Type.SILENCE, 1.0)
  assert_eq(it.fire().size(), 0, 'a gate status suppresses the fire')


func test_duplicates_tick_independently() -> void:
  var owner := Actor.new()
  var a := Item.new(ItemCatalog.get_def(ItemCatalog.Id.WEAPON), owner)
  var b := Item.new(ItemCatalog.get_def(ItemCatalog.Id.WEAPON), owner)
  a.cooldown.step()
  assert_almost_eq(a.cooldown.accum, 1.0, 0.0001, 'first instance advanced')
  assert_almost_eq(b.cooldown.accum, 0.0, 0.0001, 'duplicate has its own Ticker')


func test_trigger_item_declares_its_subscription() -> void:
  var d := ItemCatalog.get_def(ItemCatalog.Id.AVENGER)
  assert_eq(d.trigger_subs.size(), 1, 'avenger declares one trigger')
  assert_eq(d.trigger_subs[0]['event'], EventBus.Event.STATUS_APPLIED)
  assert_eq(d.trigger_subs[0]['filter'], StatusDef.Type.POISON, 'on poison applied, not block')
