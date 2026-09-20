class_name TargetFilter
extends RefCounted
## A narrowing of the target pool (docs/systems/item.md) — the candidate items an effect
## should aim at, tested one by one. A definition's filter is shared by every instance of
## that item and is treated as read-only after authoring (it is authored data, like the
## shape, not something the fire pipeline mutates).

enum Kind { TYPE, MECHANIC }
enum Mode { ALL, ANY }

# Flat list of conditions — { 'kind': int (Kind), 'id': String }. A TYPE condition's id is an
# ItemType const; a MECHANIC condition's id is a MechanicRegistry id.
var conditions: Array[Dictionary] = []
# ALL = every condition must pass; ANY = at least one must pass.
var mode: int = Mode.ALL

## Append a condition on an ItemType const (e.g. ItemType.WEAPON).
func add_type(id: String) -> void:
  conditions.append({'kind': Kind.TYPE, 'id': id})


## Append a condition on a mechanic id (e.g. PoisonMechanic.ID).
func add_mechanic(id: String) -> void:
  conditions.append({'kind': Kind.MECHANIC, 'id': id})


## True when there are no conditions (no filtering).
func is_empty() -> bool:
  return conditions.is_empty()


## Pure: reads item.def only — safe to call from a read-only tooltip preview.
## An empty condition list passes everything; a null item or def fails.
func matches(item: Item) -> bool:
  if item == null or item.def == null:
    return false
  if conditions.is_empty():
    return true
  if mode == Mode.ALL:
    for condition: Dictionary in conditions:
      if not _passes(condition, item):
        return false
    return true
  for condition: Dictionary in conditions:
    if _passes(condition, item):
      return true
  return false


func _passes(condition: Dictionary, item: Item) -> bool:
  match condition.get('kind', Kind.TYPE):
    Kind.TYPE:
      return item.def.types.has(condition.get('id', ''))
    Kind.MECHANIC:
      return item.def.mechanics.has(condition.get('id', ''))
  return false
