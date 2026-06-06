class_name StatusManagerAutoload
extends Node
## The stateless status rulebook (status_manager_prd) — autoload registered
## `StatusManager`. Holds NO instances (they live on their targets); it only
## defines how each type behaves, keyed via StatusDef. Globally reachable
## precisely because it's stateless.


## Apply / stack a status on a target; returns the instance (the Combat manager
## registers its Ticker, if any, and publishes the on-apply event — Step 4).
func apply(target, type: int, count: float, source = null, flags: int = 0) -> Status:
  var def: StatusDef = StatusCatalog.get_def(type)
  # (source-side application modifiers — e.g. "your poison applies twice" — deferred)
  var existing: Status = _find(target, type)
  if existing != null:
    if def.stacking == StatusDef.Stacking.REFRESH:
      existing.count = count
      if existing.ticker != null:
        existing.ticker.accum = 0.0
    else:
      existing.count += count
    return existing
  var s := Status.new()
  s.type = type
  s.count = count
  s.source = source
  s.flags = flags
  match def.shape:
    StatusDef.Shape.PERIODIC:
      s.ticker = Ticker.from_seconds(def.tick_interval)
    StatusDef.Shape.TIMED:
      s.ticker = Ticker.from_seconds(def.duration)
  target.statuses.append(s)
  return s


## The incoming-damage pipeline: amplifiers (deferred) then absorbers (block).
## Block consumes its pool unless the payload is `unblockable`. Returns net to HP.
func resolve_incoming_damage(target, raw: float, flags: int = 0) -> float:
  var net: float = raw
  # Amplifiers (Vulnerable, …) — scale up BEFORE absorbers, so block soaks the
  # amplified amount (#6 incoming seam). A product of the target's modifier statuses.
  net *= _incoming_damage_mult(target)
  if (flags & Delivery.Flag.UNBLOCKABLE) == 0:
    var block: Status = _find(target, StatusDef.Type.BLOCK)
    if block != null:
      var absorbed: float = minf(block.count, net)
      block.count -= absorbed
      net -= absorbed
      if block.count <= 0.0:
        target.statuses.erase(block)
  return maxf(net, 0.0)


## Advance one sim-step of a time-driven status; applies its effect and returns
## true when it has expired (the caller removes it). Periodic fires its payload —
## Step 4 will route this through a travel-0 Delivery for the VFX wall; the net
## effect (take_damage) is identical.
func advance_status(status: Status, owner) -> bool:
  var def: StatusDef = StatusCatalog.get_def(status.type)
  match def.shape:
    StatusDef.Shape.PERIODIC:
      if status.ticker.step():
        # Carry the applying effect's flags (e.g. UNBLOCKABLE) into the tick, so an
        # unblockable DoT bypasses block per decision #5 (the flag is otherwise lost
        # between application and the tick — the Delivery is long gone).
        owner.take_damage(status.count * def.damage_per_tick, status.flags)
        status.count -= 1.0
        status.ticker.reset()
        return status.count <= 0.0
    StatusDef.Shape.TIMED:
      if status.ticker.step():
        return true
  return false


## Presentation lookup for the UI (it draws; this doesn't).
func info(type: int) -> Dictionary:
  var def: StatusDef = StatusCatalog.get_def(type)
  return { 'icon': def.icon, 'color': def.color, 'name': def.name_key }


func _find(target, type: int) -> Status:
  for s in target.statuses:
    if s.type == type:
      return s
  return null


## The product of `actor`'s outgoing damage modifiers (#6) — applied to its items' DAMAGE
## payloads at fire time (Item._resolve_effect). 1.0 when unaffected (Weak → 0.75).
func outgoing_damage_mult(actor) -> float:
  var mult: float = 1.0
  for s in actor.statuses:
    mult *= StatusCatalog.get_def(s.type).outgoing_damage_mult
  return mult


## The product of `target`'s incoming damage amplifiers (#6) — applied before block in
## resolve_incoming_damage. 1.0 when unaffected (Vulnerable → 1.5).
func _incoming_damage_mult(target) -> float:
  var mult: float = 1.0
  for s in target.statuses:
    mult *= StatusCatalog.get_def(s.type).incoming_damage_mult
  return mult
