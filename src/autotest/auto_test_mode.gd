class_name AutoTestMode
extends Node
## The headless autotest entry (autotest.md). It drives a whole deterministic descent
## (Game → Run → Encounter → Combat) — or one fight with --single-fight — to a clean
## resolution and reports it. The root of `autotest.tscn` — launch it as a dedicated main
## scene so nothing presentational mounts:
##
##   <godot> --headless --path . res://src/autotest/autotest.tscn -- \
##           --autotest --seed 1 --speed 5 --timeout 120 --wall-timeout 30 \
##           --strategy greedy-synergy --report user://autotest_report.md
##
## It parses flags, forces a fresh-user run (nosave / notutorial), seeds the run RNG
## (--seed), sets the Timekeeper dial from --speed, takes draft picks via the AutoTestDriver's
## seeded strategy (--strategy), and drives `CombatManager.sim_step()` directly (no
## _physics_process, no real time → bit-reproducible). It enforces a game-time timeout, a
## wall-clock hang watchdog, and stuck detection, then sets the exit code (0 = resolved —
## won / died / capped; 1 = stuck / timed out) and quits.
##
## Damage / fire / block / healing numbers come from the CombatManager's CombatLog —
## the SINGLE SOURCE OF TRUTH (docs/systems/combat_log.md). Each fight attaches a fresh
## CombatLog before its sim_step loop and ingests its player side at fight end; there is
## no per-step HP-diff reconstruction.
##
## (The harness doesn't quit/resume mid-run itself; the deterministic-resume invariant is
## covered by GUT.)

# Project-local, git-ignored output dir for run artifacts (log + report).
const OUTPUT_DIR: String = 'res://autotest_results'

# --- config (defaults; overridden by _parse_args) ---------------------------
var seed_value: int = 0
var speed: float = Balance.TIMESCALE_FAST_TEST
var timeout_seconds: float = 120.0          # max game-seconds before fail
var wall_timeout_seconds: float = 30.0      # max real-seconds (hang watchdog)
var stuck_threshold_seconds: float = 10.0   # flat total-HP this long = stuck (per fight)
var strategy: String = 'first-viable'
var single_fight: bool = false              # --single-fight: the Phase-2 one-fight path
var encounters: int = 0                     # --encounters N: cap beats (0 = play the whole map)
# Run artifacts default into a project-local, git-ignored dir (autotest_results/)
# so they're easy to find but never committed; --log / --report override.
var log_path: String = OUTPUT_DIR + '/autotest_log.txt'
var report_path: String = OUTPUT_DIR + '/autotest_report.md'
# Forced for every autotest run — a fresh user, no persisted state. `nosave` is
# honoured in run_full (Save.disabled) so a headless run never clobbers the real
# run slot; `notutorial` is parity for a tutorial system that doesn't exist yet.
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
  print('[AutoTest] start — mode=%s seed=%d speed=%.1fx timeout=%.0fs wall=%.0fs strategy=%s (nosave+notutorial forced)' % [
    'single-fight' if single_fight else 'run', seed_value, speed, timeout_seconds, wall_timeout_seconds, strategy,
  ])
  var result: Dictionary = run_once() if single_fight else run_full()
  _report(result)
  Game.reset()   # tear the run down (frees the player + board) before we quit
  get_tree().quit(result['exit_code'])


# --- the run (testable core; no tree, no quit, no I/O) ----------------------

## Build and drive ONE fight to a verdict (the Phase-2 path; `--single-fight`).
## Pure of the scene tree and process exit so GUT can call it directly.
func run_once() -> Dictionary:
  logger = AutoTestLogger.new()
  driver = AutoTestDriver.new(strategy, seed_value)

  var fight: Dictionary = _build_fight()
  var cm: CombatManager = fight['cm']
  var player: Actor = fight['player']
  var enemies: Array = fight['enemies']
  var names: Dictionary = fight['names']

  cm.start()
  cm.timekeeper.set_base_scale(speed)   # plumbed; inert for the direct sim_step loop
  logger.log_event('fight_started', {
    'seed': seed_value,
    'player_hp': player.max_hp,
    'enemy_count': enemies.size(),
  })

  var wall_start: int = Time.get_ticks_msec()
  var fight_result: Dictionary = _drive_fight(
    cm, player, wall_start, int(wall_timeout_seconds * 1000.0), seconds_to_steps(timeout_seconds))

  var resolved: bool = cm.is_resolved()
  var outcome: String = fight_result['outcome']
  if outcome == '':
    outcome = 'WIN' if cm.player_won() else 'LOSS'

  var result: Dictionary = {
    'outcome': outcome,
    'resolved': resolved,
    'won': resolved and cm.player_won(),
    'steps': fight_result['steps'],
    'sim_seconds': cm.timekeeper.sim_time,
    'wall_ms': Time.get_ticks_msec() - wall_start,
    'player_hp': player.hp,
    'player_max_hp': player.max_hp,
    'enemies': _enemy_states(enemies, names),
    'seed': seed_value,
  }
  logger.log_event('fight_ended', { 'outcome': outcome, 'steps': fight_result['steps'] })
  result['summary'] = logger.summarize(result)
  result['exit_code'] = 0 if resolved else 1

  cm.teardown()
  cm.free()
  return result


## Drive a full headless run (Game → Run → Encounter → Combat): start a seeded run,
## resolve each beat (step fights with per-step damage observation, take draft
## picks via the Driver, advance), and report the verdict. `--seed` is LIVE here
## (it seeds the run RNG). Exit 0 if the run ended cleanly (won OR died) or hit the
## `--encounters` cap; 1 only on a failure (a fight stuck / timed out / wall).
func run_full() -> Dictionary:
  Save.disabled = nosave   # honour the forced nosave: never clobber the real run slot
  logger = AutoTestLogger.new()
  driver = AutoTestDriver.new(strategy, seed_value)
  Game.start_run(seed_value)
  var run: RunManager = Game.run
  logger.log_event('run_started', { 'seed': seed_value })

  var wall_start: int = Time.get_ticks_msec()
  var wall_timeout_ms: int = int(wall_timeout_seconds * 1000.0)
  var timeout_steps: int = seconds_to_steps(timeout_seconds)   # per-fight game-time cap
  var cap: int = encounters if encounters > 0 else 1000

  var outcome: String = ''
  var total_steps: int = 0
  var beats_cleared: int = 0
  while not run.is_ended():
    if beats_cleared >= cap:
      outcome = 'CAP'
      break
    if Time.get_ticks_msec() - wall_start >= wall_timeout_ms:
      outcome = 'WALL_TIMEOUT'
      break
    # CHOICE beat: pick a path first (the Driver stands in for the player) — that creates
    # the live encounter. A FIXED beat (boss / relic / rest) already has one.
    if run.has_pending_choice():
      var path: int = driver.choose_path(run.pending_choice())
      logger.log_event('choice', { 'beat': run.position, 'options': run.pending_choice().size(), 'picked': path })
      run.pick_path(path)
    var enc: Encounter = run.current_encounter()
    var hp_before: float = run.player.hp
    var beat_name: String = _beat_name(enc)
    var is_fight: bool = enc.is_fight()
    logger.log_event('encounter_started', {
      'beat': run.position, 'frame': enc.def.name_key, 'fight': is_fight,
    })
    run.begin_current()
    # EVENT beat: the Driver makes the binary choice (the tier-2 pick), which applies the
    # outcome + resolves it. A FIXED/CHOICE fight has a CombatManager; a rest resolved on begin.
    if enc.is_event():
      var event_pick: int = driver.choose_event_option(enc.event_options())
      logger.log_event('event', { 'beat': run.position, 'options': enc.event_options().size(), 'picked': event_pick })
      run.pick_event_option(event_pick)   # via the RunManager so an ADD_ALLY option recruits a run-scoped ally
    var cm: CombatManager = run.combat_manager()
    var fight_steps: int = 0
    var fail: String = ''
    if cm != null:
      if run.potions.size() > 0 and driver.should_throw_potion():
        logger.log_event('potion_thrown', { 'beat': run.position, 'potion': run.potions[0].def.name_key })
        run.throw_potion(0)
      var fight_result: Dictionary = _drive_fight(cm, run.player, wall_start, wall_timeout_ms, timeout_steps)
      fight_steps = fight_result['steps']
      total_steps += fight_steps
      fail = fight_result['outcome']
    var beat_outcome: String = fail
    if beat_outcome == '':
      beat_outcome = ('WON' if cm.player_won() else 'LOST') if cm != null else ('event' if enc.is_event() else 'rest')
    logger.record_encounter({
      'beat': run.position, 'type': _beat_type(enc), 'name': beat_name,
      'duration': fight_steps * Balance.STEP, 'hp_before': hp_before, 'hp_after': run.player.hp,
      'outcome': beat_outcome,
    })
    if fail != '':
      outcome = fail
      break
    if run.is_ended():
      if run.outcome() == RunManager.Outcome.WON:
        beats_cleared += 1   # the finale counts as cleared; a death clears nothing more
      break
    if run.has_pending_draft():
      var offer: Array = run.pending_draft()
      var pick: int = driver.choose_draft(offer, run.player.board)
      logger.log_event('draft', { 'beat': run.position, 'picked': offer[pick].name_key, 'strategy': strategy })
      run.apply_draft_pick(pick)
    beats_cleared += 1
    run.advance()

  var ended: bool = run.is_ended()
  if outcome == '':
    outcome = 'WON' if run.outcome() == RunManager.Outcome.WON else 'DIED'
  var failed: bool = outcome == 'STUCK' or outcome == 'TIMEOUT' or outcome == 'WALL_TIMEOUT'

  var result: Dictionary = {
    'outcome': outcome,
    'resolved': ended,
    'won': ended and run.outcome() == RunManager.Outcome.WON,
    'steps': total_steps,
    'sim_seconds': total_steps * Balance.STEP,
    'wall_ms': Time.get_ticks_msec() - wall_start,
    'player_hp': run.player.hp,
    'player_max_hp': run.player.max_hp,
    'beats_cleared': beats_cleared,
    'board_size': run.player.board.size(),
    'enemies': [],
    'player_items': _player_item_names(run.player),
    'strategy': strategy,
    'seed': seed_value,
  }
  logger.log_event('run_ended', { 'outcome': outcome, 'beats': beats_cleared, 'steps': total_steps })
  result['summary'] = logger.summarize(result)
  result['exit_code'] = 1 if failed else 0
  return result


## Step a single fight's CombatManager to a verdict — a per-fight game-time cap, a
## per-fight stuck guard, and the shared wall-clock watchdog. Returns { steps, outcome };
## outcome is '' when it resolved normally, else 'STUCK' / 'TIMEOUT' / 'WALL_TIMEOUT'.
## Shared by run_once + run_full.
##
## The damage / fire / block / healing tallies come from the CombatManager's CombatLog —
## the SINGLE SOURCE OF TRUTH (docs/systems/combat_log.md). We attach a fresh log
## before the loop (the manager direct-writes it at each mutation site) and ingest its
## PLAYER side at fight end; there is no per-step HP-diff reconstruction anymore. The stuck
## guard still reads live-roster HP (its job is detecting a flat fight, not attribution).
func _drive_fight(
    cm: CombatManager, _fight_player: Actor, wall_start: int, wall_timeout_ms: int, timeout_steps: int) -> Dictionary:
  var stuck := AutoTestStuckDetector.new(seconds_to_steps(stuck_threshold_seconds))
  stuck.note(_total_hp(_live_actors(cm)))   # baseline
  cm.combat_log = CombatLog.new()   # the manager logs every mutation here — our source of truth
  var steps: int = 0
  var outcome: String = ''
  while not cm.is_resolved():
    if Time.get_ticks_msec() - wall_start >= wall_timeout_ms:
      outcome = 'WALL_TIMEOUT'
      break
    if steps >= timeout_steps:
      outcome = 'TIMEOUT'
      break
    cm.sim_step()
    steps += 1
    if stuck.note(_total_hp(_live_actors(cm))):
      outcome = 'STUCK'
      logger.log_event('stuck', { 'flat_steps': stuck.flat_steps() })
      break
  logger.ingest_combat_log(cm.combat_log)   # fold this fight's player-side tallies in
  return { 'steps': steps, 'outcome': outcome }


## Every body currently in the fight — the whole player side (run actor + allies +
## summon tokens) plus the enemy side. Fresh each call: rosters mutate mid-fight.
func _live_actors(cm: CombatManager) -> Array:
  return cm.player_side() + cm.enemies


# --- fight construction -----------------------------------------------------

## A default player board (mirrors the sandbox) vs the authored grunt. Enemy names
## are kept beside the actors for the log/report (the Actor itself is name-blind).
func _build_fight() -> Dictionary:
  var player := Actor.new(Balance.PLAYER_START_HP)
  for id in [ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER]:
    player.board.append(Item.new(ItemCatalog.get_def(id), player))

  var grunt: EnemyDef = EnemyCatalog.get_def(EnemyCatalog.GRUNT)
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


# --- per-beat labels + roster reads (the source of truth is the CombatLog) ---

## A label for the per-encounter table: the (first) enemy's name for a fight, else the
## location frame.
func _beat_name(enc: Encounter) -> String:
  if enc.is_fight() and not enc.def.enemy_ids.is_empty():
    return EnemyCatalog.get_def(enc.def.enemy_ids[0]).name_key
  return enc.def.name_key


func _beat_type(enc: Encounter) -> String:
  if enc.is_fight():
    return 'Fight'
  if enc.is_event():
    return 'Event'
  return 'Rest'


## The final player board's item names — the contribution table's row set.
func _player_item_names(player: Actor) -> Array:
  var names: Array = []
  for it in player.board:
    names.append(it.def.name_key)
  return names


func _total_hp(actors: Array) -> float:
  var total: float = 0.0
  for fight_actor in actors:
    total += fight_actor.hp
  return total


func _enemy_states(enemies: Array, names: Dictionary) -> Array:
  var out: Array = []
  for enemy in enemies:
    out.append({ 'name': names.get(enemy, 'Enemy'), 'hp': enemy.hp, 'max_hp': enemy.max_hp })
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
      if not AutoTestDriver.STRATEGIES.has(strategy):
        push_warning('[AutoTest] unknown --strategy "%s" (valid: %s) — it will behave as first-viable' % [
          strategy, ', '.join(AutoTestDriver.STRATEGIES),
        ])
      i += 1
    elif arg == '--log':
      log_path = _value(args, i)
      i += 1
    elif arg == '--report':
      report_path = _value(args, i)
      i += 1
    elif arg == '--encounters':
      encounters = int(_value(args, i))
      i += 1
    elif arg == '--single-fight':
      single_fight = true
    i += 1


func _value(args: Array, i: int) -> String:
  return args[i + 1] if i + 1 < args.size() else ''
