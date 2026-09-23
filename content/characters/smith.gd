extends CharacterDef
## Smith (PLACEHOLDER label — owner's to rename; docs/design/smith.md) — the roster's on-ramp
## character. It manages no separate resource: its skills buff its own weapons and armour over a
## fight. Still the owner's to fill: the go-wide and go-tall skills, the signature relic and a
## portrait.


func _init() -> void:
  id = 'smith'
  name_key = 'Orrin'                 # PLACEHOLDER personal name — owner's to rename
  subtitle_key = 'Smith'             # PLACEHOLDER role line — owner's to rename
  portrait = 'res://assets/portraits/characters/warrior_nb.png'   # PLACEHOLDER portrait — owner's to swap
  item_pool = [
    'mighty_blow',
    'broadaxe',
    'warhammer',
    'dagger',
    'iron_maiden',
    'tongs',
    'poker',
    'deep_forge',
    'wide_forge',
    'jar_of_acid',
    'acid_bath',
    'greatsword',
    'vambraces',
    'sallet',
    'kite_shield',
    'breast_plate',
  ]
  # One weapon, one skill and one armour item, drawn per run (the owner's constraint).
  starting_item_types = [ItemType.WEAPON, ItemType.SKILL, ItemType.ARMOUR]
  starting_relic_id = ''             # no signature relic yet (the owner's to design)
