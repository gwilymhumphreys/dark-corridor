extends ItemDef
## Spite Ward — an unpooled example of a trigger: a shield item whose cooldown bar also fills
## completely whenever poison is applied on its own side.


func _init() -> void:
  id = 'spite_ward'
  name_key = 'Spite Ward'
  types = [ItemType.ARMOUR]
  mechanics = [PoisonMechanic.ID, ShieldMechanic.ID]   # poison: it charges off it (owner, 2026-09-20)
  icon = 'res://assets/icons/items/skull_shield.png'
  cooldown = 2.0
  effects = [ItemEffect.shield(8.0)]
  trigger_subs = [{
    'event': EventBus.Event.APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': 'poison',
  }]
