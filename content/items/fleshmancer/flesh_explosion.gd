extends ItemDef
## Flesh Explosion — the Fleshmancer's first payoff for losing items: a hit on every enemy on a long
## cooldown that fills faster each time one of its own items is destroyed (a chunk decaying or being
## consumed). The fill per destroyed item is the power ceiling to watch. Uncommon because it is
## trigger-driven.


func _init() -> void:
  id = 'flesh_explosion'
  name_key = 'Flesh Explosion'       # owner's name
  types = [ItemType.SPELL]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/skill_blood_boiling_nb.png'
  rarity = Rarity.UNCOMMON
  cooldown = 20.0
  effects = [ItemEffect.attack(70.0, ItemEffect.Shape.ALL_OPPONENTS)]
  # Each own item destroyed fills this share of the bar (about 1s of the 20s).
  trigger_subs = [{
    'event': EventBus.Event.ITEM_DESTROYED,
    'amount': 0.05,
  }]
