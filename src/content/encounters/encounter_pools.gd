class_name EncounterPools
## Which encounters the choice before each fight can offer (docs/plans/encounter_choice.md): one list
## of EncounterCatalog ids per card position, left to right. Every encounter goes in one list. The
## left list holds the shops, so the left card is always a shop. An encounter in no
## list is authored but never met, the same way an item in no pool is never drafted.
##
## PLACEHOLDER lists: the owner places the encounters. Built lazily into `_positions` so tests can put
## fixture lists in place (FixtureContent).

## How many encounters a choice offers, one per position.
const POSITIONS: int = 3

## The shops: the normal shop, the rare shop and one per mechanic. When none can be offered, the draw
## fills the position from the other lists.
const LEFT: Array = [
  'shop_pedlar',
  'shop_rare',
  'shop_attack',
  'shop_shield',
  'shop_heal',
  'shop_poison',
  'shop_burn',
  'shop_regen',
  'shop_bleed',
  'shop_charge',
  'shop_decharge',
  'shop_crit',
]
const MIDDLE: Array = ['event_shrine', 'relic_cache']
const RIGHT: Array = ['event_wanderer', 'rest']

static var _positions: Array = []   # one Array of ids per position, left to right


## The encounter ids the card at `index` (0 = left) is drawn from.
static func at(index: int) -> Array[String]:
  if _positions.is_empty():
    _positions = [LEFT.duplicate(), MIDDLE.duplicate(), RIGHT.duplicate()]
  var ids: Array[String] = []
  if index >= 0 and index < _positions.size():
    ids.assign(_positions[index])
  return ids
