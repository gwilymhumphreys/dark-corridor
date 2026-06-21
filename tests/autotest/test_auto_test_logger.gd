extends GutTest
## AutoTestLogger — now sourced from the CombatLog single source of truth (Design B,
## docs/systems/combat_log.md): the old `attribute_damage` / `_split_remainder` HP-diff
## helper is GONE (direct per-tick emission has no proportional weight-split — more
## correct by design). These cover ingest_combat_log folding a fight's player-side
## tallies in, the per-encounter records, and the summary / report formatting.


const PLAYER := CombatLog.Side.PLAYER
const ENEMY := CombatLog.Side.ENEMY


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


# --- ingest_combat_log (the single source of truth) -------------------------

func test_ingest_folds_player_side_fires_and_damage() -> void:
  var clog := CombatLog.new()
  clog.on_item_fired('Rusted Blade', PLAYER, 0.1)
  clog.on_item_fired('Rusted Blade', PLAYER, 0.2)
  clog.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 12.0, 0.2)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  assert_eq(log.fires_by_item['Rusted Blade'], 2, 'fires folded in')
  assert_almost_eq(log.damage_by_family['Rusted Blade'], 12.0, 0.0001, 'damage per item folded in')
  assert_almost_eq(log.total_damage, 12.0, 0.0001, 'player-side dealt total folded in')


func test_ingest_credits_dot_to_its_applier_not_a_lump() -> void:
  # Direct emission credits each DoT tick to its own applier — no generic Poison lump.
  var clog := CombatLog.new()
  clog.on_damage('Venom Fang', PLAYER, 'Grunt', ENEMY, 3.0, 0.5)
  clog.on_damage('Venom Fang', PLAYER, 'Grunt', ENEMY, 3.0, 1.0)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  assert_almost_eq(log.damage_by_family['Venom Fang'], 6.0, 0.0001, 'poison credited to its applier')
  assert_false(log.damage_by_family.has(CombatLog.SOURCELESS),
      'no generic lump when the applier is known')


func test_ingest_folds_block_and_healing() -> void:
  var clog := CombatLog.new()
  clog.on_block('Iron Guard', PLAYER, 'Player', PLAYER, 8.0, 0.1)
  clog.on_block('Iron Guard', PLAYER, 'Player', PLAYER, 8.0, 0.2)
  clog.on_heal('Salve', PLAYER, 'Player', PLAYER, 12.0, 0.3)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  assert_almost_eq(log.block_by_item['Iron Guard'], 16.0, 0.0001, 'block accumulates per item')
  assert_almost_eq(log.healing_by_item['Salve'], 12.0, 0.0001, 'healing accumulates per item')


func test_ingest_is_player_side_only() -> void:
  # An enemy item that did damage must NOT enter the player-only contribution tally.
  var clog := CombatLog.new()
  clog.on_item_fired('Claw', ENEMY, 0.1)
  clog.on_damage('Claw', ENEMY, 'Player', PLAYER, 7.0, 0.1)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  assert_false(log.fires_by_item.has('Claw'), 'enemy fires are excluded')
  assert_false(log.damage_by_family.has('Claw'), 'enemy damage is excluded')
  assert_almost_eq(log.total_damage, 0.0, 0.0001, 'the total is player-dealt only')


func test_ingest_records_incoming_gross_by_enemy() -> void:
  # Incoming pressure is the enemy side's GROSS output — for ranking which enemy items hit
  # hardest, kept apart from the player's own output. (raw omitted → gross == net here.)
  var clog := CombatLog.new()
  clog.on_damage('Claw', ENEMY, 'Player', PLAYER, 7.0, 0.1)
  clog.on_damage('Claw', ENEMY, 'Player', PLAYER, 5.0, 0.4)
  clog.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 9.0, 0.2)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  assert_almost_eq(log.incoming_by_enemy['Claw'], 12.0, 0.0001, 'enemy gross output tallied by source')
  assert_false(log.incoming_by_enemy.has('Rusted Blade'), 'player output is not "incoming"')
  assert_almost_eq(log.total_incoming, 12.0, 0.0001, 'total incoming is the enemy gross')
  assert_almost_eq(log.total_damage, 9.0, 0.0001, 'total dealt stays player output')


func test_ingest_incoming_counts_fully_blocked_hits() -> void:
  # The point of GROSS: a hit the player fully blocked (net 0) still registers as threat,
  # so a block-heavy build does not read as "the enemy did nothing".
  var clog := CombatLog.new()
  clog.on_damage('Claw', ENEMY, 'Player', PLAYER, 0.0, 0.1, 8.0)   # net 0, gross 8 (all blocked)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  assert_almost_eq(log.incoming_by_enemy['Claw'], 8.0, 0.0001, 'a fully-blocked hit still shows as incoming')
  assert_almost_eq(log.total_incoming, 8.0, 0.0001)


func test_ingest_accumulates_across_multiple_fights() -> void:
  var log := AutoTestLogger.new()
  for _fight in 2:
    var clog := CombatLog.new()
    clog.on_item_fired('Rusted Blade', PLAYER, 0.1)
    clog.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 10.0, 0.1)
    log.ingest_combat_log(clog)
  assert_eq(log.fires_by_item['Rusted Blade'], 2, 'fires accumulate across fights')
  assert_almost_eq(log.total_damage, 20.0, 0.0001, 'damage accumulates across fights')


func test_ingest_null_is_a_noop() -> void:
  var log := AutoTestLogger.new()
  log.ingest_combat_log(null)
  assert_almost_eq(log.total_damage, 0.0, 0.0001, 'a null log folds nothing')
  assert_true(log.fires_by_item.is_empty())


# --- accumulation + summary -------------------------------------------------

func test_summarize_merges_result_with_the_ingested_tally() -> void:
  var clog := CombatLog.new()
  clog.on_damage('Blade', PLAYER, 'Grunt', ENEMY, 12.0, 0.1)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  var s := log.summarize({
    'outcome': 'WIN', 'resolved': true, 'won': true, 'steps': 120,
    'sim_seconds': 2.0, 'wall_ms': 5,
    'player_hp': 80.0, 'player_max_hp': 100.0,
    'enemies': [{ 'name': 'Corridor Grunt', 'hp': 0.0, 'max_hp': 40.0 }],
  })
  assert_eq(s['outcome'], 'WIN')
  assert_eq(s['steps'], 120)
  assert_true(s['won'])
  assert_almost_eq(s['total_damage'], 12.0, 0.0001)
  assert_almost_eq(s['damage_by_family']['Blade'], 12.0, 0.0001)
  assert_eq(s['enemies'][0]['name'], 'Corridor Grunt')


func test_format_summary_and_report_write() -> void:
  var clog := CombatLog.new()
  clog.on_damage('Blade', PLAYER, 'Grunt', ENEMY, 12.0, 0.1)
  clog.on_damage('Venom Fang', PLAYER, 'Grunt', ENEMY, 3.0, 0.5)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  var s := log.summarize({
    'outcome': 'WIN', 'resolved': true, 'won': true, 'steps': 90,
    'sim_seconds': 1.5, 'wall_ms': 4,
    'player_hp': 88.0, 'player_max_hp': 100.0,
    'enemies': [{ 'name': 'Corridor Grunt', 'hp': 0.0, 'max_hp': 40.0 }],
  })
  assert_gt(log.format_summary(s).size(), 0, 'summary renders some lines')

  var path := 'user://autotest_report_test.md'
  log.write_report(path, s)
  var text := FileAccess.get_file_as_string(path)
  assert_string_contains(text, '# AutoTest report')
  assert_string_contains(text, 'Blade')
  DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- Phase 5: per-encounter + per-item contribution -------------------------

func test_record_encounter_is_summarized() -> void:
  var log := AutoTestLogger.new()
  log.record_encounter({
    'beat': 0, 'type': 'Fight', 'name': 'Corridor Grunt',
    'duration': 5.0, 'hp_before': 100.0, 'hp_after': 80.0, 'outcome': 'WON',
  })
  var s := log.summarize({})
  assert_eq(s['encounters'].size(), 1, 'the beat is recorded')
  assert_almost_eq(s['encounters'][0]['duration'], 5.0, 0.0001, 'duration captured')
  assert_almost_eq(s['encounters'][0]['hp_after'], 80.0, 0.0001, 'HP attrition captured')


func test_item_contribution_flags_never_fired_as_trap() -> void:
  var clog := CombatLog.new()
  clog.on_item_fired('Rusted Blade', PLAYER, 0.1)
  clog.on_item_fired('Rusted Blade', PLAYER, 0.2)
  clog.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 12.0, 0.2)
  clog.on_item_fired('Venom Fang', PLAYER, 0.3)   # fires, but no DIRECT damage here
  # Iron Guard never fired.
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  var s := log.summarize({ 'player_items': ['Rusted Blade', 'Iron Guard', 'Venom Fang'] })
  var by := {}
  for r in log._item_contribution_rows(s):
    by[r['name']] = r
  assert_eq(by['Rusted Blade']['fires'], 2, 'fires counted')
  assert_almost_eq(by['Rusted Blade']['damage'], 12.0, 0.0001, 'damage attributed')
  assert_false(by['Rusted Blade']['trap'], 'a firing damage item is not a trap')
  assert_false(by['Venom Fang']['trap'], 'a firing non-damage item is not a trap')
  assert_true(by['Iron Guard']['trap'], 'a never-fired item is a trap pick')


func test_item_contribution_aggregates_duplicates() -> void:
  var clog := CombatLog.new()
  clog.on_item_fired('Spite Ward', PLAYER, 0.1)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  var rows := log._item_contribution_rows(log.summarize({ 'player_items': ['Spite Ward', 'Spite Ward'] }))
  assert_eq(rows.size(), 1, 'duplicates aggregate to one row')
  assert_eq(rows[0]['count'], 2, 'with a count')


func test_item_contribution_carries_block_and_healing() -> void:
  var clog := CombatLog.new()
  clog.on_item_fired('Iron Guard', PLAYER, 0.1)
  clog.on_block('Iron Guard', PLAYER, 'Player', PLAYER, 8.0, 0.1)
  clog.on_block('Iron Guard', PLAYER, 'Player', PLAYER, 8.0, 0.2)
  clog.on_heal('Salve', PLAYER, 'Player', PLAYER, 12.0, 0.3)
  var log := AutoTestLogger.new()
  log.ingest_combat_log(clog)
  var rows := log._item_contribution_rows(log.summarize({ 'player_items': ['Iron Guard', 'Salve'] }))
  assert_almost_eq(float(rows[0]['block']), 16.0, 0.0001, 'block accumulates per item')
  assert_almost_eq(float(rows[1]['healing']), 12.0, 0.0001, 'healing accumulates per item')
  assert_false(rows[0]['trap'], 'a firing block item is not a trap')


func test_report_header_carries_seed_and_strategy() -> void:
  var log := AutoTestLogger.new()
  var summary := log.summarize({ 'seed': 42, 'strategy': 'greedy-synergy' })
  var path := 'user://test_tune_report.md'
  log.write_report(path, summary)
  var text := FileAccess.get_file_as_string(path)
  DirAccess.open('user://').remove(path)
  assert_string_contains(text, '- Seed: 42', 'the report identifies its seed')
  assert_string_contains(text, '- Strategy: greedy-synergy', 'and its strategy')
