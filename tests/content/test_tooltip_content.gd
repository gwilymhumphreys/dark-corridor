extends GutTest
## The tooltip content builder's icon segment (docs/systems/tooltips.md, docs/plans/
## mechanic_icons.md step 5): the attack and heal effect lines carry their mechanic's inline
## glyph (a segment with 't' == 'icon') in place of the old "damage" / "Heal" word, while the
## other mechanics still use a keyword chip and are untouched.

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


## A self-heal item built by hand (FixtureItems has no heal builder).
func _heal_def() -> ItemDef:
  var def := ItemDef.new()
  def.id = 'test_tooltip_heal'
  def.types = [ItemType.ARMOUR]
  def.name_key = 'Test Heal'
  def.icon = 'res://assets/icons/items/old_sword.png'
  def.cooldown = 2.0
  var heal := ItemEffect.new()
  heal.mechanic = HealMechanic.ID
  heal.value = 10.0
  heal.shape = ItemEffect.Shape.SELF
  def.effects = [heal]
  def.panel_color = Colours.HEAL
  return def


func test_attack_line_has_an_icon_segment_and_no_damage_word() -> void:
  var it: Item = Item.new(FixtureItems.attack(), _actor(100.0))
  var content: Dictionary = TooltipContent.new().build(it)
  var line: Array = content['lines'][0]
  var icon: Dictionary = _first_segment(line, 'icon')
  assert_true(icon != {}, 'the attack line carries an icon segment')
  assert_eq(icon.get('id'), AttackMechanic.ID, 'the icon is the attack glyph')
  for seg: Dictionary in line:
    if seg['t'] == 'text':
      assert_false(seg['s'].find('damage') != -1, 'no text segment says "damage": %s' % seg['s'])


func test_heal_line_has_an_icon_segment() -> void:
  var it: Item = Item.new(_heal_def(), _actor(100.0))
  var content: Dictionary = TooltipContent.new().build(it)
  var line: Array = content['lines'][0]
  var icon: Dictionary = _first_segment(line, 'icon')
  assert_true(icon != {}, 'the heal line carries an icon segment')
  assert_eq(icon.get('id'), HealMechanic.ID, 'the icon is the heal glyph')


func test_shield_line_still_uses_a_chip_not_an_icon() -> void:
  var it: Item = Item.new(FixtureItems.shield(), _actor(100.0))
  var content: Dictionary = TooltipContent.new().build(it)
  var line: Array = content['lines'][0]
  assert_true(_first_segment(line, 'chip') != {}, 'the shield line still carries a keyword chip')
  assert_true(_first_segment(line, 'icon') == {}, 'the shield line has no icon segment')


## The first segment of `line` whose 't' is `kind`, or {} if none.
func _first_segment(line: Array, kind: String) -> Dictionary:
  for seg: Dictionary in line:
    if seg['t'] == kind:
      return seg
  return {}
