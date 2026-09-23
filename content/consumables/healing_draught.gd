extends ConsumableDef
## Healing Draught — a potion that heals the player when thrown.


func _init() -> void:
  id = 'healing_draught'
  name_key = 'Healing Draught'
  icon = 'res://assets/icons/potions/alchemy_31_bigheal_flask.png'
  effects = [ItemEffect.heal(20.0)]
