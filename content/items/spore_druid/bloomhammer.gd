extends ItemDef
## Bloomhammer — the slow end of the Spore Druid weapon spread (docs/design/spore_druid.md): a heavy
## hit that puts two Spores on at once, for when a Mass payoff needs a burst of Spores.


func _init() -> void:
  id = 'bloomhammer'
  name_key = 'Bloomhammer'           # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/wooden_hammer.png'
  cooldown = 5.0
  effects = [
    ItemEffect.attack(40.0),
    ItemEffect.apply_status('spores', 2.0, ItemEffect.Shape.OPPONENT_LEFTMOST),
  ]
