extends GutTest
## Relic passives (docs/systems/content.md → Relic): always-on abilities built from RelicDef.passives
## onto the relic's Item. They act through the same hooks as statuses (CombatHooks), called before
## the statuses, but are not statuses: nothing that reads the status list finds them.


var _actors: Array[Actor] = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for a in _actors:
    a.dissolve()
  _actors.clear()
  TestCleanup.reset_all_managers()


# --- helpers (not test_*; GUT ignores them) ---------------------------------

func _actor() -> Actor:
  var a := Actor.new(100.0)
  _actors.append(a)
  return a


func _board_item(actor: Actor, def: ItemDef) -> Item:
  var it := Item.new(def, actor)
  actor.board.append(it)
  return it


func _give(actor: Actor, def: RelicDef) -> Item:
  var it := Item.new(def, actor)
  actor.relics.append(it)
  return it


## FixtureItems.attack with no type tags, so a weapon filter does not pick it.
func _untagged_attack() -> ItemDef:
  var d := FixtureItems.attack()
  d.types = []
  return d


# --- building -------------------------------------------------------------------

func test_a_relic_item_builds_one_passive_per_entry() -> void:
  var relic := Item.new(FixtureKit.weapon_bonus_relic())
  assert_eq(relic.passives.size(), 1)
  assert_true(relic.passives[0] is AttackBonusPassive, 'the class is chosen by the mechanic')
  assert_eq(Item.new(FixtureItems.attack()).passives.size(), 0, 'an item has no passives')


func test_the_registry_has_no_class_for_other_mechanics() -> void:
  assert_true(PassiveRegistry.has(AttackBonusMechanic.ID))
  assert_true(PassiveRegistry.has(AttackPercentBonusMechanic.ID))
  assert_false(PassiveRegistry.has(ShieldMechanic.ID), 'shield is not a passive yet')


# --- bonuses ---------------------------------------------------------------------

func test_a_weapon_bonus_raises_the_owners_weapon_attacks() -> void:
  var p := _actor()
  var weapon := _board_item(p, FixtureItems.attack())
  _give(p, FixtureKit.weapon_bonus_relic())
  var hit: ItemEffect = weapon.def.effects[0]
  assert_eq(weapon.display_value(hit), FixtureItems.ATTACK_DAMAGE + FixtureKit.RELIC_WEAPON_ATTACK_BONUS,
      'the tooltip value includes the bonus')
  assert_eq(weapon.base_value(hit), FixtureItems.ATTACK_DAMAGE, 'and shows it as changed')
  var payloads: Array = weapon.fire()
  assert_eq(payloads[0].value, FixtureItems.ATTACK_DAMAGE + FixtureKit.RELIC_WEAPON_ATTACK_BONUS,
      'the fired attack carries the bonus')


func test_an_item_added_during_the_fight_is_covered() -> void:
  var p := _actor()
  _give(p, FixtureKit.weapon_bonus_relic())
  var later := _board_item(p, FixtureItems.attack())
  assert_eq(later.display_value(later.def.effects[0]), FixtureItems.ATTACK_DAMAGE + FixtureKit.RELIC_WEAPON_ATTACK_BONUS)


func test_it_skips_other_types_other_actors_and_other_mechanics() -> void:
  var p := _actor()
  var e := _actor()
  _give(p, FixtureKit.weapon_bonus_relic())
  var untagged := _board_item(p, _untagged_attack())
  assert_eq(untagged.display_value(untagged.def.effects[0]), FixtureItems.ATTACK_DAMAGE, 'not an untagged item')
  var theirs := _board_item(e, FixtureItems.attack())
  assert_eq(theirs.display_value(theirs.def.effects[0]), FixtureItems.ATTACK_DAMAGE, 'not the enemy weapon')
  var shield := _board_item(p, FixtureItems.shield())
  shield.def.types = [ItemType.WEAPON]
  assert_eq(shield.display_value(shield.def.effects[0]), FixtureItems.SHIELD_VALUE, 'not a shield')


func test_a_relic_attack_is_not_raised() -> void:
  var p := _actor()
  _give(p, FixtureKit.weapon_bonus_relic())
  var attack_relic := RelicDef.new()
  attack_relic.types = [ItemType.WEAPON]
  attack_relic.effects = FixtureItems.attack().effects
  var relic := _give(p, attack_relic)
  assert_eq(relic.display_value(attack_relic.effects[0]), FixtureItems.ATTACK_DAMAGE, 'a relic is not on the board')


func test_a_percent_bonus_passive_raises_by_percent() -> void:
  var p := _actor()
  var weapon := _board_item(p, FixtureItems.attack())
  var def := RelicDef.new()
  def.passives = [ItemEffect.make(AttackPercentBonusMechanic.ID, 50.0, ItemEffect.Shape.ALL_OWN_ITEMS)]
  _give(p, def)
  assert_eq(weapon.display_value(weapon.def.effects[0]), roundf(FixtureItems.ATTACK_DAMAGE * 1.5))


# --- not a status ------------------------------------------------------------------

func test_a_passive_is_not_a_status() -> void:
  var p := _actor()
  var relic := _give(p, FixtureKit.weapon_bonus_relic())
  assert_eq(p.statuses.size(), 0, 'the status list stays empty')
  StatusManager.apply(p, WeakStatus.ID, 1.0, 3.0)
  var hooks: Array[CombatHooks] = StatusManager.hooks_of(p)
  assert_eq(hooks.size(), 2)
  assert_eq(hooks[0], relic.passives[0], 'the passive comes before the statuses')
  assert_true(hooks[1] is WeakStatus)
