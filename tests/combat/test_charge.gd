extends GutTest
## Charge and Decharge (docs/systems/mechanics.md): a charge delivery adds seconds of
## progress to the target ITEM's cooldown bar (so it fires sooner); a decharge takes
## them away (so it fires later). Progress is clamped to the bar — never below empty,
## never past full, so a charge can never bank more than one fire (decision #30). A
## gated item's bar is frozen and banks nothing; a land that applies nothing publishes
## no APPLIED event.


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


## An instant, effect-less item with the given cooldown on `owner_actor`'s board.
func _cooldown_item(owner_actor: Actor, cooldown_seconds: float) -> Item:
  var def := ItemDef.new()
  def.id = 'test_charge_item'
  def.cooldown = cooldown_seconds
  var it := Item.new(def, owner_actor)
  owner_actor.board.append(it)
  return it


## A mechanic Delivery aimed at `target_item`, landed through the mechanic's own land.
func _land_delivery(cm: CombatManager, source_actor: Actor, mechanic_id: String,
    value: float, target_item: Item) -> void:
  var d := Delivery.new()
  d.kind = Delivery.Kind.MECHANIC
  d.mechanic = mechanic_id
  d.value = value
  d.target = target_item
  d.source = target_item
  d.source_actor = source_actor
  d.travel = Ticker.new(0)
  MechanicRegistry.get_mechanic(mechanic_id).land(d, cm)


# --- charge -----------------------------------------------------------------

func test_charge_adds_progress() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var it := _cooldown_item(p, 4.0)
  assert_eq(it.cooldown.accum, 0.0, 'the bar starts empty')
  _land_delivery(cm, p, ChargeMechanic.ID, 1.0, it)
  assert_almost_eq(it.cooldown.accum, 1.0 / Balance.STEP, 0.0001, 'a 1-second charge fills one second of progress')


func test_charge_is_clamped_to_a_full_bar() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var it := _cooldown_item(p, 1.0)
  _land_delivery(cm, p, ChargeMechanic.ID, 5.0, it)
  assert_almost_eq(it.cooldown.accum, it.cooldown.threshold, 0.0001, 'charging past full stops at the threshold')


# --- decharge ---------------------------------------------------------------

func test_decharge_removes_progress() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var it := _cooldown_item(p, 4.0)
  it.cooldown.accum = it.cooldown.threshold - 30.0   # part-filled, set directly — stepping this far would fire it
  var before: float = it.cooldown.accum
  _land_delivery(cm, p, DechargeMechanic.ID, 1.0, it)
  assert_almost_eq(it.cooldown.accum, before - 1.0 / Balance.STEP, 0.0001, 'a 1-second decharge removes one second of progress')


func test_decharge_is_clamped_at_empty() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var it := _cooldown_item(p, 4.0)
  _land_delivery(cm, p, DechargeMechanic.ID, 1.0, it)
  assert_almost_eq(it.cooldown.accum, 0.0, 0.0001, 'decharging an empty bar leaves it at zero')
  assert_true(it.cooldown.accum >= 0.0, 'the accumulator never goes negative')


# --- gated items -------------------------------------------------------------

func test_a_gated_item_is_unaffected() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var it := _cooldown_item(p, 4.0)
  it.cooldown.accum = it.cooldown.threshold - 30.0   # part-filled, set directly — stepping this far would fire it
  var silence: StatusEffect = StatusManager.apply(it, 'silence', 1.0, 0.0)
  var before: float = it.cooldown.accum
  _land_delivery(cm, p, ChargeMechanic.ID, 1.0, it)
  assert_eq(it.cooldown.accum, before, 'a charge of a gated item banks nothing')
  _land_delivery(cm, p, DechargeMechanic.ID, 1.0, it)
  assert_eq(it.cooldown.accum, before, 'a decharge of a gated item banks nothing')
  it.statuses.erase(silence)


# --- APPLIED events ----------------------------------------------------------

func test_landing_publishes_applied_with_the_mechanic_id() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var charged := _cooldown_item(p, 4.0)
  var decharged := _cooldown_item(p, 4.0)
  decharged.cooldown.accum = decharged.cooldown.threshold - 30.0   # part-filled — it must not be empty
  var seen: Array = []
  cm.bus.add_listener(EventBus.Event.APPLIED,
      func(data, _source_actor, _source_item) -> void:
        seen.append(data))
  _land_delivery(cm, p, ChargeMechanic.ID, 1.0, charged)
  assert_eq(seen, [ChargeMechanic.ID], 'a charge land published APPLIED with the charge id')
  _land_delivery(cm, p, DechargeMechanic.ID, 1.0, decharged)
  assert_eq(seen, [ChargeMechanic.ID, DechargeMechanic.ID], 'a decharge land published APPLIED with the decharge id')


func test_a_charge_that_applies_nothing_publishes_nothing() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var it := _cooldown_item(p, 1.0)
  it.cooldown.accum = it.cooldown.threshold   # already full
  var seen: Array = []
  cm.bus.add_listener(EventBus.Event.APPLIED,
      func(data, _source_actor, _source_item) -> void:
        seen.append(data))
  _land_delivery(cm, p, ChargeMechanic.ID, 1.0, it)
  assert_true(seen.is_empty(), 'charging an already-full bar published no APPLIED event')
