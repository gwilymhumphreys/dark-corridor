extends ItemDef
## Deep Forge — the Smith's fire, a slow rare item that burns every enemy and gives one random attack
## item +50% attack for the rest of the fight (owner, 2026-09-23). The burn spends the rare budget
## at the all-opponents price (docs/design/item_heuristics.md); the attack bonus is unpriced. Goes
## tall; the Wide Forge is its go-wide twin. No type yet.


func _init() -> void:
  id = 'deep_forge'
  name_key = 'Deep Forge'            # owner's working name — to be renamed
  types = []                         # no type yet — owner's to decide
  mechanics = [AttackPercentBonusMechanic.ID, BurnMechanic.ID]
  icon = 'res://assets/icons/items/forge.png'   # PLACEHOLDER icon — owner's to swap
  rarity = Rarity.RARE
  cooldown = 10.0
  var attack_items := TargetFilter.new()
  attack_items.add_mechanic(AttackMechanic.ID)
  var bonus := ItemEffect.make(AttackPercentBonusMechanic.ID, 50.0, ItemEffect.Shape.OWN_ITEM_RANDOM)
  bonus.target_filter = attack_items
  effects = [
    ItemEffect.make(BurnMechanic.ID, 22.0, ItemEffect.Shape.ALL_OPPONENTS),
    bonus,
  ]
