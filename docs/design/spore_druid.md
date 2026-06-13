# Spore Druid — Working File

> First character. Working doc — add cards as they come, cull to a pool later. Targets in [`card_pool_targets.md`](card_pool_targets.md), held loosely.

**Concept:** a fungal druid whose deck is built on spores (status types) and the synergies among them. Identity lives in the spore engine — not warrior / mage / rogue. Reads instantly (spores spread), but isn't a fantasy-trope class.

**Status-identity character (the Silent analog):** most cards are spore appliers, which are skills/utility. Expect this character to run skill-heavy — the attack-heavy default likely inverts here.

---

## Structure — two pillars (not four threads)

The character is **one identity, several strategies** (the StS Defect model: orbs are the signature engine, but 0-cost/claw is a distinct non-orb line, with crossover). Spores are the signature engine; summon is a second pillar beside it so the character isn't one-dimensional. **Cap at two pillars** — each new pillar is a real synergy direction the no-skip 1-of-3 draft has to feed; two engines that cross over beats four that compete and go thin.

### Pillar 1 — Spores (signature engine)

The spore engine has two ways to play — **Mass** and **Self** — not separate pillars, just different ways into spores. A player drafts each differently; they share the applier commons. (Spread — rewarding *different* types held at once — is **not** an archetype: it's a state with no consume-verb or draft identity of its own. It lives as a cross-cutting *mechanism* a card or two can reward, not a thing you build toward.)

- **Mass** — each Mass card *names its own fuel*: consume X of a printed spore type (rarely >1 type) for a scaling effect. Not a generic engine — a card only references a spore that can be consumed, so the stacked/timed split (below) is a per-card authoring fact, not a system rule. Conditional (dead without their fuel) → skews uncommon/rare. Commons stay the appliers; Mass lives a tier up.
- **Self** — payoffs for being heavily spored, plus *beneficial* self-spores (regen, block-on-tick). Cleanest framing is "spore myself with good stuff + reward being spored," **not** "poison yourself and cope" — the masochist line (eat a bad spore, payoff justifies it) is the spicy high-risk *sub*-line, not the whole premise. Inward/defensive. **Anti-synergy with Mass** lives in *target shape* (Self appliers spray everyone; Mass wants one type stacked on one target) — kept live deliberately as a real draft tension.

Cross-cutting applier commons feed multiple flavours — a main-spore applier counts toward Mass *and* the distinct-status variety, and (if self-shaped) feeds Self. That overlap keeps any one flavour from becoming the only concern.

### Spore roster — small and synergistic (resolved 2026-06-08)

Rather than a wide bestiary of bespoke spores (flavourful, but a steep learning curve, and most would just shadow statuses the engine already has), the roster is **deliberately small and synergistic**: **one main spore** — a *stacked* counter that is the Mass fuel and the character's signature — plus **1–2 minor** bespoke spores. Everything else reuses the **shared status baseline** every character can reach (**Vulnerable**, **Weak** — the StS model; [`game_design.md`](game_design.md) Status System, decision #28). "Many spore effects" is then expressed by cards that **count distinct statuses present** (the Spread mechanism), not by authoring many statuses. The main spore counter **stands out** precisely because it's the one bespoke stacked thing amid reused statuses.

The main spore **does nothing on its own for now** — pure Mass ammo (the thallid-counter shape) — explicitly **open to change** (it may earn a solo effect later). **Name: Spores** (owner's call — the signature counter is simply *Spores*, no bespoke flavour name; plain, no invented jargon). This **supersedes** the earlier doc framing that used *poison* as the canonical Mass fuel: the bespoke main spore is the fuel now; poison, if it appears at all, is just another reusable status, not the signature.

### Pillar 2 — Summon (candidate, specifics TBD)

Fungal without being a spore (thallids, saprolings, the dead rising as spore-thralls), and crosses over with pillar 1 (spores spawn tokens; tokens carry spores). A board of tokens *is* the cascade getting wider — obvious fantasy, obvious payoff.

- **Summons are shared vocabulary** (owner, 2026-06-12 — see the cross-cutting note in
  [`character_ideas.md`](character_ideas.md)): other characters (e.g. the Elementalist) will
  summon too, so the druid's summons must *feel different* — this character's corner is
  **byproduct / ephemeral / swarm / sacrificeable** (the engine overflows into tokens), vs.
  deliberate-purchase durable allies elsewhere.
- **Open: is summon a replacement for Spread, or a genuine second pillar?** Leaning second pillar (the Defect shape), but summon may be the tighter third-flavour than Spread is — Spread still lacks a consume-verb, summon has an obvious one. Walk-and-think, not decide-now.
- **Cost flag:** summon promotes the deferred party/roster experiment (decision #22 — "treat each side as a roster," currently *don't build it now*) to *required* for the demo character. Fights are mostly 1–2 bodies; a summon thread needs the player side to be a party. Real cost — possibly right, but it's being called in early. If summon is a true pillar carrying real weight, the justification is sound.

## Watch / open

- **Self anti-synergy must stay live both ways.** Too-strong self payoff → you take both for free and the tension was fake; too-weak → nobody touches Self and it's a trap archetype. Both halves have to stay draftable. Prototype-tuning watch — easy to balance away without noticing you killed the decision.
- **Spread is a mechanism, not an archetype** (demoted). A card or two can reward holding different spore types; it has no consume-verb or build identity of its own, so don't author toward it as a thread. If a spread-payoff card ends up wanting a consume-verb (fire once per distinct type present, variety spent as ammo), fine — but that's one card's design, not a direction.
- **Spore accumulation differs by type (by design, like DoTs generally).** Stacked spores (the main spore counter — count grows, the count is Mass fuel) vs. timed spores (e.g. blinding — applications extend duration, not effect). Rationale: stacks are useless in hallway fights and overpowered vs. bosses; timing dodges that. Consequence: only stacked spores are Mass-eligible, and per-card Mass naturally never references a timed one. So a Mass payoff needs the main-spore appliers to exist first — don't write a Mass card whose fuel doesn't exist yet.
- **Self-application is a property of the applier's target shape, not the spore.** Whether a spore is survivable on self depends on which applier carries it (enemy-shaped vs self/all-shaped), same per-card logic as Mass. So lethal/blind/confuse simply never ride a self-shaped applier — no spore needs to be universally self-safe. Self uses the specific appliers authored to carry good-or-tolerable-on-you spores.
- **Spore type count — resolved (2026-06-08): few-and-deep.** One main bespoke spore (the stacked Mass fuel) + 1–2 minor, with **Vulnerable / Weak** reused as the shared baseline (#28) and "count distinct statuses" carrying variety. See *Spore roster* above. The dial is set toward **few**; revisit only with new info.

## Spores defined so far

- **Spores** *(the signature)* (stacked) — the Mass fuel + variety-counter. **Does nothing on its own for now** (pure ammo; open to change). The only Mass-eligible spore in the kit, and the one bespoke stacked status — it stands out against the reused baseline. **Authored in code** as `SporesStatus` (id `'spores'`) — an inert stacked counter (`is_fuel()`; accumulates, never ticks/decays/damages, spent only by `StatusManager.consume`).
- **Blinding** (timed, minor) — enemy misses for **2s**; further applications extend duration, not effect. Carried by the rare **Pocket Shrooms**. Animate the whiff with a clear tell so the eaten swing reads against the dark. Spread/Self fuel, not Mass.

**Reused baseline (not bespoke spores):** **Vulnerable**, **Weak** — the shared status vocabulary every character can apply (#28). Their appliers sit in the pool like any card and feed the distinct-status variety, but are never Mass fuel (timed, not stacked).

## Tagging key
- **Type:** A = attack (damage item) · S = skill (block / resource / utility)
- **Archetype:** mass · self · spread · x (cross-cutting / serves no single thread)

## Commons (target ~20, held loosely)

### Attacks

| Name | Shape (ST/AoE) | Archetype | Effect | Notes |
|------|----------------|-----------|--------|-------|
| Druid Staff | ST | mass (x) | 10 dmg, 3s; apply 1 Spore | The starter Spores applier. Single-target so Spores pile on one enemy (the Mass shape); a cross-cutting common that also feeds distinct-status variety. Authored: `ItemCatalog.DRUID_STAFF`, in the Spore Druid pool. |
| Spore Spitter † | ST | mass (x) | 4 dmg, 1s; apply 1 Spore | Fast pole of the first weapon spread. 1s cooldown = ~1 Spore/sec — the kit's fastest Mass-fuel engine. 4 DPS. `ItemCatalog.SPORE_SPITTER`. |
| Capped Cudgel † | ST | x | 10 dmg, 2s | Middle pole: clean tempo weapon, NO spore. 5 DPS baseline — the pure-damage draft option. `ItemCatalog.CAPPED_CUDGEL`. |
| Bloomhammer † | ST | mass (x) | 40 dmg, 5s; apply 2 Spores | Slow pole: heavy hit that dumps 2 fuel in one strike. 8 DPS — slow accrual but a sudden fuel spike. `ItemCatalog.BLOOMHAMMER`. |
| Wilt Frond † | ST | x | 20 dmg, 4s; apply Weak (2s) | A Weakness applier. Damage sits 2 DPS under the curve (7→5 = 20 dmg) to pay for the Weak rider ([`item_heuristics.md`](item_heuristics.md)). Weak isn't Mass fuel — feeds distinct-status variety. `ItemCatalog.WILT_FROND`. |

> † **Placeholder name** — agent-coined, owner's to rename (also flagged in the def's `name_key` comment).

> **DPS curve: `DPS = cooldown + 3`** (+1 DPS per second of cooldown, anchored at 2s = 5 DPS baseline). Slow items need *more* printed DPS to be worth a slot, because big hits lose value to **overkill** (damage past 0 HP wasted) and **fewer per-hit triggers** (on-hit procs / Spores-applied events fire per swing, not per damage). The cooldown axis is *also* the Spore-accrual axis (fast = fast fuel). Linear holds across the **1–6s** authoring range; the tail must taper (overkill/trigger loss is bounded) or ultra-slow weapons run away. Spore-carriers pay a tax off the line. **Authored to be adjusted in tuning.**
>
> **Outlier:** Druid Staff (10 dmg / 3s = 3.3 DPS) sits well under the line — by it the 3s starter wants 18 dmg. Left as-is (it's the starter) pending the owner's call.

### Skills

| Name | Subtype (block/resource/utility) | Archetype | Effect | Notes |
|------|----------------------------------|-----------|--------|-------|
| | | | | |

## Idea bank — fungal effects (loose inspiration, unfiltered)

Raw fuel from real fungi + D&D/MtG fungal canon. Not vetted for fit; pull from here when authoring.

Real: cordyceps (mind-control + spawn-on-death) · mycelial network (board linking, resource transfer) · decomposition (consume the dead for fuel) · bioluminescence (light — the one bright thing in the dark) · fermentation (conversion/transformation) · lichen (paired/hybrid effects) · puffball (AoE-on-trigger/death) · mycorrhizae (life-drain/leech) · dormancy (delayed/conditional triggers, sleepers) · ergot (madness/confusion — RNG, weigh against the deterministic cascade) · fairy ring (effects whose radius grows) · rot/blight (decay auras, accelerating DoTs).

Canon: myconid rapport spores (linking, animating dead as thralls) · gas spore (float, burst poison cloud) · violet fungus (rotting touch) · shrieker (alarm/aggro, summons reinforcements) · spore-raised thralls (summon from corpses) · saprolings (token swarm + sacrifice payoff) · thallids (accrue spore counters, birth tokens — literal stack-and-spend, the Mass ancestor).

On-mechanism standouts: thallid counter, decompose-for-fuel, board-linking, spawn-on-death. Awkward fit: cordyceps mind-control (fights no-player-targeting / no-clever-AI).

### Candidate spores/effects + calls

- **Lethal** (stacked) — kills when count > target HP, then spawn a token. Inverse curve to blinding: trivial vs trash, impossible vs bosses → self-selects into a **trash-clear/execute** niche, falls off against bosses (clean role, not a bug). Mass-adjacent execute payoff, enemy-only, skews rare. **Decouple the token-spawn** — "spawn on kill" wants to live on a relic/enchant, not be welded to the spore.
- **Burn** (timed) — damage-on-tick, but the *timed* counterpart to poison's *stacked*. Not a dupe of poison **iff** the accumulation model differs (refresh duration, doesn't stack, not Mass fuel, Spread/Self food). A dupe if it's just green poison. Design doc already names burn + poison as separate DoTs.
- **Confuse** (chance to hit ally) — weakest candidate: RNG, only matters in multi-body fights (dead 1-on-1, i.e. most fights), bad on self and worse once you have tokens to mis-hit. Shelve, or a late rare. Not a core spore.



## Rares — later

| Name | Type | Shape | Archetype | Effect | Notes |
|------|------|-------|-----------|--------|-------|
| Pocket Shrooms | A | ST | x | 10 dmg, 3s; apply 1 blinding spore (2s blind) | The blinding enabler. ~3.3 DPS attack + a timed control rider; **rare for the access to blinding, not for bigger numbers** (rarity = complexity, not power). |

> **Authored in code** as `ItemCatalog.POCKET_SHROOMS` (the first multi-effect rare + first Spore Druid card). Now in the **Spore Druid's `item_pool`** (#27) alongside Druid Staff; reachable in drafts once the Spore Druid is flipped into `CharacterCatalog.ids()` (selectable).

---

**Running count:** Commons — Attacks 5 (Druid Staff, Spore Spitter, Capped Cudgel, Bloomhammer, Wilt Frond) · Skills 0 (block 0 / resource 0 / utility 0). Rares — 1 (Pocket Shrooms, attack).

**Character:** `CharacterCatalog.SPORE_DRUID` scaffolded (pool: the 5 commons + Pocket Shrooms — the running count above; starts with Druid Staff; no signature relic yet; not yet selectable).
