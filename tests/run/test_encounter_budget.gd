extends GutTest
## Encounter assembly against a points target (docs/plans/encounter_points_budget.md). Checks the
## target curve's shape, that a generated fight reaches its target within the enemy limit, that a
## boss keeps its authored composition, and that the drawn set survives a save and reload.

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


func test_every_act_pool_id_resolves() -> void:
  # The pools are empty until the owner authors them, which leaves the generator dormant. Whatever
  # goes into them has to resolve, so a typo fails here instead of crashing mid-spawn.
  for act: int in range(RunMap.ACTS):
    var pool: Array[String] = RunMap.enemy_pool(act)
    var unknown: Array[String] = []
    for id: String in pool:
      if not EnemyCatalog.has(id):
        unknown.append(id)
    assert_eq(unknown, [] as Array[String], 'act %d pool ids all resolve' % act)


func test_an_empty_pool_draws_nothing() -> void:
  # A fight with no pool keeps its EncounterDef's authored enemy_ids, so the generator is dormant
  # rather than drawing wrong-sized enemies.
  var rng := RandomNumberGenerator.new()
  rng.seed = 1
  assert_eq(RunMap.draw_enemies([], 500.0, rng).size(), 0)


func test_a_draw_reaches_its_target_within_the_enemy_limit() -> void:
  var rng := RandomNumberGenerator.new()
  rng.seed = 1234
  var pool: Array[String] = [EnemyCatalog.GRUNT, EnemyCatalog.BRUTE]
  var target: float = 200.0
  var ids: Array[String] = RunMap.draw_enemies(pool, target, rng)
  assert_gt(ids.size(), 0, 'a non-empty pool draws at least one enemy')
  assert_lte(ids.size(), RunMap.MAX_ENEMIES_PER_FIGHT, 'within the enemy limit')
  var total: float = 0.0
  for id: String in ids:
    total += EnemyCatalog.get_def(id).points()
  assert_gt(total, target * (1.0 - Balance.POINTS_TARGET_TOLERANCE), 'reaches the target')


func test_a_draw_stops_at_the_enemy_limit() -> void:
  # A target no pool can reach must still not spawn a sixth enemy.
  var rng := RandomNumberGenerator.new()
  rng.seed = 5
  var ids: Array[String] = RunMap.draw_enemies([EnemyCatalog.GRUNT], 100000.0, rng)
  assert_eq(ids.size(), RunMap.MAX_ENEMIES_PER_FIGHT)


func test_the_pin_overrides_the_draw() -> void:
  RunManager.pinned_enemy_ids = [EnemyCatalog.GRUNT, EnemyCatalog.GRUNT]
  var run: RunManager = RunManager.new()
  run.start(99, CharacterCatalog.DEFAULT)
  assert_eq(run.current_encounter().enemies.size(), 2, 'the pinned composition is used as given')
  run.teardown()
  run.free()


func test_the_drawn_set_survives_a_reload() -> void:
  var run: RunManager = RunManager.new()
  run.start(7, CharacterCatalog.DEFAULT)
  var before: int = run.current_encounter().enemies.size()
  var snap: Dictionary = run.snapshot()
  run.teardown()
  run.free()

  var resumed: RunManager = RunManager.new()
  assert_true(resumed.rehydrate(snap), 'the snapshot rehydrates')
  assert_eq(resumed.current_encounter().enemies.size(), before, 'the same fight comes back')
  resumed.teardown()
  resumed.free()
