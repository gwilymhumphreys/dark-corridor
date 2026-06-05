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
