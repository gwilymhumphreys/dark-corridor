extends ItemDef
## Femur — one of the Fleshmancer's three bone shields: plain shield on the holder, protecting it
## while it hurts itself. Rib is fast with the lowest rate, Skull slow with the highest.


func _init() -> void:
  id = 'femur'
  name_key = 'Femur'                   # owner's name
  types = [ItemType.ARMOUR]
  mechanics = [ShieldMechanic.ID]
  icon = 'res://assets/icons/items/loot_23_bone.png'
  cooldown = 2.0
  effects = [ItemEffect.shield(8.0)]
