extends CharacterDef
## Spore Druid (docs/design/spore_druid.md) — the status character, built on the Spores counter and
## the items that apply and spend it. Still the owner's to fill: the signature relic, skills and more
## items.


func _init() -> void:
  id = 'spore_druid'
  name_key = 'Maren'                 # PLACEHOLDER personal name — owner's to rename
  subtitle_key = 'Rot Shepherd'      # the owner's lead role name (spore_druid.md)
  portrait = 'res://assets/portraits/characters/shaman.png'   # PLACEHOLDER portrait — owner's to swap
  item_pool = [
    'druid_staff',
    'spore_spitter',
    'capped_cudgel',
    'bloomhammer',
    'wilt_frond',
    'pocket_shrooms',
  ]
  # Three weapons, because every Spore Druid item is a weapon so far. Revisit once its skills and
  # armour exist.
  starting_item_types = [ItemType.WEAPON, ItemType.WEAPON, ItemType.WEAPON]
  starting_relic_id = ''             # no signature relic yet (the owner's to design)
