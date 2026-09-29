class_name EncounterDef
extends RefCounted
## An encounter definition (docs/systems/encounter.md, decision #23) — authored in GDScript, one file
## each under content/encounters/, collected in EncounterCatalog. One beat of the descent: a FIGHT (an
## enemy composition + a reward), an EVENT (prose + options), a REST (a partial heal) or the RELIC
## encounter (a relic choice). The location frame is player-facing → localizable via tr(def.name_key).
##
## An encounter offered before a fight (EncounterPools, docs/plans/encounter_choice.md) also has a
## rarity and rules built from the player's state: `requires` (every condition must hold, or it is
## never offered) and `weights` (each rule whose condition holds multiplies how likely it is).

enum Type { FIGHT, REST, EVENT, RELIC }
# What a WIN reports up for the RunManager to fulfil. ELITE = a relic AND a draft (the
# reward asymmetry — an elite is richer than a regular fight; #2). RELIC = a relic only
# (an act boss). RELIC_CHOICE = the player picks one of a few relics (the relic encounter). DRAFT =
# a 1-of-3 item offer. NONE = rest / event (the event's outcome is its own reward).
enum Reward { NONE, DRAFT, RELIC, ELITE, RELIC_CHOICE }
## How often an encounter is offered before its weight rules apply (Balance.ENCOUNTER_WEIGHT_*).
enum Rarity { COMMON, RARE }

var id: String = ''
var type: int = Type.FIGHT
var name_key: String = ''         # the location frame, e.g. 'A flooded antechamber'
var enemy_ids: Array[String] = []        # FIGHT: EnemyCatalog ids, left-to-right order
var reward: int = Reward.NONE     # what a WIN reports up for the Run manager to fulfil
var heal_fraction: float = 0.0    # REST: fraction of max HP restored
var event_prose_key: String = ''  # EVENT: the body prose (localized via tr())
var event_options: Array[EventOptionDef] = []   # EVENT: the options; unavailable ones are hidden
var rarity: int = Rarity.COMMON
## Offered only while every one of these holds (RunCondition subclasses, src/run/conditions/).
var requires: Array[RunCondition] = []
## { 'if': RunCondition, 'multiplier': float } — while the condition holds, the chance of being offered
## is multiplied. A multiplier of 0 stops it being offered.
var weights: Array[Dictionary] = []


## How likely this encounter is to be offered to `run` now, against the others in its position list:
## 0 when a requirement fails or it is an event with no option available, otherwise its rarity's
## weight times the multiplier of every weight rule whose condition holds.
func offer_weight(run: RunManager) -> float:
  for condition: RunCondition in requires:
    if not condition.holds(run):
      return 0.0
  if type == Type.EVENT and available_options(run).is_empty():
    return 0.0
  var weight: float = Balance.ENCOUNTER_WEIGHT_RARE if rarity == Rarity.RARE else Balance.ENCOUNTER_WEIGHT_COMMON
  for rule: Dictionary in weights:
    if (rule['if'] as RunCondition).holds(run):
      weight *= float(rule['multiplier'])
  return weight


## The indices of the event options whose conditions hold for `run`, in authored order.
func available_options(run: RunManager) -> Array[int]:
  var indices: Array[int] = []
  for index: int in event_options.size():
    if event_options[index].is_available(run):
      indices.append(index)
  return indices
