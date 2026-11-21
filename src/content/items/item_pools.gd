class_name ItemPools
## Which items each character is offered (decision #65, docs/systems/draft.md → Item pools). A pool is
## a tag, and POOL_TAGS lists the tags that are pools. An item needs every one of its tags that is a
## pool, so a character is offered it only when the character's `item_pools` hold all of them. Type
## tags are not pools, so they do not limit who is offered an item. An item with no pool tag is
## offered to every character.

## Every mechanic, plus the spores and flesh engines (owner, 2026-11-20). Any tag can be made a pool,
## a type tag included, but an item needs every one of its pool tags, so a type tag added here keeps
## its items from every character that does not hold it.
const POOL_TAGS: Array[String] = [
  AttackMechanic.ID,
  BleedMechanic.ID,
  BurnMechanic.ID,
  ChargeMechanic.ID,
  CritMechanic.ID,
  DechargeMechanic.ID,
  HasteMechanic.ID,
  HealMechanic.ID,
  PoisonMechanic.ID,
  RegenMechanic.ID,
  ShieldMechanic.ID,
  SlowMechanic.ID,
  ItemTags.FLESH,
  ItemTags.SPORES,
]


## The pools `def` needs: its tags that are in POOL_TAGS.
static func needed_pools(def: ItemDef) -> Array[String]:
  return def.tags.filter(func(tag: String) -> bool: return tag in POOL_TAGS)


## The ids of every draftable item whose needed pools are all in `pool_ids`, in catalog order, so a
## draw on the same seed always sees the same list.
static func items_for(pool_ids: Array) -> Array:
  var ids: Array = []
  for id: String in ItemCatalog.all_ids():
    var def: ItemDef = ItemCatalog.get_def(id)
    if def.draftable and needed_pools(def).all(func(tag: String) -> bool: return tag in pool_ids):
      ids.append(id)
  return ids
