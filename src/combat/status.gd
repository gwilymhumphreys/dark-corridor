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
var target = null            # the Actor/Item it sits on
