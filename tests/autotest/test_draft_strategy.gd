extends GutTest
## Phase 5 Step 1 — the autotest draft strategies: family preference, synergy
## preference, seeded reproducibility, and divergence between strategies. These are
## the `tune` "build viability" lever (play different builds headlessly).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _def(id: String) -> ItemDef:
  return ItemCatalog.get_def(id)


func test_first_viable_takes_index_0() -> void:
  var driver := AutoTestDriver.new('first-viable', 1)
  assert_eq(driver.choose_draft([_def(ItemCatalog.ARMOR), _def(ItemCatalog.WEAPON)], []), 0)


func test_damage_strategy_prefers_a_damage_candidate() -> void:
  var driver := AutoTestDriver.new('damage', 1)
  # ARMOR (block) at 0, WEAPON (damage) at 1 → the damage strategy takes index 1.
  assert_eq(driver.choose_draft([_def(ItemCatalog.ARMOR), _def(ItemCatalog.WEAPON)], []), 1)


func test_block_strategy_prefers_a_block_candidate() -> void:
  var driver := AutoTestDriver.new('block', 1)
  assert_eq(driver.choose_draft([_def(ItemCatalog.WEAPON), _def(ItemCatalog.ARMOR)], []), 1)


func test_greedy_synergy_prefers_a_connecting_candidate() -> void:
  # The board applies poison (Venom Fang); the avenger (Spite Ward) triggers on poison
  # being applied — so greedy-synergy connects them over a non-synergistic weapon.
  var owner := Actor.new(100.0)
  var board: Array = [Item.new(_def(ItemCatalog.POISON_DAGGER), owner)]
  var driver := AutoTestDriver.new('greedy-synergy', 1)
  # WEAPON (no synergy) at 0, AVENGER (synergy) at 1 → pick index 1.
  assert_eq(driver.choose_draft([_def(ItemCatalog.WEAPON), _def(ItemCatalog.AVENGER)], board), 1)


func test_random_is_reproducible_for_a_seed() -> void:
  var offer: Array = [_def(ItemCatalog.WEAPON), _def(ItemCatalog.ARMOR), _def(ItemCatalog.POISON_DAGGER)]
  var a := AutoTestDriver.new('random', 42)
  var b := AutoTestDriver.new('random', 42)
  assert_eq(a.choose_draft(offer, []), b.choose_draft(offer, []), 'same seed → same pick')


func test_strategies_can_diverge() -> void:
  var offer: Array = [_def(ItemCatalog.WEAPON), _def(ItemCatalog.ARMOR)]
  var damage := AutoTestDriver.new('damage', 1)
  var block := AutoTestDriver.new('block', 1)
  assert_ne(damage.choose_draft(offer, []), block.choose_draft(offer, []), 'damage vs block pick differently')
