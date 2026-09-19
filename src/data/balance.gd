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
# Placeholder enemy tiers for the multi-act map (#1) — HP only; the owner authors real
# enemies + boss signature mechanics. A brute is a beefier regular; a boss is tankier
# with two items.
const ENEMY_BRUTE_HP: float = 70.0
const ENEMY_BOSS_HP: float = 140.0
# A summon/token actor (docs/systems/spore_engine.md Cap 3) — low HP, disposable. Placeholder; the
# owner authors the real saprolings / boss adds (and uses it as a draftable ally too).
const ENEMY_SPORE_THRALL_HP: float = 15.0


# ── Items (placeholder defs — cooldowns in SECONDS) ──────────────────────────
# A Ticker threshold in steps = ceil(cooldown_seconds / STEP).
const WEAPON_TRAVEL: float = 0.6            # projectile flight time (docs/systems/combat_model.md)

# Claw — the enemy board's only weapon, so every enemy's damage comes from here.
const ENEMY_CLAW_COOLDOWN: float = 1.2
const ENEMY_CLAW_DAMAGE: float = 6.0

# Spite Ward — the example trigger item: a self-shield that also pushes its own cooldown whenever
# poison is applied. Unpooled, kept as the working example of a trigger subscription.
const SPITE_WARD_COOLDOWN: float = 2.0
const SPITE_WARD_SHIELD: float = 8.0         # self-target, travel 0

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

# Pocket Shrooms — the blinding-enabler RARE (spore_druid.md): a single-target attack that
# both deals damage AND applies the blinding spore (a timed evasion status). The first
# multi-effect item + the first authored Spore Druid card. Rare for the ACCESS to blinding,
# not bigger numbers (rarity = complexity; design.md). ~3.3 DPS + a timed control rider.
const POCKET_SHROOMS_COOLDOWN: float = 3.0
const POCKET_SHROOMS_DAMAGE: float = 10.0
const POCKET_SHROOMS_BLIND_STACKS: float = 1.0   # one blinding spore (count; duration = STATUS_BLIND_DURATION)

# Druid Staff — the Spore Druid's first Spores applier + its starting card (spore_druid.md):
# a single-target attack that deals damage AND stacks the Spores counter (Mass fuel) on the
# struck enemy. A COMMON applier — appliers are commons; the Mass payoff lives a tier up.
const DRUID_STAFF_COOLDOWN: float = 3.0
const DRUID_STAFF_DAMAGE: float = 10.0
const DRUID_STAFF_SPORE_STACKS: float = 1.0      # Spores applied per fire (count on the SPORES counter)

# Spore Druid common weapons — the first speed/damage spread (spore_druid.md). The axis is
# NOT neutral here: each attack's cooldown also sets its Spore-accrual RATE, so fast = fast
# fuel. Tuned around the 5 DPS baseline (Rusted Blade); the spore-carriers pay a DPS "tax"
# for the fuel they stack. Starting numbers — authored to be ADJUSTED in tuning.
const SPORE_SPITTER_COOLDOWN: float = 1.0        # fast jab — 1 Spore/sec, the Mass-fuel engine (4 DPS)
const SPORE_SPITTER_DAMAGE: float = 4.0
const SPORE_SPITTER_SPORE_STACKS: float = 1.0
const CAPPED_CUDGEL_COOLDOWN: float = 2.0        # clean tempo weapon — baseline 5 DPS, NO fuel
const CAPPED_CUDGEL_DAMAGE: float = 10.0
const BLOOMHAMMER_COOLDOWN: float = 5.0          # slow burst — 8 DPS + dumps 2 fuel in one heavy hit
const BLOOMHAMMER_DAMAGE: float = 40.0
const BLOOMHAMMER_SPORE_STACKS: float = 2.0

# Wilt Frond (PLACEHOLDER name) — a Weak-applier attack: 4s cooldown → curve DPS 7, minus a
# 2 DPS effect tax for the Weakness rider = 5 DPS of damage = 20 dmg, plus 2s Weak. Per the
# item heuristics (docs/design/item_heuristics.md): effect cost ~2 DPS, Weak duration is the
# status's global 2s. Starting properties — to be adjusted in tuning.
const WILT_FROND_COOLDOWN: float = 4.0
const WILT_FROND_DAMAGE: float = 20.0
const WILT_FROND_WEAK_STACKS: float = 1.0         # presence count (duration = STATUS_WEAK_DURATION)

# Fleshmancer commons (PLACEHOLDER numbers — owner's to tune; docs/design/character_ideas.md →
# Flesh Golem / Meat). Item-economy character: its attacks deal LOW damage AND create a Chunk of
# Flesh on the player's OWN board (the CREATE_ITEM seam, docs/systems/item_creation_and_decay.md).
# PRICING (owner, 2026-06-20): a chunk is a persistent auto-attacker, so chunk-creation is MORE
# valuable than a spore stack — the creators are priced ABOVE the druid's appliers: damage is low
# (the chunk is the payload, not the hit), tilting fast-low / slow-high between the two 1-chunk poles
# so neither dominates, and there is a **3s MINIMUM cooldown for common chunk
# creators** — a chunk lives ~4s (cd 2s x 2 uses), so faster creation stacks chunks up too quickly.
# Differentiation is cadence + chunk COUNT (Bone Maul makes 2). Starting points — tune in /tune.
const FLESH_CHUNK_COOLDOWN: float = 2.0           # the created Chunk of Flesh fires every 2s (owner)
const FLESH_CHUNK_DAMAGE: float = 1.0             # very low power, but does something (owner)
const FLESH_CHUNK_USES: int = 2                   # decays after 2 activations (the starting_uses seed)
const FLESH_CARVING_KNIFE_COOLDOWN: float = 3.0    # fast pole — at the 3s chunk-creator minimum (1 chunk)
const FLESH_CARVING_KNIFE_DAMAGE: float = 3.0      # fast / low — chunk-rate is its edge
const FLESH_CLEAVER_COOLDOWN: float = 4.0         # mid pole (1 chunk)
const FLESH_CLEAVER_DAMAGE: float = 6.0           # slower but punchier — the bigger hit is its edge (vs Carving Knife)
const FLESH_BONE_SAW_COOLDOWN: float = 6.0       # slow pole — makes 2 chunks (two CREATE_ITEM effects)
const FLESH_BONE_SAW_DAMAGE: float = 4.0         # low — its payoff is the 2 chunks, not the hit

# Flesh Explosion (owner) — the first flesh CONSUMER payoff (charge-on-destroy): an AOE nuke that
# charges as your items die. 20s base, but each own ITEM_DESTROYED pushes it ~1s (the churning chunks
# + any consume build it), so the effective cooldown is far lower in a chunk-heavy build. AOE damage
# sits below a single-target nuke for multi-enemy parity. UNCOMMON (trigger-driven). Estimate — tune
# in /tune; the charge accel is the power ceiling to watch.
const FLESH_EXPLOSION_COOLDOWN: float = 20.0
const FLESH_EXPLOSION_DAMAGE: float = 70.0              # AOE — all opponents
const FLESH_EXPLOSION_CHARGE_PER_DESTROY: float = 0.05  # push per own item destroyed = ~1s on the 20s bar

# Flensing Hook (PLACEHOLDER name) — the self-harm PRODUCER (carving theme): deals 1 UNBLOCKABLE
# damage to YOURSELF and makes 2 chunks, 4s — the HP-spend identity made literal (carve your own
# flesh). Self-damage is UNBLOCKABLE so the player's own shield can't absorb it (else the cost AND the
# self-damage synergy silently no-op). NOTE: values don't live in a vacuum (owner) — the real cost
# emerges in context: self-harm can stack, and flesh spent here isn't attacking / banking explosion
# charge (opportunity cost). Tune in /tune.
const FLESH_FLENSING_HOOK_COOLDOWN: float = 4.0
const FLESH_FLENSING_HOOK_SELF_DAMAGE: float = 2.0   # start at 2 (owner) — real cost emerges in context (stacking, flesh opportunity cost)
const FLESH_FLENSING_HOOK_CHUNKS: int = 2          # made via two CREATE_ITEM effects

# Skin Graft (PLACEHOLDER name) — a flesh CONSUMER (surgery/sewing theme): consume 1 chunk to heal,
# 4s. value 0 + scale x amount 1 = HEAL_PER_CHUNK per chunk eaten; 0 chunks present = heals 0 and
# resets (the consume "reset" behaviour — no fuel-gate). Consumes VIA remove_item, so it ALSO charges
# Flesh Explosion (the destroy synergy — heal + charge in one). TUNING WATCH: paired with Flensing
# Hook this is a net-positive HP loop; HEAL_PER_CHUNK is the dial (the real cost is contextual — flesh
# opportunity cost + stacking self-harm).
const FLESH_SKIN_GRAFT_COOLDOWN: float = 4.0
const FLESH_SKIN_GRAFT_HEAL_PER_CHUNK: float = 4.0
const FLESH_SKIN_GRAFT_CONSUME: int = 1

# Bone Spear (owner) — the Fleshmancer's first BLEED applier (docs/design/mechanic_ideas.md -> Bleed;
# the carve-as-bleed-applier fusion). A slow attack: damage + apply bleed to the enemy (UNBLOCKABLE,
# so its own shield can't soak the wound it bites itself for when it is hit by an attack).
# PLACEHOLDER — /tune.
const FLESH_BONE_SPEAR_COOLDOWN: float = 6.0
const FLESH_BONE_SPEAR_DAMAGE: float = 6.0
const FLESH_BONE_SPEAR_BLEED: float = 3.0   # enemy bleeds 3+2+1 = 6 over its next three attacks

# Bone shield spread (owner) — the Fleshmancer's self-shield: the survival FLOOR that protects the
# HP-spend engine while you voluntarily bleed yourself (character_ideas.md). The bone twin of the
# Leather spread, same fast/mid/slow curve (Rib taxed, Femur baseline, Skull rewarded). PLACEHOLDER.
const FLESH_RIB_COOLDOWN: float = 1.0       # fast, taxed — 3 shield/sec
const FLESH_RIB_SHIELD: float = 3.0
const FLESH_FEMUR_COOLDOWN: float = 2.0     # baseline — 4 shield/sec
const FLESH_FEMUR_SHIELD: float = 8.0
const FLESH_SKULL_COOLDOWN: float = 3.0     # slow, rewarded — 5 shield/sec
const FLESH_SKULL_SHIELD: float = 15.0

# Armourer big slow weapons (PLACEHOLDER numbers — /tune's job; docs/design/armourer.md → The empower
# engine). A ladder of heavy single-target attacks on 5s/6s/7s cooldowns with SIMILAR DPS but a rising
# PER-HIT (DPS ≈ cooldown + 3): the slowest lands the biggest single hit, so it is the best target for
# the Mighty Blow empower's double. Authored but UN-POOLED (the Armourer character isn't built yet).
const ARMOURER_BROADAXE_COOLDOWN: float = 5.0      # fast pole — DPS 8, per-hit 40 (doubled 80)
const ARMOURER_BROADAXE_DAMAGE: float = 40.0
const ARMOURER_WARHAMMER_COOLDOWN: float = 6.0     # mid — DPS 9, per-hit 54 (doubled 108)
const ARMOURER_WARHAMMER_DAMAGE: float = 54.0
const ARMOURER_GREATSWORD_COOLDOWN: float = 7.0    # slow pole — DPS 10, per-hit 70 (doubled 140, the boss-breaker)
const ARMOURER_GREATSWORD_DAMAGE: float = 70.0

# Mighty Blow (PLACEHOLDER — /tune) — the empower skill: a plain-cooldown metronome that banks a
# charge to double the next weapon attack (docs/design/armourer.md). Cooldown is the uptime knob
# (slower rations the empower, faster banks charges). Charges-per-fire stacks by proc count (#default).
const MIGHTY_BLOW_COOLDOWN: float = 5.0
const MIGHTY_BLOW_CHARGES: float = 1.0             # empower charges banked per fire (count on the counter)


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
# Empowered (docs/design/armourer.md → The empower engine) — the Armourer's Mighty Blow buff scales a
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


# ── Triggers (charges model — push as a fraction of the bar; docs/systems/combat_model.md) ─────
# "on poison applied -> push the shield item." ~1.0 fills the bar (an instant
# reaction); smaller values accelerate firing without completing it.
const TRIGGER_PUSH_FULL: float = 1.0
const TRIGGER_PUSH_SMALL: float = 0.25


# ── Content — Relics (run-level modifiers; docs/systems/content.md) ──────────────────────
# Stone Ward (starting relic): a combat-start status applier (start each fight with
# this much shield on the player).
const RELIC_STONE_WARD_SHIELD: float = 10.0
# Placeholder REWARD relics (granted by the reward routing; #2) — values are the owner's
# to tune. Vital Charm: a direct max-HP mod on grant. Iron Idol: more combat-start shield.
const RELIC_VITAL_CHARM_MAX_HP: float = 20.0
const RELIC_IRON_IDOL_SHIELD: float = 6.0


# ── Content — Enchantments (permanent item modifiers; docs/systems/content.md, #26) ──────
# Whetstone: scales the host item's payload values (e.g. +50% weapon damage).
const ENCHANT_WHETSTONE_MULT: float = 1.5


# ── Content — Consumables (manually-fired potions; docs/systems/content.md) ──────────────
# Healing Draught: a thrown self-heal (no Ticker — fired on the throw intent).
const POTION_HEAL: float = 20.0


# ── Run loop (HP economy + map; docs/systems/run_manager.md) ─────────────────────────────
const REST_HEAL_FRACTION: float = 0.3       # an in-act rest restores this fraction of max HP
# Draft skip → bank gold (docs decision #33). Skipping the 1-of-3 draft banks this fixed amount of
# gold instead of taking an item — a run-state resource (source built, no sink yet). The reward
# panel's gold button shows it. Placeholder — the owner tunes it.
const GOLD_SKIP: int = 2
# Placeholder event outcomes (#1) — the owner tunes/authors real event content.
const EVENT_SHRINE_HEAL_FRACTION: float = 0.4
const EVENT_SHRINE_MAX_HP: float = 15.0
const EVENT_WANDERER_DECLINE_HEAL_FRACTION: float = 0.15   # the "walk on alone" recruit-event decline


# ── Presentation — the framed combat view (docs/systems/ui_layout.md; docs/history/phase4_plan.md) ───────
# Enemy images vary in size, so each is sized to this on-screen height (px, inside the corridor
# SubViewport) when arrived at depth 0; perspective makes it smaller further away.
const ENEMY_PAINTED_HEIGHT: float = 640.0
# The approach (docs/history/phase4_plan.md Step 7): the enemy stands still and the player walks
# up to it over this many seconds at a cautious walking pace, so the enemy grows to full size as
# the corridor moves past; the boards activate on arrival. Change the two together: the depth
# divided by the duration is the approach's pace, and it has to match Corridor3D.speed or the
# footsteps fall out of step with a free walk.
const APPROACH_DEPTH_START: float = 1.4
const APPROACH_DURATION: float = 6.0


# ── Delivery visual hold (presentation lifetime; docs/systems/vfx_driver.md) ─────────────
# Sim-seconds a LANDED Delivery is retained after impact so the VFX wall can
# finish drawing its impact number / flash before the Combat manager drops it.
# This bounds the in-flight Delivery set so it can't grow unbounded over a long
# fight. Keep this >= the longest VFX visual duration (DamageNumberDrawer.duration()).
const DELIVERY_VISUAL_HOLD: float = 1.0
