extends GutTest
## The tooltip keyword catalog + content builder (docs/systems/tooltips.md, docs/plans/
## mechanics.md step 7): a mechanic id resolves to its Mechanic's card (name / desc / colour /
## icon), a weapon's keyword ids include its attack mechanic, and an item with a crit chance
## carries the crit keyword + a crit stat line.


var _actors: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for a in _actors:
    if is_instance_valid(a):
      a.dissolve()
  _actors.clear()
  TestCleanup.reset_all_managers()


func _actor(hp: float) -> Actor:
  var a := Actor.new(hp)
  _actors.append(a)
  return a


func test_mechanic_id_resolves_to_its_mechanic_card() -> void:
  assert_true(KeywordCatalog.has(AttackMechanic.ID), 'attack is a keyword')
  var entry: Dictionary = KeywordCatalog.get_entry(AttackMechanic.ID)
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(AttackMechanic.ID)
  assert_eq(entry['name_key'], mechanic.name_key, 'the card name comes from the mechanic')
  assert_eq(entry['desc_key'], mechanic.desc_key, 'the card description comes from the mechanic')
  assert_eq(entry['color'], mechanic.color(), 'the card colour comes from the mechanic')
  assert_eq(entry['icon'], mechanic.icon, 'the card icon comes from the mechanic')


func test_status_and_mechanic_keyword_ids_still_resolve() -> void:
  assert_true(KeywordCatalog.has('weak'), 'a status id still resolves')
  assert_true(KeywordCatalog.has(KeywordCatalog.FUEL), 'a kw: id still resolves')
  assert_false(KeywordCatalog.has('nonexistent'), 'an unknown id does not')
  assert_eq(KeywordCatalog.get_entry('nonexistent'), {}, 'an unknown id yields an empty card')


func test_weapon_keyword_ids_include_its_attack_mechanic() -> void:
  var it: Item = Item.new(FixtureItems.attack(), _actor(100.0))
  var ids: Array[String] = TooltipContent.keyword_ids(it)
  assert_true(AttackMechanic.ID in ids, 'the weapon\'s attack mechanic is a keyword')


func test_crit_item_has_the_crit_keyword_and_a_crit_stat_line() -> void:
  var def := ItemDef.new()
  def.id = 'test_keyword_crit'
  def.crit_chance = 0.25
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = 10.0
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  def.effects = [hit]
  var it: Item = Item.new(def, _actor(100.0))
  var ids: Array[String] = TooltipContent.keyword_ids(it)
  assert_true(CritMechanic.ID in ids, 'an item with a crit chance carries the crit keyword')
  var content: Dictionary = TooltipContent.new().build(it)
  assert_true(content['stat_lines'].any(func(line: String) -> bool: return line.begins_with('Crit chance:')),
      'the stat block has a crit line')


func test_no_crit_item_has_no_crit_keyword_or_line() -> void:
  var it: Item = Item.new(FixtureItems.attack(), _actor(100.0))
  var ids: Array[String] = TooltipContent.keyword_ids(it)
  assert_false(CritMechanic.ID in ids, 'no crit chance, no crit keyword')
  var content: Dictionary = TooltipContent.new().build(it)
  assert_false(content['stat_lines'].any(func(line: String) -> bool: return line.begins_with('Crit chance:')),
      'no crit chance, no crit stat line')
