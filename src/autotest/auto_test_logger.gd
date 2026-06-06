class_name AutoTestLogger
extends RefCounted
## The structured-event + summary sink (autotest.md). It is HANDED state by
## AutoTestMode — actor HP, the landed-Delivery set, the outcome — and reads it
## into events, a damage-by-family tally, and a printable / writable summary.
## It writes no game state (the same discipline as the VFX wall it shadows).
##
## Damage-by-family is built per sim-step from net HP loss + the Deliveries that
## landed that step (see `attribute_damage`): direct hits attribute to their
## source item's family; the unexplained remainder is DoT (poison ticks land no
## Delivery), credited to the item that applied it via a pre-step status snapshot
## (`dot_sources`) — so Venom Fang's poison shows under "Venom Fang", not a lump.

## The fallback channel for DoT HP-loss whose applier is unknown (a source-less or
## enemy-supplied DoT). When the applier IS known, its item name is used instead —
## that's the per-applier attribution the snapshot provides.
const DOT_FAMILY: String = 'Poison'

var events: Array = []                 # Array[Dictionary] — { type, data }
var damage_by_family: Dictionary = {}  # family name -> total damage attributed
var total_damage: float = 0.0
# Phase 5 (tune machinery): per-encounter breakdown + per-item fire counts.
var encounters: Array = []             # Array[Dictionary] — one per resolved beat
var fires_by_item: Dictionary = {}     # item name_key -> times it fired (player items)


## Net HP loss for ONE actor in ONE sim-step, split into damage records by family.
## Pure (no game objects) so it is unit-testable on synthetic input.
##   loss   — net HP the actor lost this step (>= 0; healing is not damage)
##   direct — Array of { 'family': String, 'raw': float }, one per DAMAGE Delivery
##            that landed on this actor this step
##   dot_sources — the actor's DoT-applying statuses snapshotted BEFORE the step:
##            Array of { 'label': String, 'weight': float } (label = the applier
##            item's name; weight = its potential tick damage). The DoT remainder is
##            split among them by weight; empty / zero-weight → the DOT_FAMILY channel.
## Returns Array of { 'family': String, 'amount': float }. Direct hits take their
## proportional share of the net loss (so block-absorbed damage is excluded);
## anything left over is the DoT remainder, credited to its applier(s). With no block
## and a single source the split is exact — the common case.
static func attribute_damage(loss: float, direct: Array, dot_sources: Array = []) -> Array:
  var out: Array = []
  if loss <= 0.0:
    return out
  var direct_raw: float = 0.0
  for hit in direct:
    direct_raw += hit['raw']
  var to_direct: float = minf(loss, direct_raw)
  if direct_raw > 0.0 and to_direct > 0.0:
    for hit in direct:
      out.append({
        'family': hit['family'],
        'amount': hit['raw'] / direct_raw * to_direct,
      })
  var remainder: float = loss - to_direct
  if remainder > 0.0001:
    out.append_array(_split_remainder(remainder, dot_sources))
  return out


## Split the DoT remainder among the snapshotted applier sources by weight. No known
## source (empty list or zero total weight) → the generic DOT_FAMILY channel (the old
## behaviour, for a source-less or enemy-supplied DoT).
static func _split_remainder(remainder: float, dot_sources: Array) -> Array:
  var total_weight: float = 0.0
  for s in dot_sources:
    total_weight += s['weight']
  if dot_sources.is_empty() or total_weight <= 0.0:
    return [{ 'family': DOT_FAMILY, 'amount': remainder }]
  var out: Array = []
  for s in dot_sources:
    out.append({ 'family': s['label'], 'amount': s['weight'] / total_weight * remainder })
  return out


func log_event(type: String, data: Dictionary = {}) -> void:
  events.append({ 'type': type, 'data': data })


## Accumulate one damage record into the family tally + the running total.
func record_damage(family: String, amount: float) -> void:
  if amount <= 0.0:
    return
  damage_by_family[family] = damage_by_family.get(family, 0.0) + amount
  total_damage += amount


## Record one resolved beat (a fight or rest) for the per-encounter table. `rec` =
## { beat, type, name, duration, hp_before, hp_after, outcome }.
func record_encounter(rec: Dictionary) -> void:
  encounters.append(rec)


## Count one fire of a player item (by name_key) — the "did it do anything" signal a
## trap pick fails. Block/heal items fire without dealing damage, so fires (not damage)
## is what distinguishes a working defensive item from an idle trap.
func record_item_fire(name: String) -> void:
  fires_by_item[name] = int(fires_by_item.get(name, 0)) + 1


## Fold the handed run `result` together with the accumulated tallies into a flat
## summary dict. `result` carries what only AutoTestMode can read off the fight:
##   { outcome, won, resolved, steps, sim_seconds, wall_ms,
##     player_hp, player_max_hp, enemies: [{ name, hp, max_hp }] }
func summarize(result: Dictionary) -> Dictionary:
  return {
    'outcome': result.get('outcome', 'UNKNOWN'),
    'resolved': result.get('resolved', false),
    'won': result.get('won', false),
    'steps': result.get('steps', 0),
    'sim_seconds': result.get('sim_seconds', 0.0),
    'wall_ms': result.get('wall_ms', 0),
    'player_hp': result.get('player_hp', 0.0),
    'player_max_hp': result.get('player_max_hp', 0.0),
    'enemies': result.get('enemies', []),
    'beats_cleared': result.get('beats_cleared', 0),   # run mode only
    'board_size': result.get('board_size', 0),         # run mode only
    'total_damage': total_damage,
    'damage_by_family': damage_by_family.duplicate(),
    'encounters': encounters.duplicate(true),           # run mode only
    'fires_by_item': fires_by_item.duplicate(),
    'player_items': result.get('player_items', []),     # final board names (run mode)
    'strategy': result.get('strategy', ''),
  }


## Human-readable summary lines (printed to console + appended to the raw log).
func format_summary(summary: Dictionary) -> PackedStringArray:
  var lines: PackedStringArray = []
  lines.append('===== AutoTest summary =====')
  lines.append('Outcome:  %s  (%s)' % [
    summary['outcome'], 'player won' if summary['won'] else 'player did not win',
  ])
  lines.append('Duration: %d sim-steps (%.2fs game-time), %d ms wall' % [
    summary['steps'], summary['sim_seconds'], summary['wall_ms'],
  ])
  if summary['board_size'] > 0:
    lines.append('Beats cleared: %d   Final board: %d items' % [summary['beats_cleared'], summary['board_size']])
  lines.append('Player HP: %.1f / %.1f' % [summary['player_hp'], summary['player_max_hp']])
  for e in summary['enemies']:
    lines.append('Enemy "%s" HP: %.1f / %.1f' % [e['name'], e['hp'], e['max_hp']])
  lines.append('Total damage dealt: %.1f' % summary['total_damage'])
  for family in _sorted_families(summary['damage_by_family']):
    lines.append('  %s: %.1f' % [family, summary['damage_by_family'][family]])
  return lines


## Append every structured event, then the summary, to a raw text log.
func write_log(path: String, summary: Dictionary) -> void:
  var lines: PackedStringArray = []
  for ev in events:
    var data_str: String = JSON.stringify(ev['data']) if not ev['data'].is_empty() else ''
    lines.append('[event] %s %s' % [ev['type'], data_str])
  lines.append_array(format_summary(summary))
  _write_file(path, '\n'.join(lines) + '\n')


## A small markdown analysis report (the `tune` workflow will read this later).
func write_report(path: String, summary: Dictionary) -> void:
  var lines: PackedStringArray = []
  lines.append('# AutoTest report — %s' % summary['outcome'])
  lines.append('')
  lines.append('- Outcome: **%s** (%s)' % [
    summary['outcome'], 'player won' if summary['won'] else 'player did not win',
  ])
  lines.append('- Duration: %d sim-steps (%.2fs game-time)' % [summary['steps'], summary['sim_seconds']])
  lines.append('- Wall time: %d ms' % summary['wall_ms'])
  if summary['board_size'] > 0:
    lines.append('- Beats cleared: %d' % summary['beats_cleared'])
    lines.append('- Final board: %d items' % summary['board_size'])
  lines.append('')
  lines.append('## Final HP')
  lines.append('')
  lines.append('- Player: %.1f / %.1f' % [summary['player_hp'], summary['player_max_hp']])
  for e in summary['enemies']:
    lines.append('- %s: %.1f / %.1f' % [e['name'], e['hp'], e['max_hp']])
  lines.append('')
  lines.append('## Damage by family')
  lines.append('')
  if summary['damage_by_family'].is_empty():
    lines.append('- (none)')
  else:
    for family in _sorted_families(summary['damage_by_family']):
      lines.append('- %s: %.1f' % [family, summary['damage_by_family'][family]])
  lines.append('')
  lines.append('Total damage dealt: **%.1f**' % summary['total_damage'])

  # Per-encounter breakdown (run mode) — duration vs the ~10–15s window + HP attrition.
  if not summary['encounters'].is_empty():
    lines.append('')
    lines.append('## Encounters')
    lines.append('')
    lines.append('| Beat | Type | Name | Duration | HP before → after | Outcome |')
    lines.append('|------|------|------|----------|-------------------|---------|')
    for enc in summary['encounters']:
      lines.append('| %d | %s | %s | %.1fs | %.0f → %.0f | %s |' % [
        int(enc.get('beat', 0)), enc.get('type', '?'), enc.get('name', ''),
        float(enc.get('duration', 0.0)), float(enc.get('hp_before', 0.0)),
        float(enc.get('hp_after', 0.0)), enc.get('outcome', ''),
      ])

  # Per-item contribution (run mode) — fires + damage; a never-fired item is a trap pick.
  var rows: Array = _item_contribution_rows(summary)
  if not rows.is_empty():
    lines.append('')
    lines.append('## Item contribution (player board)')
    lines.append('')
    lines.append('| Item | Count | Fires | Damage | Trap? |')
    lines.append('|------|-------|-------|--------|-------|')
    for r in rows:
      lines.append('| %s | %d | %d | %.1f | %s |' % [
        r['name'], int(r['count']), int(r['fires']), float(r['damage']), 'yes' if r['trap'] else '',
      ])

  _write_file(path, '\n'.join(lines) + '\n')


# --- helpers ----------------------------------------------------------------

## Per-item contribution rows from the final player board + the fire/damage tallies.
## Aggregates duplicates by name (with a count); a board item that never fired is
## flagged a trap pick (the "drafted but idle" signal `tune` reads).
func _item_contribution_rows(summary: Dictionary) -> Array:
  var counts: Dictionary = {}
  var order: Array = []
  for name in summary.get('player_items', []):
    if not counts.has(name):
      counts[name] = 0
      order.append(name)
    counts[name] = int(counts[name]) + 1
  var rows: Array = []
  for name in order:
    var fires: int = int(summary['fires_by_item'].get(name, 0))
    rows.append({
      'name': name,
      'count': counts[name],
      'fires': fires,
      'damage': float(summary['damage_by_family'].get(name, 0.0)),
      'trap': fires == 0,
    })
  return rows

## Families sorted by damage descending (stable, readable ordering for reports).
func _sorted_families(tally: Dictionary) -> Array:
  var families: Array = tally.keys()
  families.sort_custom(func(a, b): return tally[a] > tally[b])
  return families


func _write_file(path: String, content: String) -> void:
  var dir: String = path.get_base_dir()
  if dir != '' and not DirAccess.dir_exists_absolute(dir):
    DirAccess.make_dir_recursive_absolute(dir)
  var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
  if file == null:
    push_warning('[AutoTest] could not write %s (error %d)' % [path, FileAccess.get_open_error()])
    return
  file.store_string(content)
  file.close()
