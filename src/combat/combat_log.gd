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

# The fallback bucket for a source-less DoT (a tick whose status carries no applier
# item — e.g. an enemy-supplied or item-less poison). Replaces AutoTestLogger's old
# DOT_FAMILY constant; per-applier attribution credits the item directly when known.
const SOURCELESS: String = 'Poison'

# The ordered event timeline (append order = sim order) — the post-fight event log.
# Each entry: { t: float, type: String, source: String, source_side: int,
#   target: String, amount: float, data: String }. `type` in fire / damage / heal /
#   block / status / throw; `data` holds the status id or thrown consumable id.
var events: Array = []

# Per-source-item tallies, side-aware: each is Dictionary[int side -> Dictionary[String
# name_key -> value]]. summary(side) flattens one side's rows.
var fires_by_item: Dictionary = {}      # name_key -> fire count
var damage_by_item: Dictionary = {}     # name_key -> total damage dealt
var healing_by_item: Dictionary = {}    # name_key -> total healing done
var block_by_item: Dictionary = {}      # name_key -> total block (shield) applied
var statuses_by_item: Dictionary = {}   # name_key -> count of OTHER statuses applied

# Totals, split by side (Dictionary[int side -> float]). `_dealt` is damage this side
# DEALT to opponents; `_taken` is damage this side RECEIVED.
var total_damage_dealt: Dictionary = {}
var total_damage_taken: Dictionary = {}
var total_healing: Dictionary = {}
var total_block: Dictionary = {}


# --- write methods (manager-called; each takes resolved name_keys + side + sim_time) ---

## An item fired. `source_name` is its def name_key, `source_side` the firer's side.
func on_item_fired(source_name: String, source_side: int, t: float) -> void:
  _bump(fires_by_item, source_side, source_name, 1.0)
  _record(t, 'fire', source_name, source_side, '', 0.0, '')


## Damage landed on a target. `source_name` is the dealing item's name_key (SOURCELESS
## when none — a source-less DoT); `source_side` the dealer's side, `target_side` the
## target's. `amount` is the EFFECTIVE HP lost (Actor.take_damage's return). Both the
## dealer's dealt-total and the target's taken-total accrue.
func on_damage(source_name: String, source_side: int, target_name: String, target_side: int, amount: float, t: float) -> void:
  if amount <= 0.0:
    return
  _bump(damage_by_item, source_side, source_name, amount)
  total_damage_dealt[source_side] = float(total_damage_dealt.get(source_side, 0.0)) + amount
  total_damage_taken[target_side] = float(total_damage_taken.get(target_side, 0.0)) + amount
  _record(t, 'damage', source_name, source_side, target_name, amount, '')


## Healing done. `amount` is the EFFECTIVE HP restored (Actor.heal's return).
func on_heal(source_name: String, source_side: int, target_name: String, target_side: int, amount: float, t: float) -> void:
  if amount <= 0.0:
    return
  _bump(healing_by_item, source_side, source_name, amount)
  total_healing[source_side] = float(total_healing.get(source_side, 0.0)) + amount
  _record(t, 'heal', source_name, source_side, target_name, amount, '')


## Shield (block) applied — an APPLY_STATUS land whose status id is BlockStatus.ID.
func on_block(source_name: String, source_side: int, target_name: String, target_side: int, amount: float, t: float) -> void:
  if amount <= 0.0:
    return
  _bump(block_by_item, source_side, source_name, amount)
  total_block[source_side] = float(total_block.get(source_side, 0.0)) + amount
  _record(t, 'block', source_name, source_side, target_name, amount, '')


## Any OTHER status applied (not block — that is on_block). `status_id` rides `data`.
func on_status_applied(source_name: String, source_side: int, target_name: String, target_side: int, status_id: String, t: float) -> void:
  _bump(statuses_by_item, source_side, source_name, 1.0)
  _record(t, 'status', source_name, source_side, target_name, 0.0, status_id)


## A consumable thrown — the throw itself, so it shows in the event log. `consumable_id`
## rides `data`; there is no per-item tally (a thrown potion is not a board item).
func on_throw(consumable_id: String, thrower_side: int, t: float) -> void:
  _record(t, 'throw', '', thrower_side, '', 0.0, consumable_id)


# --- read surface -----------------------------------------------------------

## One side's per-item rows, flattened — Item · Fires · Damage · Block · Healing ·
## Statuses — keyed by name_key (the union of every item that did anything on that side).
## Views tr(name_key) at draw. Totals are read off the total_* dicts.
func summary(side: int) -> Array:
  var names: Dictionary = {}
  for tally in [fires_by_item, damage_by_item, block_by_item, healing_by_item, statuses_by_item]:
    for name in tally.get(side, {}).keys():
      names[name] = true
  var rows: Array = []
  for name in names.keys():
    rows.append({
      'name': name,
      'fires': int(_value(fires_by_item, side, name)),
      'damage': _value(damage_by_item, side, name),
      'block': _value(block_by_item, side, name),
      'healing': _value(healing_by_item, side, name),
      'statuses': int(_value(statuses_by_item, side, name)),
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
