extends ItemDef
## Claw — the only weapon on enemy boards, so every enemy's damage comes from it. Sized so an early
## fight costs a player with no armour up to 10% of starting health (owner, 2026-09-22).


func _init() -> void:
  id = 'claw'
  name_key = 'Claw'
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/loot_183_claw.png'
  cooldown = 4.0
  effects = [ItemEffect.attack(2.0)]
