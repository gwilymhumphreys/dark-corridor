extends ItemDef
## Bone Spear — the Fleshmancer's first bleed applier (docs/design/mechanic_ideas.md → Bleed). The
## bleed is unblockable so the enemy's own shield cannot soak the wound.


func _init() -> void:
  id = 'bone_spear'
  name_key = 'Bone Spear'            # owner's name
  tags = [AttackMechanic.ID, BleedMechanic.ID, ItemType.WEAPON]
  icon = 'res://assets/icons/items/spear_27.png'
  cooldown = 6.0
  var bleed := ItemEffect.make(BleedMechanic.ID, 3.0, ItemEffect.Shape.OPPONENT_LEFTMOST)
  bleed.flags = Delivery.Flag.UNBLOCKABLE
  effects = [ItemEffect.attack(6.0), bleed]
