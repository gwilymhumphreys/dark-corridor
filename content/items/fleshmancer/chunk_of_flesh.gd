extends ItemDef
## Chunk of Flesh — the item the Fleshmancer's attacks create on its own board
## (docs/systems/item_creation_and_decay.md). A weak attacker that decays after a few fires. Never
## drafted; it only appears through a create-item effect.


func _init() -> void:
  id = 'chunk_of_flesh'
  name_key = 'Chunk of Flesh'        # owner's term — rename if desired
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/res_149_meet.png'
  cooldown = 2.0
  starting_uses = 2                  # destroyed after this many fires (the Decay status)
  effects = [ItemEffect.attack(1.0)]
