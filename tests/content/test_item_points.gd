extends GutTest
## Item and enemy pricing in points (docs/design/item_heuristics.md). Checks the budget curve
## against the anchors the doc quotes, and checks that each mechanic's exchange rate is applied,
## so a change to a rate that breaks an authored item shows up here.

const TOLERANCE: float = 0.1


func test_budget_matches_the_documented_anchors() -> void:
  assert_almost_eq(ItemPoints.budget(2.0), 9.9, TOLERANCE, '2s budget')
  assert_almost_eq(ItemPoints.budget(5.0), 50.2, TOLERANCE, '5s budget')
  assert_almost_eq(ItemPoints.budget(7.0), 100.0, TOLERANCE, '7s budget')


func test_rate_rises_with_cooldown_and_flattens() -> void:
  assert_lt(ItemPoints.rate(1.0), ItemPoints.rate(4.0), 'rate rises')
  assert_lt(ItemPoints.rate(4.0), ItemPoints.rate(10.0), 'rate keeps rising')
  assert_lt(ItemPoints.rate(30.0), Balance.POINTS_RATE_CEILING, 'rate stays under the ceiling')
  # The rise decelerates: the gain from 10s to 20s is smaller than from 1s to 10s.
  assert_lt(ItemPoints.rate(20.0) - ItemPoints.rate(10.0), ItemPoints.rate(10.0) - ItemPoints.rate(1.0))


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


func test_parked_and_unpriced_effects_add_nothing() -> void:
  # Druid Staff is 10 damage plus a Spores application. Spores are free, so it spends 10.
  assert_almost_eq(ItemPoints.spend(ItemCatalog.get_def('druid_staff')), 10.0, TOLERANCE)


func test_spend_of_a_null_def_is_zero() -> void:
  assert_eq(ItemPoints.spend(null), 0.0)


func test_enemy_points_are_health_plus_its_items() -> void:
  var def: EnemyDef = EnemyCatalog.get_def('grunt')
  var items: float = 0.0
  for id: String in def.item_ids:
    items += ItemPoints.spend(ItemCatalog.get_def(id))
  assert_almost_eq(def.points(), def.max_hp + items, TOLERANCE)
  assert_gt(def.points(), def.max_hp, 'an armed enemy is worth more than its health')
