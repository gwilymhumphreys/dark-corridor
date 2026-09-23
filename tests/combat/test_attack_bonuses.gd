extends GutTest
## The attack bonuses and the combining rule (docs/systems/mechanics.md → Attack bonuses, Combining
## bonuses): flat bonuses first, positive percentages added, negative percentages multiplied, the two
## groups applied separately; the enchant counts as a positive percentage; the item-targeted bonus
## statuses raise only their own item's attacks; crit still multiplies last. Fixture items only.

var _made: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for cm in _made:
    if is_instance_valid(cm):
      TestCleanup.dissolve_at_reset(cm.player)
      cm.teardown()
      cm.free()
  _made.clear()
  TestCleanup.reset_all_managers()


# --- helpers (not test_*; GUT ignores them) ---

func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  TestCleanup.dissolve_at_reset(p)
  return cm


func _fire_and_land(cm: CombatManager, it: Item) -> Array:
  var arrived: Array = []
  cm._fire_item(it, arrived)
  for d in arrived:
    cm._land(d)
  return arrived


## An item that applies one attack bonus mechanic to its own attack items, instantly.
func _bonus_item(owner_actor: Actor, mechanic_id: String, value: float, shape: int) -> Item:
  var def := ItemDef.new()
  def.id = 'test_bonus_item'
  def.mechanics = [mechanic_id]
  var filter := TargetFilter.new()
  filter.add_mechanic(AttackMechanic.ID)
  var bonus := ItemEffect.make(mechanic_id, value, shape)
  bonus.target_filter = filter
  bonus.travel = 0.0
  def.effects = [bonus]
  return Item.new(def, owner_actor)


# --- the combining rule ---

func test_flat_is_added_before_percentages() -> void:
  var value: float = StatusManager.combine(10.0, [{'flat': 10.0}, {'percent': 0.5}])
  assert_almost_eq(value, 30.0, 0.0001, '(10 + 10) x 1.5')


func test_positive_percentages_add() -> void:
  var value: float = StatusManager.combine(10.0, [{'percent': 0.5}, {'percent': 1.0}])
  assert_almost_eq(value, 25.0, 0.0001, '10 x (1 + 0.5 + 1.0), not 10 x 1.5 x 2')


func test_negative_percentages_multiply() -> void:
  var value: float = StatusManager.combine(10.0, [{'percent': -0.25}, {'percent': -0.25}])
  assert_almost_eq(value, 10.0 * 0.75 * 0.75, 0.0001, 'two -25% give x0.5625')


func test_positive_and_negative_groups_apply_separately() -> void:
  var value: float = StatusManager.combine(10.0, [{'percent': 1.0}, {'percent': -0.25}, {'percent': 0.5}])
  assert_almost_eq(value, 10.0 * 2.5 * 0.75, 0.0001, 'positives summed, then the negative multiplies')


func test_the_enchant_adds_to_other_positive_percentages() -> void:
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'empowered', 1.0)
  var it := Item.new(FixtureItems.attack(), a)
  it.enchant = Enchantment.new(FixtureKit.enchant())
  var expected: float = FixtureItems.ATTACK_DAMAGE \
      * (1.0 + (Balance.EMPOWER_MULT - 1.0) + (FixtureKit.ENCHANT_MULT - 1.0))
  assert_almost_eq(it.fire()[0].value, expected, 0.0001, 'Empowered and the enchant are added together')


# --- the item statuses ---

func test_a_flat_bonus_raises_only_its_own_item() -> void:
  var a := Actor.new(100.0)
  var buffed := Item.new(FixtureItems.attack(), a)
  var other := Item.new(FixtureItems.attack(), a)
  StatusManager.apply(buffed, AttackBonusStatus.ID, 10.0)
  assert_almost_eq(buffed.fire()[0].value, FixtureItems.ATTACK_DAMAGE + 10.0, 0.0001, 'the buffed item hits harder')
  assert_almost_eq(other.fire()[0].value, FixtureItems.ATTACK_DAMAGE, 0.0001, 'another item is unchanged')


func test_a_percent_bonus_raises_only_attacks() -> void:
  var a := Actor.new(100.0)
  var shield := Item.new(FixtureItems.shield(), a)
  StatusManager.apply(shield, AttackPercentBonusStatus.ID, 50.0)
  assert_almost_eq(shield.fire()[0].value, FixtureItems.SHIELD_VALUE, 0.0001, 'a shield effect is not an attack')


func test_reapplying_a_bonus_adds_to_it() -> void:
  var a := Actor.new(100.0)
  var it := Item.new(FixtureItems.attack(), a)
  StatusManager.apply(it, AttackPercentBonusStatus.ID, 50.0)
  StatusManager.apply(it, AttackPercentBonusStatus.ID, 50.0)
  assert_almost_eq(it.fire()[0].value, FixtureItems.ATTACK_DAMAGE * 2.0, 0.0001, 'two +50% make +100%')


func test_display_value_shows_the_bonus_and_changes_nothing() -> void:
  var a := Actor.new(100.0)
  var it := Item.new(FixtureItems.attack(), a)
  StatusManager.apply(it, AttackBonusStatus.ID, 10.0)
  var effect: ItemEffect = it.def.effects[0]
  assert_almost_eq(it.display_value(effect), FixtureItems.ATTACK_DAMAGE + 10.0, 0.0001, 'the tooltip shows the bonus')
  assert_almost_eq(it.base_value(effect), FixtureItems.ATTACK_DAMAGE, 0.0001, 'the baseline leaves it out, so it is highlighted')
  assert_eq(it.statuses.size(), 1, 'the preview kept the status')


# --- delivered in a fight ---

func test_a_bonus_item_buffs_every_attack_item_of_its_owner() -> void:
  var p := Actor.new(100.0)
  var sword := Item.new(FixtureItems.attack(), p)
  var shield := Item.new(FixtureItems.shield(), p)
  var forge := _bonus_item(p, AttackBonusMechanic.ID, 10.0, ItemEffect.Shape.ALL_OWN_ITEMS)
  p.board.append(sword)
  p.board.append(shield)
  p.board.append(forge)
  var cm := _manager(p, [Actor.new(100.0)])
  cm.start()
  _fire_and_land(cm, forge)
  assert_eq(sword.statuses.size(), 1, 'the attack item got the bonus')
  assert_eq(shield.statuses.size(), 0, 'the shield item did not (the filter is the attack mechanic)')
  assert_almost_eq(sword.fire()[0].value, FixtureItems.ATTACK_DAMAGE + 10.0, 0.0001, 'and hits harder')


func test_crit_still_multiplies_after_the_bonuses() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var def := FixtureItems.attack()
  def.crit_chance = 1.0
  def.effects[0].travel = 0.0   # land on the fire, so the value can be read
  var it := Item.new(def, p)
  p.board.append(it)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(it, AttackBonusStatus.ID, 10.0)
  var arrived := _fire_and_land(cm, it)
  assert_almost_eq(arrived[0].value, (FixtureItems.ATTACK_DAMAGE + 10.0) * Balance.CRIT_MULTIPLIER, 0.0001,
      'the crit doubles the bonused value')
