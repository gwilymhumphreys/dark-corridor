class_name SporesStatus
extends StatusEffect
## Spores — the Spore Druid's signature stacked counter + the canonical Mass fuel (spore_druid.md,
## #28). An inert counter: it accumulates (stacks additively on reapply) and otherwise does nothing
## — no tick, no decay, no damage — until a Mass card spends it via consume(). "Does nothing on its
## own for now" is the design's explicit, open-to-change stance.

const ID := 'spores'


func _init() -> void:
  id = ID
  name_key = 'Spores'
  color = Colours.STATUS_SPORES


func is_fuel() -> bool:
  return true
