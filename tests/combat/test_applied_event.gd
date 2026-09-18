extends GutTest
## Step 6 of docs/systems/mechanics.md — the single APPLIED event. Every mechanic that can be
## delivered publishes APPLIED once with its id when a delivery of it lands; an APPLY_STATUS
## delivery publishes APPLIED with the status id (nothing for an unknown id); ticks publish
## nothing; and Spite Ward's trigger still charges on poison and not on shield.


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


# --- helpers (not test_*; GUT ignores them) ---------------------------------

func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  TestCleanup.dissolve_at_reset(p)
  return cm


## A one-effect item whose single effect is the named mechanic, instant.
func _mechanic_item(owner_actor: Actor, mechanic_id: String, value: float,
    shape: int = ItemEffect.Shape.OPPONENT_LEFTMOST) -> Item:
  var def := ItemDef.new()
  var effect := ItemEffect.new()
  effect.mechanic = mechanic_id
  effect.value = value
  effect.shape = shape
  effect.travel = 0.0
  def.effects = [effect]
  return Item.new(def, owner_actor)


## Land one delivery of `mechanic_id` from `p` onto `e` and return the APPLIED data seen.
func _land_mechanic(cm: CombatManager, p: Actor, e: Actor, mechanic_id: String,
    shape: int = ItemEffect.Shape.OPPONENT_LEFTMOST) -> Array:
  var applied_data: Array = []
  cm.bus.add_listener(EventBus.Event.APPLIED,
      func(data, _source_actor, _source_item) -> void:
        applied_data.append(data))
  var arrived: Array = []
  cm._fire_item(_mechanic_item(p, mechanic_id, 3.0, shape), arrived)
  for d in arrived:
    cm._land(d)
  return applied_data


# --- Each deliverable mechanic publishes APPLIED once with its id ------------

func test_attack_publishes_applied_with_its_id() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var data := _land_mechanic(cm, p, e, AttackMechanic.ID)
  assert_eq(data, [AttackMechanic.ID], 'the attack landing published APPLIED with the attack id')


func test_heal_publishes_applied_with_its_id() -> void:
  var p := Actor.new(100.0)
  p.take_damage(40.0)   # at 60 / 100 so the heal restores real HP
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var data := _land_mechanic(cm, p, p, HealMechanic.ID, ItemEffect.Shape.SELF)
  assert_eq(data, [HealMechanic.ID], 'the heal landing published APPLIED with the heal id')


func test_shield_publishes_applied_with_its_id() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var data := _land_mechanic(cm, p, p, ShieldMechanic.ID, ItemEffect.Shape.SELF)
  assert_eq(data, [ShieldMechanic.ID], 'the shield landing published APPLIED with the shield id')


func test_poison_publishes_applied_with_its_id() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var data := _land_mechanic(cm, p, e, PoisonMechanic.ID)
  assert_eq(data, [PoisonMechanic.ID], 'the poison landing published APPLIED with the poison id')


func test_burn_publishes_applied_with_its_id() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var data := _land_mechanic(cm, p, e, BurnMechanic.ID)
  assert_eq(data, [BurnMechanic.ID], 'the burn landing published APPLIED with the burn id')


func test_bleed_publishes_applied_with_its_id() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var data := _land_mechanic(cm, p, e, BleedMechanic.ID)
  assert_eq(data, [BleedMechanic.ID], 'the bleed landing published APPLIED with the bleed id')


func test_regen_publishes_applied_with_its_id() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var data := _land_mechanic(cm, p, e, RegenMechanic.ID)
  assert_eq(data, [RegenMechanic.ID], 'the regen landing published APPLIED with the regen id')


# --- APPLY_STATUS publishes APPLIED with the status id -----------------------

func _status_delivery(target, status_id: String) -> Delivery:
  var d := Delivery.new()
  d.kind = Delivery.Kind.APPLY_STATUS
  d.status_id = status_id
  d.value = 1.0
  d.target = target
  d.travel = Ticker.new(0)
  return d


func test_apply_status_publishes_applied_with_the_status_id() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var applied_data: Array = []
  cm.bus.add_listener(EventBus.Event.APPLIED,
      func(data, _source_actor, _source_item) -> void:
        applied_data.append(data))
  cm._land(_status_delivery(e, 'weak'))
  assert_eq(applied_data, ['weak'], 'an APPLY_STATUS delivery published APPLIED with the status id')


func test_apply_status_with_an_unknown_id_publishes_nothing() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var applied_data: Array = []
  cm.bus.add_listener(EventBus.Event.APPLIED,
      func(data, _source_actor, _source_item) -> void:
        applied_data.append(data))
  cm._land(_status_delivery(e, 'nonexistent_status'))
  assert_true(applied_data.is_empty(), 'an unknown status id applies nothing and publishes nothing')


# --- Ticks publish nothing ---------------------------------------------------

func test_poison_tick_publishes_nothing() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'poison', 3.0)
  var applied_data: Array = []
  cm.bus.add_listener(EventBus.Event.APPLIED,
      func(data, _source_actor, _source_item) -> void:
        applied_data.append(data))
  var poison: StatusEffect = null
  for s in e.statuses:
    if s.id == 'poison':
      poison = s
  assert_not_null(poison, 'the poison status is on the enemy')
  var interval := int(poison.ticker.threshold)
  for _i in interval:
    cm.sim_step()
  assert_true(applied_data.is_empty(), 'a poison tick published no APPLIED event')


# --- Spite Ward's trigger ----------------------------------------------------

func test_spite_ward_declares_an_applied_subscription() -> void:
  var d := ItemCatalog.get_def(ItemCatalog.AVENGER)
  assert_eq(d.trigger_subs.size(), 1, 'Spite Ward declares one trigger')
  assert_eq(d.trigger_subs[0]['event'], EventBus.Event.APPLIED, 'it subscribes to APPLIED')
  assert_eq(d.trigger_subs[0]['filter'], 'poison', 'filtered to poison')
  assert_false(d.trigger_subs[0].has('source_filter'),
      'no source_filter key — it uses the OWN_SIDE content default')
  assert_almost_eq(d.trigger_subs[0]['amount'], Balance.TRIGGER_PUSH_FULL, 0.0001,
      'the declared push amount')


func test_spite_ward_charges_on_poison_not_on_shield() -> void:
  # Read the trigger straight off the def and wire it onto a bus, so the test proves the
  # def's own subscription (event + filter + source filter) charges on poison and not on
  # shield — the same wiring CombatManager._register_item does.
  var d := ItemCatalog.get_def(ItemCatalog.AVENGER)
  var sub: Dictionary = d.trigger_subs[0]
  var player_actor := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(player_actor)
  var bus := EventBus.new()
  bus.side_resolver = func(actor) -> bool: return actor == player_actor
  var ward := Item.new(d, player_actor)
  bus.subscribe(sub['event'], ward.cooldown, sub['amount'], sub.get('filter', null),
      sub.get('source_filter', EventBus.SourceFilter.OWN_SIDE), ward)
  # Poison applied by the ward's own side (the player) matches the OWN_SIDE + 'poison' filter.
  bus.publish(sub['event'], 'poison', player_actor, null)
  assert_gt(ward.cooldown.accum, 0.0, 'poison applied on its own side pushed the trigger')
  ward.cooldown.accum = 0.0
  # Shield applied on the same side does not match the 'poison' filter.
  bus.publish(sub['event'], 'shield', player_actor, null)
  assert_eq(ward.cooldown.accum, 0.0, 'shield applied pushed nothing (the filter is poison)')
  player_actor.dissolve()
