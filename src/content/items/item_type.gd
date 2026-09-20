class_name ItemType
## Item-type tags (docs/systems/item.md) — the five synergy labels an ItemDef can carry in its
## `types` array. Pure labels with NO inherent gameplay effect: a future synergy reads tag
## membership (e.g. "your next weapon attack"), nothing keys off them today. The axis is the
## source / vessel of the effect. Items only — relics / consumables / enchants are separate
## Draftable categories and stay untagged.

const WEAPON := 'weapon'
const ARMOUR := 'armour'
const SKILL := 'skill'
const SPELL := 'spell'
const TRINKET := 'trinket'

## The displayed word for a type tag, singular then plural (e.g. 'Weapon' / 'Weapons'). The
## tooltip's type line uses the singular; a target-filter phrase uses the plural. PLACEHOLDER copy
## — the owner's words to write.
const DISPLAY_NAMES: Dictionary = {
  WEAPON: {'one': 'Weapon', 'many': 'Weapons'},
  ARMOUR: {'one': 'Armour', 'many': 'Armour'},
  SKILL: {'one': 'Skill', 'many': 'Skills'},
  SPELL: {'one': 'Spell', 'many': 'Spells'},
  TRINKET: {'one': 'Trinket', 'many': 'Trinkets'},
}


## The singular display name for an item-type id (its source English — the caller translates), or
## '' for an id that is not one of the five tags. No tr() here: this is a static method and tr() is
## an Object method, so it returns the source English straight.
static func display_name(id: String) -> String:
  if not DISPLAY_NAMES.has(id):
    return ''
  return (DISPLAY_NAMES[id] as Dictionary)['one']


## The plural display name for an item-type id (its source English — the caller translates), or
## '' for an id that is not one of the five tags. Armour is deliberately the same word in both
## forms. No tr() here (a static method cannot call the Object tr()).
static func display_name_plural(id: String) -> String:
  if not DISPLAY_NAMES.has(id):
    return ''
  return (DISPLAY_NAMES[id] as Dictionary)['many']
