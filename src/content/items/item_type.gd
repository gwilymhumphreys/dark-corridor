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
