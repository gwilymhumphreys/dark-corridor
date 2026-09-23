extends ItemDef
## Rib — one of the Fleshmancer's three bone shields: plain shield on the holder, protecting it
## while it hurts itself. Rib is fast with the lowest rate, Skull slow with the highest.


func _init() -> void:
  id = 'rib'
  name_key = 'Rib'                   # owner's name
  types = [ItemType.ARMOUR]
  mechanics = [ShieldMechanic.ID]
  icon = 'res://assets/icons/items/loot_22_remains.png'
  cooldown = 1.0
  effects = [ItemEffect.shield(3.0)]
