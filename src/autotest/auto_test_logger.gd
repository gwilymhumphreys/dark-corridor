class_name AutoTestLogger
extends RefCounted
## The structured-event + summary sink (autotest.md). It is HANDED state by
## AutoTestMode — the per-fight CombatLog, actor HP, the outcome — and folds it into
## events, per-item tallies, and a printable / writable summary. It writes no game
## state (the same discipline as the VFX wall it shadows).
##
## SINGLE SOURCE OF TRUTH (docs/systems/combat_log.md Design B): the damage / fire /
## block / healing numbers come from the CombatManager's CombatLog — the manager
## logs each at its mutation site — not from per-step HP-diff reconstruction. The old
## `attribute_damage` / `_split_remainder` HP-diff helper (and its proportional
## multi-DoT weight-split) is GONE: direct emission credits each DoT tick to its own
## applier EXACTLY, so the per-applier split is no longer an estimate. The logger
## ingests one fight's player-side tallies via `ingest_combat_log`.

var events: Array = []                 # Array[Dictionary] — { type, data }
var damage_by_family: Dictionary = {}  # item name_key -> total damage dealt (player side; each
                                       # DoT applier is its own channel — no generic lump)
var total_damage: float = 0.0
# Phase 5 (tune machinery): per-encounter breakdown + per-item fire counts.
var encounters: Array = []             # Array[Dictionary] — one per resolved beat
var fires_by_item: Dictionary = {}     # item name_key -> times it fired (player items)
# Defensive-item value (tune): block applied + healing landed per player item, so a
# block/heal item can be RANKED, not just cleared of the trap flag by firing.
var block_by_item: Dictionary = {}     # item name_key -> total block applied
var healing_by_item: Dictionary = {}   # item name_key -> total healing done (post-cap, from
                                       # Actor.heal's return — honest, no overheal)
# Incoming pressure (tune): GROSS (pre-mitigation) enemy output, keyed by the enemy item that
# dealt it. GROSS — not net HP lost — because a block-heavy test build absorbs the hit to ~0 net,
# which would hide the enemy's real threat. Net survivability is the per-encounter HP attrition.
var incoming_by_enemy: Dictionary = {}  # enemy item name_key -> gross damage thrown at the player side
var total_incoming: float = 0.0         # gross damage the player side faced (pre-mitigation)


func log_event(type: String, data: Dictionary = {}) -> void:
  events.append({ 'type': type, 'data': data })


## Fold one fight's PLAYER-SIDE CombatLog tallies into the running totals — the single
## source of truth (Design B). Called at each fight's end with the CombatManager's log.
## Player side only: the contribution table + the run total are player-only (a colorless
## item on both sides is kept separate by the log's side-keying). `damage_by_family` is
## now per ITEM (each DoT applier its own channel — direct emission, no weight-split).
func ingest_combat_log(log: CombatLog) -> void:
  if log == null:
    return
  var side: int = CombatLog.Side.PLAYER
  for row in log.summary(side):
    var name: String = row['name']
    if row['fires'] > 0:
      fires_by_item[name] = int(fires_by_item.get(name, 0)) + int(row['fires'])
    if float(row['damage']) > 0.0:
      damage_by_family[name] = float(damage_by_family.get(name, 0.0)) + float(row['damage'])
    if float(row['block']) > 0.0:
      block_by_item[name] = float(block_by_item.get(name, 0.0)) + float(row['block'])
    if float(row['healing']) > 0.0:
      healing_by_item[name] = float(healing_by_item.get(name, 0.0)) + float(row['healing'])
  total_damage += float(log.total_damage_dealt.get(side, 0.0))
  # Incoming pressure = the enemy side's GROSS output (it lands on the player side). Gross, not
  # net, so a hit the player fully blocked still registers as threat.
  for row in log.summary(CombatLog.Side.ENEMY):
    if float(row['gross']) > 0.0:
      var src: String = row['name']
      incoming_by_enemy[src] = float(incoming_by_enemy.get(src, 0.0)) + float(row['gross'])
  total_incoming += float(log.total_gross.get(CombatLog.Side.ENEMY, 0.0))


## Record one resolved beat (a fight or rest) for the per-encounter table. `rec` =
## { beat, type, name, duration, hp_before, hp_after, outcome }.
func record_encounter(rec: Dictionary) -> void:
  encounters.append(rec)


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
    'total_incoming': total_incoming,
    'incoming_by_enemy': incoming_by_enemy.duplicate(),
    'encounters': encounters.duplicate(true),           # run mode only
    'fires_by_item': fires_by_item.duplicate(),
    'block_by_item': block_by_item.duplicate(),
    'healing_by_item': healing_by_item.duplicate(),
    'player_items': result.get('player_items', []),     # final board names (run mode)
    'strategy': result.get('strategy', ''),
    'seed': result.get('seed', 0),
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
  lines.append('Incoming (gross, pre-block): %.1f' % summary['total_incoming'])
  for src in _sorted_families(summary['incoming_by_enemy']):
    lines.append('  %s: %.1f' % [src, summary['incoming_by_enemy'][src]])
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
  # Provenance — a tune pass produces many reports across seeds × strategies; each
  # artifact must identify itself.
  lines.append('- Seed: %d' % int(summary['seed']))
  if summary['strategy'] != '':
    lines.append('- Strategy: %s' % summary['strategy'])
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
  lines.append('## Damage by item')
  lines.append('')
  if summary['damage_by_family'].is_empty():
    lines.append('- (none)')
  else:
    for family in _sorted_families(summary['damage_by_family']):
      lines.append('- %s: %.1f' % [family, summary['damage_by_family'][family]])
  lines.append('')
  lines.append('Total damage dealt: **%.1f**' % summary['total_damage'])

  # Incoming pressure (the difficulty lens) — GROSS enemy output, total + per enemy item. Gross
  # (pre-block) so a block-heavy build doesn't hide enemy threat; net HP loss is the per-encounter
  # attrition below. This is what a tune pass reads to judge whether an enemy hits too hard.
  lines.append('')
  lines.append('## Incoming damage (gross, by enemy item)')
  lines.append('')
  if summary['incoming_by_enemy'].is_empty():
    lines.append('- (none)')
  else:
    for src in _sorted_families(summary['incoming_by_enemy']):
      lines.append('- %s: %.1f' % [src, summary['incoming_by_enemy'][src]])
  lines.append('')
  lines.append('Total incoming (gross, pre-block): **%.1f**' % summary['total_incoming'])

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

  # Per-item contribution (run mode) — fires + damage + block + healing; a never-fired
  # item is a trap pick, and the defensive columns let block/heal items be RANKED.
  var rows: Array = _item_contribution_rows(summary)
  if not rows.is_empty():
    lines.append('')
    lines.append('## Item contribution (player board)')
    lines.append('')
    lines.append('| Item | Count | Fires | Damage | Block | Healing | Trap? |')
    lines.append('|------|-------|-------|--------|-------|---------|-------|')
    for r in rows:
      lines.append('| %s | %d | %d | %.1f | %.1f | %.1f | %s |' % [
        r['name'], int(r['count']), int(r['fires']), float(r['damage']),
        float(r['block']), float(r['healing']), 'yes' if r['trap'] else '',
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
      'block': float(summary['block_by_item'].get(name, 0.0)),
      'healing': float(summary['healing_by_item'].get(name, 0.0)),
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
