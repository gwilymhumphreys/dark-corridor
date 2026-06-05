extends GutTest
## Step 2 — the minimal relic (a combat-start status applier). The catalog builds,
## the def carries its (status_type, count), and applying it through StatusManager
## actually grants the player the status — proving the run-state→combat seam the
## Run manager will use at fight start.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_catalog_builds_the_combat_start_relic() -> void:
  var d := RelicCatalog.get_def(RelicCatalog.Id.STONE_WARD)
  assert_eq(d.kind, RelicDef.Kind.COMBAT_START_STATUS)
  assert_eq(d.status_type, StatusDef.Type.BLOCK, 'Stone Ward grants block')
  assert_gt(d.status_count, 0.0, 'with a positive amount')
  assert_eq(d.name_key, 'Stone Ward')


func test_instance_carries_its_def() -> void:
  var d := RelicCatalog.get_def(RelicCatalog.Id.STONE_WARD)
  var r := Relic.new(d)
  assert_eq(r.def, d, 'the instance holds its definition')


func test_applying_a_combat_start_relic_grants_the_status() -> void:
  # The shape the Run manager uses: at fight start, apply each relic's status to
  # the player Actor via StatusManager.
  var d := RelicCatalog.get_def(RelicCatalog.Id.STONE_WARD)
  var player := Actor.new(100.0)
  StatusManager.apply(player, d.status_type, d.status_count)
  # Block absorbs incoming damage before HP — so the relic block is live.
  player.take_damage(d.status_count - 1.0)
  assert_eq(player.hp, 100.0, 'relic block absorbed the hit; HP untouched')
  player.take_damage(2.0)
  assert_almost_eq(player.hp, 99.0, 0.0001, 'damage past the block pool reaches HP')
