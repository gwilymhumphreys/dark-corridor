extends ItemDef
## Shield Bash — an uncommon skill that hits the front enemy for as much as the Smith's current shield,
## and keeps the shield (owner, 2026-09-23). It rewards stacking armour pieces. The damage depends on
## the shield, so the budget cannot price it; it is tuned by its cooldown instead (owner). The attack
## bonuses still apply on top of the shield amount.


func _init() -> void:
  id = 'shield_bash'
  name_key = 'Shield Bash'
  types = [ItemType.SKILL]
  mechanics = [AttackMechanic.ID, ShieldMechanic.ID]
  icon = 'res://assets/icons/items/shield_attack.png'   # PLACEHOLDER icon — owner's to swap
  rarity = Rarity.UNCOMMON
  cooldown = 8.0                     # starting point — tune here
  var bash := ItemEffect.attack(0.0)
  bash.per_owner_stack_id = ShieldStatus.ID
  bash.per_owner_stack_scale = 1.0
  effects = [bash]
