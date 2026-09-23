class_name AttackPercentBonusMechanic
extends Mechanic
## Attack Percent Bonus (PLACEHOLDER name — owner's to rename) — raises the target item's attacks by
## N percent for the rest of the fight (docs/systems/mechanics.md → Attack bonuses). Lands by
## applying `AttackPercentBonusStatus` to the item (the base `land`).

const ID := 'attack_percent_bonus'


func _init() -> void:
  id = ID
  name_key = 'Attack Percent Bonus'                            # PLACEHOLDER name — owner's to rename
  desc_key = 'Raises the item\'s attacks by a percentage for the rest of the fight.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = 'attack_percent_bonus'


func color() -> Color:
  return Colours.ATTACK
