class_name StatusEffect
extends RefCounted
## A status INSTANCE that owns BOTH its state and its behaviour — the polymorphic model
## (docs/systems/status_manager.md), replacing the old StatusDef-data + StatusManager-
## switch rulebook. One subclass per status; each overrides only the hooks it needs. Lives in its
## target's `statuses` list; the StatusManager facade calls these hooks at the right moments.
##
## Stores NO target reference — every hook receives `(target, ctx)` instead. That preserves the
## no-back-reference / no-RefCounted-cycle invariant the old `Status` documented. `ctx` is a thin
## StatusContext the CombatManager hands to ACTIVE hooks (apply other statuses, spawn, publish);
## it may be null for apply-outside-combat (e.g. a relic at fight start), so on_apply must tolerate
## a null ctx.

var id: String = ''
var count: float = 0.0
var duration: float = 0.0
var ticker: Ticker = null      # time-driven subclasses build one in setup(); inert shapes leave null
var source = null              # the Actor/Item that applied it (source-dependent rules / attribution)
var flags: int = 0             # Delivery.Flag bits carried from the applying effect (e.g. UNBLOCKABLE)

# Presentation — set by PLAIN ASSIGNMENT in each subclass's _init (`name_key = 'Weak'`) so
# tools/extract_pot.gd's `name_key = '...'` scan localizes it. Typed here on the base.
var name_key: String = ''
var color: Color = Color.WHITE
var icon: String = ''


## Initialize per-application state. The coordinator (StatusManager.apply) calls this right after
## StatusRegistry.create(). Time-driven subclasses override to also build their Ticker from
## `dur` — which is how duration rides the APPLICATION, not a global on a def.
func setup(amount: float, dur: float, src, applied_flags: int) -> void:
  count = amount
  duration = dur
  source = src
  flags = applied_flags


# --- lifecycle ---

func on_apply(target, ctx) -> void:
  pass


func on_expire(target, ctx) -> void:
  pass


## Re-application onto an existing instance of the same id. Default = STACK (additive count);
## time-driven subclasses also extend their duration. Override for refresh / max semantics.
func reapply(add_count: float, add_duration: float, src, new_flags: int) -> void:
  count += add_count


# --- per-step active effect (PUSH). Return true the step it has expired. ---

func on_step(target, ctx) -> bool:
  return false


# --- modifiers (PULL — the engine queries these at the pipeline stage, in statuses-list order,
#     so composition stays deterministic (#24) and amplify-before-absorb holds (#6)). ---

func modify_outgoing(amount: float, target, ctx) -> float:
  return amount


func modify_incoming(amount: float, target, ctx) -> float:
  return amount


## Absorb from an incoming hit, returning the unabsorbed remainder (Block overrides; mutates pool).
func absorb(amount: float, incoming_flags: int, target, ctx) -> float:
  return amount


func gates_fire() -> bool:
  return false


func causes_evasion() -> bool:
  return false


# --- Mass fuel (docs/systems/spore_engine.md Cap 1) ---

func is_fuel() -> bool:
  return false


## Spend up to `amount` of this status as fuel, returning how many were removed. Default: count-
## based (fuel subclasses opt in via is_fuel()); non-fuel returns 0.
func consume(amount: float) -> float:
  if not is_fuel():
    return 0.0
  var removed: float = minf(amount, count)
  count -= removed
  return removed


## True when this status should be removed after the incoming-damage pass — an emptied absorb
## pool (Block). Time/stack expiry is handled by on_step / consume, not here.
func is_spent() -> bool:
  return false


## Autotest damage-by-source attribution weight for a damaging DoT (count × per-tick). 0 = not one.
func dot_tick_weight() -> float:
  return 0.0
