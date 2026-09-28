extends GutTest
## The relic definition (docs/systems/content.md → Relic): an item definition with no timer. The
## instance carries its def, and the Item built from a def has a one-step bar, so a single full push
## crosses it.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_instance_carries_its_def() -> void:
  var d := FixtureKit.shield_relic()
  var r := Relic.new(d)
  assert_eq(r.def, d, 'the instance holds its definition')


func test_a_relic_def_is_an_item_def() -> void:
  assert_true(FixtureKit.shield_relic() is ItemDef, 'a relic uses the item definition')


func test_a_relic_item_crosses_on_one_full_push() -> void:
  var it := Item.new(FixtureKit.shield_relic())
  assert_false(it.cooldown.crossed(), 'an untouched relic is not ready to fire')
  it.cooldown.push(1.0)
  assert_true(it.cooldown.crossed(), 'one full push makes it fire')
