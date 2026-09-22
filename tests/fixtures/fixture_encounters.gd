class_name FixtureEncounters
## Plain encounter definitions for tests (docs/systems/testing.md). FixtureContent adds the three
## below under their own ids, and puts a fixture encounter of the same type and reward in place of
## every authored encounter, under the authored id, because the run map names encounters by id.
## Every fixture fight is one fixture enemy.
##
## The numbers are fixture constants and must NOT be pulled from Balance, for the same reason as the
## ones in fixture_items.gd.

const FIGHT: String = 'fixture_fight'
const REST: String = 'fixture_rest'
const EVENT: String = 'fixture_event'

const REST_HEAL_FRACTION: float = 0.3
const EVENT_HEAL_FRACTION: float = 0.25
const EVENT_MAX_HP: float = 10.0

# The index of each option in every fixture event.
const OPTION_HEAL: int = 0
const OPTION_MAX_HP: int = 1
const OPTION_ADD_ALLY: int = 2


## A fight against one fixture enemy.
static func fight(id: String = FIGHT, reward: int = EncounterDef.Reward.DRAFT) -> EncounterDef:
  var d := EncounterDef.new()
  d.id = id
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A fixture corridor'
  d.enemy_ids = [FixtureEnemies.ID]
  d.reward = reward
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
  heal.effect = EventOptionDef.Effect.HEAL_FRACTION
  heal.amount = EVENT_HEAL_FRACTION
  var grow := EventOptionDef.new()
  grow.label_key = 'Grow'
  grow.effect = EventOptionDef.Effect.MAX_HP_BONUS
  grow.amount = EVENT_MAX_HP
  var recruit := EventOptionDef.new()
  recruit.label_key = 'Recruit'
  recruit.effect = EventOptionDef.Effect.ADD_ALLY
  recruit.ally_def_id = FixtureEnemies.ALLY_ID
  d.event_options = [heal, grow, recruit]
  return d


## The fixture encounter that stands in for `authored`: same id, type and reward.
static func standing_in_for(authored: EncounterDef) -> EncounterDef:
  match authored.type:
    EncounterDef.Type.REST:
      return rest(authored.id)
    EncounterDef.Type.EVENT:
      return event(authored.id)
  return fight(authored.id, authored.reward)
