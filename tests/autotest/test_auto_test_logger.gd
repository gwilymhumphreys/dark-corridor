extends GutTest
## AutoTestLogger — the pure damage-attribution helper, the family/total tally,
## and the summary it folds together for the report.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


# --- attribute_damage (pure) ------------------------------------------------

func test_single_direct_hit_attributes_fully() -> void:
  var recs := AutoTestLogger.attribute_damage(10.0, [{ 'family': 'Blade', 'raw': 10.0 }])
  assert_eq(recs.size(), 1)
  assert_eq(recs[0]['family'], 'Blade')
  assert_almost_eq(recs[0]['amount'], 10.0, 0.0001)


func test_loss_with_no_direct_is_dot() -> void:
  var recs := AutoTestLogger.attribute_damage(4.0, [])
  assert_eq(recs.size(), 1)
  assert_eq(recs[0]['family'], AutoTestLogger.DOT_FAMILY, 'unexplained loss is the DoT channel')
  assert_almost_eq(recs[0]['amount'], 4.0, 0.0001)


func test_direct_plus_dot_remainder_splits() -> void:
  # 9 lost: 6 from a direct hit, the other 3 unexplained -> DoT.
  var recs := AutoTestLogger.attribute_damage(9.0, [{ 'family': 'Blade', 'raw': 6.0 }])
  var by := _by_family(recs)
  assert_almost_eq(by['Blade'], 6.0, 0.0001)
  assert_almost_eq(by[AutoTestLogger.DOT_FAMILY], 3.0, 0.0001)


func test_block_reduces_the_direct_share() -> void:
  # 6 raw direct but only 4 net lost (block absorbed 2): all 4 to the direct
  # family, no DoT remainder invented.
  var recs := AutoTestLogger.attribute_damage(4.0, [{ 'family': 'Blade', 'raw': 6.0 }])
  assert_eq(recs.size(), 1)
  assert_eq(recs[0]['family'], 'Blade')
  assert_almost_eq(recs[0]['amount'], 4.0, 0.0001)


func test_two_direct_hits_split_proportionally() -> void:
  var recs := AutoTestLogger.attribute_damage(10.0, [
    { 'family': 'A', 'raw': 6.0 },
    { 'family': 'B', 'raw': 4.0 },
  ])
  var by := _by_family(recs)
  assert_almost_eq(by['A'], 6.0, 0.0001)
  assert_almost_eq(by['B'], 4.0, 0.0001)


func test_zero_loss_yields_no_records() -> void:
  assert_eq(AutoTestLogger.attribute_damage(0.0, [{ 'family': 'A', 'raw': 3.0 }]).size(), 0)


func test_dot_remainder_credits_the_single_applier() -> void:
  # 5 lost, no direct hit, one known poison source -> all 5 to that applier item.
  var recs := AutoTestLogger.attribute_damage(5.0, [], [{ 'label': 'Venom Fang', 'weight': 3.0 }])
  assert_eq(recs.size(), 1)
  assert_eq(recs[0]['family'], 'Venom Fang', 'poison credited to its applier, not the generic channel')
  assert_almost_eq(recs[0]['amount'], 5.0, 0.0001)


func test_dot_remainder_splits_between_appliers_by_weight() -> void:
  var recs := AutoTestLogger.attribute_damage(9.0, [], [
    { 'label': 'Venom Fang', 'weight': 6.0 },
    { 'label': 'Ember Brand', 'weight': 3.0 },
  ])
  var by := _by_family(recs)
  assert_almost_eq(by['Venom Fang'], 6.0, 0.0001, 'split proportional to potential tick damage')
  assert_almost_eq(by['Ember Brand'], 3.0, 0.0001)


func test_dot_remainder_with_no_known_source_is_the_generic_channel() -> void:
  # Empty snapshot (a source-less DoT) keeps the old behaviour.
  var recs := AutoTestLogger.attribute_damage(4.0, [], [])
  assert_eq(recs[0]['family'], AutoTestLogger.DOT_FAMILY, 'source-less DoT stays the generic channel')
  assert_almost_eq(recs[0]['amount'], 4.0, 0.0001)


func test_direct_plus_dot_credits_both_the_hit_and_the_applier() -> void:
  # 9 lost: 6 from a blade, 3 from poison -> blade + its applier, no generic lump.
  var recs := AutoTestLogger.attribute_damage(
    9.0, [{ 'family': 'Rusted Blade', 'raw': 6.0 }], [{ 'label': 'Venom Fang', 'weight': 3.0 }])
  var by := _by_family(recs)
  assert_almost_eq(by['Rusted Blade'], 6.0, 0.0001)
  assert_almost_eq(by['Venom Fang'], 3.0, 0.0001)
  assert_false(by.has(AutoTestLogger.DOT_FAMILY), 'no generic Poison lump when the applier is known')


# --- accumulation + summary -------------------------------------------------

func test_record_damage_accumulates_family_and_total() -> void:
  var log := AutoTestLogger.new()
  log.record_damage('A', 3.0)
  log.record_damage('A', 2.0)
  log.record_damage('B', 4.0)
  log.record_damage('B', 0.0)   # ignored
  assert_almost_eq(log.total_damage, 9.0, 0.0001)
  assert_almost_eq(log.damage_by_family['A'], 5.0, 0.0001)
  assert_almost_eq(log.damage_by_family['B'], 4.0, 0.0001)


func test_summarize_merges_result_with_tally() -> void:
  var log := AutoTestLogger.new()
  log.record_damage('Blade', 12.0)
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
  var log := AutoTestLogger.new()
  log.record_damage('Blade', 12.0)
  log.record_damage('Poison', 3.0)
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
  var log := AutoTestLogger.new()
  log.record_item_fire('Rusted Blade')
  log.record_item_fire('Rusted Blade')
  log.record_damage('Rusted Blade', 12.0)
  log.record_item_fire('Venom Fang')   # fires, but deals no DIRECT damage (DoT channel)
  # Iron Guard never fired.
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
  var log := AutoTestLogger.new()
  log.record_item_fire('Spite Ward')
  var rows := log._item_contribution_rows(log.summarize({ 'player_items': ['Spite Ward', 'Spite Ward'] }))
  assert_eq(rows.size(), 1, 'duplicates aggregate to one row')
  assert_eq(rows[0]['count'], 2, 'with a count')


func test_item_contribution_carries_block_and_healing() -> void:
  var log := AutoTestLogger.new()
  log.record_item_fire('Iron Guard')
  log.record_item_block('Iron Guard', 8.0)
  log.record_item_block('Iron Guard', 8.0)
  log.record_item_healing('Salve', 12.0)
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


# --- helpers ----------------------------------------------------------------

func _by_family(records: Array) -> Dictionary:
  var by := {}
  for r in records:
    by[r['family']] = r['amount']
  return by
