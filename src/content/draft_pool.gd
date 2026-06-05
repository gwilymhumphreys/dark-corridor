class_name DraftPool
## The draftable item pool (draft_prd) — what a reward draft can offer. Phase 3: a
## small fixed list of player items (the enemy claw is enemy-only, excluded). The
## pool's *contents* become Meta-progression's unlocks later; this const is the
## prototype stand-in the Run manager hands to Draft.draw().

const ITEMS: Array = [
  ItemCatalog.Id.WEAPON,
  ItemCatalog.Id.ARMOR,
  ItemCatalog.Id.POISON_DAGGER,
  ItemCatalog.Id.AVENGER,
]
