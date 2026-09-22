extends GutTest
## Checks that specific authored cards, enemies, potions, enchants and relics are built as designed.
## Like the rest of tests/content/, these read real content on purpose (docs/systems/testing.md);
## the engine behaviour each one relies on is tested on fixtures elsewhere.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_grunt_has_authored_board() -> void:
  var ed := EnemyCatalog.get_def(EnemyCatalog.GRUNT)
  assert_gt(ed.max_hp, 0.0, 'grunt has HP')
  assert_eq(ed.item_ids.size(), 1, 'grunt has a one-item authored board')
  assert_eq(ed.item_ids[0], ItemCatalog.ENEMY_CLAW, 'its attack item is from the enemy pool')


func test_spite_ward_declares_an_applied_subscription() -> void:
  var d := ItemCatalog.get_def(ItemCatalog.AVENGER)
  assert_eq(d.trigger_subs.size(), 1, 'Spite Ward declares one trigger')
  assert_eq(d.trigger_subs[0]['event'], EventBus.Event.APPLIED, 'it subscribes to APPLIED')
  assert_eq(d.trigger_subs[0]['filter'], 'poison', 'filtered to poison')
  assert_false(d.trigger_subs[0].has('source_filter'),
      'no source_filter key — it uses the OWN_SIDE content default')
  assert_almost_eq(d.trigger_subs[0]['amount'], Balance.TRIGGER_PUSH_FULL, 0.0001,
      'the declared push amount')


func test_sundering_bolt_applies_vulnerable_to_opponent() -> void:
  var d := ItemCatalog.get_def(ItemCatalog.SUNDER)
  assert_eq(d.effects[0].kind, Delivery.Kind.APPLY_STATUS)
  assert_eq(d.effects[0].status_id, 'vulnerable')
  assert_eq(d.effects[0].shape, ItemEffect.Shape.OPPONENT_LEFTMOST)
  assert_almost_eq(d.effects[0].duration, Balance.STATUS_VULNERABLE_DURATION, 0.0001)


func test_mighty_blow_applies_empowered_to_self() -> void:
  var p: Payload = Item.new(ItemCatalog.get_def(ItemCatalog.MIGHTY_BLOW), Actor.new()).fire()[0]
  assert_eq(p.kind, Delivery.Kind.APPLY_STATUS, 'Mighty Blow is a status applier')
  assert_eq(p.status_id, 'empowered', 'it applies the empower buff')
  assert_eq(p.shape, ItemEffect.Shape.SELF, 'to the firer (self)')
  assert_almost_eq(p.value, Balance.MIGHTY_BLOW_CHARGES, 0.0001, 'banking one charge per fire')


func test_mighty_blow_is_a_skill_on_a_cooldown() -> void:
  var d := ItemCatalog.get_def(ItemCatalog.MIGHTY_BLOW)
  assert_true(d.types.has(ItemType.SKILL), 'Mighty Blow is a skill')
  assert_almost_eq(d.cooldown, Balance.MIGHTY_BLOW_COOLDOWN, 0.0001, 'a plain-cooldown metronome')


func test_the_three_big_weapons_are_authored_correctly() -> void:
  var specs := [
    [ItemCatalog.SMITH_BROADAXE, Balance.SMITH_BROADAXE_COOLDOWN, Balance.SMITH_BROADAXE_DAMAGE],
    [ItemCatalog.SMITH_WARHAMMER, Balance.SMITH_WARHAMMER_COOLDOWN, Balance.SMITH_WARHAMMER_DAMAGE],
    [ItemCatalog.SMITH_GREATSWORD, Balance.SMITH_GREATSWORD_COOLDOWN, Balance.SMITH_GREATSWORD_DAMAGE],
  ]
  for spec in specs:
    var d: ItemDef = ItemCatalog.get_def(spec[0])
    assert_true(d.types.has(ItemType.WEAPON), '%s is a weapon' % spec[0])
    assert_almost_eq(d.cooldown, spec[1], 0.0001, '%s cooldown' % spec[0])
    assert_eq(d.effects[0].mechanic, AttackMechanic.ID, '%s deals damage' % spec[0])
    assert_almost_eq(d.effects[0].value, spec[2], 0.0001, '%s damage' % spec[0])
    assert_eq(d.effects[0].shape, ItemEffect.Shape.OPPONENT_LEFTMOST, '%s is single-target' % spec[0])


func test_catalog_builds_the_heal_potion() -> void:
  var d := ConsumableCatalog.get_def(ConsumableCatalog.HEALING_DRAUGHT)
  assert_eq(d.name_key, 'Healing Draught')
  assert_eq(d.effects.size(), 1)
  assert_eq(d.effects[0].mechanic, HealMechanic.ID, 'it heals')
  assert_eq(d.effects[0].shape, ItemEffect.Shape.SELF, 'the thrower')
  assert_almost_eq(d.effects[0].value, Balance.POTION_HEAL, 0.0001)


func test_catalog_builds_the_scale_value_enchant() -> void:
  var d := EnchantCatalog.get_def(EnchantCatalog.WHETSTONE)
  assert_eq(d.name_key, 'Whetstone')
  assert_almost_eq(d.value_mult, Balance.ENCHANT_WHETSTONE_MULT, 0.0001)


func test_catalog_builds_the_combat_start_relic() -> void:
  var d := RelicCatalog.get_def(RelicCatalog.STONE_WARD)
  assert_eq(d.kind, RelicDef.Kind.COMBAT_START_STATUS)
  assert_eq(d.status_id, 'shield', 'Stone Ward grants shield')
  assert_almost_eq(d.status_count, Balance.RELIC_STONE_WARD_SHIELD, 0.0001)
  assert_eq(d.name_key, 'Stone Ward')


func test_catalog_builds_the_max_hp_relic() -> void:
  var d := RelicCatalog.get_def(RelicCatalog.VITAL_CHARM)
  assert_eq(d.kind, RelicDef.Kind.MAX_HP_BONUS)
  assert_almost_eq(d.max_hp_bonus, Balance.RELIC_VITAL_CHARM_MAX_HP, 0.0001)


func test_shrine_event_offers_a_heal_and_a_max_hp_option() -> void:
  var d := EncounterCatalog.get_def(EncounterCatalog.EVENT_SHRINE)
  assert_eq(d.event_options[0].effect, EventOptionDef.Effect.HEAL_FRACTION)
  assert_eq(d.event_options[1].effect, EventOptionDef.Effect.MAX_HP_BONUS)
  assert_almost_eq(d.event_options[1].amount, Balance.EVENT_SHRINE_MAX_HP, 0.0001)


func test_wanderer_event_recruits_the_spore_thrall() -> void:
  var d := EncounterCatalog.get_def(EncounterCatalog.EVENT_WANDERER)
  assert_eq(d.event_options[0].effect, EventOptionDef.Effect.ADD_ALLY)
  assert_eq(d.event_options[0].ally_def_id, EnemyCatalog.SPORE_THRALL)
