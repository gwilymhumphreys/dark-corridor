class_name CombatLog
extends RefCounted
## The per-fight observation sink (docs/systems/combat_log.md): a combat-scoped tally +
## ordered event timeline the CombatManager writes to at each mutation site (where the
## amount + source + sim_time are already in hand). It is the SINGLE SOURCE OF TRUTH for
## damage / healing / shield / fire numbers — the live HUD, the post-fight report, AND
## the autotest / tune report all read it (no parallel HP-diff reconstruction).
##
## It stores NO game-object references — only `name_key` strings, ids, side ints, and
## primitives, captured at write time — so it never participates in the Actor<->Item
## RefCounted cycle and has nothing to clean up (CLAUDE.md). Session-only: a fresh log
## per fight, gone at teardown.
##
## Side-awareness is required: a colorless item can sit on BOTH sides, so a flat
## `name_key` key would conflate the two; the per-item tallies are nested `side ->
## name_key -> value`, and the player report + autotest contribution table read the
## player side only. Localization: stores `name_key`s / ids, never display strings —
## views tr() at draw.

enum Side { PLAYER, ENEMY }

# The fallback bucket for a source-less DIRECT hit — a damage Delivery with no source
# item (a thrown consumable's hit, whose actor identity rides source_actor). Status (DoT)
# damage is NOT bucketed here: it keys by the status's OWN name_key via on_status_damage,
# so it never needs a source-item fallback.
const SOURCELESS: String = 'Poison'

# The ordered event timeline (append order = sim order) — the post-fight event log.
# Each entry: { t: float, type: String, source: String, source_side: int,
#   target: String, amount: float, data: String }. `type` in fire / damage / heal /
#   shield / status / throw; `data` holds the status id or thrown consumable id.
var events: Array = []

# Per-source-item tallies, side-aware: each is Dictionary[int side -> Dictionary[String
# name_key -> value]]. summary(side) flattens one side's rows.
var fires_by_item: Dictionary = {}      # name_key -> fire count
var damage_by_item: Dictionary = {}     # name_key -> total NET damage dealt (effective HP removed)
var gross_by_item: Dictionary = {}      # name_key -> total GROSS damage dealt (pre-mitigation, the
                                        # threat/punch metric — meaningful even when shield ate it all)
var healing_by_item: Dictionary = {}    # name_key -> total healing done
var shield_by_item: Dictionary = {}     # name_key -> total shield applied
var statuses_by_item: Dictionary = {}   # name_key -> count of OTHER statuses applied

# Per-STATUS damage, side-aware (side -> status name_key -> total NET damage that status dealt).
# DoT / cash-out (Bleed) damage is bucketed by the STATUS, NOT credited to the applier item:
# appliers of the same status MERGE into one instance (the first applier is kept as `source`), so
# per-item DoT attribution was a fiction the moment a second item fed the pool. The honest split is
# "the item applied the status N times" (statuses_by_item) + "the status dealt N damage overall"
# (here). Folds into the side totals too — only the per-item breakdown is replaced.
var damage_by_status: Dictionary = {}

# Totals, split by side (Dictionary[int side -> float]). `_dealt` is damage this side
# DEALT to opponents; `_taken` is damage this side RECEIVED.
var total_damage_dealt: Dictionary = {}   # side -> NET damage this side dealt
var total_damage_taken: Dictionary = {}   # side -> NET damage this side received (HP lost)
var total_gross: Dictionary = {}          # side -> GROSS damage this side dealt (pre-mitigation)
var total_healing: Dictionary = {}
var total_shield: Dictionary = {}


# --- write methods (manager-called; each takes resolved name_keys + side + sim_time) ---

## An item fired. `source_name` is its def name_key, `source_side` the firer's side.
func on_item_fired(source_name: String, source_side: int, t: float) -> void:
  _bump(fires_by_item, source_side, source_name, 1.0)
  _record(t, 'fire', source_name, source_side, '', 0.0, '')


## Damage landed on a target. `source_name` is the dealing item's name_key (SOURCELESS
## when none — a source-less DoT); `source_side` the dealer's side, `target_side` the
## target's. `net` is the EFFECTIVE HP lost (Actor.take_damage's return); `raw` is the
## GROSS hit before the target's mitigation (shield) — omit (or pass < 0) and it defaults
## to `net`. GROSS is recorded even when shield absorbs the whole hit (net 0), so the
## incoming-pressure tally stays meaningful against a shield-heavy build; NET only accrues
## when HP actually moved.
func on_damage(source_name: String, source_side: int, target_name: String, target_side: int, net: float, t: float, raw: float = -1.0) -> void:
  if raw < 0.0:
    raw = net
  if raw <= 0.0:
    return
  _bump(gross_by_item, source_side, source_name, raw)
  total_gross[source_side] = float(total_gross.get(source_side, 0.0)) + raw
  if net > 0.0:
    _bump(damage_by_item, source_side, source_name, net)
    total_damage_dealt[source_side] = float(total_damage_dealt.get(source_side, 0.0)) + net
    total_damage_taken[target_side] = float(total_damage_taken.get(target_side, 0.0)) + net
  _record(t, 'damage', source_name, source_side, target_name, net, '')


## Damage dealt by a STATUS (a DoT tick or a cash-out like Bleed), bucketed by the status's own
## `status_name` — NOT credited to the applier item (see `damage_by_status`). `source_side` is the
## dealer's side (the status source's side), `target_side` the holder's; `net` is the effective HP
## lost; `status_id` rides the event `data`. Still folds into the side TOTALS (so total damage +
## incoming pressure stay complete) and the timeline — only the per-item breakdown becomes
## per-status. `raw` defaults to net (a tick has no pre-shield value to hand).
func on_status_damage(status_name: String, source_side: int, target_name: String, target_side: int, net: float, t: float, status_id: String, raw: float = -1.0) -> void:
  if raw < 0.0:
    raw = net
  if raw <= 0.0:
    return
  total_gross[source_side] = float(total_gross.get(source_side, 0.0)) + raw
  if net > 0.0:
    _bump(damage_by_status, source_side, status_name, net)
    total_damage_dealt[source_side] = float(total_damage_dealt.get(source_side, 0.0)) + net
    total_damage_taken[target_side] = float(total_damage_taken.get(target_side, 0.0)) + net
  _record(t, 'damage', status_name, source_side, target_name, net, status_id)


## Healing done. `amount` is the EFFECTIVE HP restored (Actor.heal's return).
func on_heal(source_name: String, source_side: int, target_name: String, _target_side: int, amount: float, t: float) -> void:
  if amount <= 0.0:
    return
  _bump(healing_by_item, source_side, source_name, amount)
  total_healing[source_side] = float(total_healing.get(source_side, 0.0)) + amount
  _record(t, 'heal', source_name, source_side, target_name, amount, '')


## Shield applied — an APPLY_STATUS land whose status id is ShieldStatus.ID.
func on_shield(source_name: String, source_side: int, target_name: String, _target_side: int, amount: float, t: float) -> void:
  if amount <= 0.0:
    return
  _bump(shield_by_item, source_side, source_name, amount)
  total_shield[source_side] = float(total_shield.get(source_side, 0.0)) + amount
  _record(t, 'shield', source_name, source_side, target_name, amount, '')


## Any OTHER status applied (not shield — that is on_shield). `status_id` rides `data`.
func on_status_applied(source_name: String, source_side: int, target_name: String, _target_side: int, status_id: String, t: float) -> void:
  _bump(statuses_by_item, source_side, source_name, 1.0)
  _record(t, 'status', source_name, source_side, target_name, 0.0, status_id)


## A consumable thrown — the throw itself, so it shows in the event log. `consumable_id`
## rides `data`; there is no per-item tally (a thrown potion is not a board item).
func on_throw(consumable_id: String, thrower_side: int, t: float) -> void:
  _record(t, 'throw', '', thrower_side, '', 0.0, consumable_id)


# --- read surface -----------------------------------------------------------

## One side's per-item rows, flattened — Item · Fires · Damage · Shield · Healing ·
## Statuses — keyed by name_key (the union of every item that did anything on that side).
## Views tr(name_key) at draw. Totals are read off the total_* dicts.
func summary(side: int) -> Array:
  var names: Dictionary = {}
  for tally in [fires_by_item, damage_by_item, gross_by_item, shield_by_item, healing_by_item, statuses_by_item]:
    for name in tally.get(side, {}).keys():
      names[name] = true
  var rows: Array = []
  for name in names.keys():
    rows.append({
      'name': name,
      'fires': int(_value(fires_by_item, side, name)),
      'damage': _value(damage_by_item, side, name),
      'gross': _value(gross_by_item, side, name),
      'shield': _value(shield_by_item, side, name),
      'healing': _value(healing_by_item, side, name),
      'statuses': int(_value(statuses_by_item, side, name)),
    })
  return rows


## One side's per-status damage rows: [{ name, damage }] — the "status damage" report section,
## the DoT / cash-out output the per-item table no longer carries. Views tr(name) at draw.
func status_damage(side: int) -> Array:
  var rows: Array = []
  for name in damage_by_status.get(side, {}).keys():
    rows.append({
      'name': name,
      'damage': _value(damage_by_status, side, name),
    })
  return rows


# --- internals --------------------------------------------------------------

func _bump(tally: Dictionary, side: int, name: String, amount: float) -> void:
  if not tally.has(side):
    tally[side] = {}
  tally[side][name] = float(tally[side].get(name, 0.0)) + amount


func _value(tally: Dictionary, side: int, name: String) -> float:
  return float(tally.get(side, {}).get(name, 0.0))


func _record(t: float, type: String, source: String, source_side: int, target: String, amount: float, data: String) -> void:
  events.append({
    't': t,
    'type': type,
    'source': source,
    'source_side': source_side,
    'target': target,
    'amount': amount,
    'data': data,
  })
