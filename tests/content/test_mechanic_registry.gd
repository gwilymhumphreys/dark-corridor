extends GutTest
## The mechanic registry (docs/systems/mechanics.md): one shared Mechanic instance per id, built
## lazily like the StatusRegistry. This run registers all twelve: attack, heal, shield, poison,
## burn, bleed, regen, charge, decharge, crit and the two attack bonuses.


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
  assert_true(MechanicRegistry.has(ChargeMechanic.ID), 'charge is registered')
  assert_true(MechanicRegistry.has(DechargeMechanic.ID), 'decharge is registered')
  assert_true(MechanicRegistry.has(CritMechanic.ID), 'crit is registered')
  assert_true(MechanicRegistry.has(AttackBonusMechanic.ID), 'attack bonus is registered')
  assert_true(MechanicRegistry.has(AttackPercentBonusMechanic.ID), 'attack percent bonus is registered')
  assert_false(MechanicRegistry.has(''), 'an empty id is not registered')


func test_get_mechanic_returns_the_right_class() -> void:
  assert_true(MechanicRegistry.get_mechanic(AttackMechanic.ID) is AttackMechanic, 'attack')
  assert_true(MechanicRegistry.get_mechanic(HealMechanic.ID) is HealMechanic, 'heal')
  assert_true(MechanicRegistry.get_mechanic(ShieldMechanic.ID) is ShieldMechanic, 'shield')
  assert_true(MechanicRegistry.get_mechanic(PoisonMechanic.ID) is PoisonMechanic, 'poison')
  assert_true(MechanicRegistry.get_mechanic(BurnMechanic.ID) is BurnMechanic, 'burn')
  assert_true(MechanicRegistry.get_mechanic(RegenMechanic.ID) is RegenMechanic, 'regen')
  assert_true(MechanicRegistry.get_mechanic(BleedMechanic.ID) is BleedMechanic, 'bleed')
  assert_true(MechanicRegistry.get_mechanic(ChargeMechanic.ID) is ChargeMechanic, 'charge')
  assert_true(MechanicRegistry.get_mechanic(DechargeMechanic.ID) is DechargeMechanic, 'decharge')
  assert_true(MechanicRegistry.get_mechanic(CritMechanic.ID) is CritMechanic, 'crit')


func test_get_mechanic_returns_the_same_shared_instance() -> void:
  var first: Mechanic = MechanicRegistry.get_mechanic(ShieldMechanic.ID)
  var second: Mechanic = MechanicRegistry.get_mechanic(ShieldMechanic.ID)
  assert_eq(first, second, 'one shared instance per id')


func test_shield_multiplier_defaults_to_one() -> void:
  assert_almost_eq(MechanicRegistry.shield_multiplier(AttackMechanic.ID), 1.0, 0.0001, 'attack uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier(''), 1.0, 0.0001, 'an empty id uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier('crit'), 1.0, 0.0001, 'crit uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier(ChargeMechanic.ID), 1.0, 0.0001, 'charge uses the default')
  assert_almost_eq(MechanicRegistry.shield_multiplier(DechargeMechanic.ID), 1.0, 0.0001, 'decharge uses the default')
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
  assert_eq(MechanicRegistry.get_mechanic(ChargeMechanic.ID).color(), Colours.CHARGE, 'charge')
  assert_eq(MechanicRegistry.get_mechanic(DechargeMechanic.ID).color(), Colours.DECHARGE, 'decharge')
  assert_eq(MechanicRegistry.get_mechanic(CritMechanic.ID).color(), Colours.CRIT, 'crit')


## Every mechanic's sound folder is its id under mechanics/, and each one is distinct, so two
## mechanics can never end up sharing a sound by accident.
func test_each_mechanic_sound_key_is_its_id() -> void:
  var ids: Array[String] = [
    AttackMechanic.ID, HealMechanic.ID, ShieldMechanic.ID, PoisonMechanic.ID, BurnMechanic.ID,
    RegenMechanic.ID, BleedMechanic.ID, ChargeMechanic.ID, DechargeMechanic.ID, CritMechanic.ID,
  ]
  # A bare Delivery, whose target is null, so every mechanic gives its plain key, attack included.
  var delivery: Delivery = Delivery.new()
  var seen: Dictionary = {}
  for id: String in ids:
    var key: String = MechanicRegistry.get_mechanic(id).sound_key(delivery)
    assert_eq(key, 'mechanics/' + id, id + ' plays its own folder')
    assert_eq(SfxManager.bus_for(key), SfxManagerAutoload.BUS_WORLD, id + ' carries the corridor reverb')
    assert_false(seen.has(key), 'no two mechanics share a sound folder')
    seen[key] = true


## The attack mechanic varies its sound by the target: a shielded actor gets the
## blade-on-metal hit, an unshielded one the plain hit.
func test_attack_sound_key_varies_with_the_target_shield() -> void:
  var attack: AttackMechanic = MechanicRegistry.get_mechanic(AttackMechanic.ID)
  var plain: Delivery = Delivery.new()
  plain.target = Actor.new(50.0)
  assert_eq(attack.sound_key(plain), 'mechanics/attack', 'an unshielded target plays the plain hit')
  var shielded_target: Actor = Actor.new(50.0)
  StatusManager.apply(shielded_target, ShieldStatus.ID, 5.0)
  var shielded: Delivery = Delivery.new()
  shielded.target = shielded_target
  assert_eq(attack.sound_key(shielded), 'mechanics/attack/shielded', 'a shielded target plays the blade-on-metal hit')


func test_attack_sound_uses_the_items_weapon_folder() -> void:
  var attacker: Actor = Actor.new(100.0)
  var target: Actor = Actor.new(100.0)
  var def: ItemDef = ItemDef.new()
  def.attack_sound = 'blade'
  var item: Item = Item.new(def, attacker)
  var delivery: Delivery = Delivery.new()
  delivery.mechanic = AttackMechanic.ID
  delivery.source = item
  delivery.target = target
  assert_eq(MechanicRegistry.get_mechanic(AttackMechanic.ID).sound_key(delivery),
      'mechanics/attack/blade', 'a blade item plays the blade folder')
  attacker.dissolve()
  target.dissolve()


func test_attack_sound_without_a_weapon_folder_is_the_plain_path() -> void:
  var attacker: Actor = Actor.new(100.0)
  var target: Actor = Actor.new(100.0)
  var item: Item = Item.new(ItemDef.new(), attacker)
  var delivery: Delivery = Delivery.new()
  delivery.mechanic = AttackMechanic.ID
  delivery.source = item
  delivery.target = target
  assert_eq(MechanicRegistry.get_mechanic(AttackMechanic.ID).sound_key(delivery),
      'mechanics/attack', 'an item naming no weapon folder plays the plain attack folder')
  attacker.dissolve()
  target.dissolve()
