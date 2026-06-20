extends GutTest
## CombatManager → CombatLog wiring (Step 2 of docs/plans/combat_log.md): the manager
## direct-writes the optional combat_log at each mutation site — fire, direct damage,
## DoT damage, heal, shield (block), other statuses, and throws — side-aware and with
## timestamps. Drives real fights with a log attached and asserts what it captured.


const PLAYER := CombatLog.Side.PLAYER
const ENEMY := CombatLog.Side.ENEMY

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


# --- helpers ----------------------------------------------------------------

func _spawn(max_hp: float, item_ids: Array, name: String = '') -> Actor:
  var a := Actor.new(max_hp)
  a.display_name = name
  for id in item_ids:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  return a


func _manager_with_log(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  cm.start()
  cm.combat_log = CombatLog.new()   # the run screen / autotest attach one after start()
  return cm


func _name_of(side: int, log: CombatLog) -> Dictionary:
  var by := {}
  for r in log.summary(side):
    by[r['name']] = r
  return by


# --- the six sites + throw, end-to-end --------------------------------------

func test_a_full_fight_logs_fires_damage_block_and_dot() -> void:
  # Player: Rusted Blade (direct damage), Iron Guard (block), Venom Fang (poison DoT).
  # Enemy: Claw (direct damage to the player).
  var p := _spawn(Balance.PLAYER_START_HP,
      [ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER], 'Wanderer')
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW], 'Corridor Grunt')
  var cm := _manager_with_log(p, [e])
  cm.run_headless()
  var log: CombatLog = cm.combat_log
  var player_rows := _name_of(PLAYER, log)

  # Fire (site 1) — every player item that fired is counted.
  assert_gt(player_rows.get('Rusted Blade', {}).get('fires', 0), 0, 'the blade fired')
  assert_gt(player_rows.get('Iron Guard', {}).get('fires', 0), 0, 'the guard fired')
  assert_gt(player_rows.get('Venom Fang', {}).get('fires', 0), 0, 'the fang fired')

  # Direct damage (site 2) — the blade's hits land on the enemy.
  assert_gt(float(player_rows['Rusted Blade']['damage']), 0.0, 'direct damage logged to the blade')

  # Shield (site 5) — Iron Guard's block, by BlockStatus.ID (not a literal).
  assert_gt(float(player_rows['Iron Guard']['block']), 0.0, 'block logged to the guard')

  # DoT damage (site 3) — Venom Fang's poison ticks credited to it directly.
  assert_gt(float(player_rows['Venom Fang']['damage']), 0.0, 'DoT damage credited to its applier')

  # Other status (site 6) — poison APPLIED is counted (separate from its tick damage).
  assert_gt(player_rows['Venom Fang']['statuses'], 0, 'the poison application is counted')

  # Totals split by side: the player dealt damage; the player also took the enemy's Claw.
  assert_gt(float(log.total_damage_dealt[PLAYER]), 0.0, 'player-side dealt total')
  assert_gt(float(log.total_block[PLAYER]), 0.0, 'player-side block total')


func test_enemy_damage_is_logged_on_the_enemy_side() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [], 'Wanderer')   # player deals nothing
  var e := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW], 'Corridor Grunt')
  var cm := _manager_with_log(p, [e])
  # Step a handful of times; the enemy claws the player (player never wins — it has no board).
  for _i in 200:
    if cm.is_resolved():
      break
    cm.sim_step()
  var log: CombatLog = cm.combat_log
  var enemy_rows := _name_of(ENEMY, log)
  assert_gt(float(enemy_rows.get('Claw', {}).get('damage', 0.0)), 0.0, 'the enemy Claw is logged enemy-side')
  assert_gt(float(log.total_damage_taken[PLAYER]), 0.0, 'the player took damage (taken total, player side)')
  assert_true(_name_of(PLAYER, log).is_empty(), 'the boardless player logged nothing player-side')


func test_heal_is_logged() -> void:
  var p := _spawn(100.0, [], 'Wanderer')
  p.take_damage(40.0)   # at 60 / 100 so a heal restores real HP
  var e := _spawn(1000.0, [], 'Corridor Grunt')
  var cm := _manager_with_log(p, [e])
  var def := ConsumableDef.new()
  def.id = 'test_salve'
  def.name_key = 'Test Salve'
  var effect := ItemEffect.new()
  effect.kind = Delivery.Kind.HEAL
  effect.value = 15.0
  effect.shape = ItemEffect.Shape.SELF
  effect.travel = 0.0
  def.effects = [effect]
  cm.throw_consumable(Consumable.new(def), p)
  var log: CombatLog = cm.combat_log
  # A thrown consumable has no source ITEM, so its heal credits the SOURCELESS bucket;
  # what matters is the heal total + the timeline event.
  assert_gt(float(log.total_healing[PLAYER]), 0.0, 'healing logged on the thrower side')
  var saw_heal := false
  for ev in log.events:
    if ev['type'] == 'heal':
      saw_heal = true
  assert_true(saw_heal, 'a heal event is in the timeline')


func test_throw_is_logged_with_its_def_id() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [], 'Wanderer')
  var e := _spawn(1000.0, [], 'Corridor Grunt')
  var cm := _manager_with_log(p, [e])
  var def := ConsumableDef.new()
  def.id = 'test_dart'
  def.name_key = 'Test Dart'
  var effect := ItemEffect.new()
  effect.kind = Delivery.Kind.DAMAGE
  effect.value = 5.0
  effect.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  effect.travel = 0.0
  def.effects = [effect]
  cm.throw_consumable(Consumable.new(def), p)
  var log: CombatLog = cm.combat_log
  var saw_throw := false
  for ev in log.events:
    if ev['type'] == 'throw' and ev['data'] == 'test_dart' and ev['source_side'] == PLAYER:
      saw_throw = true
  assert_true(saw_throw, 'the throw is in the timeline carrying its consumable id + thrower side')


# --- null-guard: no log attached is harmless --------------------------------

func test_no_log_attached_runs_clean() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON], 'Wanderer')
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW], 'Corridor Grunt')
  var cm := CombatManager.new(p, [e])
  _made.append(cm)
  cm.start()
  # combat_log left null (the sandbox / most tests): every write is null-guarded.
  var steps := cm.run_headless()
  assert_gt(steps, 0, 'a fight with no log attached resolves normally')
  assert_null(cm.combat_log, 'the log stays unset')


# --- the timeline records in sim order with timestamps ----------------------

func test_timeline_is_ordered_and_timestamped() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON], 'Wanderer')
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW], 'Corridor Grunt')
  var cm := _manager_with_log(p, [e])
  cm.run_headless()
  var events: Array = cm.combat_log.events
  assert_gt(events.size(), 0, 'the fight produced timeline events')
  var last_t: float = -1.0
  for ev in events:
    assert_true(ev['t'] >= last_t, 'timestamps are non-decreasing (sim order)')
    last_t = ev['t']
