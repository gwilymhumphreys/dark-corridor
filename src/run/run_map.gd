class_name RunMap
## The act/beat structure of a descent (docs/systems/run_manager.md) — a single linear track of
## ACTS acts x BEATS_PER_ACT beats. PLACEHOLDER layout + numbers: the owner tunes act
## count, beat count, the per-band placement, and the candidate pools. The design target
## is 3 acts of ~15 beats; the content is intentionally a tiny pool drawn repeatedly, not
## 45 unique encounters (that's the owner's content).
##
## Beats are addressed by a single global `position` (0 .. total-1); the act and the
## beat-within-act are derived. Each beat is either FIXED (the boss at an act's end, the
## guaranteed midpoint relic) or a ROLL: the RunManager rolls COMBAT vs EVENT (an anti-repeat
## weighted roll) and draws a def from the matching pool. There is no player-facing choice —
## the beat's content is auto-selected (RunManager._roll_beat). An empty event pool forces
## combat (the easy opener).
##
## Per-act bands (0-based beat index; the boundaries are the consts below — beat_spec is
## the authority, this is the shape):
##   the easy opener (0 .. EASY_BEATS_END)      easy combat (draft), no events
##   the mid band (up to ELITE_FROM_BEAT)       combat or event
##   from ELITE_FROM_BEAT on                    combat or event; a rolled combat may be an elite
##   RELIC_BEAT                                 FIXED — the guaranteed midpoint relic
##   BOSS_BEAT (the act's last)                 FIXED — the act-end boss (the final act's ends the run)

enum BeatKind { FIXED, ROLL }

const ACTS: int = 3
const BEATS_PER_ACT: int = 15
const TOTAL_BEATS: int = ACTS * BEATS_PER_ACT

# Fixed placements within each act (0-based beat index). Boss is always the last beat.
const RELIC_BEAT: int = 7    # the guaranteed midpoint relic
const BOSS_BEAT: int = BEATS_PER_ACT - 1

# The easy opener: beats 0 .. EASY_BEATS_END are forced (easy) combat with a draft — no events.
const EASY_BEATS_END: int = 2
# From this beat on, a rolled combat may be an elite (the deeper combat pool includes one).
const ELITE_FROM_BEAT: int = 6

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


## The spec for the beat at `position`: a FIXED beat names its encounter `id` (boss / midpoint
## relic); every other beat is a ROLL carrying the `combat_pool` + `event_pool` the RunManager
## rolls between (an empty event pool forces combat — the easy opener).
static func beat_spec(position: int) -> Dictionary:
  var beat: int = beat_in_act(position)
  var act: int = act_of(position)
  if beat == BOSS_BEAT:
    return { 'kind': BeatKind.FIXED, 'id': boss_for(act) }
  if beat == RELIC_BEAT:
    return { 'kind': BeatKind.FIXED, 'id': 'fight_relic' }
  return {
    'kind': BeatKind.ROLL,
    'combat_pool': combat_pool(beat),
    'event_pool': event_pool(beat),
  }


## The act's boss encounter (placeholder: one boss def reused per act — the FINAL-act boss
## is the run's ending, decided by position, not a distinct def).
static func boss_for(_act: int) -> String:
  return 'fight_boss'


## The combat defs a rolled beat draws from when it rolls COMBAT. The easy opener is a single
## easy fight; from ELITE_FROM_BEAT on the pool includes the elite (a richer relic+draft fight);
## the middle band is regular fights. PLACEHOLDER ids — the owner scales the pools per act/depth.
static func combat_pool(beat: int) -> Array:
  if beat <= EASY_BEATS_END:
    return ['fight_grunt']
  if beat >= ELITE_FROM_BEAT:
    return ['fight_grunt', 'fight_tough', 'fight_elite']
  return ['fight_grunt', 'fight_tough']


## The event defs a rolled beat draws from when it rolls EVENT. Empty for the easy opener
## (0 .. EASY_BEATS_END) so those beats are always combat. PLACEHOLDER ids — the owner adds events.
static func event_pool(beat: int) -> Array:
  if beat <= EASY_BEATS_END:
    return []
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
