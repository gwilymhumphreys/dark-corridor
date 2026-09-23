class_name PoolStatus
extends StatusEffect
## Intermediate base for absorb-pool statuses (Shield) — the old StatusDef.Shape.POOL. An inert
## pool that soaks incoming damage until drained; no ticker, no decay. Reapply stacks the pool
## additively (the base default). Removed once emptied (is_spent), after the incoming-damage pass.


## Soak from an incoming hit, returning the unabsorbed remainder. Unblockable payloads bypass the
## pool entirely (#5). The pool spends the damage times the dealing mechanic's shield multiplier
## (docs/systems/mechanics.md → Shield): `m` is `MechanicRegistry.shield_multiplier(mechanic_id)`,
## so a poison hit (m = 2) drains shield twice as fast and a burn hit (m = 0.5) half as fast.
## The pool is a whole number: the cost of a hit is rounded (`roundi(amount * m)`). A pool that can
## pay it loses the cost and lets nothing through; one that can't covers `count / m` damage, drops
## to 0 and passes the fractional rest on (take_damage rounds it when it reaches HP).
func absorb(amount: float, incoming_flags: int, target, ctx, mechanic_id: String = '') -> float:
  if (incoming_flags & Delivery.Flag.UNBLOCKABLE) != 0:
    return amount
  var m: float = MechanicRegistry.shield_multiplier(mechanic_id)
  var cost: int = roundi(amount * m)
  if cost <= count:
    count -= cost
    return 0.0
  var covered: float = count / m   # damage the whole pool can cover
  count = 0
  return amount - covered


func is_spent() -> bool:
  return count <= 0
