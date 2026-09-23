class_name Item
extends RefCounted
## A board participant (docs/systems/item.md) configured by an ItemDef. Owns a cooldown
## Ticker; the Combat manager advances it each step and, on cross, calls fire().
## Every item is active (ticks); declared triggers push the SAME accumulator (the
## def's trigger_subs, wired to the event bus by the manager). Holds its own
## item-targeted statuses + one enchant slot (stubbed in Phase 1).

var def: ItemDef
var owner: Actor               # board membership (self-target; opponent resolution)
var cooldown: Ticker
var statuses: Array[StatusEffect] = []   # item-targeted instances (silence = gate, decay = use-status).
                                         # NOTE: value modifiers are NOT read from here — see docs/systems/item.md.
var enchant: Enchantment = null          # one enchant slot


func _init(item_def: ItemDef, item_owner: Actor = null) -> void:
  def = item_def
  owner = item_owner
  cooldown = Ticker.from_seconds(def.cooldown)


## Break THIS item's half of the Actor<->Item reference cycle when it is removed from a board
## mid-fight — decay emptying it (CombatManager.remove_item) or Cap 1's combat-scoped teardown
## strip. The single-item parallel of Actor.dissolve() (which dissolves a whole board at discard):
## drop the owner back-reference and clear the combat-scoped statuses. The board erase is the
## caller's. Idempotent.
func dissolve() -> void:
  owner = null
  statuses.clear()


## The fire pipeline (docs/systems/item.md): gate -> fire (reset the cooldown) -> resolve
## each effect into a Payload (applying modifiers / enchants — none yet) -> hand
## them up. Returns [] if a gate status (silence) suppresses the fire — a backstop:
## the Combat manager already freezes a gated item's cooldown (decision #30), so a
## gated item normally never crosses. The manager only calls this on a cooldown
## cross; the fire-emote + event routing are the manager's.
func fire() -> Array:
  if is_gated():
    return []
  cooldown.reset()
  var payloads: Array[Payload] = []
  for effect in def.effects:
    payloads.append(_resolve_effect(effect))
  return payloads


## True while a gate status (silence) sits on this item. The Combat manager consults
## this each step to FREEZE the cooldown (decision #30: a gate holds time — no accrual,
## so the gate lifting never releases a banked burst of fires).
func is_gated() -> bool:
  for s in statuses:
    if s.gates_fire():
      return true
  return false


## True when any of this item's effects uses the named mechanic (docs/systems/mechanics.md) —
## how items, relics and enchantments refer to a mechanic ("your attack items"). For `'crit'`
## (which is never an effect's mechanic) it is true when the item has a crit chance.
func uses(mechanic_id: String) -> bool:
  if mechanic_id == CritMechanic.ID:
    return def.crit_chance > 0.0
  for effect in def.effects:
    if effect.mechanic == mechanic_id:
      return true
  return false


## Read-only display value for the tooltip (docs/systems/tooltips.md) — the value the tooltip
## SHOWS, computed WITHOUT side effects. Mirrors the pure stages of _resolve_effect (the enchant and
## the status bonuses) but never resets the cooldown or spends fuel, so it is safe to call every
## frame while inspecting. Consume-scaling is excluded (it needs a non-mutating stack peek;
## tooltips.md). Pairs with base_value for the changed-value highlight.
func display_value(effect: ItemEffect) -> float:
  return _scaled_value(effect, true)


## The baseline the changed-value highlight compares against: the authored value scaled by the
## enchant only (a PERMANENT modifier — #26), so the highlight reflects combat-scoped status
## changes (Weak, the attack bonuses), not the enchant. Read-only.
func base_value(effect: ItemEffect) -> float:
  return _scaled_value(effect, false)


## The effect's value with the enchant and, when `with_statuses` and the effect is an attack, every
## status bonus, combined by StatusManager.combine (docs/systems/mechanics.md → Combining bonuses).
## The enchant counts as a percentage bonus and applies to every effect; statuses only to attacks.
## Pure.
func _scaled_value(effect: ItemEffect, with_statuses: bool) -> float:
  var base: float = effect.value
  # A value that scales by a status the owner holds reads it first, so bonuses apply on top of it.
  if effect.per_owner_stack_id != '' and owner != null:
    base += StatusManager.stack_count(owner, effect.per_owner_stack_id) * effect.per_owner_stack_scale
  var bonuses: Array[Dictionary] = []
  if enchant != null:
    bonuses.append({'percent': enchant.def.value_mult - 1.0})   # a permanent item modifier
  if with_statuses and effect.mechanic == AttackMechanic.ID:
    bonuses.append_array(StatusManager.outgoing_bonuses(owner, self))
  return StatusManager.combine(base, bonuses)


## The item-side stages on top of the shared template copy (Payload.from_effect):
## enchant scaling, the outgoing stat-status seam, self-fuel consume, source identity.
func _resolve_effect(effect: ItemEffect) -> Payload:
  var p := Payload.from_effect(effect)
  # The enchant (docs/systems/content.md / #26) and, for an attack, the status bonuses on the owner
  # and on this item (#6), worked out AT FIRE TIME and locked into the payload, cascade-safe.
  p.value = _scaled_value(effect, true)
  # Status-stack consume (docs/systems/spore_engine.md Cap 1): SELF-fuel resolves now (the
  # owner is known) by spending its stacks + scaling. OPPONENT-fuel (Mass) rides the
  # payload's consume declaration to the Combat manager, which knows the resolved target.
  if effect.consume_id != '' and not effect.consume_from_target and owner != null:
    p.value += StatusManager.consume(owner, effect.consume_id, effect.consume_amount) * effect.consume_scale
  p.source = self
  p.source_actor = owner
  return p
