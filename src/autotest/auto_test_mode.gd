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

# Per-player-item cooldown progress across the run, for fire-count detection (a fire
# resets the cooldown, dropping progress). Player items only — they persist the run.
var _item_progress: Dictionary = {}


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
  seed(seed_value)   # plumbed; a single Phase-1 fight draws no RNG
  logger = AutoTestLogger.new()
  driver = AutoTestDriver.new(strategy, seed_value)

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

  var wall_start: int = Time.get_ticks_msec()
  var fr: Dictionary = _drive_fight(
    cm, actors, wall_start, int(wall_timeout_seconds * 1000.0), seconds_to_steps(timeout_seconds))

  var resolved: bool = cm.is_resolved()
  var outcome: String = fr['outcome']
  if outcome == '':
    outcome = 'WIN' if cm.player_won() else 'LOSS'

  var result: Dictionary = {
    'outcome': outcome,
    'resolved': resolved,
    'won': resolved and cm.player_won(),
    'steps': fr['steps'],
    'sim_seconds': cm.timekeeper.sim_time,
    'wall_ms': Time.get_ticks_msec() - wall_start,
    'player_hp': player.hp,
    'player_max_hp': player.max_hp,
    'enemies': _enemy_states(enemies, names),
  }
  logger.log_event('fight_ended', { 'outcome': outcome, 'steps': fr['steps'] })
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
  _item_progress.clear()
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
    var cm: CombatManager = run.combat_manager()
    var fight_steps: int = 0
    var fail: String = ''
    if cm != null:
      if run.potions.size() > 0 and driver.should_throw_potion():
        logger.log_event('potion_thrown', { 'beat': run.position, 'potion': run.potions[0].def.name_key })
        run.throw_potion(0)
      var fr: Dictionary = _drive_fight(
        cm, [run.player] + enc.enemies, wall_start, wall_timeout_ms, timeout_steps)
      fight_steps = fr['steps']
      total_steps += fight_steps
      fail = fr['outcome']
    var beat_outcome: String = fail
    if beat_outcome == '':
      beat_outcome = ('WON' if cm.player_won() else 'LOST') if cm != null else 'rest'
    logger.record_encounter({
      'beat': run.position, 'type': 'Fight' if is_fight else 'Rest', 'name': beat_name,
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
  }
  logger.log_event('run_ended', { 'outcome': outcome, 'beats': beats_cleared, 'steps': total_steps })
  result['summary'] = logger.summarize(result)
  result['exit_code'] = 1 if failed else 0
  return result


## Step a single fight's CombatManager to a verdict — per-step damage observation,
## a per-fight game-time cap, a per-fight stuck guard, and the shared wall-clock
## watchdog. Returns { steps, outcome }; outcome is '' when it resolved normally,
## else 'STUCK' / 'TIMEOUT' / 'WALL_TIMEOUT'. Shared by run_once + run_full.
func _drive_fight(
    cm: CombatManager, actors: Array, wall_start: int, wall_timeout_ms: int, timeout_steps: int) -> Dictionary:
  var stuck := AutoTestStuckDetector.new(seconds_to_steps(stuck_threshold_seconds))
  stuck.note(_total_hp(actors))   # baseline
  var steps: int = 0
  var outcome: String = ''
  while not cm.is_resolved():
    if Time.get_ticks_msec() - wall_start >= wall_timeout_ms:
      outcome = 'WALL_TIMEOUT'
      break
    if steps >= timeout_steps:
      outcome = 'TIMEOUT'
      break
    var before: Dictionary = _hp_snapshot(actors)
    var dot_before: Dictionary = _dot_snapshot(actors)   # applier sources, pre-tick
    cm.sim_step()
    steps += 1
    _observe_damage(cm, actors, before, dot_before)
    _observe_fires(actors[0])   # player fires (the contribution table is player-only)
    if stuck.note(_total_hp(actors)):
      outcome = 'STUCK'
      break
  return { 'steps': steps, 'outcome': outcome }


## Count a player item's fire when its cooldown resets this step (progress drops). The
## same "did it fire" read the ItemIcon uses for its recoil — handed state, no game
## write. First sight of an item records no fire (last = current).
func _observe_fires(player: Actor) -> void:
  for it in player.board:
    var progress: float = it.cooldown.progress()
    var last: float = _item_progress.get(it, progress)
    if progress < last - 0.2:
      logger.record_item_fire(it.def.name_key)
    _item_progress[it] = progress


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
## unexplained remainder is DoT, credited to the item that applied it via the
## pre-step `dot_before` snapshot (else the generic channel). See AutoTestLogger.
## Known limitation: attribution is net-HP-based, so a heal landing the SAME step
## masks part of the damage (the report under-counts that step). Not corrected by
## adding the heal back — the potion is thrown at full HP, where the heal is wasted
## and the net is already exact; only per-application tracking would fix the edge.
func _observe_damage(cm: CombatManager, actors: Array, before: Dictionary, dot_before: Dictionary) -> void:
  var now: float = cm.timekeeper.sim_time
  var direct_by_target: Dictionary = {}
  for d in cm.deliveries():
    # Skip visual_only DoT-tick Deliveries — that damage is attributed via dot_before.
    if d.visual_only:
      continue
    if d.landed and d.kind == Delivery.Kind.DAMAGE and is_equal_approx(d.impact_time, now):
      if not direct_by_target.has(d.target):
        direct_by_target[d.target] = []
      direct_by_target[d.target].append({ 'family': _family_of(d.source), 'raw': d.value })
  for a in actors:
    var loss: float = before[a] - a.hp
    if loss <= 0.0:
      continue
    var direct: Array = direct_by_target.get(a, [])
    for rec in AutoTestLogger.attribute_damage(loss, direct, dot_before.get(a, [])):
      logger.record_damage(rec['family'], rec['amount'])


func _family_of(source: Variant) -> String:
  if source is Item and source.def != null and source.def.name_key != '':
    return source.def.name_key
  return 'Unknown'


## Snapshot each actor's DoT-applying statuses BEFORE a step, so the post-step
## remainder can be credited to the item that applied the poison — even if its last
## tick removed the status. `label` = the applier item's name (else the status name,
## e.g. 'Poison', for a source-less DoT); `weight` = its potential tick damage
## (count × damage_per_tick), used to split a remainder between multiple appliers.
## Note: two appliers of the SAME type merge into one Status (keeping the first
## source — StatusManager.apply), so the split only separates DIFFERENT DoT types;
## same-type poison from two items is all credited to the first applier.
func _dot_snapshot(actors: Array) -> Dictionary:
  var snap: Dictionary = {}
  for a in actors:
    snap[a] = _dot_sources_of(a)
  return snap


func _dot_sources_of(actor) -> Array:
  var out: Array = []
  for st in actor.statuses:
    var def: StatusDef = StatusCatalog.get_def(st.type)
    if def.shape == StatusDef.Shape.PERIODIC and def.damage_per_tick > 0.0:
      out.append({ 'label': _dot_label(st, def), 'weight': maxf(st.count, 0.0) * def.damage_per_tick })
  return out


func _dot_label(st: Status, def: StatusDef) -> String:
  if st.source is Item and st.source.def != null and st.source.def.name_key != '':
    return st.source.def.name_key
  return def.name_key   # source-less DoT keeps the status-name channel (e.g. 'Poison')


## A label for the per-encounter table: the (first) enemy's name for a fight, else the
## location frame.
func _beat_name(enc: Encounter) -> String:
  if enc.is_fight() and not enc.def.enemy_ids.is_empty():
    return EnemyCatalog.get_def(enc.def.enemy_ids[0]).name_key
  return enc.def.name_key


## The final player board's item names — the contribution table's row set.
func _player_item_names(player: Actor) -> Array:
  var names: Array = []
  for it in player.board:
    names.append(it.def.name_key)
  return names


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
    elif arg == '--encounters':
      encounters = int(_value(args, i))
      i += 1
    elif arg == '--single-fight':
      single_fight = true
    i += 1


func _value(args: Array, i: int) -> String:
  return args[i + 1] if i + 1 < args.size() else ''
