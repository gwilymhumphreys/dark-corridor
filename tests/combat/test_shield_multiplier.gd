extends GutTest
## Shield multipliers through the damage pipeline (docs/systems/mechanics.md → Shield):
## `take_damage` / `resolve_incoming_damage` / `absorb` carry a mechanic id, and the shield pool
## spends the damage times the mechanic's multiplier. The multiplier is exercised with a test-only
## mechanic (a 2.0 shield multiplier) registered in the MechanicRegistry for the duration of the
## suite, so the pipeline is tested independently of any one mechanic's constant.


## A test-only mechanic whose hits drain shield twice as fast.
class TestDoubleMechanic extends Mechanic:
  func _init() -> void:
    id = 'test_double'


  func shield_multiplier() -> float:
    return 2.0


func before_each() -> void:
  TestCleanup.reset_all_managers()
  # Build the registry (so `has` works), then add the test mechanic under its id.
  MechanicRegistry.has(AttackMechanic.ID)
  MechanicRegistry._mechanics['test_double'] = TestDoubleMechanic.new()


func after_each() -> void:
  MechanicRegistry._mechanics.erase('test_double')
  TestCleanup.reset_all_managers()


func test_double_multiplier_drains_shield_twice_as_fast() -> void:
  # The plan's example: 10 damage at m = 2 against 30 shield removes 20 shield, no health.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 30.0)
  a.take_damage(10.0, 0, 'test_double')
  assert_eq(_find(a, 'shield').count, 10, '30 - 10 x 2 = 10 shield left')
  assert_eq(a.hp, 100, 'no health lost')


func test_double_multiplier_exhausts_shield_and_leaks_the_rest() -> void:
  # Against 6 shield the pool covers 3 damage (6 / 2) and is used up; 7 goes to health.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 6.0)
  a.take_damage(10.0, 0, 'test_double')
  assert_null(_find(a, 'shield'), 'the shield pool is removed once emptied')
  assert_eq(a.hp, 93, '10 - 3 covered = 7 health lost')


func test_attack_uses_the_default_multiplier() -> void:
  # 'attack' is registered with the default 1.0 multiplier: 10 against 6 shield removes 6, 4 leaks.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 6.0)
  a.take_damage(10.0, 0, AttackMechanic.ID)
  assert_null(_find(a, 'shield'), 'the shield pool is removed once emptied')
  assert_eq(a.hp, 96, '10 - 6 = 4 health lost')


func test_unblockable_skips_shield_regardless_of_mechanic() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 30.0)
  a.take_damage(10.0, Delivery.Flag.UNBLOCKABLE, 'test_double')
  assert_eq(_find(a, 'shield').count, 30, 'the shield is untouched')
  assert_eq(a.hp, 90, 'the full amount goes to health')


func test_vulnerable_scales_before_shield_absorbs() -> void:
  # Vulnerable (x1.5) amplifies in the amplifier stage, before the shield absorbs: 10 → 15,
  # and the shield spends 15 x 2 = 30 of its 40 — the loss matches the amplified amount.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'vulnerable', 1.0, Balance.STATUS_VULNERABLE_DURATION)
  StatusManager.apply(a, 'shield', 40.0)
  a.take_damage(10.0, 0, 'test_double')
  var amplified: float = 10.0 * Balance.STATUS_VULNERABLE_DAMAGE_MULT
  assert_eq(_find(a, 'shield').count, roundi(40.0 - amplified * 2.0),
      'the shield loss matches the amplified amount times the multiplier')
  assert_eq(a.hp, 100, 'the shield covered the amplified hit')


func test_no_mechanic_id_behaves_as_multiplier_one() -> void:
  # The default empty mechanic id uses the 1.0 multiplier — the pre-mechanic behaviour.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'shield', 6.0)
  a.take_damage(10.0)
  assert_null(_find(a, 'shield'), 'the shield pool is removed once emptied')
  assert_eq(a.hp, 96, '10 - 6 = 4 health lost')


# --- helpers (not test_*; GUT ignores them) ---

func _find(a: Actor, id: String) -> StatusEffect:
  for s in a.statuses:
    if s.id == id:
      return s
  return null
