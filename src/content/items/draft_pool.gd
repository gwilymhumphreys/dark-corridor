class_name DraftPool
## The draftable item pool (docs/systems/draft.md) — what a reward draft can offer. Phase 3: a
## small fixed list of player items (the enemy claw is enemy-only, excluded). The
## pool's *contents* become Meta-progression's unlocks later; this const is the
## prototype stand-in the Run manager hands to Draft.draw().

const ITEMS: Array = [
  ItemCatalog.WEAPON,
  ItemCatalog.ARMOR,
  ItemCatalog.POISON_DAGGER,
  ItemCatalog.AVENGER,
  ItemCatalog.LEATHER_GLOVES,
  ItemCatalog.LEATHER_TREWS,
  ItemCatalog.LEATHER_BREASTPLATE,
]
