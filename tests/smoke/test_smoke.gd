extends GutTest
## Smoke test: proves the GUT harness runs headlessly and that the Balance
## constants file loads. Delete or fold into real suites once the spine exists.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_harness_runs() -> void:
  assert_eq(1 + 1, 2, 'GUT harness is wired up')


func test_balance_constants_present() -> void:
  assert_gt(Balance.STEP, 0.0, 'STEP is a positive fixed timestep')
  assert_eq(Balance.BATTLE_SPEEDS.size(), 3, 'three battle-speed settings')
