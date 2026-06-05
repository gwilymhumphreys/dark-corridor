class_name AutoTestLogger
extends RefCounted
## The structured-event + summary sink (autotest.md). It is HANDED state by
## AutoTestMode — actor HP, the landed-Delivery set, the outcome — and reads it
## into events, a damage-by-family tally, and a printable / writable summary.
## It writes no game state (the same discipline as the VFX wall it shadows).
##
## Damage-by-family is built per sim-step from net HP loss + the Deliveries that
## landed that step (see `attribute_damage`): direct hits attribute to their
## source item's family; the unexplained remainder is the DoT channel (poison,
## the one damaging status in Phase 1, which lands no Delivery yet).

## The family label for HP loss not explained by a landed Delivery this step.
## Phase 1 has exactly one damaging status (poison); when more exist this needs a
## pre-step status snapshot to disambiguate which DoT dealt the remainder.
const DOT_FAMILY: String = 'Poison'

var events: Array = []                 # Array[Dictionary] — { type, data }
var damage_by_family: Dictionary = {}  # family name -> total damage attributed
var total_damage: float = 0.0


## Net HP loss for ONE actor in ONE sim-step, split into damage records by family.
## Pure (no game objects) so it is unit-testable on synthetic input.
##   loss   — net HP the actor lost this step (>= 0; healing is not damage)
##   direct — Array of { 'family': String, 'raw': float }, one per DAMAGE Delivery
##            that landed on this actor this step
##   dot_family — label for the unexplained remainder (the DoT channel)
## Returns Array of { 'family': String, 'amount': float }. Direct hits take their
## proportional share of the net loss (so block-absorbed damage is excluded);
## anything left over is the DoT remainder. With no block and a single source the
## split is exact — the common Phase 1 case.
static func attribute_damage(loss: float, direct: Array, dot_family: String = DOT_FAMILY) -> Array:
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
    out.append({ 'family': dot_family, 'amount': remainder })
  return out


func log_event(type: String, data: Dictionary = {}) -> void:
  events.append({ 'type': type, 'data': data })


## Accumulate one damage record into the family tally + the running total.
func record_damage(family: String, amount: float) -> void:
  if amount <= 0.0:
    return
  damage_by_family[family] = damage_by_family.get(family, 0.0) + amount
  total_damage += amount


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
    'total_damage': total_damage,
    'damage_by_family': damage_by_family.duplicate(),
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
  _write_file(path, '\n'.join(lines) + '\n')


# --- helpers ----------------------------------------------------------------

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
