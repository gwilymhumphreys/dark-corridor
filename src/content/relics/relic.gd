class_name Relic
extends RefCounted
## A relic instance (docs/systems/content.md) — held in the player run-state, NOT Actor-owned
## (decision #6). Thin in Phase 3: it carries its def. The Run manager reads it to
## apply the combat-start status when a fight begins, and stores its id in the run
## snapshot. (Triggered / direct shapes — and an enchant slot equivalent — later.)

var def: RelicDef


func _init(relic_def: RelicDef) -> void:
  def = relic_def
