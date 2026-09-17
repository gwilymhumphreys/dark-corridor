extends GutTest
## Step 3 of docs/plans/mechanics.md — poison as a mechanic, and burn + regen (statuses,
## mechanics, colours, constants). Poison drains shield double, burn half; regen heals each
## tick and never expires. The registry knows all three, and a poison mechanic effect still
## publishes APPLIED with 'poison' (Spite Ward's trigger depends on it).


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

func _find(a: Actor, id: String) -> StatusEffect:
  for s in a.statuses:
    if s.id == id:
      return s
  return null


func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  TestCleanup.dissolve_at_reset(p)
  return cm


# --- Poison: double shield ---------------------------------------------------

func test_poison_hit_uses_double_shield() -> void:
  # The plan's example: 10 poison damage against 30 shield removes 20 shield, no health.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 30.0)
  a.take_damage(10.0, 0, PoisonMechanic.ID)
  assert_almost_eq(_find(a, 'shield').count, 10.0, 0.0001, '30 - 10 x 2 = 10 shield left')
  assert_almost_eq(a.hp, 100.0, 0.0001, 'no health lost')


func test_poison_hit_exhausts_shield_and_leaks_the_rest() -> void:
  # Against 6 shield the pool covers 3 damage (6 / 2) and is used up; 7 goes to health.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 6.0)
  a.take_damage(10.0, 0, PoisonMechanic.ID)
  assert_null(_find(a, 'shield'), 'the shield pool is removed once emptied')
  assert_almost_eq(a.hp, 93.0, 0.0001, '10 - 3 covered = 7 health lost')


# --- Burn: ticks + half shield ------------------------------------------------

func test_burn_ticks_for_stacks_and_uses_half_shield() -> void:
  # 10 burn stacks tick for 10 x BURN_DAMAGE_PER_TICK; the shield spends half of it (m = 0.5),
  # so 30 shield covers the full 10 and is left at 25, and the burn loses one stack.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 30.0)
  var b := StatusManager.apply(a, 'burn', 10.0)
  var interval := int(b.ticker.threshold)
  for _i in interval:
    StatusManager.advance_status(b, a)
  assert_almost_eq(a.hp, 100.0, 0.0001, 'the shield covered the tick')
  var tick_damage: float = 10.0 * Balance.BURN_DAMAGE_PER_TICK
  assert_almost_eq(_find(a, 'shield').count, 30.0 - tick_damage * Balance.SHIELD_MULTIPLIER_BURN, 0.0001,
      '10 burn damage against 30 shield leaves 25 (the half multiplier)')
  assert_almost_eq(b.count, 9.0, 0.0001, 'the burn lost one stack')


func test_burn_tick_without_shield_drops_health() -> void:
  var a := Actor.new(100.0)
  var b := StatusManager.apply(a, 'burn', 3.0)
  var interval := int(b.ticker.threshold)
  for _i in interval:
    StatusManager.advance_status(b, a)
  assert_almost_eq(a.hp, 100.0 - 3.0 * Balance.BURN_DAMAGE_PER_TICK, 0.0001,
      'the tick dealt stacks x BURN_DAMAGE_PER_TICK to health')


# --- Regen: heals each tick, never expires ------------------------------------

func test_regen_heals_each_tick_and_never_expires() -> void:
  var a := Actor.new(100.0)
  a.take_damage(40.0)   # at 60 / 100 so a heal restores real HP
  var r := StatusManager.apply(a, 'regen', 3.0)
  var interval := int(r.ticker.threshold)
  for _tick in 3:
    for _i in interval:
      assert_false(StatusManager.advance_status(r, a), 'regen never reports expiry')
  assert_almost_eq(a.hp, 60.0 + 3.0 * 3.0 * Balance.REGEN_HEAL_PER_TICK, 0.0001,
      'three ticks healed stacks x REGEN_HEAL_PER_TICK each')
  assert_almost_eq(r.count, 3.0, 0.0001, 'regen keeps all its stacks after several ticks')
  assert_true(a.statuses.has(r), 'and the status is still on the actor')


# --- Regen tick in a running CombatManager is logged as a heal ----------------

func test_regen_tick_in_a_running_combat_manager_is_logged_as_a_heal() -> void:
  var p := Actor.new(100.0)
  p.display_name = 'Wanderer'
  p.take_damage(40.0)   # at 60 / 100
  # A self-regen: the holder is its own source, so the heal credits the player side.
  StatusManager.apply(p, 'regen', 2.0, 0.0, p)
  var e := Actor.new(1000.0)
  e.display_name = 'Corridor Grunt'
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  cm.combat_log = CombatLog.new()   # the run screen / autotest attach one after start()
  var r: StatusEffect = _find(p, 'regen')
  # Step exactly one full regen tick (the ticker's threshold steps), so the player heals once.
  for _i in int(r.ticker.threshold):
    cm.sim_step()
  assert_almost_eq(p.hp, 60.0 + 2.0 * Balance.REGEN_HEAL_PER_TICK, 0.0001, 'the regen tick healed the player')
  assert_almost_eq(_find(p, 'regen').count, 2.0, 0.0001, 'and it kept its stacks')
  var log: CombatLog = cm.combat_log
  assert_gt(float(log.total_healing[CombatLog.Side.PLAYER]), 0.0, 'the heal is tallied on the player side')
  var saw_heal := false
  for ev in log.events:
    if ev['type'] == 'heal' and ev['source'] == 'Regen' and ev['source_side'] == CombatLog.Side.PLAYER:
      saw_heal = true
  assert_true(saw_heal, 'a regen heal event is in the timeline, sourced by the status name')


# --- A poison mechanic effect applies poison and still publishes APPLIED --------

func test_poison_mechanic_effect_applies_poison_and_publishes_applied() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var cm := _manager(p, [e])
  cm.start()
  var def := ItemDef.new()
  var effect := ItemEffect.new()
  effect.mechanic = PoisonMechanic.ID
  effect.value = 3.0
  effect.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  effect.travel = 0.0
  def.effects = [effect]
  var applied_data: Array = []
  cm.bus.add_listener(EventBus.Event.APPLIED,
      func(data, _source_actor, _source_item) -> void:
        applied_data.append(data))
  var arrived: Array = []
  cm._fire_item(Item.new(def, p), arrived)
  for d in arrived:
    cm._land(d)
  assert_true(_has_status(e, 'poison'), 'the poison mechanic effect applied the poison status')
  assert_almost_eq(_find(e, 'poison').count, 3.0, 0.0001, 'with the delivery value as its count')
  assert_true(applied_data.has('poison'), 'it still publishes APPLIED with the poison id (Spite Ward)')


func _has_status(actor: Actor, id: String) -> bool:
  for s in actor.statuses:
    if s.id == id:
      return true
  return false


# --- The registry knows all three, and the multipliers are the Balance constants --

func test_registries_have_poison_burn_and_regen() -> void:
  assert_true(MechanicRegistry.has(PoisonMechanic.ID), 'poison is registered')
  assert_true(MechanicRegistry.has(BurnMechanic.ID), 'burn is registered')
  assert_true(MechanicRegistry.has(RegenMechanic.ID), 'regen is registered')
  assert_true(StatusRegistry.has('poison'), 'the poison status is registered')
  assert_true(StatusRegistry.has('burn'), 'the burn status is registered')
  assert_true(StatusRegistry.has('regen'), 'the regen status is registered')


func test_shield_multipliers_return_the_balance_constants() -> void:
  assert_almost_eq(MechanicRegistry.shield_multiplier(PoisonMechanic.ID), Balance.SHIELD_MULTIPLIER_POISON, 0.0001, 'poison')
  assert_almost_eq(MechanicRegistry.shield_multiplier(BurnMechanic.ID), Balance.SHIELD_MULTIPLIER_BURN, 0.0001, 'burn')
  assert_almost_eq(MechanicRegistry.shield_multiplier(RegenMechanic.ID), 1.0, 0.0001, 'regen uses the default')


func test_statuses_copy_their_presentation_from_the_mechanic() -> void:
  for mechanic_id in [PoisonMechanic.ID, BurnMechanic.ID, RegenMechanic.ID]:
    var mechanic: Mechanic = MechanicRegistry.get_mechanic(mechanic_id)
    var status: StatusEffect = StatusRegistry.create(mechanic_id)
    assert_eq(status.name_key, mechanic.name_key, mechanic_id + ' name')
    assert_eq(status.desc_key, mechanic.desc_key, mechanic_id + ' description')
    assert_eq(status.icon, mechanic.icon, mechanic_id + ' icon')
