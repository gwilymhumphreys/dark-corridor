extends GutTest
## Item pools (decision #65, ItemPools): an item is offered for a list of pools when every one of its
## tags that is a pool is in the list. Runs on fixture items only; FixtureContent.install makes every
## authored item undraftable.


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()


func after_each() -> void:
  TestCleanup.reset_all_managers()


## Put `def` in the catalog as a draftable item, after the fixtures.
func _add_draftable(def: ItemDef) -> ItemDef:
  def.draftable = true
  ItemCatalog._defs[def.id] = def
  return def


func test_an_item_needing_two_pools_is_offered_only_when_both_are_held() -> void:
  var ward: ItemDef = _add_draftable(FixtureItems.poison_trigger())   # poison and shield
  assert_eq(ItemPools.needed_pools(ward), [PoisonMechanic.ID, ShieldMechanic.ID], 'it needs poison and shield')
  assert_false(ItemPools.items_for([PoisonMechanic.ID]).has(ward.id), 'not with poison alone')
  assert_false(ItemPools.items_for([ShieldMechanic.ID]).has(ward.id), 'not with shield alone')
  assert_true(ItemPools.items_for([PoisonMechanic.ID, ShieldMechanic.ID]).has(ward.id), 'offered with both')


func test_a_type_tag_does_not_limit_who_is_offered_an_item() -> void:
  # The fixture attack is a weapon, and no list here holds the weapon tag.
  assert_true(ItemPools.items_for([AttackMechanic.ID]).has(FixtureItems.attack().id), 'offered with attack alone')
  assert_eq(ItemPools.needed_pools(FixtureItems.attack()), [AttackMechanic.ID], 'the weapon tag is not a pool')


func test_an_item_with_no_pool_tag_is_offered_for_any_pools() -> void:
  var sunder: ItemDef = _add_draftable(FixtureItems.vulnerable())   # a skill with no pool tag
  assert_true(ItemPools.items_for([]).has(sunder.id), 'offered with no pools')
  assert_true(ItemPools.items_for([BurnMechanic.ID]).has(sunder.id), 'and with any others')


func test_an_undraftable_item_is_never_offered() -> void:
  # The fixture enemy attack has the same tags as the fixture attack, but is not draftable.
  var all_pools: Array = ItemPools.POOL_TAGS.duplicate()
  assert_false(ItemPools.items_for(all_pools).has(FixtureItems.enemy_attack().id), 'not with every pool held')
  for id: String in ItemPools.items_for(all_pools):
    assert_true(ItemCatalog.get_def(id).draftable, '%s is draftable' % id)


func test_items_come_in_catalog_order() -> void:
  var expected: Array = [FixtureItems.attack().id, FixtureItems.shield().id, FixtureItems.poison().id]
  assert_eq(ItemPools.items_for([AttackMechanic.ID, ShieldMechanic.ID, PoisonMechanic.ID]), expected,
    'in the order of the catalog')
  assert_eq(ItemPools.items_for([PoisonMechanic.ID, ShieldMechanic.ID, AttackMechanic.ID]), expected,
    'whatever order the pools are listed in')
