extends CharacterDef
## Smith (PLACEHOLDER label — owner's to rename; docs/design/smith.md) — the roster's on-ramp
## character. It manages no separate resource: its skills buff its own weapons and armour over a
## fight. Still the owner's to fill: the go-wide and go-tall skills, the signature relic and a
## portrait.


func _init() -> void:
  id = 'smith'
  name_key = 'Orrin'                 # PLACEHOLDER personal name — owner's to rename
  class_key = 'Smith'                # PLACEHOLDER class — owner's to rename
  portrait = 'res://assets/portraits/characters/warrior_nb.png'   # PLACEHOLDER portrait — owner's to swap
  select_image = 'res://assets/portraits/large/curver_a.png'   # PLACEHOLDER picture, owner's to swap
  # The owner's interim pools until the characters are revisited (2026-11-20): every character
  # holds attack, shield and heal, and the Smith holds only those three.
  item_pools = [
    AttackMechanic.ID,
    ShieldMechanic.ID,
    HealMechanic.ID,
  ]
  # One weapon, one skill and one armour item, drawn per run (the owner's constraint).
  starting_item_types = [ItemType.WEAPON, ItemType.SKILL, ItemType.ARMOUR]
  starting_relic_id = ''             # no signature relic yet (the owner's to design)
