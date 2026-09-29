class_name RelicDef
extends ItemDef
## A relic definition (docs/systems/content.md → Relic) — an item with no timer, authored in
## GDScript and collected in RelicCatalog. It uses the item fields (effects, trigger_subs, mechanics,
## crit_chance, the tooltip), adds always-on `passives`, and builds an Item for each fight (Actor.relics), but its bar never
## fills over time: each trigger fills it completely, and it fires on the next step.
## A relic trigger entry is an item trigger without 'seconds':
##   { event: EventBus.Event, filter: Variant (a status or mechanic id), source_filter: EventBus.SourceFilter }

# Always-on abilities for the whole fight, written like item effects (mechanic, value, shape, target
# filter) and listed in the tooltip as item effect lines. Each mechanic needs a passive class in
# PassiveRegistry; Item builds one instance per entry.
var passives: Array[ItemEffect] = []
# How many times the relic can fire in one fight. 0 = no limit; 1 = "the first time each fight".
var fires_per_fight: int = 0
# Maximum health added once, when the relic is granted (a direct run-state change, baked into the
# saved snapshot's max_hp and never re-applied on load).
var max_hp_bonus: float = 0.0


func _init() -> void:
  # One sim step, so the Item's Ticker crosses on a single full push. Never shown: a relic's
  # tooltip has no charge line.
  cooldown = Balance.STEP
