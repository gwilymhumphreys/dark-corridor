class_name EncounterCatalog
## The encounter definitions (decision #23 — GDScript, keyed by Id). A regular fight
## (a grunt, rewards a draft) and a rest (a partial heal) compose the prototype map.
## FIGHT_ELITE (relic + draft) and FIGHT_RELIC (a mid-boss, relic only) are placeholder
## reward-routing beats (#2) — catalog-only, not in the map; the owner slots them into the
## real act structure / choice layer. Lazily built once.

enum Id { FIGHT_GRUNT, REST, FIGHT_ELITE, FIGHT_RELIC, FIGHT_TOUGH, FIGHT_BOSS, EVENT_SHRINE }

static var _defs: Dictionary = {}


static func get_def(id: int) -> EncounterDef:
  if _defs.is_empty():
    _build()
  return _defs[id]


static func _build() -> void:
  _defs[Id.FIGHT_GRUNT] = _fight_grunt()
  _defs[Id.REST] = _rest()
  _defs[Id.FIGHT_ELITE] = _fight_elite()
  _defs[Id.FIGHT_RELIC] = _fight_relic()
  _defs[Id.FIGHT_TOUGH] = _fight_tough()
  _defs[Id.FIGHT_BOSS] = _fight_boss()
  _defs[Id.EVENT_SHRINE] = _event_shrine()


static func _fight_grunt() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = Id.FIGHT_GRUNT
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A dim corridor'
  d.enemy_ids = [EnemyCatalog.Id.GRUNT]
  d.reward = EncounterDef.Reward.DRAFT
  return d


static func _rest() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = Id.REST
  d.type = EncounterDef.Type.REST
  d.name_key = 'A quiet alcove'
  d.heal_fraction = Balance.REST_HEAL_FRACTION
  d.reward = EncounterDef.Reward.NONE
  return d


## Placeholder elite (#2): a tougher fight (two grunts) rewarding a relic AND a draft.
static func _fight_elite() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = Id.FIGHT_ELITE
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'An elite ambush'
  d.enemy_ids = [EnemyCatalog.Id.GRUNT, EnemyCatalog.Id.GRUNT]
  d.reward = EncounterDef.Reward.ELITE
  return d


## Placeholder mid-boss-style relic beat (#2): a fight rewarding a relic only.
static func _fight_relic() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = Id.FIGHT_RELIC
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A warded vault'
  d.enemy_ids = [EnemyCatalog.Id.GRUNT]
  d.reward = EncounterDef.Reward.RELIC
  return d


## Placeholder tougher regular fight (#1): a brute, still a draft reward — choice-pool fare.
static func _fight_tough() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = Id.FIGHT_TOUGH
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'A blocked passage'
  d.enemy_ids = [EnemyCatalog.Id.BRUTE]
  d.reward = EncounterDef.Reward.DRAFT
  return d


## Placeholder boss (#1): the act-end fight. Rewards a relic (the RunManager ends the run
## on the FINAL act's boss instead — that's the descent's ending).
static func _fight_boss() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = Id.FIGHT_BOSS
  d.type = EncounterDef.Type.FIGHT
  d.name_key = 'The warden\'s gate'
  d.enemy_ids = [EnemyCatalog.Id.BOSS]
  d.reward = EncounterDef.Reward.RELIC
  return d


## Placeholder non-combat EVENT (#1): prose + a binary choice with direct player-Actor
## outcomes. The owner authors real event prose + relic/potion outcomes; this proves the
## event path (resolution, the option-pick intent, the outcome) end to end.
static func _event_shrine() -> EncounterDef:
  var d := EncounterDef.new()
  d.id = Id.EVENT_SHRINE
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
