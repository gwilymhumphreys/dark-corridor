extends ItemDef
## Druid Staff — the Spore Druid's first Spores applier (docs/design/spore_druid.md): an attack that
## also puts one Spore on the struck enemy. Single-target so Spores pile on one enemy, the shape a
## Mass payoff wants to consume. Appliers are commons; the Mass payoff sits a tier up.


func _init() -> void:
  id = 'druid_staff'
  name_key = 'Druid Staff'
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/staff_v2_02.png'
  cooldown = 3.0
  effects = [
    ItemEffect.attack(10.0),
    ItemEffect.apply_status('spores', 1.0, ItemEffect.Shape.OPPONENT_LEFTMOST),
  ]
