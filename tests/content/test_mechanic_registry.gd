extends GutTest
## The mechanic registry (docs/systems/mechanics.md): one shared Mechanic instance per id, built
## lazily like the StatusRegistry. This run registers all eight: attack, heal, shield, poison,
## burn, bleed, regen and crit.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_has_is_true_for_the_registered_ids_and_false_for_the_rest() -> void:
  assert_true(MechanicRegistry.has(AttackMechanic.ID), 'attack is registered')
  assert_true(MechanicRegistry.has(HealMechanic.ID), 'heal is registered')
  assert_true(MechanicRegistry.has(ShieldMechanic.ID), 'shield is registered')
  assert_true(MechanicRegistry.has(PoisonMechanic.ID), 'poison is registered')
  assert_true(MechanicRegistry.has(BurnMechanic.ID), 'burn is registered')
  assert_true(MechanicRegistry.has(RegenMechanic.ID), 'regen is registered')
  assert_true(MechanicRegistry.has(BleedMechanic.ID), 'bleed is registered')
  assert_true(MechanicRegistry.has(CritMechanic.ID), 'crit is registered')
  assert_false(MechanicRegistry.has(''), 'an empty id is not registered')


func test_get_mechanic_returns_the_right_class() -> void:
  assert_true(MechanicRegistry.get_mechanic(AttackMechanic.ID) is AttackMechanic, 'attack')
  assert_true(MechanicRegistry.get_mechanic(HealMechanic.ID) is HealMechanic, 'heal')
  assert_true(MechanicRegistry.get_mechanic(ShieldMechanic.ID) is ShieldMechanic, 'shield')
  assert_true(MechanicRegistry.get_mechanic(PoisonMechanic.ID) is PoisonMechanic, 'poison')
  assert_true(MechanicRegistry.get_mechanic(BurnMechanic.ID) is BurnMechanic, 'burn')
  assert_true(MechanicRegistry.get_mechanic(RegenMechanic.ID) is RegenMechanic, 'regen')
  assert_true(MechanicRegistry.get_mechanic(BleedMechanic.ID) is BleedMechanic, 'bleed')
  assert_true(MechanicRegistry.get_mechanic(CritMechanic.ID) is CritMechanic, 'crit')


func test_get_mechanic_returns_the_same_shared_instance() -> void:
  var first: Mechanic = MechanicRegistry.get_mechanic(ShieldMechanic.ID)
  var second: Mechanic = MechanicRegistry.get_mechanic(ShieldMechanic.ID)
  assert_eq(first, second, 'one shared instance per id')


func test_shield_multiplier_defaults_to_one() -> void:
  assert_almost_eq(MechanicRegistry.shield_multiplier(AttackMechanic.ID), 1.0, 0.0001, 'attack uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier(''), 1.0, 0.0001, 'an empty id uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier('crit'), 1.0, 0.0001, 'crit uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier('nonexistent'), 1.0, 0.0001, 'an unknown id uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier(BleedMechanic.ID), Balance.SHIELD_MULTIPLIER_BLEED, 0.0001, 'bleed uses its constant')


func test_each_mechanic_colour_matches_its_colours_variable() -> void:
  assert_eq(MechanicRegistry.get_mechanic(AttackMechanic.ID).color(), Colours.ATTACK, 'attack')
  assert_eq(MechanicRegistry.get_mechanic(HealMechanic.ID).color(), Colours.HEAL, 'heal')
  assert_eq(MechanicRegistry.get_mechanic(ShieldMechanic.ID).color(), Colours.SHIELD, 'shield')
  assert_eq(MechanicRegistry.get_mechanic(PoisonMechanic.ID).color(), Colours.POISON, 'poison')
  assert_eq(MechanicRegistry.get_mechanic(BurnMechanic.ID).color(), Colours.BURN, 'burn')
  assert_eq(MechanicRegistry.get_mechanic(RegenMechanic.ID).color(), Colours.REGEN, 'regen')
  assert_eq(MechanicRegistry.get_mechanic(BleedMechanic.ID).color(), Colours.BLEED, 'bleed')
  assert_eq(MechanicRegistry.get_mechanic(CritMechanic.ID).color(), Colours.CRIT, 'crit')
