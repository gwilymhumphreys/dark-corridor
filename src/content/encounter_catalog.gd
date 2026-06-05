class_name EncounterCatalog
## The encounter definitions (decision #23 — GDScript, keyed by Id). Phase 3 pool:
## one regular fight (a grunt, rewards a draft) and one rest (a partial heal). The
## Run manager composes these into a short linear map. Lazily built once.

enum Id { FIGHT_GRUNT, REST }

static var _defs: Dictionary = {}


static func get_def(id: int) -> EncounterDef:
  if _defs.is_empty():
    _build()
  return _defs[id]


static func _build() -> void:
  _defs[Id.FIGHT_GRUNT] = _fight_grunt()
  _defs[Id.REST] = _rest()


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
