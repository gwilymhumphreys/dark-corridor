extends GutTest
## The tooltip content builder's lines (docs/systems/tooltips.md): a basic apply is a value and
## an icon segment with no words, the charge-time line is the cooldown beside the charge_time
## glyph, an item's crit chance is one more effect line, and a more complicated effect keeps its
## worded line with an icon in place of the old keyword chip.

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


## An AOE attack def built by hand (FixtureItems.attack is single-target): type tags `types`, authored
## mechanics list `mechanics`. Its AOE shape yields the structural kw:aoe keyword, so the def doubles
## as "an item with a structural keyword" for ordering assertions.
func _attack_def(types: Array[String], mechanics: Array[String]) -> ItemDef:
  var def := ItemDef.new()
  def.id = 'test_tooltip_attack'
  def.types = types
  def.mechanics = mechanics
  def.name_key = 'Test Attack'
  def.icon = 'res://assets/icons/items/old_sword.png'
  def.cooldown = 1.0
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = 5.0
  hit.shape = ItemEffect.Shape.ALL_OPPONENTS
  def.effects = [hit]
  def.panel_colour_name = 'ATTACK'
  return def


## A pure status applier: an APPLY_STATUS effect naming `status_id`, with an empty authored mechanics
## list. Proves the derived non-mechanic part of the keyword column still surfaces a status id.
func _status_def(status_id: String) -> ItemDef:
  var def := ItemDef.new()
  def.id = 'test_tooltip_status'
  def.name_key = 'Test Debuff'
  def.icon = 'res://assets/icons/items/old_sword.png'
  def.cooldown = 1.0
  var eff := ItemEffect.new()
  eff.kind = Delivery.Kind.APPLY_STATUS
  eff.status_id = status_id
  eff.value = 1.0
  eff.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  def.effects = [eff]
  def.panel_colour_name = 'ATTACK'
  return def


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
  def.panel_colour_name = 'HEAL'
  return def


## A single-target attack is a basic apply: the attack glyph and a value, no words at all.
func test_attack_line_is_the_attack_glyph_and_a_value() -> void:
  var it: Item = Item.new(FixtureItems.attack(), _actor(100.0))
  var line: Array = TooltipContent.new().build(it)['lines'][0]
  assert_eq(line.size(), 2, 'a single-target attack line has two segments')
  assert_eq(line[0]['id'], AttackMechanic.ID, 'the icon is the attack glyph')
  assert_true(_first_segment(line, 'text') == {}, 'a basic apply line has no words')


func test_heal_line_has_an_icon_segment() -> void:
  var it: Item = Item.new(_heal_def(), _actor(100.0))
  var content: Dictionary = TooltipContent.new().build(it)
  var line: Array = content['lines'][0]
  var icon: Dictionary = _first_segment(line, 'icon')
  assert_true(icon != {}, 'the heal line carries an icon segment')
  assert_eq(icon.get('id'), HealMechanic.ID, 'the icon is the heal glyph')


## A self-shield is a basic apply: the line is exactly the shield icon and a value, no words.
func test_basic_apply_line_is_an_icon_and_a_value_only() -> void:
  var it: Item = Item.new(FixtureItems.shield(), _actor(100.0))
  var content: Dictionary = TooltipContent.new().build(it)
  var line: Array = content['lines'][0]
  assert_eq(line.size(), 2, 'a basic apply line has two segments')
  assert_eq(line[0]['t'], 'icon', 'the first segment is the icon')
  assert_eq(line[1]['t'], 'value', 'the second segment is the value')
  assert_eq(line[0]['id'], ShieldMechanic.ID, 'the icon is the shield glyph')


## An effect that is not a basic apply keeps its worded line, with an icon where the chip used to be.
func test_complex_effect_keeps_a_worded_line_with_an_icon() -> void:
  var it: Item = Item.new(_attack_def([ItemType.WEAPON], [AttackMechanic.ID]), _actor(100.0))
  var line: Array = TooltipContent.new().build(it)['lines'][0]
  assert_true(_first_segment(line, 'icon') != {}, 'the all-enemies line carries an icon segment')
  assert_true(_first_segment(line, 'text') != {}, 'the all-enemies line still has words')
  assert_true(_first_segment(line, 'chip') == {}, 'no keyword chip is left in a tooltip line')


## The charge-time line: the charge_time glyph, then the item's cooldown in seconds.
func test_charge_line_is_the_charge_time_glyph_and_the_cooldown() -> void:
  var it: Item = Item.new(_heal_def(), _actor(100.0))
  var line: Array = TooltipContent.new().build(it)['charge_line']
  assert_eq(line[0]['id'], IconSlots.CHARGE_TIME, 'the charge line carries the charge_time glyph')
  assert_eq(line[1]['s'], '2s', 'the charge line reads the cooldown in seconds')


## An item's crit chance is one more effect line: the crit glyph, then the percentage.
func test_crit_chance_is_an_effect_line() -> void:
  var def: ItemDef = _heal_def()
  def.crit_chance = 0.25
  var it: Item = Item.new(def, _actor(100.0))
  var lines: Array = TooltipContent.new().build(it)['lines']
  var last: Array = lines[lines.size() - 1]
  assert_eq(last[0]['id'], CritMechanic.ID, 'the crit line carries the crit glyph')
  assert_eq(last[1]['s'], '25%', 'the crit line reads the chance as a percentage')


## No crit chance, no crit line.
func test_no_crit_chance_adds_no_line() -> void:
  var it: Item = Item.new(_heal_def(), _actor(100.0))
  assert_eq(TooltipContent.new().build(it)['lines'].size(), 1, 'an item with no crit chance has one line')


## The keyword column leads with the item's authored mechanics list: an authored mechanic appears
## ahead of any structural kw: id (the AOE shape's kw:aoe).
func test_keyword_column_leads_with_authored_mechanics() -> void:
  var it: Item = Item.new(_attack_def([ItemType.WEAPON], [AttackMechanic.ID]), _actor(100.0))
  var ids: Array[String] = TooltipContent.new().keyword_ids(it)
  var authored_idx: int = ids.find(AttackMechanic.ID)
  assert_true(authored_idx != -1, 'the authored attack mechanic is in the keyword column')
  var structural_idx: int = ids.find(KeywordCatalog.AOE)
  assert_true(structural_idx != -1, 'the AOE structural keyword is in the keyword column')
  assert_lt(authored_idx, structural_idx, 'the authored mechanic sits ahead of the structural keyword')


## A status keyword still appears: an APPLY_STATUS effect's status_id survives the rebuild of the
## non-mechanic part (the regression guard — the most likely thing to be silently lost).
func test_status_keyword_still_appears() -> void:
  var it: Item = Item.new(_status_def(WeakStatus.ID), _actor(100.0))
  var ids: Array[String] = TooltipContent.new().keyword_ids(it)
  assert_true(ids.has(WeakStatus.ID), 'the applied status keyword is in the keyword column')


## An authored mechanic no effect names still appears — what makes the list authored, not derived.
func test_authored_mechanic_not_named_by_effects_still_appears() -> void:
  var it: Item = Item.new(_attack_def([ItemType.WEAPON], [PoisonMechanic.ID]), _actor(100.0))
  var ids: Array[String] = TooltipContent.new().keyword_ids(it)
  assert_true(ids.has(PoisonMechanic.ID), 'an authored mechanic absent from the effects is still listed')


## The type line: a weapon-tagged item gives a non-empty type line naming the weapon; an untagged
## item gives the empty string (the panel hides the line).
func test_type_line_names_the_tags_and_empty_for_untagged() -> void:
  var tagged: Item = Item.new(_attack_def([ItemType.WEAPON], []), _actor(100.0))
  var tagged_line: String = TooltipContent.new().build(tagged)['type_line']
  assert_true(tagged_line != '', 'a weapon-tagged item has a non-empty type line')
  assert_true(tagged_line.find(ItemType.display_name(ItemType.WEAPON)) != -1,
      'the type line names the weapon tag')
  var untagged: Item = Item.new(_attack_def([], []), _actor(100.0))
  assert_eq(TooltipContent.new().build(untagged)['type_line'], '', 'an untagged item has an empty type line')


## The target phrase `_shape_text` produces for a shape + filter, as its text with each icon
## written as [id].
func _phrase(shape: int, filter: TargetFilter) -> String:
  var text: String = ''
  for seg: Dictionary in TooltipContent.new()._shape_text(shape, filter):
    text += seg['s'] if seg['t'] == 'text' else '[%s]' % seg['id']
  return text


## A type-tag filter (weapons) on ALL_OWN_ITEMS narrows the phrase to the lowercased weapon name,
## and the bare unfiltered phrase no longer appears.
func test_filtered_shape_names_the_type_not_the_bare_phrase() -> void:
  var f := TargetFilter.new()
  f.add_type(ItemType.WEAPON)
  var phrase: String = _phrase(ItemEffect.Shape.ALL_OWN_ITEMS, f)
  assert_true(phrase.find(ItemType.display_name(ItemType.WEAPON).to_lower()) != -1,
      'the phrase names the weapon type: %s' % phrase)
  assert_false(phrase.find('all your items') != -1, 'the bare phrase is gone: %s' % phrase)


## The same effect with a null filter gives exactly the owner's baseline copy.
func test_null_filter_gives_the_baseline_phrase() -> void:
  assert_eq(_phrase(ItemEffect.Shape.ALL_OWN_ITEMS, null), 'all your items',
      'a null filter gives the baseline phrase')


## A filter of one mechanic shows that mechanic's icon in the gap.
func test_mechanic_filter_shows_the_mechanic_icon() -> void:
  var f := TargetFilter.new()
  f.add_mechanic(PoisonMechanic.ID)
  assert_eq(_phrase(ItemEffect.Shape.ALL_OWN_ITEMS, f), 'each of your [poison] items')


## An attack bonus reads as its value with a sign, then the attack icon, then the target phrase.
func test_attack_bonus_line_shows_the_attack_icon_after_the_value() -> void:
  var def := ItemDef.new()
  var f := TargetFilter.new()
  f.add_mechanic(AttackMechanic.ID)
  var bonus := ItemEffect.make(AttackBonusMechanic.ID, 10.0, ItemEffect.Shape.ALL_OWN_ITEMS)
  bonus.target_filter = f
  def.effects = [bonus]
  var item := Item.new(def, _actor(100.0))
  var text: String = ''
  for seg: Dictionary in TooltipContent.new()._effect_line(item, bonus):
    text += seg['s'] if seg.has('s') else '[%s]' % seg['id']
  assert_eq(text, '[attack] +10 to each of your [attack] items')


## A filter on an actor shape is ignored: the phrase is the unfiltered baseline copy.
func test_filter_on_actor_shape_is_ignored() -> void:
  var f := TargetFilter.new()
  f.add_type(ItemType.WEAPON)
  assert_eq(_phrase(ItemEffect.Shape.ALL_OPPONENTS, f), 'all enemies', 'an actor shape ignores the filter')


## The first segment of `line` whose 't' is `kind`, or {} if none.
## A trigger line names its event and the seconds it charges the item each time it goes off.
func test_trigger_line_shows_the_seconds_it_charges() -> void:
  var def: ItemDef = _heal_def()
  def.cooldown = 5.0
  def.trigger_subs = [{'event': EventBus.Event.APPLIED, 'seconds': 1.0, 'filter': 'poison'}]
  var lines: Array = TooltipContent.new().build(Item.new(def, _actor(100.0)))['lines']
  var line: Array = lines[lines.size() - 1]
  var ids: Array = []
  var texts: Array = []
  for seg: Dictionary in line:
    if seg['t'] == 'icon':
      ids.append(seg['id'])
    else:
      texts.append(seg['s'])
  assert_eq(ids, [PoisonMechanic.ID, ChargeMechanic.ID], 'the event icon, then the charge icon')
  assert_has(texts, '1s', 'the seconds it charges')


func _first_segment(line: Array, kind: String) -> Dictionary:
  for seg: Dictionary in line:
    if seg['t'] == kind:
      return seg
  return {}
