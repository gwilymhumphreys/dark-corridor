class_name Delivery
extends RefCounted
## The in-flight carrier (combat_prd): a payload `(kind, value)` + a resolved
## target + a travel Ticker. It LANDS (applies its payload) when travel elapses
## — on arrival, not on fire. `travel_time` 0 lands the same step (the zero
## case, not a special path). Spawned by the Combat manager when an item fires;
## the manager resolves the item's relative target-shape into the concrete
## `target` here.

enum Kind { DAMAGE, HEAL, APPLY_STATUS }

var kind: int = Kind.DAMAGE
var value: float = 0.0
var status_type: int = -1     # set when kind == APPLY_STATUS
var flags: int = 0            # payload flags (e.g. unblockable) — see StatusManager
var target                    # Actor (Phase 1); item-targeting resolved later
var source                    # the Actor/Item that fired this
var travel: Ticker
var color: Color = Color.WHITE

var fire_time: float = 0.0    # sim timestamp; the wall reads render_time - fire_time
var impact_time: float = -1.0 # set on landing; the wall reads render_time - impact_time
var landed: bool = false
var fizzled: bool = false


## Advance the travel Ticker one sim-step; returns true the step it arrives.
func step_travel() -> bool:
  return travel.step()
