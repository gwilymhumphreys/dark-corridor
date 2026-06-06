class_name Status
extends RefCounted
## A status INSTANCE (status_manager_prd) — data that lives on its target
## (Actor / Item), not in the StatusManager. The behaviour for `type` lives in
## the StatusManager rulebook (keyed via StatusDef); this is just the per-target
## state. Only time-driven shapes (periodic / timed) carry a Ticker.

var type: int                # StatusDef.Type
var count: float = 0.0       # stacks / pool / magnitude (per-type meaning)
var ticker: Ticker = null    # periodic / timed only; pool / static have none
var source = null            # the Actor/Item that applied it (source-dependent rules)
var flags: int = 0           # Delivery.Flag bits carried from the applying effect — so a
                             # DoT can be unblockable (passed back into take_damage per tick)
# No back-reference to the target: a status lives IN its target's status list, so
# the container is the owner. Storing target here would form an Actor<->Status /
# Item<->Status reference cycle (RefCounted has no cycle collection) — so we don't.
