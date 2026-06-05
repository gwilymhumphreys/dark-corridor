extends GutTest
## Step 4 — the per-fight orchestrator. A full deterministic fight, seed-free
## reproducibility, the poison->avenger trigger firing one step later (loop-proof
## synergy), mid-flight fizzle, simultaneous-death-is-loss, and teardown breaking
## the reference cycles.


var _made: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  # Tear each fight down (as the Encounter will) and free the manager Node, so no
  # orphans linger past the test.
  for cm in _made:
    if is_instance_valid(cm):
      cm.teardown()
      cm.free()
  _made.clear()
  TestCleanup.reset_all_managers()


# --- helpers ----------------------------------------------------------------

func _spawn(max_hp: float, item_ids: Array) -> Actor:
  var a := Actor.new(max_hp)
  for id in item_ids:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  return a


func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  return cm


func _has_status(actor: Actor, type: int) -> bool:
  for s in actor.statuses:
    if s.type == type:
      return true
  return false


func _run_basic() -> Dictionary:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.Id.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var steps := cm.run_headless()
  return { 'won': cm._player_won, 'steps': steps, 'hp': p.hp }


# --- tests ------------------------------------------------------------------

func test_player_beats_weaker_enemy() -> void:
  var r := _run_basic()
  assert_true(r['won'], 'player (100 HP) outlasts the grunt (40 HP) at equal output')
  assert_gt(r['steps'], 0, 'the fight took some steps')


func test_fight_is_deterministic() -> void:
  var a := _run_basic()
  var b := _run_basic()
  assert_eq(a['won'], b['won'], 'same winner')
  assert_eq(a['steps'], b['steps'], 'same step count (no RNG in Phase 1)')
  assert_almost_eq(a['hp'], b['hp'], 0.0001, 'identical final HP — bit-reproducible')


func test_poison_trigger_fires_avenger_next_step() -> void:
  # A custom avenger that NEVER fires on its own cooldown, so any block it grants
  # MUST come from the poison trigger.
  var avenger := ItemDef.new()
  avenger.cooldown = 9999.0
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_type = StatusDef.Type.BLOCK
  blk.value = 5.0
  blk.shape = ItemEffect.Shape.SELF
  avenger.effects = [blk]
  avenger.trigger_subs = [{
    'event': EventBus.Event.STATUS_APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': StatusDef.Type.POISON,
  }]

  var p := Actor.new(500.0)
  p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.Id.POISON_DAGGER), p))
  p.board.append(Item.new(avenger, p))
  var e := _spawn(500.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()

  # Step until the poison lands on the enemy.
  var guard := 0
  while not _has_status(e, StatusDef.Type.POISON) and guard < 1000:
    cm.sim_step()
    guard += 1
  assert_true(_has_status(e, StatusDef.Type.POISON), 'poison was applied')
  assert_false(_has_status(p, StatusDef.Type.BLOCK), 'the push does NOT fire the avenger the same step')

  cm.sim_step()
  assert_true(_has_status(p, StatusDef.Type.BLOCK), 'the avenger fires one step later (loop-proof synergy)')


func test_delivery_fizzles_if_target_died() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(10.0)
  var cm := _manager(p, [e])
  cm.start()
  e.take_damage(10.0)   # enemy already dead
  var d := Delivery.new()
  d.kind = Delivery.Kind.DAMAGE
  d.value = 5.0
  d.target = e
  d.travel = Ticker.new(1)
  cm._land(d)
  assert_true(d.fizzled, 'a delivery to a dead target fizzles, applies nothing')


func test_simultaneous_death_is_loss() -> void:
  var p := Actor.new(5.0)
  var e := Actor.new(5.0)
  var cm := _manager(p, [e])
  cm.start()
  watch_signals(cm)
  p.take_damage(5.0)
  e.take_damage(5.0)
  cm._check_resolution()
  assert_signal_emitted(cm, 'resolved')
  assert_eq(get_signal_parameters(cm, 'resolved')[0], false, 'both dead same tick = loss')


func test_deliveries_are_pruned_not_accumulated() -> void:
  # Two unkillable actors trading blows forever: without pruning, every fired
  # Delivery would pile up in _deliveries. With it, only the few in-flight /
  # still-animating at any moment survive — the set stays bounded.
  var p := _spawn(1_000_000.0, [ItemCatalog.Id.WEAPON])
  var e := _spawn(1_000_000.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var peak := 0
  for i in 2000:
    cm.sim_step()
    peak = maxi(peak, cm._deliveries.size())
  assert_false(cm._resolved, 'neither actor dies in this window — the fight is still live')
  assert_lt(peak, 6, 'in-flight + animating Deliveries stay bounded (without pruning this would be ~50+)')


func test_teardown_clears_combat_state() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.Id.POISON_DAGGER])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  cm.run_headless()
  cm.teardown()
  assert_true(p.statuses.is_empty(), 'player combat statuses cleared')
  assert_true(e.statuses.is_empty(), 'enemy combat statuses cleared')
  assert_true(cm._deliveries.is_empty(), 'in-flight deliveries dropped')
