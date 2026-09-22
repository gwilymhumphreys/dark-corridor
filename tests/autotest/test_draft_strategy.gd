extends GutTest
## Phase 5 Step 1 — the autotest draft strategies: family preference, synergy
## preference, seeded reproducibility, and divergence between strategies. These are
## the `tune` "build viability" lever (play different builds headlessly).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_first_viable_takes_index_0() -> void:
  var driver := AutoTestDriver.new('first-viable', 1)
  assert_eq(driver.choose_draft([FixtureItems.shield(), FixtureItems.attack()], []), 0)


func test_damage_strategy_prefers_a_damage_candidate() -> void:
  var driver := AutoTestDriver.new('damage', 1)
  # ARMOR (shield) at 0, WEAPON (damage) at 1 → the damage strategy takes index 1.
  assert_eq(driver.choose_draft([FixtureItems.shield(), FixtureItems.attack()], []), 1)


func test_shield_strategy_prefers_a_shield_candidate() -> void:
  var driver := AutoTestDriver.new('shield', 1)
  assert_eq(driver.choose_draft([FixtureItems.attack(), FixtureItems.shield()], []), 1)


func test_greedy_synergy_prefers_a_connecting_candidate() -> void:
  # The board applies poison; the fixture trigger item charges on poison being applied — so
  # greedy-synergy connects them over a non-synergistic weapon.
  var owner_actor := Actor.new(100.0)
  var board: Array = [Item.new(FixtureItems.poison(), owner_actor)]
  var driver := AutoTestDriver.new('greedy-synergy', 1)
  # WEAPON (no synergy) at 0, the trigger item (synergy) at 1 → pick index 1.
  assert_eq(driver.choose_draft([FixtureItems.attack(), FixtureItems.poison_trigger()], board), 1)


func test_random_is_reproducible_for_a_seed() -> void:
  var offer: Array = [FixtureItems.attack(), FixtureItems.shield(), FixtureItems.poison()]
  var a := AutoTestDriver.new('random', 42)
  var b := AutoTestDriver.new('random', 42)
  assert_eq(a.choose_draft(offer, []), b.choose_draft(offer, []), 'same seed → same pick')


func test_strategies_can_diverge() -> void:
  var offer: Array = [FixtureItems.attack(), FixtureItems.shield()]
  var damage := AutoTestDriver.new('damage', 1)
  var shield := AutoTestDriver.new('shield', 1)
  assert_ne(damage.choose_draft(offer, []), shield.choose_draft(offer, []), 'damage vs shield pick differently')
