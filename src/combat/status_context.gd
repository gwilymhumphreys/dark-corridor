class_name StatusContext
extends RefCounted
## The reserved `ctx` seam, finally realized (docs/systems/status_manager.md "Open / deferred";
## docs/systems/item_creation_and_decay.md Cap 2). A status that must act BEYOND its own target —
## the decay use-status emptying and asking "remove my host item" — needs a handle on the
## Combat manager to do so. This is the minimal version: a single `remove_item` capability the
## CombatManager fulfils. It stays minimal by design — apply_status / spawn / publish / rng are
## added only as later statuses need them (the no-speculative-surface discipline). The
## CombatManager builds one and hands it to active status hooks.

var _cm: CombatManager


func _init(combat_manager: CombatManager) -> void:
  _cm = combat_manager


## Remove a single live item from its owner's board (the individual-item-removal path). The decay
## use-status calls this when its activation pool empties; the CombatManager deregisters the item's
## Ticker + triggers and dissolves it.
func remove_item(item: Item) -> void:
  if _cm != null:
    _cm.remove_item(item)
