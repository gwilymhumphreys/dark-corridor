class_name RunMap
## The act/beat structure of a descent (run_manager_prd) — a single linear track of
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
## Per-act bands (0-based beat index):
##   0 .. EASY_BEATS_END        easy combat (draft), no events
##   (EASY_BEATS_END+1) .. 5    combat or event
##   ELITE_FROM_BEAT, 8 .. 13   combat or event; a rolled combat may be an elite
##   RELIC_BEAT (7)             FIXED — the guaranteed midpoint relic
##   BOSS_BEAT (14)             FIXED — the act-end boss (the final act's boss ends the run)

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
    return { 'kind': BeatKind.FIXED, 'id': EncounterCatalog.FIGHT_RELIC }
  return {
    'kind': BeatKind.ROLL,
    'combat_pool': combat_pool(beat),
    'event_pool': event_pool(beat),
  }


## The act's boss encounter (placeholder: one boss def reused per act — the FINAL-act boss
## is the run's ending, decided by position, not a distinct def).
static func boss_for(_act: int) -> String:
  return EncounterCatalog.FIGHT_BOSS


## The combat defs a rolled beat draws from when it rolls COMBAT. The easy opener is a single
## easy fight; from ELITE_FROM_BEAT on the pool includes the elite (a richer relic+draft fight);
## the middle band is regular fights. PLACEHOLDER ids — the owner scales the pools per act/depth.
static func combat_pool(beat: int) -> Array:
  if beat <= EASY_BEATS_END:
    return [EncounterCatalog.FIGHT_GRUNT]
  if beat >= ELITE_FROM_BEAT:
    return [EncounterCatalog.FIGHT_GRUNT, EncounterCatalog.FIGHT_TOUGH, EncounterCatalog.FIGHT_ELITE]
  return [EncounterCatalog.FIGHT_GRUNT, EncounterCatalog.FIGHT_TOUGH]


## The event defs a rolled beat draws from when it rolls EVENT. Empty for the easy opener
## (0 .. EASY_BEATS_END) so those beats are always combat. PLACEHOLDER ids — the owner adds events.
static func event_pool(beat: int) -> Array:
  if beat <= EASY_BEATS_END:
    return []
  return [EncounterCatalog.EVENT_SHRINE, EncounterCatalog.EVENT_WANDERER]
