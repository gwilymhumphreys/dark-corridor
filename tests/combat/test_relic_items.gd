extends GutTest
## Relic items in a fight (docs/systems/content.md → Relic): an Actor's `relics` fire when a trigger
## fills their bar, on the next step, never by time; `fires_per_fight` limits them; a relic firing
## is not an item firing (no ITEM_FIRED, no Empowered stack used) but its effects publish as usual;
## FIGHT_START and DAMAGE_TAKEN publish; board-wide effects never pick a relic; an enemy's relics
## come from its def.


var _made: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for cm in _made:
    if is_instance_valid(cm):
      cm.teardown()
      cm.free()
  _made.clear()
  FixtureContent.uninstall()
  TestCleanup.reset_all_managers()


# --- helpers (not test_*; GUT ignores them) ---------------------------------

func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  TestCleanup.dissolve_at_reset(p)
  for e in enemy_list:
    TestCleanup.dissolve_at_reset(e)
  return cm


## A relic def with one effect and one trigger.
func _relic(effect: ItemEffect, sub: Dictionary, fires_per_fight: int = 0) -> RelicDef:
  var d := RelicDef.new()
  d.id = 'test_relic'
  d.name_key = 'Test Relic'
  d.effects = [effect]
  d.trigger_subs = [sub]
  d.fires_per_fight = fires_per_fight
  return d


func _give(actor: Actor, def: RelicDef) -> Item:
  var it := Item.new(def, actor)
  actor.relics.append(it)
  return it


func _steps(cm: CombatManager, n: int) -> void:
  for i in n:
    cm.sim_step()


# --- firing -------------------------------------------------------------------

func test_a_fight_start_relic_fires_once_on_step_two() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var relic := _give(p, _relic(ItemEffect.shield(5.0), {'event': EventBus.Event.FIGHT_START}))
  var cm := _manager(p, [e])
  cm.start()
  cm.sim_step()
  assert_eq(relic.fires, 0, 'nothing on the first step: the event is published after crossings are collected')
  cm.sim_step()
  assert_eq(relic.fires, 1, 'it fires on step two')
  _steps(cm, 300)
  assert_eq(relic.fires, 1, 'and never again by time')


func test_a_relic_fires_the_step_after_its_event() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var relic := _give(p, _relic(ItemEffect.shield(2.0),
      {'event': EventBus.Event.APPLIED, 'filter': PoisonMechanic.ID}))
  var cm := _manager(p, [e])
  cm.start()
  cm.sim_step()
  cm.bus.publish(EventBus.Event.APPLIED, PoisonMechanic.ID, p)
  assert_eq(relic.fires, 0, 'the event only fills the bar')
  cm.sim_step()
  assert_eq(relic.fires, 1, 'it fires on the next step')
  cm.bus.publish(EventBus.Event.APPLIED, ShieldMechanic.ID, p)
  cm.sim_step()
  assert_eq(relic.fires, 1, 'an event its filter does not match does nothing')


func test_fires_per_fight_limits_a_relic() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var relic := _give(p, _relic(ItemEffect.shield(2.0),
      {'event': EventBus.Event.APPLIED, 'filter': PoisonMechanic.ID}, 1))
  var cm := _manager(p, [e])
  cm.start()
  for i in 3:
    cm.bus.publish(EventBus.Event.APPLIED, PoisonMechanic.ID, p)
    cm.sim_step()
  assert_eq(relic.fires, 1, 'a once-per-fight relic fires the first time only')


## A relic with two trigger entries, each with its own effects: shield 2 when poison is applied, and
## an attack of 4, once per fight, when shield is applied.
func _two_entry_relic() -> RelicDef:
  var d := RelicDef.new()
  d.id = 'test_two_entry_relic'
  d.name_key = 'Test Two Entry Relic'
  d.trigger_subs = [
    {'event': EventBus.Event.APPLIED, 'filter': PoisonMechanic.ID, 'effects': [ItemEffect.shield(2.0)]},
    {'event': EventBus.Event.APPLIED, 'filter': ShieldMechanic.ID, 'effects': [ItemEffect.attack(4.0)],
     'fires_per_fight': 1},
  ]
  return d


func test_each_trigger_entry_fires_only_its_own_effects() -> void:
  var relic := Item.new(_two_entry_relic())
  var first: Array = relic.fire_trigger(0)
  assert_eq(first.size(), 1)
  assert_eq(first[0].mechanic, ShieldMechanic.ID, 'the first entry shields')
  var second: Array = relic.fire_trigger(1)
  assert_eq(second[0].mechanic, AttackMechanic.ID, 'the second entry attacks')
  assert_eq(relic.fires, 2, 'both count for the flash')


func test_trigger_entries_fire_separately_and_together() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var relic := _give(p, _two_entry_relic())
  var cm := _manager(p, [e])
  cm.start()
  cm.sim_step()
  cm.bus.publish(EventBus.Event.APPLIED, PoisonMechanic.ID, p)
  cm.sim_step()
  assert_eq(relic.trigger_fires, [1, 0], 'poison fires only the first entry')
  cm.bus.publish(EventBus.Event.APPLIED, PoisonMechanic.ID, p)
  cm.bus.publish(EventBus.Event.APPLIED, ShieldMechanic.ID, p)
  cm.sim_step()
  assert_eq(relic.trigger_fires, [2, 1], 'both fire when both events happen in one step')
  cm.bus.publish(EventBus.Event.APPLIED, PoisonMechanic.ID, p)
  cm.bus.publish(EventBus.Event.APPLIED, ShieldMechanic.ID, p)
  cm.sim_step()
  assert_eq(relic.trigger_fires, [3, 1], "the second entry's limit stops only that entry")


func test_entries_without_effects_share_the_relics_limit() -> void:
  var d := _relic(ItemEffect.shield(2.0), {'event': EventBus.Event.APPLIED, 'filter': PoisonMechanic.ID}, 1)
  d.trigger_subs.append({'event': EventBus.Event.APPLIED, 'filter': ShieldMechanic.ID})
  var relic := Item.new(d)
  assert_false(relic.trigger_spent(1))
  relic.fire_trigger(0)
  assert_true(relic.trigger_spent(1), "a fire from one entry uses up the relic's shared limit")


func test_a_dead_owners_relic_does_not_fire() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var relic := _give(e, _relic(ItemEffect.shield(2.0), {'event': EventBus.Event.FIGHT_START}))
  var cm := _manager(p, [e])
  cm.start()
  cm.sim_step()
  e.hp = 0
  e.died.emit()
  cm.sim_step()
  assert_eq(relic.fires, 0, 'a relic whose owner died does not fire')


# --- a relic firing is not an item firing ------------------------------------

func test_a_relic_fire_does_not_publish_item_fired() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  _give(p, _relic(ItemEffect.shield(2.0), {'event': EventBus.Event.FIGHT_START}))
  var cm := _manager(p, [e])
  cm.start()
  var fired: Array = []
  cm.bus.add_listener(EventBus.Event.ITEM_FIRED, func(data, _a, _i) -> void: fired.append(data))
  _steps(cm, 2)
  assert_eq(fired, [], 'items that react to an item firing ignore relics')


func test_a_relic_attack_does_not_use_up_empowered() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  _give(p, _relic(ItemEffect.attack(5.0), {'event': EventBus.Event.FIGHT_START}))
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, EmpoweredStatus.ID, 1.0)
  _steps(cm, 2)
  assert_eq(StatusManager.stack_count(p, EmpoweredStatus.ID), 1, 'the Empowered stack is kept for an item')


func test_a_relics_poison_charges_an_item_that_reacts_to_poison() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var relic_def := _relic(ItemEffect.make(PoisonMechanic.ID, 2.0, ItemEffect.Shape.OPPONENT_LEFTMOST),
      {'event': EventBus.Event.FIGHT_START})
  var relic := _give(p, relic_def)
  var watcher_def := ItemDef.new()
  watcher_def.cooldown = 100.0
  watcher_def.effects = [ItemEffect.shield(1.0)]
  watcher_def.trigger_subs = [{'event': EventBus.Event.APPLIED, 'seconds': 10.0, 'filter': PoisonMechanic.ID}]
  var watcher := Item.new(watcher_def, p)
  p.board.append(watcher)
  var cm := _manager(p, [e])
  cm.start()
  _steps(cm, 2)
  var landed: Array = []
  for d in cm._deliveries:
    if d.source == relic and not d.landed:
      landed.append(d)
      cm._land(d)
  assert_eq(landed.size(), 1, 'the relic sent its poison')
  assert_gt(watcher.cooldown.accum, 3.0, 'the poison landing charged the item that reacts to poison')


# --- events ---------------------------------------------------------------------

func test_damage_taken_publishes_for_a_hit_and_a_status() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var seen: Array = []
  cm.bus.add_listener(EventBus.Event.DAMAGE_TAKEN,
      func(data, source_actor, _i) -> void: seen.append([data, source_actor]))
  var hit_def := ItemDef.new()
  hit_def.effects = [ItemEffect.attack(3.0)]
  CombatSteps.fire_and_land(cm, Item.new(hit_def, p))
  assert_eq(seen, [[AttackMechanic.ID, e]], 'a hit publishes DAMAGE_TAKEN with the actor that lost health')
  seen.clear()
  StatusManager.apply(e, PoisonMechanic.ID, 3.0)
  _steps(cm, 120)
  assert_true(seen.size() > 0 and seen[0] == [PoisonMechanic.ID, e], 'a poison tick publishes it too')


# --- targeting ----------------------------------------------------------------

func test_board_wide_effects_never_pick_a_relic() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(1000.0)
  var relic := _give(p, _relic(ItemEffect.shield(2.0), {'event': EventBus.Event.FIGHT_START}))
  var cm := _manager(p, [e])
  cm.start()
  assert_false(relic in cm._all_own_items(p), 'a relic is not one of its owner\'s items')


# --- enemies ------------------------------------------------------------------

func test_an_enemy_def_builds_its_relics() -> void:
  FixtureContent.install()
  var def := EnemyDef.new()
  def.relic_ids = [FixtureKit.SHIELD_RELIC_ID]
  var e: Actor = def.make_actor()
  TestCleanup.dissolve_at_reset(e)
  assert_eq(e.relics.size(), 1, 'the enemy holds an item for its relic')
  assert_eq(e.relics[0].owner, e, 'owned by the enemy')
  assert_true(e.board.is_empty(), 'and not on its board')
