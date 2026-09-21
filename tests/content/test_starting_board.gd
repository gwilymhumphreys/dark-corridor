extends GutTest
## The run-start board drawn from a character's type constraints
## (CharacterCatalog.starting_board). A character lists the ItemTypes it opens with instead of
## fixed ids, and one random item of each is drawn from its own pool on the run RNG, so every run
## opens differently but a seed always opens the same way.


func _rng(seed_value: int) -> RandomNumberGenerator:
  var r := RandomNumberGenerator.new()
  r.seed = seed_value
  return r


func _types_of(ids: Array) -> Array:
  var types: Array = []
  for id: String in ids:
    types.append_array(ItemCatalog.get_def(id).types)
  return types


func test_the_smith_opens_with_a_weapon_a_skill_and_an_armour() -> void:
  var smith: CharacterDef = CharacterCatalog.get_def(CharacterCatalog.SMITH)
  var ids: Array = CharacterCatalog.starting_board(smith, _rng(1))
  assert_eq(ids.size(), 3, 'three items')
  var types: Array = _types_of(ids)
  assert_true(types.has(ItemType.WEAPON), 'one of them is a weapon')
  assert_true(types.has(ItemType.SKILL), 'one of them is a skill')
  assert_true(types.has(ItemType.ARMOUR), 'one of them is armour')


func test_every_drawn_item_comes_from_the_characters_own_pool() -> void:
  for character_id: String in [CharacterCatalog.SMITH, CharacterCatalog.SPORE_DRUID, CharacterCatalog.FLESHMANCER]:
    var def: CharacterDef = CharacterCatalog.get_def(character_id)
    for id: String in CharacterCatalog.starting_board(def, _rng(3)):
      assert_true(def.item_pool.has(id), '%s drew %s from its own pool' % [character_id, id])


func test_the_same_seed_draws_the_same_board() -> void:
  var smith: CharacterDef = CharacterCatalog.get_def(CharacterCatalog.SMITH)
  assert_eq(CharacterCatalog.starting_board(smith, _rng(42)),
    CharacterCatalog.starting_board(smith, _rng(42)), 'a seed always opens the same way')


func test_a_repeated_type_draws_distinct_items() -> void:
  # The Spore Druid's pool is all weapons, so it asks for three of them. Asking twice for a type
  # must not hand back the same item twice.
  var druid: CharacterDef = CharacterCatalog.get_def(CharacterCatalog.SPORE_DRUID)
  for seed_value: int in [1, 2, 3, 4, 5]:
    var ids: Array = CharacterCatalog.starting_board(druid, _rng(seed_value))
    assert_eq(ids.size(), 3, 'three weapons on seed %d' % seed_value)
    var seen: Array = []
    for id: String in ids:
      assert_false(seen.has(id), 'no repeat on seed %d' % seed_value)
      seen.append(id)


func test_different_seeds_can_draw_different_boards() -> void:
  var smith: CharacterDef = CharacterCatalog.get_def(CharacterCatalog.SMITH)
  var seen: Array = []
  for seed_value: int in range(20):
    var ids: Array = CharacterCatalog.starting_board(smith, _rng(seed_value))
    if not seen.has(ids):
      seen.append(ids)
  assert_gt(seen.size(), 1, 'the opening board varies across seeds')


func test_a_character_with_fixed_ids_keeps_them() -> void:
  # starting_item_types is opt-in: with none set, the authored starting_item_ids are used as they
  # always were.
  var def := CharacterDef.new()
  def.id = 'test_fixed'
  def.starting_item_ids = [ItemCatalog.CAPPED_CUDGEL]
  assert_eq(CharacterCatalog.starting_board(def, _rng(1)), [ItemCatalog.CAPPED_CUDGEL])


func test_a_type_with_nothing_in_the_pool_is_skipped() -> void:
  # A half-authored character still starts rather than crashing — it just opens short-handed.
  var def := CharacterDef.new()
  def.id = 'test_missing_type'
  def.item_pool = [ItemCatalog.CAPPED_CUDGEL]
  def.starting_item_types = [ItemType.WEAPON, ItemType.ARMOUR]
  assert_eq(CharacterCatalog.starting_board(def, _rng(1)), [ItemCatalog.CAPPED_CUDGEL],
    'the weapon is drawn and the missing armour is skipped')
