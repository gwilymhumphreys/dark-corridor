extends GutTest
## Item and enemy pricing in points (docs/design/item_heuristics.md). Checks the budget curve
## against the anchors the doc quotes, and checks that each mechanic's exchange rate is applied,
## so a change to a rate that breaks an authored item shows up here.

const TOLERANCE: float = 0.1


func test_rate_at_the_baseline_cooldown_is_the_baseline_rate() -> void:
  assert_almost_eq(ItemPoints.rate(Balance.POINTS_RATE_BASELINE_COOLDOWN), Balance.POINTS_RATE_AT_BASELINE, TOLERANCE)


func test_budget_is_rate_times_cooldown() -> void:
  assert_almost_eq(ItemPoints.budget(6.0), 6.0 * ItemPoints.rate(6.0), TOLERANCE)


func test_rarer_items_get_a_larger_budget() -> void:
  var common: float = ItemPoints.budget(4.0)
  assert_almost_eq(ItemPoints.budget(4.0, ItemDef.Rarity.COMMON), common, TOLERANCE, 'common is the default')
  assert_almost_eq(ItemPoints.budget(4.0, ItemDef.Rarity.UNCOMMON), common * Balance.POINTS_UNCOMMON_MULTIPLIER, TOLERANCE)
  assert_almost_eq(ItemPoints.budget(4.0, ItemDef.Rarity.RARE), common * Balance.POINTS_RARE_MULTIPLIER, TOLERANCE)


func test_rate_rises_in_a_straight_line() -> void:
  # Each second of cooldown adds the same amount to the rate, however slow the item.
  var early: float = ItemPoints.rate(2.0) - ItemPoints.rate(1.0)
  var late: float = ItemPoints.rate(21.0) - ItemPoints.rate(20.0)
  assert_almost_eq(early, Balance.POINTS_RATE_PER_SECOND, TOLERANCE)
  assert_almost_eq(late, Balance.POINTS_RATE_PER_SECOND, TOLERANCE)


func test_single_target_damage_is_one_point_each() -> void:
  # Capped Cudgel is 10 damage on 2s, the anchor the whole curve is built on.
  assert_almost_eq(ItemPoints.spend(ItemCatalog.get_def('capped_cudgel')), 10.0, TOLERANCE)


func test_shield_costs_more_than_damage() -> void:
  # Femur is 8 self-shield, so 8 x POINTS_PER_SHIELD.
  var expected: float = 8.0 * Balance.POINTS_PER_SHIELD
  assert_almost_eq(ItemPoints.spend(ItemCatalog.get_def('femur')), expected, TOLERANCE)


func test_self_damage_is_a_credit() -> void:
  # Flensing Hook damages its own holder and creates chunks. The chunks are unpriced, so its spend
  # is the self-damage credit alone, which is negative.
  assert_lt(ItemPoints.spend(ItemCatalog.get_def('flensing_hook')), 0.0)


func test_bleed_uses_the_triangular_total() -> void:
  # Bone Spear is 6 damage plus 3 bleed; 3 stacks bite for 3 + 2 + 1 = 6 over three attacks.
  var expected: float = 6.0 * Balance.POINTS_PER_DAMAGE + 6.0 * Balance.POINTS_PER_BLEED_DAMAGE
  assert_almost_eq(ItemPoints.spend(ItemCatalog.get_def('bone_spear')), expected, TOLERANCE)


func test_an_empowered_stack_costs_its_points_rate() -> void:
  # Mighty Blow adds one stack.
  assert_almost_eq(ItemPoints.spend(ItemCatalog.get_def('mighty_blow')), Balance.POINTS_PER_EMPOWERED_STACK, TOLERANCE)


func test_parked_and_unpriced_effects_add_nothing() -> void:
  # Druid Staff is 10 damage plus a Spores application. Spores are free, so it spends 10.
  assert_almost_eq(ItemPoints.spend(ItemCatalog.get_def('druid_staff')), 10.0, TOLERANCE)


func test_a_trigger_costs_its_seconds_times_the_expected_count_at_the_item_budget_rate() -> void:
  var def := ItemDef.new()
  def.cooldown = 5.0
  def.rarity = ItemDef.Rarity.UNCOMMON
  def.trigger_subs = [{'event': EventBus.Event.APPLIED, 'seconds': 1.0, 'filter': 'poison'}]
  var per_second: float = ItemPoints.budget(def.cooldown, def.rarity) / def.cooldown
  var expected: float = 1.0 * Balance.POINTS_TRIGGERS_PER_COOLDOWN * per_second
  assert_almost_eq(ItemPoints.trigger_points(def, def.trigger_subs[0]), expected, TOLERANCE)
  assert_almost_eq(ItemPoints.spend(def), expected, TOLERANCE, 'spend adds the trigger')


func test_spend_of_a_null_def_is_zero() -> void:
  assert_eq(ItemPoints.spend(null), 0.0)


func test_enemy_points_are_health_plus_its_items() -> void:
  var def: EnemyDef = EnemyCatalog.get_def('grunt')
  var items: float = 0.0
  for id: String in def.item_ids:
    items += ItemPoints.spend(ItemCatalog.get_def(id))
  assert_almost_eq(def.points(), def.max_hp + items, TOLERANCE)
  assert_gt(def.points(), def.max_hp, 'an armed enemy is worth more than its health')
