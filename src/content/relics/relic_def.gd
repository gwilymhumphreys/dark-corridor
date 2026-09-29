class_name RelicDef
extends ItemDef
## A relic definition (docs/systems/content.md → Relic) — an item with no timer, authored in
## GDScript and collected in RelicCatalog. It uses the item fields (effects, trigger_subs, mechanics,
## crit_chance, the tooltip), adds always-on `passives`, and builds an Item for each fight (Actor.relics), but its bar never
## fills over time: each trigger fills it completely, and it fires on the next step.
## A relic trigger entry is an item trigger without 'seconds', optionally with its own effects and
## limit (docs/systems/content.md → Relic):
##   { event: EventBus.Event, filter: Variant (a status or mechanic id), source_filter: EventBus.SourceFilter,
##     effects: Array[ItemEffect], fires_per_fight: int }
## An entry without 'effects' fires the relic's `effects` and counts against the relic's
## `fires_per_fight`; an entry with them fires only its own, limited by its own 'fires_per_fight'.

# Always-on abilities for the whole fight, written like item effects (mechanic, value, shape, target
# filter) and listed in the tooltip as item effect lines. Each mechanic needs a passive class in
# PassiveRegistry; Item builds one instance per entry.
var passives: Array[ItemEffect] = []
# How many times the relic can fire in one fight. 0 = no limit; 1 = "the first time each fight".
var fires_per_fight: int = 0
# Abilities outside fights: { event: RunManager.RunEvent, effects: Array[RunEffect] }. The Run
# manager applies an entry's effects when its event happens (docs/systems/content.md → Relic).
var run_triggers: Array[Dictionary] = []


func _init() -> void:
  # One sim step, so the Item's Ticker crosses on a single full push. Never shown: a relic's
  # tooltip has no charge line.
  cooldown = Balance.STEP


## True when trigger entry `index` carries its own effects.
func has_own_effects(index: int) -> bool:
  return trigger_subs[index].has('effects')


## The effects trigger entry `index` fires: its own, or the relic's.
func trigger_effects(index: int) -> Array[ItemEffect]:
  if not has_own_effects(index):
    return effects
  var own: Array[ItemEffect] = []
  own.assign(trigger_subs[index]['effects'])
  return own
