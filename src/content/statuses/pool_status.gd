class_name PoolStatus
extends StatusEffect
## Intermediate base for absorb-pool statuses (Shield) — the old StatusDef.Shape.POOL. An inert
## pool that soaks incoming damage until drained; no ticker, no decay. Reapply stacks the pool
## additively (the base default). Removed once emptied (is_spent), after the incoming-damage pass.


## Soak from an incoming hit, returning the unabsorbed remainder. Unblockable payloads bypass the
## pool entirely (#5). The pool spends the damage times the dealing mechanic's shield multiplier
## (docs/systems/mechanics.md → Shield): `m` is `MechanicRegistry.shield_multiplier(mechanic_id)`,
## so a poison hit (m = 2) drains shield twice as fast and a burn hit (m = 0.5) half as fast.
func absorb(amount: float, incoming_flags: int, target, ctx, mechanic_id: String = '') -> float:
  if (incoming_flags & Delivery.Flag.UNBLOCKABLE) != 0:
    return amount
  var m: float = MechanicRegistry.shield_multiplier(mechanic_id)
  var net: float = amount
  var covered: float = minf(net, count / m)   # damage the shield can cover
  count -= covered * m
  net -= covered
  return net


func is_spent() -> bool:
  return count <= 0.0
