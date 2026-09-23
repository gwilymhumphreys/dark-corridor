extends ItemDef
## Skull — one of the Fleshmancer's three bone shields: plain shield on the holder, protecting it
## while it hurts itself. Rib is fast with the lowest rate, Skull slow with the highest.


func _init() -> void:
  id = 'skull'
  name_key = 'Skull'                   # owner's name
  types = [ItemType.ARMOUR]
  mechanics = [ShieldMechanic.ID]
  icon = 'res://assets/icons/items/quest_24_scull.png'
  cooldown = 3.0
  effects = [ItemEffect.shield(15.0)]
