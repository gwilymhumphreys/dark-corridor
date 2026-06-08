class_name EncounterCatalog
## The encounter definitions (decision #23 — GDScript, keyed by Id). A regular fight
## (a grunt, rewards a draft) and a rest (a partial heal) compose the prototype map.
## FIGHT_ELITE (relic + draft) and FIGHT_RELIC (a mid-boss, relic only) are placeholder
## reward-routing beats (#2) — catalog-only, not in the map; the owner slots them into the
## real act structure / choice layer. Lazily built once.

const FIGHT_GRUNT := 'fight_grunt'
const REST := 'rest'
const FIGHT_ELITE := 'fight_elite'
const FIGHT_RELIC := 'fight_relic'
const FIGHT_TOUGH := 'fight_tough'
const FIGHT_BOSS := 'fight_boss'
const EVENT_SHRINE := 'event_shrine'
const EVENT_WANDERER := 'event_wanderer'

static var _defs: Dictionary = {}


static func get_def(id: String) -> EncounterDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('EncounterCatalog: unknown encounter id "%s"' % id)
  return _defs[id]


static func _build() -> void:
  _defs[FIGHT_GRUNT] = _fight_grunt()
  _defs[REST] = _rest()
  _defs[FIGHT_ELITE] = _fight_elite()
  _defs[FIGHT_RELIC] = _fight_relic()
  _defs[FIGHT_TOUGH] = _fight_tough()
  _defs[FIGHT_BOSS] = _fight_boss()
  _defs[EVENT_SHRINE] = _event_shrine()
  _defs[EVENT_WANDERER] = _event_wanderer()


static func _fight_grunt() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = FIGHT_GRUNT
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A dim corridor'
  d.enemy_ids = [EnemyCatalog.GRUNT]
  d.reward = EncounterDef.Reward.DRAFT
  return d


static func _rest() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = REST
  d.type = EncounterDef.Type.REST
  d.name_key = 'A quiet alcove'
  d.heal_fraction = Balance.REST_HEAL_FRACTION
  d.reward = EncounterDef.Reward.NONE
  return d


## Placeholder elite (#2): a tougher fight (two grunts) rewarding a relic AND a draft.
static func _fight_elite() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = FIGHT_ELITE
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'An elite ambush'
  d.enemy_ids = [EnemyCatalog.GRUNT, EnemyCatalog.GRUNT]
  d.reward = EncounterDef.Reward.ELITE
  return d


## Placeholder mid-boss-style relic beat (#2): a fight rewarding a relic only.
static func _fight_relic() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = FIGHT_RELIC
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A warded vault'
  d.enemy_ids = [EnemyCatalog.GRUNT]
  d.reward = EncounterDef.Reward.RELIC
  return d


## Placeholder tougher regular fight (#1): a brute, still a draft reward — choice-pool fare.
static func _fight_tough() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = FIGHT_TOUGH
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A blocked passage'
  d.enemy_ids = [EnemyCatalog.BRUTE]
  d.reward = EncounterDef.Reward.DRAFT
  return d


## Placeholder boss (#1): the act-end fight. Rewards a relic (the RunManager ends the run
## on the FINAL act's boss instead — that's the descent's ending).
static func _fight_boss() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = FIGHT_BOSS
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'The warden\'s gate'
  d.enemy_ids = [EnemyCatalog.BOSS]
  d.reward = EncounterDef.Reward.RELIC
  return d


## Placeholder non-combat EVENT (#1): prose + a binary choice with direct player-Actor
## outcomes. The owner authors real event prose + relic/potion outcomes; this proves the
## event path (resolution, the option-pick intent, the outcome) end to end.
static func _event_shrine() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = EVENT_SHRINE
  d.type = EncounterDef.Type.EVENT
  d.name_key = 'A dripping shrine'
  d.event_prose_key = 'A black idol slumps in an alcove, weeping cold water. ' \
    + 'You could kneel and drink, or pry the shard from its brow.'
  var pray := EventOptionDef.new()
  pray.label_key = 'Kneel and drink'
  pray.effect = EventOptionDef.Effect.HEAL_FRACTION
  pray.amount = Balance.EVENT_SHRINE_HEAL_FRACTION
  var pry := EventOptionDef.new()
  pry.label_key = 'Pry the shard loose'
  pry.effect = EventOptionDef.Effect.MAX_HP_BONUS
  pry.amount = Balance.EVENT_SHRINE_MAX_HP
  d.event_options = [pray, pry]
  return d


## Placeholder recruit EVENT (#1) — the event-driven ally-acquisition path: one option
## recruits a run-scoped ally (ADD_ALLY, built from a placeholder EnemyDef), the other declines
## for a small heal. Proves the ADD_ALLY outcome end to end (RunManager.pick_event_option →
## add_ally → the ally joins every later fight + persists in the snapshot). The owner authors
## the real recruit prose + which ally def joins.
static func _event_wanderer() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = EVENT_WANDERER
  d.type = EncounterDef.Type.EVENT
  d.name_key = 'A figure in the dark'
  d.event_prose_key = 'A gaunt shape uncurls from a recess, a notched blade across its knees. ' \
    + 'It rasps an offer: walk together a while, and it will fight at your side.'
  var welcome := EventOptionDef.new()
  welcome.label_key = 'Let it join you'
  welcome.effect = EventOptionDef.Effect.ADD_ALLY
  welcome.ally_def_id = EnemyCatalog.SPORE_THRALL
  var refuse := EventOptionDef.new()
  refuse.label_key = 'Walk on alone'
  refuse.effect = EventOptionDef.Effect.HEAL_FRACTION
  refuse.amount = Balance.EVENT_WANDERER_DECLINE_HEAL_FRACTION
  d.event_options = [welcome, refuse]
  return d
