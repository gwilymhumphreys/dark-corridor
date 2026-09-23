extends ItemDef
## Wide Forge — a slow rare item that burns every enemy and gives every attack item of yours +5
## attack for the rest of the fight (owner, 2026-09-23). "Attack item" means any item with the attack
## mechanic, not only weapons. The burn spends the rare budget at the all-opponents price
## (docs/design/item_heuristics.md); the attack bonus is unpriced. Goes wide; the Deep Forge is its
## go-tall twin. No type yet.
##
## The flat bonus helps fast attack items far more than slow ones (it can double a Dagger's hit but
## barely changes a Greatsword's). That is intended: this is meant to be a strong rare payoff item
## for a go-wide board (owner, 2026-09-23). Do not switch it to a percentage to even it out; tune the
## flat amount instead (lowered from 10 to 5).


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
  var bonus := ItemEffect.make(AttackBonusMechanic.ID, 5.0, ItemEffect.Shape.ALL_OWN_ITEMS)
  bonus.target_filter = attack_items
  effects = [
    ItemEffect.make(BurnMechanic.ID, 22.0, ItemEffect.Shape.ALL_OPPONENTS),
    bonus,
  ]
