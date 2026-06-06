class_name RunMap
## The act/beat structure of a descent (run_manager_prd) — a single linear track of
## ACTS acts x BEATS_PER_ACT beats. PLACEHOLDER layout + numbers: the owner tunes act
## count, beat count, the per-beat placement, and the candidate pools. The design target
## is 3 acts of ~15 beats; the content is intentionally a tiny pool drawn repeatedly, not
## 45 unique encounters (that's the owner's content).
##
## Beats are addressed by a single global `position` (0 .. total-1); the act and the
## beat-within-act are derived. Each beat is either FIXED (the boss at an act's end, the
## guaranteed midpoint relic, the per-act rest) or a CHOICE (assemble 2-3 candidates from
## the act pool and let the player pick — RunManager).

enum BeatKind { FIXED, CHOICE }

const ACTS: int = 3
const BEATS_PER_ACT: int = 15
const TOTAL_BEATS: int = ACTS * BEATS_PER_ACT

# Fixed placements within each act (0-based beat index). Boss is always the last beat.
const RELIC_BEAT: int = 7    # the guaranteed midpoint relic
const REST_BEAT: int = 3     # the one guaranteed in-act rest
const BOSS_BEAT: int = BEATS_PER_ACT - 1

# How many candidates a choice beat offers.
const CHOICE_COUNT: int = 3


static func act_of(position: int) -> int:
  return position / BEATS_PER_ACT


static func beat_in_act(position: int) -> int:
  return position % BEATS_PER_ACT


static func is_final_beat(position: int) -> bool:
  return position >= TOTAL_BEATS - 1


## True when advancing FROM `position` crosses into a new act (→ the between-act full heal).
static func crosses_act(position: int) -> bool:
  return act_of(position) != act_of(position + 1)


## The spec for the beat at `position`: a FIXED beat names its encounter `id`; a CHOICE
## beat carries the act `pool` to draw candidates from.
static func beat_spec(position: int) -> Dictionary:
  var beat: int = beat_in_act(position)
  var act: int = act_of(position)
  if beat == BOSS_BEAT:
    return { 'kind': BeatKind.FIXED, 'id': boss_for(act) }
  if beat == RELIC_BEAT:
    return { 'kind': BeatKind.FIXED, 'id': EncounterCatalog.Id.FIGHT_RELIC }
  if beat == REST_BEAT:
    return { 'kind': BeatKind.FIXED, 'id': EncounterCatalog.Id.REST }
  return { 'kind': BeatKind.CHOICE, 'pool': act_pool(act) }


## The act's boss encounter (placeholder: one boss def reused per act — the FINAL-act boss
## is the run's ending, decided by position, not a distinct def).
static func boss_for(_act: int) -> int:
  return EncounterCatalog.Id.FIGHT_BOSS


## The candidate pool a choice beat draws from (placeholder: a small fixed set; the owner
## scales pools per act + adds events). Kept as ids so the RunManager draws + the choice
## UI telegraphs without the map owning instances.
static func act_pool(_act: int) -> Array:
  return [
    EncounterCatalog.Id.FIGHT_GRUNT,
    EncounterCatalog.Id.FIGHT_TOUGH,
    EncounterCatalog.Id.FIGHT_ELITE,
    EncounterCatalog.Id.EVENT_SHRINE,
  ]
