class_name AutoTestMode
extends Node
## The headless autotest entry (autotest.md), Phase 2 scope: drive ONE deterministic
## fight to a clean resolution and report it. The root of `autotest.tscn` — launch
## it as a dedicated main scene so nothing presentational mounts:
##
##   <godot> --headless --path . res://src/autotest/autotest.tscn -- \
##           --autotest --seed 1 --speed 5 --timeout 120 --wall-timeout 30 \
##           --report user://autotest_report.md
##
## It parses flags, forces a fresh-user run (nosave / notutorial), seeds the RNG,
## sets the Timekeeper dial from --speed, builds a player-vs-enemy fight from the
## catalogs, and drives `CombatManager.sim_step()` directly (no _physics_process,
## no real time → bit-reproducible). It enforces a game-time timeout, a wall-clock
## hang watchdog, and stuck detection, hands every step to the logger, then sets
## the exit code (0 = the fight resolved, 1 = stuck / timed out) and quits.
##
## The run loop (multiple encounters, draft strategies, the seeded run RNG) is
## Phase 3; the AutoTestDriver is a no-op stub until then, and --seed / --speed are
## plumbed-but-inert here (a single Phase 1 fight has no RNG and the direct
## sim_step loop advances one STEP per call regardless of the dial).

# Project-local, git-ignored output dir for run artifacts (log + report).
const OUTPUT_DIR: String = 'res://autotest_results'

# --- config (defaults; overridden by _parse_args) ---------------------------
var seed_value: int = 0
var speed: float = Balance.TIMESCALE_FAST_TEST
var timeout_seconds: float = 120.0          # max game-seconds before fail
var wall_timeout_seconds: float = 30.0      # max real-seconds (hang watchdog)
var stuck_threshold_seconds: float = 10.0   # flat total-HP this long = stuck
var strategy: String = 'first-viable'
# Run artifacts default into a project-local, git-ignored dir (autotest_results/)
# so they're easy to find but never committed; --log / --report override.
var log_path: String = OUTPUT_DIR + '/autotest_log.txt'
var report_path: String = OUTPUT_DIR + '/autotest_report.md'
# Forced for every autotest run — a fresh user, no persisted state. (No Save /
# tutorial systems exist yet; these are honoured for parity + Phase 3.)
var nosave: bool = true
var notutorial: bool = true

var logger: AutoTestLogger
var driver: AutoTestDriver


## sim-steps spanning `seconds` of game-time (rounds up). The one bit of timeout
## math: --timeout and the stuck threshold are authored in game-seconds, enforced
## in whole steps. Static + pure so it is unit-testable.
static func seconds_to_steps(seconds: float) -> int:
  return int(ceil(seconds / Balance.STEP))


func _ready() -> void:
  if Engine.is_editor_hint():
    return
  _parse_args()
  print('[AutoTest] start — seed=%d speed=%.1fx timeout=%.0fs wall=%.0fs strategy=%s (nosave+notutorial forced)' % [
    seed_value, speed, timeout_seconds, wall_timeout_seconds, strategy,
  ])
  var result: Dictionary = run_once()
  _report(result)
  get_tree().quit(result['exit_code'])


# --- the run (testable core; no tree, no quit, no I/O) ----------------------

## Build and drive one fight to a verdict; return the result + summary. Pure of
## the scene tree and process exit so GUT can call it directly.
func run_once() -> Dictionary:
  seed(seed_value)   # plumbed; Phase 1 combat draws no RNG (inert until Phase 3)
  logger = AutoTestLogger.new()
  driver = AutoTestDriver.new(strategy)

  var fight: Dictionary = _build_fight()
  var cm: CombatManager = fight['cm']
  var player: Actor = fight['player']
  var enemies: Array = fight['enemies']
  var names: Dictionary = fight['names']
  var actors: Array = [player] + enemies

  cm.start()
  cm.timekeeper.set_base_scale(speed)   # plumbed; inert for the direct sim_step loop
  logger.log_event('fight_started', {
    'seed': seed_value,
    'player_hp': player.max_hp,
    'enemy_count': enemies.size(),
  })

  var timeout_steps: int = seconds_to_steps(timeout_seconds)
  var stuck := AutoTestStuckDetector.new(seconds_to_steps(stuck_threshold_seconds))
  var wall_timeout_ms: int = int(wall_timeout_seconds * 1000.0)
  var wall_start: int = Time.get_ticks_msec()
  stuck.note(_total_hp(actors))   # baseline

  var alive: Dictionary = {}
  for a in actors:
    alive[a] = true

  var outcome: String = ''
  var steps: int = 0
  while not cm.is_resolved():
    if Time.get_ticks_msec() - wall_start >= wall_timeout_ms:
      outcome = 'WALL_TIMEOUT'
      break
    if steps >= timeout_steps:
      outcome = 'TIMEOUT'
      break
    var before: Dictionary = _hp_snapshot(actors)
    cm.sim_step()
    steps += 1
    _observe_damage(cm, actors, before)
    _log_deaths(actors, alive, names, steps)
    if stuck.note(_total_hp(actors)):
      outcome = 'STUCK'
      break

  var resolved: bool = cm.is_resolved()
  if resolved:
    outcome = 'WIN' if cm.player_won() else 'LOSS'

  var result: Dictionary = {
    'outcome': outcome,
    'resolved': resolved,
    'won': resolved and cm.player_won(),
    'steps': steps,
    'sim_seconds': cm.timekeeper.sim_time,
    'wall_ms': Time.get_ticks_msec() - wall_start,
    'player_hp': player.hp,
    'player_max_hp': player.max_hp,
    'enemies': _enemy_states(enemies, names),
  }
  logger.log_event('fight_ended', { 'outcome': outcome, 'steps': steps })
  result['summary'] = logger.summarize(result)
  result['exit_code'] = 0 if resolved else 1

  cm.teardown()
  cm.free()
  return result


# --- fight construction -----------------------------------------------------

## A default player board (mirrors the sandbox) vs the authored grunt. Enemy names
## are kept beside the actors for the log/report (the Actor itself is name-blind).
func _build_fight() -> Dictionary:
  var player := Actor.new(Balance.PLAYER_START_HP)
  for id in [ItemCatalog.Id.WEAPON, ItemCatalog.Id.ARMOR, ItemCatalog.Id.POISON_DAGGER]:
    player.board.append(Item.new(ItemCatalog.get_def(id), player))

  var grunt: EnemyDef = EnemyCatalog.get_def(EnemyCatalog.Id.GRUNT)
  var enemy := Actor.new(grunt.max_hp)
  for id in grunt.item_ids:
    enemy.board.append(Item.new(ItemCatalog.get_def(id), enemy))

  var names: Dictionary = {}
  names[enemy] = grunt.name_key
  return {
    'cm': CombatManager.new(player, [enemy]),
    'player': player,
    'enemies': [enemy],
    'names': names,
  }


# --- per-step observation (reads handed state; writes none to the game) ------

## Attribute each actor's net HP loss this step to a damage family and feed it to
## the logger. Direct hits come from the Deliveries that landed this step; the
## unexplained remainder is the DoT channel (poison). See AutoTestLogger.
func _observe_damage(cm: CombatManager, actors: Array, before: Dictionary) -> void:
  var now: float = cm.timekeeper.sim_time
  var direct_by_target: Dictionary = {}
  for d in cm.deliveries():
    if d.landed and d.kind == Delivery.Kind.DAMAGE and is_equal_approx(d.impact_time, now):
      if not direct_by_target.has(d.target):
        direct_by_target[d.target] = []
      direct_by_target[d.target].append({ 'family': _family_of(d.source), 'raw': d.value })
  for a in actors:
    var loss: float = before[a] - a.hp
    if loss <= 0.0:
      continue
    var direct: Array = direct_by_target.get(a, [])
    for rec in AutoTestLogger.attribute_damage(loss, direct):
      logger.record_damage(rec['family'], rec['amount'])


func _log_deaths(actors: Array, alive: Dictionary, names: Dictionary, step: int) -> void:
  for a in actors:
    if alive[a] and not a.is_alive():
      alive[a] = false
      logger.log_event('actor_died', { 'who': names.get(a, 'Player'), 'step': step })


func _family_of(source: Variant) -> String:
  if source is Item and source.def != null and source.def.name_key != '':
    return source.def.name_key
  return 'Unknown'


func _hp_snapshot(actors: Array) -> Dictionary:
  var snap: Dictionary = {}
  for a in actors:
    snap[a] = a.hp
  return snap


func _total_hp(actors: Array) -> float:
  var total: float = 0.0
  for a in actors:
    total += a.hp
  return total


func _enemy_states(enemies: Array, names: Dictionary) -> Array:
  var out: Array = []
  for e in enemies:
    out.append({ 'name': names.get(e, 'Enemy'), 'hp': e.hp, 'max_hp': e.max_hp })
  return out


# --- reporting + flags ------------------------------------------------------

func _report(result: Dictionary) -> void:
  var summary: Dictionary = result['summary']
  for line in logger.format_summary(summary):
    print(line)
  if log_path != '':
    logger.write_log(log_path, summary)
    print('[AutoTest] log written: %s' % ProjectSettings.globalize_path(log_path))
  if report_path != '':
    logger.write_report(report_path, summary)
    print('[AutoTest] report written: %s' % ProjectSettings.globalize_path(report_path))
  print('[AutoTest] %s — exit %d' % [result['outcome'], result['exit_code']])


func _parse_args() -> void:
  var args: Array = []
  args.append_array(OS.get_cmdline_args())
  args.append_array(OS.get_cmdline_user_args())
  var i: int = 0
  while i < args.size():
    var arg: String = args[i]
    if arg == '--seed':
      seed_value = int(_value(args, i))
      i += 1
    elif arg == '--speed':
      speed = float(_value(args, i))
      i += 1
    elif arg == '--timeout':
      timeout_seconds = float(_value(args, i))
      i += 1
    elif arg == '--wall-timeout':
      wall_timeout_seconds = float(_value(args, i))
      i += 1
    elif arg == '--strategy':
      strategy = _value(args, i)
      i += 1
    elif arg == '--log':
      log_path = _value(args, i)
      i += 1
    elif arg == '--report':
      report_path = _value(args, i)
      i += 1
    i += 1


func _value(args: Array, i: int) -> String:
  return args[i + 1] if i + 1 < args.size() else ''
