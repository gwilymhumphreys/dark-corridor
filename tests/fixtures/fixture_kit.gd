class_name FixtureKit
## Plain potion, enchant and relic definitions for tests (docs/systems/testing.md), so a test of
## throwing, enchanting or relic effects does not depend on authored content. FixtureContent adds
## them to their catalogs, which a test needs only when it looks a definition up by id (a save and
## reload, a character's starting kit).
##
## The numbers are fixture constants and must NOT be pulled from Balance, for the same reason as the
## ones in fixture_items.gd.

const POTION_ID: String = 'fixture_potion'
const ENCHANT_ID: String = 'fixture_enchant'
const SHIELD_RELIC_ID: String = 'fixture_shield_relic'
const MAX_HP_RELIC_ID: String = 'fixture_max_hp_relic'

const POTION_HEAL: float = 20.0
const ENCHANT_MULT: float = 1.5
const RELIC_SHIELD: float = 5.0
const RELIC_MAX_HP: float = 10.0


## A potion that heals its thrower.
static func potion() -> ConsumableDef:
  var d := ConsumableDef.new()
  d.id = POTION_ID
  d.name_key = 'Fixture Potion'
  d.icon = 'res://assets/icons/potions/alchemy_31_bigheal_flask.png'
  var heal := ItemEffect.new()
  heal.mechanic = HealMechanic.ID
  heal.value = POTION_HEAL
  heal.shape = ItemEffect.Shape.SELF
  d.effects = [heal]
  return d


## An enchant that multiplies every value its item fires.
static func enchant() -> EnchantDef:
  var d := EnchantDef.new()
  d.id = ENCHANT_ID
  d.name_key = 'Fixture Enchant'
  d.value_mult = ENCHANT_MULT
  return d


## A relic that gives its owner shield at the start of every fight. `id` lets FixtureContent put
## one in place of an authored relic.
static func shield_relic(id: String = SHIELD_RELIC_ID) -> RelicDef:
  var d := RelicDef.new()
  d.id = id
  d.name_key = 'Fixture Shield Relic'
  d.kind = RelicDef.Kind.COMBAT_START_STATUS
  d.status_id = 'shield'
  d.status_count = RELIC_SHIELD
  d.panel_colour_name = 'SHIELD'
  return d


## A relic that raises its owner's maximum health once, when granted.
static func max_hp_relic() -> RelicDef:
  var d := RelicDef.new()
  d.id = MAX_HP_RELIC_ID
  d.name_key = 'Fixture Health Relic'
  d.kind = RelicDef.Kind.MAX_HP_BONUS
  d.max_hp_bonus = RELIC_MAX_HP
  d.panel_colour_name = 'HEAL'
  return d
