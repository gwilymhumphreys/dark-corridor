class_name ItemTags
## The item tags that are neither a type tag (ItemType) nor a mechanic (MechanicRegistry), and the
## rule for which tags are known (decision #70, docs/systems/item.md → Tags). A tag names something
## content refers to, such as the engine an item belongs to; item pools will read them (decision #65).

const SPORES := 'spores'   # makes or spends spores
const FLESH := 'flesh'     # makes or spends Chunks of Flesh, or is one

const OTHER: Array[String] = [SPORES, FLESH]


## Whether `tag` can go in an item's tags: a type tag, a mechanic, or one of OTHER.
static func is_known(tag: String) -> bool:
  return ItemType.is_type(tag) or MechanicRegistry.is_mechanic(tag) or tag in OTHER
