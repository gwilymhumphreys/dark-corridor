class_name Balance
## Placeholder tuning + sim constants for the combat spine. Hand-authored and
## edited freely — the `tune` workflow will eventually own the balance section.
## These are throwaway STARTING values, not design decisions (docs describe
## systems, not numbers — CLAUDE.md). Grouped: Clock · Timescale · Actor ·
## Items · Statuses · Triggers.


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
const ENEMY_PLACEHOLDER_HP: float = 40.0


# ── Items (placeholder defs — cooldowns in SECONDS) ──────────────────────────
# A Ticker threshold in steps = ceil(cooldown_seconds / STEP).
const WEAPON_COOLDOWN: float = 1.2
const WEAPON_DAMAGE: float = 6.0
const WEAPON_TRAVEL: float = 0.3            # projectile flight time (combat_prd)

const ARMOR_COOLDOWN: float = 2.0
const ARMOR_BLOCK: float = 8.0              # self-target, travel 0

const POISON_APPLIER_COOLDOWN: float = 1.6
const POISON_APPLIER_STACKS: float = 3.0    # stacks applied per fire

# Hex Bolt — the example item-targeting item: a bolt that silences a RANDOM enemy item
# (OPPONENT_ITEM_RANDOM, chosen on the seeded per-fight RNG; #14/#20). Proves the
# random-item-target path end-to-end; not pooled by default (the grunt has one item).
const HEX_BOLT_COOLDOWN: float = 2.5

# Sundering Bolt — the example stat-status applier (#6): applies Vulnerable to the
# leftmost enemy (so the next hits land amplified). Demonstrates the incoming seam end
# to end; catalog-only, not pooled by default.
const SUNDER_COOLDOWN: float = 3.0


# ── Statuses ─────────────────────────────────────────────────────────────────
const POISON_TICK_INTERVAL: float = 0.5     # seconds between poison ticks
const POISON_DAMAGE_PER_TICK: float = 1.0   # per-tick damage (per-stack rule is content)
# Block is a pure pool (persists until consumed, no decay) — no constants beyond
# the ARMOR_BLOCK that feeds it.
const SAMPLE_DEBUFF_DURATION: float = 5.0   # a timed status, to exercise that shape
# Stat-statuses (#6) — % damage modifiers (timed). Placeholder values; the owner tunes
# them (and may author per-stack variants — the engine supports it).
const STATUS_WEAK_DAMAGE_MULT: float = 0.75       # Weak: holder deals 25% less damage
const STATUS_WEAK_DURATION: float = 5.0
const STATUS_VULNERABLE_DAMAGE_MULT: float = 1.5  # Vulnerable: holder takes 50% more
const STATUS_VULNERABLE_DURATION: float = 5.0


# ── Triggers (charges model — push as a fraction of the bar; combat_prd) ─────
# "on poison applied -> push the block item." ~1.0 fills the bar (an instant
# reaction); smaller values accelerate firing without completing it.
const TRIGGER_PUSH_FULL: float = 1.0
const TRIGGER_PUSH_SMALL: float = 0.25


# ── Content — Relics (run-level modifiers; content_prd) ──────────────────────
# Phase 3's single relic: a combat-start status applier (start each fight with
# this much block on the player).
const RELIC_STONE_WARD_BLOCK: float = 10.0


# ── Content — Enchantments (permanent item modifiers; content_prd, #26) ──────
# Whetstone: scales the host item's payload values (e.g. +50% weapon damage).
const ENCHANT_WHETSTONE_MULT: float = 1.5


# ── Content — Consumables (manually-fired potions; content_prd) ──────────────
# Healing Draught: a thrown self-heal (no Ticker — fired on the throw intent).
const POTION_HEAL: float = 20.0


# ── Run loop (HP economy + map; run_manager_prd) ─────────────────────────────
const REST_HEAL_FRACTION: float = 0.3       # an in-act rest restores this fraction of max HP


# ── Presentation — the framed combat view (ui_layout_prd; phase4_plan) ───────
# The enemy occupant's on-screen scale when arrived (depth 0) inside the corridor
# SubViewport; the approach scales it from depth via CorridorScaled.axis_scale.
const ENEMY_FULL_SCALE: float = 3.0
# The approach (phase4_plan Step 7): the enemy starts this many corridor cells deep
# (a speck at the vanishing point) and walks to depth 0 (full size) over this many
# seconds; the boards activate / combat begins on arrival.
const APPROACH_DEPTH_START: float = 5.0
const APPROACH_DURATION: float = 2.5


# ── Delivery visual hold (presentation lifetime; vfx_driver_prd) ─────────────
# Sim-seconds a LANDED Delivery is retained after impact so the VFX wall can
# finish drawing its impact number / flash before the Combat manager drops it.
# This bounds the in-flight Delivery set so it can't grow unbounded over a long
# fight. Keep this >= the longest VFX visual duration (vfx_driver.gd NUM_DURATION).
const DELIVERY_VISUAL_HOLD: float = 0.7
