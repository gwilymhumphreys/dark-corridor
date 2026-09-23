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


## The incoming-damage pipeline: amplifiers (Vulnerable) scale up FIRST, then absorbers (Shield)
## soak the amplified amount (#6). Two passes over the target's statuses so the order holds;
## emptied pools are removed afterward. `mechanic_id` names the mechanic that dealt the damage
## (docs/systems/mechanics.md → Shield) — the shield pool spends its multiplier against it.
## Returns net damage to HP.
func resolve_incoming_damage(target, raw: float, flags: int = 0, ctx = null, mechanic_id: String = '') -> float:
  var net: float = raw
  for s in target.statuses:
    net = s.modify_incoming(net, target, ctx)
  for s in target.statuses:
    net = s.absorb(net, flags, target, ctx, mechanic_id)
  _remove_spent(target)
  return maxf(net, 0.0)


## Advance one sim-step of a status; returns true when it has expired (the caller removes it).
## Active effects (a DoT tick) happen inside the instance's on_step.
func advance_status(status: StatusEffect, target, ctx = null) -> bool:
  return status.on_step(target, ctx)


## Every status bonus to an outgoing attack from `item`: those on its owner `actor` (Weak, Empowered)
## and those on the item itself (the attack bonuses). Either may be null. Pure — this runs in the
## tooltip-preview path too.
func outgoing_bonuses(actor, item = null) -> Array[Dictionary]:
  var bonuses: Array[Dictionary] = []
  if actor != null:
    for s in actor.statuses:
      bonuses.append(s.outgoing_bonus(actor, item))
  if item != null:
    for s in item.statuses:
      bonuses.append(s.outgoing_bonus(item, item))
  return bonuses


## `value` with `bonuses` applied by the combining rule (docs/systems/mechanics.md → Combining
## bonuses, owner 2026-09-23): flat bonuses are added first; positive percentages are added
## together; negative percentages multiply together; the two groups are applied separately.
static func combine(value: float, bonuses: Array[Dictionary]) -> float:
  var flat: float = 0.0
  var positive: float = 0.0
  var negative: float = 1.0
  for bonus: Dictionary in bonuses:
    flat += bonus.get('flat', 0.0)
    var percent: float = bonus.get('percent', 0.0)
    if percent > 0.0:
      positive += percent
    elif percent < 0.0:
      negative *= 1.0 + percent
  return (value + flat) * (1.0 + positive) * negative


## True if `actor` carries any status that causes evasion (Blind) — the engine asks the instances,
## never a status name (#23).
func has_evasion(actor) -> bool:
  for s in actor.statuses:
    if s.causes_evasion():
      return true
  return false


## Whether `target` currently holds any of status `id`. A read, so callers can branch on it
## without touching the status list.
func has_status(target, id: String) -> bool:
  return _find(target, id) != null


## How many stacks of `id` `target` holds (0 when absent). Read-only.
func stack_count(target, id: String) -> int:
  var s: StatusEffect = _find(target, id)
  return s.count if s != null else 0


## Spend up to `amount` of `id` from `target` as Mass fuel (docs/systems/spore_engine.md Cap 1), returning how
## many were removed (so the consuming effect scales by what it found). Only fuel statuses (stacked
## DoT / the Spores counter) spend; others return 0. A drained instance is removed.
func consume(target, id: String, amount: float) -> int:
  var s: StatusEffect = _find(target, id)
  if s == null:
    return 0
  var removed: int = s.consume(amount)
  if s.count <= 0 and removed > 0:
    s.on_expire(target, null)   # the natural-removal hook (every removal site calls it)
    target.statuses.erase(s)
  return removed


## Remove up to `amount` stacks of `id` from `target` — any status, not only fuel (unlike
## consume). A status reduced to zero or below is removed with its on_expire hook (the
## natural-removal hook). Does nothing when the status is absent or `amount` <= 0.
func reduce(target, id: String, amount: float) -> void:
  if amount <= 0.0:
    return
  var s: StatusEffect = _find(target, id)
  if s == null:
    return
  s.count -= roundi(amount)
  if s.count <= 0:
    s.on_expire(target, null)
    target.statuses.erase(s)


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
