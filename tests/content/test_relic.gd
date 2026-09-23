extends GutTest
## Step 2 — the minimal relic (a combat-start status applier). The def carries its
## (status_type, count), and applying it through StatusManager actually grants the player the
## status — proving the run-state→combat seam the Run manager will use at fight start.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_instance_carries_its_def() -> void:
  var d := FixtureKit.shield_relic()
  var r := Relic.new(d)
  assert_eq(r.def, d, 'the instance holds its definition')


func test_applying_a_combat_start_relic_grants_the_status() -> void:
  # The shape the Run manager uses: at fight start, apply each relic's status to
  # the player Actor via StatusManager.
  var d := FixtureKit.shield_relic()
  var player := Actor.new(100.0)
  StatusManager.apply(player, d.status_id, d.status_count, d.status_duration)
  # Shield absorbs incoming damage before HP — so the relic shield is live.
  player.take_damage(d.status_count - 1.0)
  assert_eq(player.hp, 100, 'relic shield absorbed the hit; HP untouched')
  player.take_damage(2.0)
  assert_eq(player.hp, 99, 'damage past the shield pool reaches HP')
