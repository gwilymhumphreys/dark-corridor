class_name RunMap
## The act/beat structure of a descent (docs/systems/run_manager.md) — a single linear track of
## ACTS acts x BEATS_PER_ACT beats. PLACEHOLDER numbers and pools: the owner tunes them.
##
## Beats are addressed by a single global `position` (0 .. total-1); the act and the
## beat-within-act are derived. Each act is the same row of SQUARES (the fights and the relic
## encounter the map shows) with EVENTS_PER_ACT events placed between them. Where the events fall
## is drawn per act from the run seed (act_layout), so a resumed run gets the same layout without
## saving it. An event may only come straight before one of EVENT_GAPS: never first, never straight
## before an elite fight, the relic encounter or the boss, and one per gap, so never two in a row.
##
## A beat's spec (beat_spec) is FIXED — it names its encounter (an elite fight, the relic
## encounter, the boss) — or DRAWN: the RunManager draws a def from its pool on the run RNG (a
## regular fight from the combat pool, an event from the event pool).

enum BeatKind { FIXED, DRAWN }
## What a square on the map is.
enum Square { FIGHT, ELITE, RELIC, BOSS }

const ACTS: int = 3
const BEATS_PER_ACT: int = 15
const TOTAL_BEATS: int = ACTS * BEATS_PER_ACT

## The squares of every act, in order. The boss is always last.
const SQUARES: Array[Square] = [
  Square.FIGHT, Square.FIGHT, Square.FIGHT, Square.ELITE, Square.FIGHT, Square.RELIC,
  Square.FIGHT, Square.ELITE, Square.FIGHT, Square.FIGHT, Square.BOSS,
]
## Events per act. SQUARES plus these make BEATS_PER_ACT (a test checks it).
const EVENTS_PER_ACT: int = 4
## The squares (0-based index into SQUARES) an event may come straight before.
const EVENT_GAPS: Array[int] = [1, 2, 4, 6, 8, 9]
const BOSS_BEAT: int = BEATS_PER_ACT - 1   # no event comes after the boss, so it is the act's last beat
## The first fights of each act (squares 0 .. EASY_SQUARES_END) draw from the easy combat pool.
const EASY_SQUARES_END: int = 2
const ELITE_ENCOUNTER_ID: String = 'fight_elite'
const RELIC_ENCOUNTER_ID: String = 'relic_cache'
# Spreads the run seed into a distinct layout stream per act (a prime stride).
const LAYOUT_SEED_STRIDE: int = 7919

# The most enemies a generated fight may hold (docs/systems/encounter.md — 1 to 4, most 1 to 2).
const MAX_ENEMIES_PER_FIGHT: int = 4


static func act_of(position: int) -> int:
  @warning_ignore('integer_division')
  return position / BEATS_PER_ACT


static func beat_in_act(position: int) -> int:
  return position % BEATS_PER_ACT


static func is_final_beat(position: int) -> bool:
  return position >= TOTAL_BEATS - 1


## True when advancing FROM `position` crosses into a new act (→ the between-act full heal).
static func crosses_act(position: int) -> bool:
  return act_of(position) != act_of(position + 1)


## The act's beats in order, BEATS_PER_ACT long: each is the index into SQUARES of the square it
## is, or -1 for an event. The events go in EVENTS_PER_ACT of the EVENT_GAPS, drawn on a random
## number generator seeded from `run_seed` and the act, so the same run always gets the same layout.
static func act_layout(act: int, run_seed: int) -> Array[int]:
  var layout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
  layout_rng.seed = run_seed + (act + 1) * LAYOUT_SEED_STRIDE
  var gaps: Array[int] = EVENT_GAPS.duplicate()
  var event_before: Array[int] = []
  for _n in EVENTS_PER_ACT:
    event_before.append(gaps.pop_at(layout_rng.randi_range(0, gaps.size() - 1)))
  var beats: Array[int] = []
  for square: int in SQUARES.size():
    if square in event_before:
      beats.append(-1)
    beats.append(square)
  return beats


## The index into SQUARES of the beat at `position`, or -1 when it is an event.
static func square_at(position: int, run_seed: int) -> int:
  return act_layout(act_of(position), run_seed)[beat_in_act(position)]


## The spec for the beat at `position`: FIXED names its encounter `id` (an elite fight, the relic
## encounter, the boss); DRAWN carries the `pool` the RunManager draws from. Both carry the
## `square` (-1 for an event).
static func beat_spec(position: int, run_seed: int) -> Dictionary:
  var square: int = square_at(position, run_seed)
  if square == -1:
    return { 'kind': BeatKind.DRAWN, 'pool': event_pool(), 'square': square }
  match SQUARES[square]:
    Square.ELITE:
      return { 'kind': BeatKind.FIXED, 'id': ELITE_ENCOUNTER_ID, 'square': square }
    Square.RELIC:
      return { 'kind': BeatKind.FIXED, 'id': RELIC_ENCOUNTER_ID, 'square': square }
    Square.BOSS:
      return { 'kind': BeatKind.FIXED, 'id': boss_for(act_of(position)), 'square': square }
  return { 'kind': BeatKind.DRAWN, 'pool': combat_pool(square), 'square': square }


## The act's boss encounter (placeholder: one boss def reused per act — the FINAL-act boss
## is the run's ending, decided by position, not a distinct def).
static func boss_for(_act: int) -> String:
  return 'fight_boss'


## The combat defs a regular fight square draws from: the easy fight for the act's first squares,
## then regular fights. PLACEHOLDER ids — the owner scales the pools per act/depth.
static func combat_pool(square: int) -> Array:
  if square <= EASY_SQUARES_END:
    return ['fight_grunt']
  return ['fight_grunt', 'fight_tough']


## The event defs an event beat draws from. PLACEHOLDER ids — the owner adds events.
static func event_pool() -> Array:
  return ['event_shrine', 'event_wanderer']


## The points a fight at `position` should be worth (docs/plans/encounter_points_budget.md). Fixed:
## calculated from an ESTIMATE of the player's board at that beat rather than from the actual board,
## so drafting well stays rewarded. The estimate is a starting board plus one drafted item per
## regular fight won, converted to damage per second and multiplied by the target fight length. The
## synergy factor is the single knob covering everything the estimate cannot see.
static func target_points(position: int) -> float:
  var items: float = Balance.POINTS_STARTING_ITEMS + Balance.POINTS_DRAFTS_PER_BEAT * float(position)
  var damage: float = items * ItemPoints.rate(Balance.POINTS_AVERAGE_ITEM_COOLDOWN) * Balance.POINTS_DAMAGE_FRACTION
  var through_run: float = float(position) / float(maxi(TOTAL_BEATS - 1, 1))
  var synergy: float = 1.0 + Balance.POINTS_SYNERGY_GROWTH * through_run
  return damage * Balance.POINTS_FIGHT_SECONDS * synergy


## The EnemyCatalog ids a generated fight in this act draws from (EnemyPools.REGULAR). While an
## act's list is empty, a fight keeps its EncounterDef's authored enemy_ids, so the generator is
## dormant rather than drawing the wrong-sized enemies.
static func enemy_pool(act: int) -> Array[String]:
  return EnemyPools.regular(act)


## Draw enemies from `pool` until their points reach `target`, up to MAX_ENEMIES_PER_FIGHT
## (docs/plans/encounter_points_budget.md). The draw is random and ignores composition — a mix is
## picked on points alone, and positioning is handled later. It stops once within
## Balance.POINTS_TARGET_TOLERANCE of the target, so it overshoots rather than undershoots. An empty
## pool draws nothing, which leaves the fight's authored composition in place.
static func draw_enemies(pool: Array[String], target: float, rng: RandomNumberGenerator) -> Array[String]:
  var ids: Array[String] = []
  if pool.is_empty():
    return ids
  var floor_points: float = target * (1.0 - Balance.POINTS_TARGET_TOLERANCE)
  var total: float = 0.0
  while ids.size() < MAX_ENEMIES_PER_FIGHT and total < floor_points:
    var picked: String = pool[rng.randi_range(0, pool.size() - 1)]
    ids.append(picked)
    total += EnemyCatalog.get_def(picked).points()
  return ids
