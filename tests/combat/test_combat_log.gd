extends GutTest
## CombatLog — the per-fight observation sink (docs/systems/combat_log.md). Pure tally +
## ordered timeline on synthetic input: fires increment per item, damage/heal/block
## accumulate per source + in side totals, the timeline records t · type · amount in
## order, throws log + carry the def id, side tagging keeps the same name_key separate
## on each side, and a null/source-less DoT falls back to the generic bucket.


const PLAYER := CombatLog.Side.PLAYER
const ENEMY := CombatLog.Side.ENEMY


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


# --- fires ------------------------------------------------------------------

func test_fires_increment_per_item() -> void:
  var log := CombatLog.new()
  log.on_item_fired('Rusted Blade', PLAYER, 0.1)
  log.on_item_fired('Rusted Blade', PLAYER, 0.2)
  log.on_item_fired('Venom Fang', PLAYER, 0.3)
  var rows := _by_name(log.summary(PLAYER))
  assert_eq(rows['Rusted Blade']['fires'], 2, 'two fires counted for the blade')
  assert_eq(rows['Venom Fang']['fires'], 1, 'one fire for the fang')


# --- damage -----------------------------------------------------------------

func test_damage_accumulates_per_source_and_in_totals() -> void:
  var log := CombatLog.new()
  log.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 6.0, 0.1)
  log.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 4.0, 0.2)
  var rows := _by_name(log.summary(PLAYER))
  assert_almost_eq(rows['Rusted Blade']['damage'], 10.0, 0.0001, 'per-item damage accumulates')
  assert_almost_eq(float(log.total_damage_dealt[PLAYER]), 10.0, 0.0001, 'player-side dealt total')
  assert_almost_eq(float(log.total_damage_taken[ENEMY]), 10.0, 0.0001, 'enemy-side taken total')


func test_damage_of_zero_or_less_is_ignored() -> void:
  var log := CombatLog.new()
  log.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 0.0, 0.1)
  assert_true(log.summary(PLAYER).is_empty(), 'zero damage records nothing')
  assert_eq(log.events.size(), 0, 'and appends no timeline event')


func test_gross_defaults_to_net_when_raw_omitted() -> void:
  var log := CombatLog.new()
  log.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 6.0, 0.1)
  var rows := _by_name(log.summary(PLAYER))
  assert_almost_eq(rows['Rusted Blade']['gross'], 6.0, 0.0001, 'gross defaults to net when raw omitted')
  assert_almost_eq(rows['Rusted Blade']['damage'], 6.0, 0.0001)


func test_gross_is_recorded_even_when_net_is_zero() -> void:
  # A fully-blocked hit (net 0, gross 8): gross still registers the threat; net does not move HP.
  var log := CombatLog.new()
  log.on_damage('Claw', ENEMY, 'Player', PLAYER, 0.0, 0.1, 8.0)
  var rows := _by_name(log.summary(ENEMY))
  assert_almost_eq(rows['Claw']['gross'], 8.0, 0.0001, 'gross records the pre-block hit')
  assert_almost_eq(rows['Claw']['damage'], 0.0, 0.0001, 'net stays zero — block ate it')
  assert_almost_eq(float(log.total_gross[ENEMY]), 8.0, 0.0001, 'gross total accrues')
  assert_false(log.total_damage_dealt.has(ENEMY), 'no net dealt recorded for a fully-blocked hit')
  assert_eq(log.events.size(), 1, 'still appends one timeline event (amount = net 0)')


# --- heal -------------------------------------------------------------------

func test_healing_accumulates_per_source_and_total() -> void:
  var log := CombatLog.new()
  log.on_heal('Salve', PLAYER, 'Player', PLAYER, 5.0, 0.1)
  log.on_heal('Salve', PLAYER, 'Player', PLAYER, 7.0, 0.2)
  var rows := _by_name(log.summary(PLAYER))
  assert_almost_eq(rows['Salve']['healing'], 12.0, 0.0001, 'per-item healing accumulates')
  assert_almost_eq(float(log.total_healing[PLAYER]), 12.0, 0.0001, 'player-side healing total')


# --- block ------------------------------------------------------------------

func test_block_accumulates_per_source_and_total() -> void:
  var log := CombatLog.new()
  log.on_block('Iron Guard', PLAYER, 'Player', PLAYER, 8.0, 0.1)
  log.on_block('Iron Guard', PLAYER, 'Player', PLAYER, 8.0, 0.2)
  var rows := _by_name(log.summary(PLAYER))
  assert_almost_eq(rows['Iron Guard']['block'], 16.0, 0.0001, 'per-item block accumulates')
  assert_almost_eq(float(log.total_block[PLAYER]), 16.0, 0.0001, 'player-side block total')


# --- statuses ---------------------------------------------------------------

func test_status_applied_counts_and_carries_the_id() -> void:
  var log := CombatLog.new()
  log.on_status_applied('Venom Fang', PLAYER, 'Grunt', ENEMY, 'poison', 0.1)
  var rows := _by_name(log.summary(PLAYER))
  assert_eq(rows['Venom Fang']['statuses'], 1, 'one status applied counted')
  assert_eq(log.events[0]['type'], 'status')
  assert_eq(log.events[0]['data'], 'poison', 'the status id rides the event data')


# --- throws -----------------------------------------------------------------

func test_throw_logs_an_event_carrying_the_def_id() -> void:
  var log := CombatLog.new()
  log.on_throw('healing_potion', PLAYER, 1.4)
  assert_eq(log.events.size(), 1)
  assert_eq(log.events[0]['type'], 'throw')
  assert_eq(log.events[0]['data'], 'healing_potion', 'the thrown consumable id is captured')
  assert_almost_eq(log.events[0]['t'], 1.4, 0.0001)


# --- the timeline (order, t, type, amount) ----------------------------------

func test_timeline_records_in_sim_order_with_t_type_amount() -> void:
  var log := CombatLog.new()
  log.on_item_fired('Rusted Blade', PLAYER, 0.1)
  log.on_damage('Rusted Blade', PLAYER, 'Grunt', ENEMY, 6.0, 0.2)
  log.on_heal('Salve', PLAYER, 'Player', PLAYER, 3.0, 0.3)
  assert_eq(log.events.size(), 3, 'one event per write')
  assert_eq(log.events[0]['type'], 'fire')
  assert_eq(log.events[1]['type'], 'damage')
  assert_eq(log.events[2]['type'], 'heal')
  assert_almost_eq(log.events[1]['amount'], 6.0, 0.0001, 'the damage amount is on the event')
  assert_almost_eq(log.events[2]['t'], 0.3, 0.0001, 'timestamps captured in order')


# --- side awareness ---------------------------------------------------------

func test_the_same_name_key_on_each_side_stays_separate() -> void:
  # A colorless item can sit on both sides — a flat key would conflate them.
  var log := CombatLog.new()
  log.on_damage('Claw', PLAYER, 'Grunt', ENEMY, 10.0, 0.1)
  log.on_damage('Claw', ENEMY, 'Player', PLAYER, 4.0, 0.2)
  assert_almost_eq(_by_name(log.summary(PLAYER))['Claw']['damage'], 10.0, 0.0001, 'player-side Claw')
  assert_almost_eq(_by_name(log.summary(ENEMY))['Claw']['damage'], 4.0, 0.0001, 'enemy-side Claw, separate')
  assert_almost_eq(float(log.total_damage_dealt[PLAYER]), 10.0, 0.0001)
  assert_almost_eq(float(log.total_damage_dealt[ENEMY]), 4.0, 0.0001)


func test_summary_returns_only_the_requested_side() -> void:
  var log := CombatLog.new()
  log.on_item_fired('Rusted Blade', PLAYER, 0.1)
  log.on_item_fired('Enemy Claw', ENEMY, 0.1)
  var player_names := _by_name(log.summary(PLAYER))
  assert_true(player_names.has('Rusted Blade'), 'player item present')
  assert_false(player_names.has('Enemy Claw'), 'enemy item absent from the player summary')


# --- source-less DoT fallback -----------------------------------------------

func test_sourceless_dot_falls_to_the_generic_bucket() -> void:
  # A DoT whose applier item is unknown is credited under the SOURCELESS bucket.
  var log := CombatLog.new()
  log.on_damage(CombatLog.SOURCELESS, ENEMY, 'Player', PLAYER, 3.0, 0.5)
  var rows := _by_name(log.summary(ENEMY))
  assert_true(rows.has(CombatLog.SOURCELESS), 'a source-less DoT keeps the generic bucket')
  assert_almost_eq(rows[CombatLog.SOURCELESS]['damage'], 3.0, 0.0001)


# --- helpers ----------------------------------------------------------------

func _by_name(rows: Array) -> Dictionary:
  var by := {}
  for r in rows:
    by[r['name']] = r
  return by
