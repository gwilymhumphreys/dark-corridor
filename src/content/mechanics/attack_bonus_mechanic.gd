class_name AttackBonusMechanic
extends Mechanic
## Attack Bonus (PLACEHOLDER name — owner's to rename) — gives the target item +N damage on each of
## its attacks for the rest of the fight (docs/systems/mechanics.md → Attack bonuses). Lands by
## applying `AttackBonusStatus` to the item (the base `land`).

const ID := 'attack_bonus'


func _init() -> void:
  id = ID
  name_key = 'Attack Bonus'                                    # PLACEHOLDER name — owner's to rename
  desc_key = 'Adds damage to the item\'s attacks for the rest of the fight.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = 'attack_bonus'


func color() -> Color:
  return Colours.ATTACK
