extends GutTest
## FF1 — the minimal enchant (scale-a-value). An instance carries its def, and an enchanted
## item's fire scales its payload values — the permanent-item-modifier path (a saved board
## modifier, not a status — #26).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_instance_carries_its_def() -> void:
  var d := FixtureKit.enchant()
  assert_eq(Enchantment.new(d).def, d)


func test_enchant_scales_the_item_payload_value() -> void:
  var actor := Actor.new(100.0)
  var base_weapon := Item.new(FixtureItems.attack(), actor)
  var base_value: float = base_weapon.fire()[0].value

  var enchanted := Item.new(FixtureItems.attack(), actor)
  enchanted.enchant = Enchantment.new(FixtureKit.enchant())
  var enchanted_value: float = enchanted.fire()[0].value

  assert_almost_eq(enchanted_value, base_value * FixtureKit.ENCHANT_MULT, 0.0001,
    'the enchant scales the fired payload value')
