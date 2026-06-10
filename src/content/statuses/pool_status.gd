class_name PoolStatus
extends StatusEffect
## Intermediate base for absorb-pool statuses (Block) — the old StatusDef.Shape.POOL. An inert
## pool that soaks incoming damage until drained; no ticker, no decay. Reapply stacks the pool
## additively (the base default). Removed once emptied (is_spent), after the incoming-damage pass.


## Soak from an incoming hit, returning the unabsorbed remainder. Unblockable payloads bypass the
## pool entirely (#5).
func absorb(amount: float, incoming_flags: int, target, ctx) -> float:
  if (incoming_flags & Delivery.Flag.UNBLOCKABLE) != 0:
    return amount
  var absorbed: float = minf(count, amount)
  count -= absorbed
  return amount - absorbed


func is_spent() -> bool:
  return count <= 0.0
