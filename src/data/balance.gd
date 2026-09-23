class_name Balance
## Placeholder tuning + sim constants for the combat spine. Hand-authored and
## edited freely — the `tune` workflow will eventually own the balance section.
## These are throwaway STARTING values, not design decisions (docs describe
## systems, not numbers — CLAUDE.md). Only values shared by several definitions or
## systems live here; a number one item, enemy, relic, potion, enchant or encounter
## uses is written on that definition under content/ (docs/design/authoring.md).


# ── Clock / fixed timestep (sim config, not balance) ─────────────────────────
# One fixed STEP of game-time per sim-step. = the physics period, so timescale
# x1 runs one sim-step per physics tick (Timekeeper PRD).
const STEP: float = 1.0 / 60.0
# Catch-up ceiling: the most sim-steps one physics frame may run before the
# backlog is dropped (Timekeeper steps_due cap — a hang slows, never spirals).
const MAX_STEPS: int = 8


# ── Timescale dial (one scalar; Timekeeper PRD) ──────────────────────────────
const TIMESCALE_PAUSE: float = 0.0
const TIMESCALE_SLOWMO: float = 0.05        # hover-to-inspect
const TIMESCALE_BASE: float = 1.0           # default battle-speed
const TIMESCALE_FAST_TEST: float = 5.0      # --speed dev / autotest
const BATTLE_SPEEDS: Array[float] = [1.0, 2.0, 3.0]  # player setting x1/x2/x3


# ── Actor ────────────────────────────────────────────────────────────────────
const PLAYER_START_HP: float = 100.0
# The health of an enemy definition that sets none, and of the combat sandbox's enemy.
const ENEMY_PLACEHOLDER_HP: float = 168.0


# ── Items ────────────────────────────────────────────────────────────────────
const TRAVEL_STEPS: int = 36                # sim-steps every delivery flies (docs/systems/combat_model.md)
const POTION_TRAVEL_STEPS: int = 1          # a thrown potion lands on the next step (decision #48)


# ── Statuses ─────────────────────────────────────────────────────────────────
const POISON_TICK_INTERVAL: float = 0.5     # seconds between poison ticks
const POISON_DAMAGE_PER_TICK: float = 1.0   # per-tick damage (per-stack rule is content)
const BURN_TICK_INTERVAL: float = 0.5       # seconds between burn ticks — PLACEHOLDER — owner tunes
const BURN_DAMAGE_PER_TICK: float = 1.0     # per-tick damage (per-stack rule is content) — PLACEHOLDER — owner tunes
const REGEN_TICK_INTERVAL: float = 0.5      # seconds between regen ticks — PLACEHOLDER — owner tunes
const REGEN_HEAL_PER_TICK: float = 1.0      # per-tick healing (per-stack rule is content) — PLACEHOLDER — owner tunes
# Shield is a pure pool (persists until consumed, no decay) — no constants of its own; each
# shield item carries the amount it applies.
const SAMPLE_DEBUFF_DURATION: float = 5.0   # a timed status, to exercise that shape
# Stat-statuses (#6) — % damage modifiers (timed). Placeholder values; the owner tunes
# them (and may author per-stack variants — the engine supports it).
const STATUS_WEAK_DAMAGE_MULT: float = 0.75       # Weak: holder deals 25% less damage
const STATUS_WEAK_DURATION: float = 2.0           # global to all Weak appliers (duration lives on the status, not the item)
const STATUS_VULNERABLE_DAMAGE_MULT: float = 1.5  # Vulnerable: holder takes 50% more
const STATUS_VULNERABLE_DURATION: float = 5.0
# Empowered (docs/design/smith.md → The empower engine) — the Smith's Mighty Blow buff scales a
# WEAPON attack's damage by this each charge spent. 2.0 = "double the next weapon attack" (PLACEHOLDER
# — /tune). One charge per weapon attack (the consume rate is in EmpoweredStatus, not tunable here).
const EMPOWER_MULT: float = 2.0
# Blind (docs/systems/spore_engine.md Cap 2) — a timed evasion status; the holder's attacks whiff for
# this long. 2s = the Spore Druid's blinding spore as designed (spore_druid.md), applied by
# Pocket Shrooms. A default duration an applier passes per-application (TimedStatus stacks/extends).
const STATUS_BLIND_DURATION: float = 2.0
# Shield multipliers (docs/systems/mechanics.md → Shield): how much shield a hit of the mechanic
# uses (1.0 = normal). The poison and burn mechanic classes return theirs; bleed returns its
# once it is converted.
const SHIELD_MULTIPLIER_POISON: float = 2.0   # PLACEHOLDER — owner tunes
const SHIELD_MULTIPLIER_BURN: float = 0.5     # PLACEHOLDER — owner tunes
const SHIELD_MULTIPLIER_BLEED: float = 0.5    # PLACEHOLDER — owner tunes
# Heal cleanse (docs/systems/mechanics.md → Heal): a heal removes floor(value × this) stacks of the
# target's poison, burn and bleed (value = the full heal, including overheal).
const HEAL_CLEANSE_FRACTION: float = 0.1      # PLACEHOLDER — owner tunes
# Crit (docs/systems/mechanics.md → Crit): the multiplier applied to a critting fire's mechanic
# delivery values.
const CRIT_MULTIPLIER: float = 2.0            # PLACEHOLDER — owner tunes


# ── Run loop (HP economy + map; docs/systems/run_manager.md) ─────────────────────────────
# Draft skip → bank gold (docs decision #33). Skipping the 1-of-3 draft banks this fixed amount of
# gold instead of taking an item — a run-state resource (source built, no sink yet). The reward
# panel's gold button shows it. Placeholder — the owner tunes it.
const GOLD_SKIP: int = 2


# ── Presentation — the framed combat view (docs/systems/ui_layout.md; docs/history/phase4_plan.md) ───────
# Enemy images vary in size, so each is sized to this on-screen height (px, inside the corridor
# SubViewport) when arrived at depth 0; perspective makes it smaller further away.
const ENEMY_PAINTED_HEIGHT: float = 640.0
# The approach (docs/history/phase4_plan.md Step 7): the enemy stands still and the player walks
# up to it over this many seconds at a steady walking pace, so the enemy grows to full size as
# the corridor moves past; the boards activate on arrival. Change the two together: the depth
# divided by the duration is the approach's pace, and it has to match Corridor3D.speed or the
# footsteps fall out of step with a free walk (docs/systems/corridors/corridor_3d.md#the-walking-pace).
const APPROACH_DEPTH_START: float = 1.8
const APPROACH_DURATION: float = 6.0
# How much the walk speeds up and slows down over its length. The distance walked is a blend
# between a straight line and a smoothstep: 0 holds one steady speed the whole way, 1 is a full
# smoothstep, which starts and ends at a standstill and runs half again as fast in the middle.
const APPROACH_EASE: float = 0.5
# The enemy's name, health and items fade up over the end of the walk instead of appearing when
# the fight starts. This is how long that fade takes; it finishes as the player arrives.
const ENEMY_REVEAL_DURATION: float = 2.0


# ── Delivery visual hold (presentation lifetime; docs/systems/vfx_driver.md) ─────────────
# Sim-seconds a LANDED Delivery is retained after impact so the VFX wall can
# finish drawing its impact number / flash before the Combat manager drops it.
# This bounds the in-flight Delivery set so it can't grow unbounded over a long
# fight. Keep this >= the longest VFX visual duration (DamageNumberDrawer.duration()).
const DELIVERY_VISUAL_HOLD: float = 1.0


# ── Item points (docs/design/item_heuristics.md) ─────────────────────────────
# The budget curve: an item's points per second of cooldown is POINTS_RATE_AT_BASELINE at
# POINTS_RATE_BASELINE_COOLDOWN and rises in a straight line by POINTS_RATE_PER_SECOND for each
# second of cooldown, with no cap (owner, 2026-09-23). Its budget is that rate times its cooldown.
# The arithmetic is in ItemPoints. PLACEHOLDER — the owner tunes in /tune.
# These are the only copies of the point values: docs name the constants rather than repeat them.
const POINTS_RATE_BASELINE_COOLDOWN: float = 2.0
const POINTS_RATE_AT_BASELINE: float = 5.0
const POINTS_RATE_PER_SECOND: float = 1.25
# Uncommon and rare items get a larger budget than a common item on the same cooldown, so they are
# stronger as well as more involved (owner, 2026-09-23). PLACEHOLDER — the owner tunes in /tune.
const POINTS_UNCOMMON_MULTIPLIER: float = 1.5
const POINTS_RARE_MULTIPLIER: float = 2.0
# What one unit of each mechanic costs in points. One point is one damage from a single-target
# attack. Self-damage is a credit rather than a cost. PLACEHOLDER — the owner tunes in /tune.
const POINTS_PER_DAMAGE: float = 1.0
const POINTS_PER_SELF_DAMAGE: float = 1.5
const POINTS_PER_HEAL: float = 0.75
const POINTS_PER_SHIELD: float = 1.25
const POINTS_PER_POISON_DAMAGE: float = 1.0
const POINTS_PER_BURN_DAMAGE: float = 0.75
const POINTS_PER_BLEED_DAMAGE: float = 0.5
const POINTS_PER_CHARGE_SECOND: float = 6.0
# An effect aimed at every opponent costs this many times the same effect on one target.
const POINTS_ALL_OPPONENTS_MULTIPLIER: float = 1.5
# How many times a trigger is expected to go off per cooldown of its item. A trigger that charges its
# item costs the seconds it charges, times this, at the item's own points per second. The real count
# rises through a run as the board grows (owner, 2026-09-23). PLACEHOLDER — the owner tunes in /tune.
const POINTS_TRIGGERS_PER_COOLDOWN: float = 2.0


# ── Encounter budgets (docs/plans/encounter_points_budget.md) ────────────────
# The target points a fight is worth is calculated from an ESTIMATE of the player's board at that
# beat, not from the actual board, so drafting well stays rewarded. RunMap.target_points does the
# arithmetic. Every one of these is an estimate — PLACEHOLDER, the owner tunes in /tune.
const POINTS_STARTING_ITEMS: float = 3.0        # the intended starting board floor
const POINTS_DRAFTS_PER_BEAT: float = 0.84      # measured: a full autotest run ends on 41 items
const POINTS_AVERAGE_ITEM_COOLDOWN: float = 4.0 # the cooldown taken as an average draft
const POINTS_DAMAGE_FRACTION: float = 0.7       # the share of a board's output that is damage
const POINTS_FIGHT_SECONDS: float = 20.0        # how long a regular fight should last, early or late
# How much harder the curve gets than the raw board estimate, across the whole run. This is the one
# knob covering synergies, relics and enchants — they are deliberately not modelled.
const POINTS_SYNERGY_GROWTH: float = 0.5
const POINTS_ELITE_MULTIPLIER: float = 1.5      # an elite's target, on the same curve
# How far under the target a drawn set may stop. The draw adds enemies until it is within this
# fraction of the target, so it overshoots rather than undershoots.
const POINTS_TARGET_TOLERANCE: float = 0.15
