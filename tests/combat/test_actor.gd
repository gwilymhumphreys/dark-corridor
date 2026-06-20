extends GutTest
## Step 2 — the passive combatant. HP, damage/heal bounds, and a single `died`.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_starts_at_full_hp() -> void:
  var a := Actor.new(50.0)
  assert_eq(a.hp, 50.0, 'starts at max')
  assert_eq(a.max_hp, 50.0)
  assert_true(a.is_alive())


func test_take_damage_reduces_hp() -> void:
  var a := Actor.new(50.0)
  a.take_damage(20.0)
  assert_eq(a.hp, 30.0, 'damage with no block hits HP directly')


func test_heal_caps_at_max() -> void:
  var a := Actor.new(50.0)
  a.take_damage(30.0)
  a.heal(100.0)
  assert_eq(a.hp, 50.0, 'heal does not exceed max_hp')


func test_heal_does_not_revive_the_dead() -> void:
  var a := Actor.new(10.0)
  a.take_damage(10.0)
  assert_false(a.is_alive(), 'dead at 0 HP')
  a.heal(5.0)
  assert_eq(a.hp, 0.0, 'heal cannot bring a corpse back above 0')
  assert_false(a.is_alive(), 'still dead after a heal')


func test_death_emits_once() -> void:
  var a := Actor.new(10.0)
  watch_signals(a)
  a.take_damage(10.0)
  assert_false(a.is_alive(), 'zero HP is dead')
  assert_signal_emit_count(a, 'died', 1, 'died fires on reaching 0')
  a.take_damage(5.0)
  assert_signal_emit_count(a, 'died', 1, 'damaging a corpse does not re-emit died')


# --- return values (Design C — the HP delta for the CombatLog) --------------

func test_take_damage_returns_the_hp_lost() -> void:
  var a := Actor.new(50.0)
  assert_almost_eq(a.take_damage(20.0), 20.0, 0.0001, 'no block: returns the raw amount lost')


func test_take_damage_returns_net_after_block() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, BlockStatus.ID, 8.0)   # absorbs 8 of the incoming hit
  var dealt := a.take_damage(20.0)
  assert_almost_eq(dealt, 12.0, 0.0001, 'block-absorbed damage is excluded from the return')
  assert_eq(a.hp, 38.0, 'and only the net reached HP')


func test_take_damage_returns_capped_on_a_killing_blow() -> void:
  var a := Actor.new(10.0)
  var dealt := a.take_damage(25.0)
  assert_almost_eq(dealt, 10.0, 0.0001, 'a killing blow returns the EFFECTIVE damage, not inflated raw')


func test_take_damage_on_a_corpse_returns_zero() -> void:
  var a := Actor.new(10.0)
  a.take_damage(10.0)
  assert_almost_eq(a.take_damage(5.0), 0.0, 0.0001, 'a corpse takes no damage')


func test_heal_returns_the_hp_restored() -> void:
  var a := Actor.new(50.0)
  a.take_damage(30.0)
  assert_almost_eq(a.heal(12.0), 12.0, 0.0001, 'returns the HP actually restored')


func test_heal_returns_post_cap_amount() -> void:
  var a := Actor.new(50.0)
  a.take_damage(5.0)   # at 45 / 50
  assert_almost_eq(a.heal(100.0), 5.0, 0.0001, 'overheal is excluded: only 5 was restorable')


func test_heal_on_a_corpse_returns_zero() -> void:
  var a := Actor.new(10.0)
  a.take_damage(10.0)
  assert_almost_eq(a.heal(5.0), 0.0, 0.0001, 'a corpse cannot be healed')
