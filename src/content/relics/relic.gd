class_name Relic
extends RefCounted
## A relic the run owns (docs/systems/content.md → Relic): it carries its def. The Run manager
## builds an Item from it for each fight (Actor.relics) and stores its id in the run snapshot.

var def: RelicDef


func _init(relic_def: RelicDef) -> void:
  def = relic_def
