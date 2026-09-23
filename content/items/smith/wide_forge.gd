extends ItemDef
## Wide Forge — a slow rare item that burns every enemy and gives every attack item of yours +10
## attack for the rest of the fight (owner, 2026-09-23). "Attack item" means any item with the attack
## mechanic, not only weapons. The burn spends the rare budget at the all-opponents price
## (docs/design/item_heuristics.md); the attack bonus is unpriced. Goes wide; the Deep Forge is its
## go-tall twin. No type yet.


func _init() -> void:
  id = 'wide_forge'
  name_key = 'Wide Forge'            # owner's working name — to be renamed
  types = []                         # no type yet — owner's to decide
  mechanics = [AttackBonusMechanic.ID, BurnMechanic.ID]
  icon = 'res://assets/icons/items/tech_forge.png'   # PLACEHOLDER icon — owner's to swap
  rarity = Rarity.RARE
  cooldown = 10.0
  var attack_items := TargetFilter.new()
  attack_items.add_mechanic(AttackMechanic.ID)
  var bonus := ItemEffect.make(AttackBonusMechanic.ID, 10.0, ItemEffect.Shape.ALL_OWN_ITEMS)
  bonus.target_filter = attack_items
  effects = [
    ItemEffect.make(BurnMechanic.ID, 22.0, ItemEffect.Shape.ALL_OPPONENTS),
    bonus,
  ]
