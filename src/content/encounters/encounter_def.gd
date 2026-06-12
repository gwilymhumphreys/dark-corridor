class_name EncounterDef
extends RefCounted
## An encounter definition (docs/systems/encounter.md, decision #23) — authored in GDScript,
## collected in EncounterCatalog. One beat of the descent: a FIGHT (an enemy
## composition + a reward) or a REST (a partial heal). The location frame +
## telegraph are player-facing → localizable via tr(def.name_key). Phase 3 builds
## fight + rest only (events with prose, elite/boss tiers, telegraph demands later).

enum Type { FIGHT, REST, EVENT }
# What a WIN reports up for the RunManager to fulfil. ELITE = a relic AND a draft (the
# reward asymmetry — an elite is richer than a regular fight; #2). RELIC = a relic only
# (a mid-boss / guaranteed-relic beat). DRAFT = a 1-of-3 item offer. NONE = rest / event
# (the event's outcome is its own reward).
enum Reward { NONE, DRAFT, RELIC, ELITE }

var id: String = ''
var type: int = Type.FIGHT
var name_key: String = ''         # the location frame, e.g. 'A flooded antechamber'
var enemy_ids: Array = []         # FIGHT: EnemyCatalog ids (String), left-to-right order
var reward: int = Reward.NONE     # what a WIN reports up for the Run manager to fulfil
var heal_fraction: float = 0.0    # REST: fraction of max HP restored
var event_prose_key: String = ''  # EVENT: the body prose (localized via tr())
var event_options: Array = []     # EVENT: Array[EventOptionDef] — the binary choice
