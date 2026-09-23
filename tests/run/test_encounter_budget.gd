extends GutTest
## Encounter assembly against a points target (docs/plans/encounter_points_budget.md). Checks the
## target curve's shape, that a generated fight reaches its target within the enemy limit, that a
## boss takes its act boss list or keeps its authored composition, and that the drawn set survives
## a save and reload.

var _pin_before: Array[String] = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _pin_before = RunManager.pinned_enemy_ids
  RunManager.pinned_enemy_ids = []


func after_each() -> void:
  RunManager.pinned_enemy_ids = _pin_before
  TestCleanup.reset_all_managers()


func test_target_rises_every_beat() -> void:
  var previous: float = 0.0
  for position: int in range(RunMap.TOTAL_BEATS):
    var target: float = RunMap.target_points(position)
    assert_gt(target, previous, 'beat %d target rises' % position)
    previous = target


func test_target_ends_far_above_where_it_starts() -> void:
  # The board grows uncapped and the synergy factor compounds on top, so the last beat is worth
  # many times the first. The exact values are tuning; the order of magnitude is the check.
  var first: float = RunMap.target_points(0)
  var last: float = RunMap.target_points(RunMap.TOTAL_BEATS - 1)
  assert_gt(last, first * 10.0, 'the last beat is worth more than ten times the first')


func test_an_empty_pool_draws_nothing() -> void:
  # A fight with no pool keeps its EncounterDef's authored enemy_ids, so the generator is dormant
  # rather than drawing wrong-sized enemies.
  var rng := RandomNumberGenerator.new()
  rng.seed = 1
  assert_eq(RunMap.draw_enemies([], 500.0, rng).size(), 0)


func test_a_draw_reaches_its_target_within_the_enemy_limit() -> void:
  var rng := RandomNumberGenerator.new()
  rng.seed = 1234
  FixtureContent.install()
  var pool: Array[String] = [FixtureEnemies.ID, FixtureEnemies.BIG_ID]
  var target: float = 200.0
  var ids: Array[String] = RunMap.draw_enemies(pool, target, rng)
  assert_gt(ids.size(), 0, 'a non-empty pool draws at least one enemy')
  assert_lte(ids.size(), RunMap.MAX_ENEMIES_PER_FIGHT, 'within the enemy limit')
  var total: float = 0.0
  for id: String in ids:
    total += EnemyCatalog.get_def(id).points()
  assert_gte(total, target * (1.0 - Balance.POINTS_TARGET_TOLERANCE), 'reaches the target')


func test_a_draw_stops_at_the_enemy_limit() -> void:
  # A target no pool can reach must still not spawn a sixth enemy.
  var rng := RandomNumberGenerator.new()
  rng.seed = 5
  FixtureContent.install()
  var ids: Array[String] = RunMap.draw_enemies([FixtureEnemies.ID], 100000.0, rng)
  assert_eq(ids.size(), RunMap.MAX_ENEMIES_PER_FIGHT)


func test_the_pin_overrides_the_draw() -> void:
  FixtureContent.install()
  RunManager.pinned_enemy_ids = [FixtureEnemies.ID, FixtureEnemies.ID]
  var run: RunManager = RunManager.new()
  run.start(99, FixtureCharacter.ID)
  assert_eq(run.current_encounter().enemies.size(), 2, 'the pinned composition is used as given')
  run.teardown()
  run.free()


func test_the_drawn_set_survives_a_reload() -> void:
  FixtureContent.install()
  var run: RunManager = RunManager.new()
  run.start(7, FixtureCharacter.ID)
  var before: int = run.current_encounter().enemies.size()
  var snap: Dictionary = run.snapshot()
  run.teardown()
  run.free()

  var resumed: RunManager = RunManager.new()
  assert_true(resumed.rehydrate(snap), 'the snapshot rehydrates')
  assert_eq(resumed.current_encounter().enemies.size(), before, 'the same fight comes back')
  resumed.teardown()
  resumed.free()


func test_a_boss_fight_uses_its_act_boss_list() -> void:
  FixtureContent.install()
  EnemyPools._by_act['boss'][0] = [FixtureEnemies.ID, FixtureEnemies.BIG_ID]
  var run: RunManager = _run_at_the_first_boss()
  var enemies: Array = run.current_encounter().enemies
  assert_eq(enemies.size(), 2, 'the boss fight holds the act boss list')
  assert_almost_eq((enemies[1] as Actor).max_hp, FixtureEnemies.BIG_HP, 0.0001, 'in list order')
  run.teardown()
  run.free()


func test_a_boss_fight_keeps_its_authored_enemies_while_the_list_is_empty() -> void:
  FixtureContent.install()
  var run: RunManager = _run_at_the_first_boss()
  var authored: int = EncounterCatalog.get_def('fight_boss').enemy_ids.size()
  assert_eq(run.current_encounter().enemies.size(), authored, 'the encounter keeps its own enemies')
  run.teardown()
  run.free()


func _run_at_the_first_boss() -> RunManager:
  var run: RunManager = RunManager.new()
  run.start(3, FixtureCharacter.ID)
  run.position = RunMap.BOSS_BEAT - 1
  run.advance()
  assert_eq(run.current_encounter().def.id, 'fight_boss', 'the run is at the boss')
  return run
