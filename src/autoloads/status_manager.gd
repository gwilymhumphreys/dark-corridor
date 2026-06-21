class_name StatusManagerAutoload
extends Node
## The status FACADE (docs/systems/status_manager.md) — autoload registered `StatusManager`. Holds NO
## instances (they live on their targets, as StatusEffect subclasses). Behaviour is no longer a
## switch here: each call delegates to the status instances, looping a target's `statuses` in
## insertion order so composition stays deterministic (#24). Statuses are keyed by string id (#23);
## the StatusRegistry builds the right subclass. Globally reachable precisely because it's stateless.


## Apply / stack a status on a target; returns the instance. An existing status of the same id
## AND the same flags is re-applied (the class decides stacking — additive by default; timed
## extends its duration); a different-flags application (e.g. unblockable poison over blockable)
## gets its OWN instance, so the flags of one application never silently rewrite another's.
## A reapply keeps the FIRST applier as `source`; the combat log credits that source for the
## stack's DoT ticks (no proportional split). Otherwise the registry builds a fresh one, sets its
## per-application state (count + DURATION — duration rides the application now, not a global),
## and runs on_apply. `ctx` is null outside combat (e.g. a relic at fight start); on_apply
## tolerates that.
func apply(target, id: String, count: float, duration: float = 0.0, source = null, flags: int = 0, ctx = null) -> StatusEffect:
  var existing: StatusEffect = _find_matching(target, id, flags)
  if existing != null:
    existing.reapply(count, duration, source, flags)
    return existing
  var s: StatusEffect = StatusRegistry.create(id)
  if s == null:
    return null
  s.setup(count, duration, source, flags)
  target.statuses.append(s)   # in place BEFORE on_apply, so the hook sees itself on the target
  s.on_apply(target, ctx)
  return s


## The incoming-damage pipeline: amplifiers (Vulnerable) scale up FIRST, then absorbers (Block)
## soak the amplified amount (#6). Two passes over the target's statuses so the order holds;
## emptied pools are removed afterward. Returns net damage to HP.
func resolve_incoming_damage(target, raw: float, flags: int = 0, ctx = null) -> float:
  var net: float = raw
  for s in target.statuses:
    net = s.modify_incoming(net, target, ctx)
  for s in target.statuses:
    net = s.absorb(net, flags, target, ctx)
  _remove_spent(target)
  return maxf(net, 0.0)


## Advance one sim-step of a status; returns true when it has expired (the caller removes it).
## Active effects (a DoT tick) happen inside the instance's on_step.
func advance_status(status: StatusEffect, target, ctx = null) -> bool:
  return status.on_step(target, ctx)


## The product of `actor`'s outgoing-damage modifiers (#6) applied to an outgoing DAMAGE value at
## fire time (Weak scales it down). Folds each status's modify_outgoing in list order.
func modify_outgoing(actor, amount: float, ctx = null) -> float:
  var out: float = amount
  for s in actor.statuses:
    out = s.modify_outgoing(out, actor, ctx)
  return out


## True if `actor` carries any status that causes evasion (Blind) — the engine asks the instances,
## never a status name (#23).
func has_evasion(actor) -> bool:
  for s in actor.statuses:
    if s.causes_evasion():
      return true
  return false


## Spend up to `amount` of `id` from `target` as Mass fuel (docs/systems/spore_engine.md Cap 1), returning how
## many were removed (so the consuming effect scales by what it found). Only fuel statuses (stacked
## DoT / the Spores counter) spend; others return 0. A drained instance is removed.
func consume(target, id: String, amount: float) -> float:
  var s: StatusEffect = _find(target, id)
  if s == null:
    return 0.0
  var removed: float = s.consume(amount)
  if s.count <= 0.0 and removed > 0.0:
    s.on_expire(target, null)   # the natural-removal hook (every removal site calls it)
    target.statuses.erase(s)
  return removed


func _find(target, id: String) -> StatusEffect:
  for s in target.statuses:
    if s.id == id:
      return s
  return null


## The apply-time match: same id AND same flags (consume/_find stay id-only — fuel
## spend doesn't care which application's flags a stack arrived under).
func _find_matching(target, id: String, flags: int) -> StatusEffect:
  for s in target.statuses:
    if s.id == id and s.flags == flags:
      return s
  return null


func _remove_spent(target) -> void:
  # In-place reverse walk: no allocation when nothing is spent (this runs on every take_damage),
  # and removing from the tail can't shift an index we haven't visited yet.
  for i in range(target.statuses.size() - 1, -1, -1):
    if target.statuses[i].is_spent():
      target.statuses[i].on_expire(target, null)   # the natural-removal hook
      target.statuses.remove_at(i)
