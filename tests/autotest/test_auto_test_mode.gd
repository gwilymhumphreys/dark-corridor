extends GutTest
## AutoTestMode — the timeout math + a full headless run_once: the default fight
## resolves to a deterministic win, attributes damage by family, and a too-short
## timeout fails as a TIMEOUT (exit 1). Drives the real sim with no scene tree.


var _modes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureRun.install()


func after_each() -> void:
  for m in _modes:
    if is_instance_valid(m):
      m.free()
  _modes.clear()
  TestCleanup.reset_all_managers()


func _mode() -> AutoTestMode:
  var m := AutoTestMode.new()   # never added to the tree, so _ready/quit don't fire
  m.character = FixtureCharacter.ID
  _modes.append(m)
  return m


# --- timeout math -----------------------------------------------------------

func test_seconds_to_steps_rounds_up() -> void:
  assert_eq(AutoTestMode.seconds_to_steps(1.0), 60, '1s at STEP=1/60 is 60 steps')
  assert_eq(AutoTestMode.seconds_to_steps(0.0), 0, 'zero seconds is zero steps')
  assert_eq(AutoTestMode.seconds_to_steps(0.001), 1, 'a sliver of a second rounds up to one step')


# --- full headless run ------------------------------------------------------

func test_run_once_resolves_default_fight_as_a_win() -> void:
  var r := _mode().run_once()
  assert_eq(r['outcome'], 'WIN', 'the default player build beats the grunt')
  assert_true(r['resolved'])
  assert_eq(r['exit_code'], 0, 'a clean resolution passes')
  assert_gt(r['steps'], 0, 'the fight took some steps')
  assert_almost_eq(r['sim_seconds'], r['steps'] * Balance.STEP, 0.0001, 'sim-time = steps x STEP')


func test_run_once_is_deterministic() -> void:
  var a := _mode().run_once()
  var b := _mode().run_once()
  assert_eq(a['steps'], b['steps'], 'same step count')
  assert_eq(a['outcome'], b['outcome'], 'same outcome')
  assert_almost_eq(a['player_hp'], b['player_hp'], 0.0001, 'identical final HP — bit-reproducible')


func test_run_once_attributes_damage_per_player_item() -> void:
  # Sourced from the CombatLog (Design B): damage_by_family is per ITEM, DIRECT hits only, and
  # PLAYER-SIDE only. Status (DoT) damage is NOT here — it is bucketed by status in
  # damage_by_status. So the attack's hits show per item, the poison shows under its status, and
  # the enemy's item (enemy side) is excluded. The board is fixtures, not the default character's
  # kit, because this needs one direct attacker and one pure applier side by side.
  var m := _FixtureBoardMode.new()
  _modes.append(m)
  var r := m.run_once()
  var fam: Dictionary = r['summary']['damage_by_family']
  var by_status: Dictionary = r['summary']['damage_by_status']
  assert_true(fam.has('Fixture Blade'), 'direct attack damage credited to the player item')
  assert_false(fam.has('Fixture Fang'), 'a pure applier deals no DIRECT damage — not in the per-item table')
  assert_true(by_status.has('Poison'), 'poison DoT bucketed under its status')
  assert_false(fam.has('Fixture Claw'), 'the enemy item is enemy-side — excluded from the player-only tally')
  assert_gt(r['summary']['total_damage'], 0.0, 'some player damage was dealt')


func test_tiny_timeout_fails_as_timeout() -> void:
  var m := _mode()
  m.timeout_seconds = 0.05   # ~3 steps — far too short for the fight to resolve
  var r := m.run_once()
  assert_eq(r['outcome'], 'TIMEOUT')
  assert_false(r['resolved'])
  assert_eq(r['exit_code'], 1, 'an unresolved fight fails')


## A run_once fight with a known board: one direct attacker, one pure applier, and an enemy whose
## item is named differently so per-item rows stay tellable apart by side. The shipped default
## board is the default character's starting kit, which has no applier in it.
class _FixtureBoardMode extends AutoTestMode:
  func _build_fight() -> Dictionary:
    var player := Actor.new(Balance.PLAYER_START_HP)
    for def in [FixtureItems.attack(), FixtureItems.poison()]:
      player.board.append(Item.new(def, player))

    var enemy := Actor.new(Balance.ENEMY_PLACEHOLDER_HP)
    enemy.board.append(Item.new(FixtureItems.enemy_attack(), enemy))

    var names: Dictionary = {}
    names[enemy] = 'Fixture Grunt'
    return {
      'cm': CombatManager.new(player, [enemy]),
      'player': player,
      'enemies': [enemy],
      'names': names,
    }
