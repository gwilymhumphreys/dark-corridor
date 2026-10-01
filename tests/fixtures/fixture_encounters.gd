class_name FixtureEncounters
## Plain encounter definitions for tests (docs/systems/testing.md). FixtureContent adds the five
## below under their own ids, offers the rest, the event and the reward encounter before every fight
## (one per EncounterPools position, in that order), and puts a fixture encounter of the same type and reward in place of
## every authored encounter, under the authored id, because the run map names encounters by id.
## Every fixture fight is one fixture enemy.
##
## The numbers are fixture constants and must NOT be pulled from Balance, for the same reason as the
## ones in fixture_items.gd.

const FIGHT: String = 'fixture_fight'
const REST: String = 'fixture_rest'
const EVENT: String = 'fixture_event'
const REWARD: String = 'fixture_reward'
const SHOP: String = 'fixture_shop'

# The position of each fixture encounter in the choice before every fight (FixtureContent).
const CHOICE_REST: int = 0
const CHOICE_EVENT: int = 1
const CHOICE_REWARD: int = 2
# How many relics the fixture reward encounter offers.
const REWARD_RELICS: int = 3
# How many items the fixture shop sells, before its relic and potion.
const SHOP_ITEMS: int = 2

const REST_HEAL_FRACTION: float = 0.3
const EVENT_HEAL_FRACTION: float = 0.25
const EVENT_MAX_HP: int = 10

# The index of each option in every fixture event.
const OPTION_HEAL: int = 0
const OPTION_MAX_HP: int = 1
const OPTION_ADD_ALLY: int = 2


## A fight against one fixture enemy.
static func fight(id: String = FIGHT, fight_reward: int = EncounterDef.Reward.NONE) -> EncounterDef:
  var d := EncounterDef.new()
  d.id = id
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A fixture corridor'
  d.enemy_ids = [FixtureEnemies.ID]
  d.reward = fight_reward
  return d


## A rest that heals a fixed fraction of maximum health.
static func rest(id: String = REST) -> EncounterDef:
  var d := EncounterDef.new()
  d.id = id
  d.type = EncounterDef.Type.REST
  d.name_key = 'A fixture alcove'
  d.heal_fraction = REST_HEAL_FRACTION
  d.reward = EncounterDef.Reward.NONE
  return d


## An event with three options: heal, raise maximum health, or recruit the fixture ally.
static func event(id: String = EVENT) -> EncounterDef:
  var d := EncounterDef.new()
  d.id = id
  d.type = EncounterDef.Type.EVENT
  d.name_key = 'A fixture event'
  d.event_prose_key = 'A fixture event.'
  var heal := EventOptionDef.new()
  heal.label_key = 'Heal'
  heal.effects = [RunEffect.heal_fraction(EVENT_HEAL_FRACTION)]
  var grow := EventOptionDef.new()
  grow.label_key = 'Grow'
  grow.effects = [RunEffect.max_hp(EVENT_MAX_HP)]
  var recruit := EventOptionDef.new()
  recruit.label_key = 'Recruit'
  recruit.effects = [RunEffect.add_ally(FixtureEnemies.ALLY_ID)]
  d.event_options = [heal, grow, recruit]
  return d


## A reward encounter: no fight, a pick of REWARD_RELICS relics.
static func reward(id: String = REWARD) -> EncounterDef:
  var d := EncounterDef.new()
  d.id = id
  d.type = EncounterDef.Type.REWARD
  d.name_key = 'A fixture reliquary'
  d.stock = [StockEntry.relics(REWARD_RELICS)]
  return d


## A shop selling SHOP_ITEMS items, a relic and a potion. Offered with a single matching item, since
## the fixture character's pool is small.
static func shop(id: String = SHOP) -> EncounterDef:
  var d := EncounterDef.new()
  d.id = id
  d.type = EncounterDef.Type.SHOP
  d.name_key = 'A fixture shop'
  d.stock = [StockEntry.items(SHOP_ITEMS), StockEntry.relics(1), StockEntry.potions(1)]
  d.min_items = 1
  return d


## The fixture encounter that stands in for `authored`: same id, type and reward.
static func standing_in_for(authored: EncounterDef) -> EncounterDef:
  match authored.type:
    EncounterDef.Type.REST:
      return rest(authored.id)
    EncounterDef.Type.EVENT:
      return event(authored.id)
    EncounterDef.Type.REWARD:
      return reward(authored.id)
    EncounterDef.Type.SHOP:
      return shop(authored.id)
  return fight(authored.id, authored.reward)
