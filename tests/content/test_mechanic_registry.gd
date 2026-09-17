extends GutTest
## The mechanic registry (docs/plans/mechanics.md): one shared Mechanic instance per id, built
## lazily like the StatusRegistry. This run registers attack, heal and shield; the rest join as
## their mechanics are converted.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_has_is_true_for_the_registered_ids_and_false_for_the_rest() -> void:
  assert_true(MechanicRegistry.has(AttackMechanic.ID), 'attack is registered')
  assert_true(MechanicRegistry.has(HealMechanic.ID), 'heal is registered')
  assert_true(MechanicRegistry.has(ShieldMechanic.ID), 'shield is registered')
  assert_false(MechanicRegistry.has('poison'), 'poison is not registered yet')
  assert_false(MechanicRegistry.has(''), 'an empty id is not registered')


func test_get_mechanic_returns_the_right_class() -> void:
  assert_true(MechanicRegistry.get_mechanic(AttackMechanic.ID) is AttackMechanic, 'attack')
  assert_true(MechanicRegistry.get_mechanic(HealMechanic.ID) is HealMechanic, 'heal')
  assert_true(MechanicRegistry.get_mechanic(ShieldMechanic.ID) is ShieldMechanic, 'shield')


func test_get_mechanic_returns_the_same_shared_instance() -> void:
  var first: Mechanic = MechanicRegistry.get_mechanic(ShieldMechanic.ID)
  var second: Mechanic = MechanicRegistry.get_mechanic(ShieldMechanic.ID)
  assert_eq(first, second, 'one shared instance per id')


func test_shield_multiplier_defaults_to_one() -> void:
  assert_almost_eq(MechanicRegistry.shield_multiplier(AttackMechanic.ID), 1.0, 0.0001, 'attack uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier(''), 1.0, 0.0001, 'an empty id uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier('poison'), 1.0, 0.0001, 'an unknown id uses the default')


func test_each_mechanic_colour_matches_its_colours_variable() -> void:
  assert_eq(MechanicRegistry.get_mechanic(AttackMechanic.ID).color(), Colours.ATTACK, 'attack')
  assert_eq(MechanicRegistry.get_mechanic(HealMechanic.ID).color(), Colours.HEAL, 'heal')
  assert_eq(MechanicRegistry.get_mechanic(ShieldMechanic.ID).color(), Colours.SHIELD, 'shield')
