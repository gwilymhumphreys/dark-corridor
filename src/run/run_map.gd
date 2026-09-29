class_name RunMap
## The act/beat structure of a descent (docs/systems/run_manager.md) — a single linear track of
## ACTS acts x BEATS_PER_ACT beats. PLACEHOLDER numbers and pools: the owner tunes them.
##
## Beats are addressed by a single global `position` (0 .. total-1); the act and the
## beat-within-act are derived. Each act is the row of SQUARES (the fights the map shows), and every
## square has a choice beat straight before it, where the player picks one of three encounters or
## walks past them (docs/plans/encounter_choice.md). So a choice beat is at an even beat in the act
## and a square at the odd beat after it.
##
## A beat's spec (beat_spec) is CHOICE (the RunManager draws the three encounters), FIXED — it names
## its encounter (an elite fight, the boss) — or DRAWN: the RunManager draws a regular fight's def
## from the combat pool on the run RNG.

enum BeatKind { FIXED, DRAWN, CHOICE }
## What a square on the map is.
enum Square { FIGHT, ELITE, BOSS }

const ACTS: int = 1
## The squares of every act, in order. The boss is always last.
const SQUARES: Array[Square] = [
  Square.FIGHT, Square.FIGHT, Square.FIGHT, Square.ELITE, Square.FIGHT,
  Square.FIGHT, Square.ELITE, Square.FIGHT, Square.FIGHT, Square.BOSS,
]
## A choice beat before every square (a test checks it is twice SQUARES).
const BEATS_PER_ACT: int = 20
const TOTAL_BEATS: int = ACTS * BEATS_PER_ACT
## Every square is a fight, so this is the number of fights in the run (a test checks it).
const TOTAL_FIGHTS: int = 10
const BOSS_BEAT: int = BEATS_PER_ACT - 1   # the boss square is the act's last beat
## The first fights of each act (squares 0 .. EASY_SQUARES_END) draw from the easy combat pool.
const EASY_SQUARES_END: int = 2
const ELITE_ENCOUNTER_ID: String = 'fight_elite'

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


## True when the beat at `position` is the choice of encounters before a square.
static func is_choice_beat(position: int) -> bool:
  return beat_in_act(position) % 2 == 0


## The index into SQUARES of the beat at `position`, or -1 when it is a choice beat.
static func square_at(position: int) -> int:
  if is_choice_beat(position):
    return -1
  @warning_ignore('integer_division')
  return beat_in_act(position) / 2


## The number (0-based, counted through the whole run) of the fight at `position`, or of the fight
## straight after it for a choice beat.
static func fight_number(position: int) -> int:
  @warning_ignore('integer_division')
  return act_of(position) * SQUARES.size() + beat_in_act(position) / 2


## The spec for the beat at `position`: CHOICE for a choice beat; FIXED names its encounter `id`
## (an elite fight, the boss); DRAWN carries the `pool` of regular fights the RunManager draws from.
## Every spec carries the `square` (-1 for a choice beat).
static func beat_spec(position: int) -> Dictionary:
  var square: int = square_at(position)
  if square == -1:
    return { 'kind': BeatKind.CHOICE, 'square': square }
  match SQUARES[square]:
    Square.ELITE:
      return { 'kind': BeatKind.FIXED, 'id': ELITE_ENCOUNTER_ID, 'square': square }
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


## The points a fight at `position` should be worth (docs/plans/encounter_points_budget.md). Fixed:
## calculated from an ESTIMATE of the player's board at that fight rather than from the actual
## board, so drafting well stays rewarded. The estimate is a starting board plus the drafts expected
## per fight won, converted to damage per second and multiplied by the target fight length. The
## synergy factor is the single knob covering everything the estimate cannot see. Counted in fights,
## not beats, because half the beats are choices of encounters.
static func target_points(position: int) -> float:
  var fight: float = float(fight_number(position))
  var items: float = Balance.POINTS_STARTING_ITEMS + Balance.POINTS_DRAFTS_PER_FIGHT * fight
  var damage: float = items * ItemPoints.rate(Balance.POINTS_AVERAGE_ITEM_COOLDOWN) * Balance.POINTS_DAMAGE_FRACTION
  var through_run: float = fight / float(maxi(TOTAL_FIGHTS - 1, 1))
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
