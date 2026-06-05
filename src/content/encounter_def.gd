class_name EncounterDef
extends RefCounted
## An encounter definition (encounter_prd, decision #23) — authored in GDScript,
## collected in EncounterCatalog. One beat of the descent: a FIGHT (an enemy
## composition + a reward) or a REST (a partial heal). The location frame +
## telegraph are player-facing → localizable via tr(def.name_key). Phase 3 builds
## fight + rest only (events with prose, elite/boss tiers, telegraph demands later).

enum Type { FIGHT, REST }
enum Reward { NONE, DRAFT, RELIC }

var id: int = -1
var type: int = Type.FIGHT
var name_key: String = ''         # the location frame, e.g. 'A flooded antechamber'
var enemy_ids: Array = []         # FIGHT: EnemyCatalog ids, left-to-right order
var reward: int = Reward.NONE     # what a WIN reports up for the Run manager to fulfil
var heal_fraction: float = 0.0    # REST: fraction of max HP restored
