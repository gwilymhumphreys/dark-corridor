extends CharacterDef
## Fleshmancer (PLACEHOLDER label — owner's to rename; docs/design/character_ideas.md → Flesh Golem /
## Meat) — the item-economy character: its attacks create Chunks of Flesh on its own board, which decay
## after a few fires, and other items eat them. Still the owner's to fill: the signature relic and more
## pool depth.


func _init() -> void:
  id = 'fleshmancer'
  name_key = 'Aldous'                # PLACEHOLDER personal name — owner's to rename
  class_key = 'Disgraced Surgeon'    # the owner's class name (2026-09-18)
  portrait = 'res://assets/portraits/characters/leper_nb.png'
  select_image = 'res://assets/portraits/large/gemini_a.png'   # PLACEHOLDER picture, owner's to swap
  item_pool = [
    'carving_knife',
    'cleaver',
    'bone_saw',
    'flesh_explosion',
    'flensing_hook',
    'skin_graft',
    'bone_spear',
    'rib',
    'femur',
    'skull',
  ]
  # Two chunk producers and a shield, drawn per run. PLACEHOLDER mix: swap a weapon for
  # ItemType.SKILL or ItemType.SPELL if the opening should carry one.
  starting_item_types = [ItemType.WEAPON, ItemType.WEAPON, ItemType.ARMOUR]
  starting_relic_id = ''             # no signature relic yet (the owner's to design)
