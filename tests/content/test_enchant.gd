extends GutTest
## FF1 — the minimal enchant (scale-a-value). The catalog builds, an instance
## carries its def, and an enchanted item's fire scales its payload values — the
## permanent-item-modifier path (a saved board modifier, not a status — #26).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_catalog_builds_the_scale_value_enchant() -> void:
  var d := EnchantCatalog.get_def(EnchantCatalog.WHETSTONE)
  assert_eq(d.name_key, 'Whetstone')
  assert_gt(d.value_mult, 1.0, 'a scale-a-value enchant boosts the host item')


func test_instance_carries_its_def() -> void:
  var d := EnchantCatalog.get_def(EnchantCatalog.WHETSTONE)
  assert_eq(Enchantment.new(d).def, d)


func test_enchant_scales_the_item_payload_value() -> void:
  var actor := Actor.new(100.0)
  var base_weapon := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), actor)
  var base_value: float = base_weapon.fire()[0].value

  var enchanted := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), actor)
  enchanted.enchant = Enchantment.new(EnchantCatalog.get_def(EnchantCatalog.WHETSTONE))
  var enchanted_value: float = enchanted.fire()[0].value

  assert_almost_eq(enchanted_value, base_value * Balance.ENCHANT_WHETSTONE_MULT, 0.0001,
    'the enchant scales the fired payload value (+50%)')
