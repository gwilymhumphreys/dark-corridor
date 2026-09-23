extends ItemDef
## Bloodletting — applies bleed, and charges itself 1 second whenever its own side applies poison
## (owner, 2026-09-23). The trigger is priced as Balance.POINTS_TRIGGERS_PER_COOLDOWN triggers per
## cooldown (ItemPoints.trigger_points); the rest of the budget goes on bleed, priced at the bleed
## rate (docs/design/item_heuristics.md). No type yet.


func _init() -> void:
  id = 'bloodletting'
  name_key = 'Bloodletting'          # owner's name
  types = []                         # no type yet — owner's to decide
  mechanics = [BleedMechanic.ID, PoisonMechanic.ID]   # poison: it charges off it, like Spite Ward
  icon = 'res://assets/icons/items/alchemy_06_blood.png'   # PLACEHOLDER icon — owner's to swap
  cooldown = 5.0
  effects = [ItemEffect.make(BleedMechanic.ID, 9.0, ItemEffect.Shape.OPPONENT_LEFTMOST)]
  trigger_subs = [{
    'event': EventBus.Event.APPLIED,
    'seconds': 1.0,
    'filter': 'poison',
  }]
