# Dark Corridor — Design Snapshot

> **This is a working doc, not a settled spec.** Decisions here are current leanings to test in prototype, not commitments — re-litigate freely with new information.

*Working title, named after a prog rock band. Lock in or change later.*

**Status:** Paper design, idle-time exploration. Not a committed project. Captured to avoid re-deriving the same conclusions next session.

**Context:** Sketched while AMTKAG is in final-mile launch prep (Steam page, itch playtest). Active build is gated on AMTKAG shipping. This doc is for future-me, not for marketing.

-----

## One-sentence pitch

A short, draft-heavy auto-combat dungeon descent: walk forward through a single corridor, fight, pick an item, repeat — die, spend meta progression, restart. Bazaar items, Vampire Crawlers framing, a roguelike (not incremental) spine.

## Inspirations

- **Topdeck Automat** — auto-resolving combat, build-is-the-game thesis, character-as-modifier model (portrait + signature relic).
- **Vampire Crawlers** — first-person grid corridor framing, short dopamine fights, draft-after-fight cadence. *Avoid:* late-game collapse into infinite loops; thin dungeon framing.
- **Loot Loop** — short total runtime, single prestige layer. We take the brevity but lean away from its incremental/anti-grind ethos and toward a roguelike spine. Final boss = real ending.
- **Bazaar** — item activation model (passives / triggers / actives), cooldown visualization.
- **Backpack Battles** — considered for inventory model, rejected: spatial tetris puzzle is friction we don't want; slots are uniform here.
- **Slay the Spire** — one influence among several. The parts we draw on: elites and bosses as distinct problems that take thoughtful drafting ahead of them to solve, the attack / block / scaling high-level item categories, and limited healing. The parts we don't take: branching routes, deck dilution, card removal. Used both as inspiration and as a contrast that keeps the design honest about what it trades away.
-----

## Core loop

```
Walk forward (2-3s)
  → Encounter (10-15s combat, OR non-combat event)
  → Draft 1-of-3 (each slot a low chance of an enchant or potion instead of an item, 5-10s)
  → repeat through 3 acts (~15 encounters each)
  → die or beat final boss
  → Spend meta progression in skill tree
  → Restart
```

Each act holds a boss (telegraphed ahead of time), a guaranteed relic at the act midpoint, 1-5 elites offered, and a mix of basic fights and events filling the rest. Full successful run ≈ 45 encounters ≈ 30-45 minutes.

## Structure

- **3 acts, ~15 encounters each.** Starting target, tunable.
- **Single corridor** that evolves visually as you descend (lighting temperature, fog density, wall props, ambient audio, enemy roster) — no biome changes, just a deepening.
- **No branches, no exploration, auto-advance.**
- **2 mid-bosses + final boss.** Final boss = credits, real ending. The floor's boss is telegraphed ahead of time.
- **A 1D linear progress map** shows the floor's beats and the player's progress along it — boss at the end, guaranteed relic at the midpoint. It's forward visibility on a single linear track, not a branching route map.
- **Act transitions** happen via a full rest after each act boss (automatic, full HP restore). Within each act, one guaranteed small rest encounter sits as a partial-heal beat.
- **Death is final per run.** No retreat, no escape valve.
- **Auto-save on entry to each encounter.** Player can quit mid-run and resume the next encounter cleanly. Important for the mobile/short-session pattern.
## Combat

### Default behavior

- Fully auto. No player input by default. Drafts are the game; combat is the readout.
- Target duration: 10-15 seconds for regular fights, longer for elites and bosses (board-vs-board mutual cascades take time to resolve). Cascade-speeds-up-with-engine-growth applies as a trend, but mutual-engine fights raise the floor.
- Combat readability is the design pressure. Player needs to see what their build is doing or the next draft has no information basis. Item activations need clear visual/audio tells; damage numbers, item triggers, status effects must overlay the combat scene cleanly.
### Multi-enemy fights and targeting

- **1-4 enemies per encounter.** Most are 1-2; group fights are authored and exist to give AOE a reason to be drafted.
- **No player targeting.** Adds a second opt-in input layer on top of potions, requires per-enemy threat differentiation, and isn't necessary because fights are authored.
- **Auto-targeting rule: leftmost living enemy.** Single-target items hit the leftmost; AOE items hit all.
- **The rule never gets "smart."** No lowest-HP, no highest-threat targeting. Consistency beats optimality — predictability is what lets the player learn their build. Auto-targeting that tries to be clever feels like an opponent.
- **Fight design teaches the rule.** Tank in front of DPS = tank protects DPS, AOE bypasses. Boss-with-adds = adds in front for AOE to clear, single-target chips the boss. Spatial composition is the puzzle.
### AOE vs single-target as a draft axis

- Items get a damage-shape tag: single-target or AOE.
- All-single-target builds struggle vs ad-heavy fights; all-AOE builds waste damage vs bosses. Mixed builds need balance.
- One elite per floor and some bosses will be multi-body fights, where AOE earns its place.
- Costs nothing — just a tag plus authored fight composition. Pays back as real draft decision density.
### Enemy variety

- Aim for good enemy variety, with each encounter feeling distinct either through the individual unit or through composition.
- Most fights are 1-2 bodies, so the individual unit usually has to be interesting on its own. Composition helps but isn't enough by itself.
- Make enemies until the roster feels like enough — no fixed count.
### Enemy loadouts

Enemies have visible item loadouts — player can see what they're about to do. This converts auto-combat from "watch my cascade" into "watch the cascades collide." Mutual cooldowns create a visible race.

- **Regular enemies:** Spire-style signatures. 1-2 items (attack + buff is the default pattern). Predictable, readable at a glance.
- **Elites:** 2-3 items with light synergy.
- **Bosses:** 3-5 items with deliberate synergies. Mutual-cascade fights against the player's engine. Each boss has one signature mechanic (spike-armor, heal-over-time, summons-adds) expressed through their loadout, forcing a different draft strategy in the act leading up to it.
- **Late-act regular enemies trend toward small engines** — escalation parallel to player power.
- **Item model:** each enemy has its own attack item, with its own value and icon, distinct from player items and not drawn from a shared attack pool. On top of that, an enemy may carry a defensive or utility item from a small shared enemy pool. Icons can visually overlap with player items to start with — they just shouldn't be mechanically identical to the player's. This keeps enemy threats distinct enough that players won't confuse "their" items with enemy ones.
### Healing and HP economy

- **HP persists between encounters.** No automatic between-fight reset. Damage taken carries forward.
- **Sources of healing within an act:**
  - Heal items (active subtype) — sustained recovery during fights.
  - Heal potions — burst recovery tactical use.
  - Small rest encounters — partial heal (see Encounters).
- **Full heal between acts.** Automatic full HP restore after every act boss. Players enter each new act at full HP regardless of how they finished the previous one.
- **Max HP can increase within a run.** Via relics, certain lore events, possibly rare items. Permanent max-HP boosts via meta-progression are deprioritized (see Meta-progression — flat-power unlocks bad).
## Visual / Tech — mechanical constraints only

*Full art direction, palette, tone, VFX, and audio live in the **Art Direction & Audio** doc. This section captures only what the mechanics depend on. Keep it short; depth goes in the other doc.*

- **2D, Godot 4.** Scaling tile-segments form the corridor — split into separate wall / floor / ceiling tiles (mix-and-match), same concentric-scaling model as the original frame-segment description. Enemies are 2D sprites, not billboards. Authored at ~360p pixel scale but rendered at full monitor res (sprites scaled up, not a low-res viewport) to avoid integer-scaling shimmer. *(Supersedes the old "3D corridor + 2D billboarded sprites" line.)*
- **Items dominate the screen; the corridor view is mood/feedback.** Whether combat sits in a small framed window or a full-screen scene is open (see UI/Layout) — either way the items are the game, which is what the UI/Layout section is built around.
- **Color vocabulary is the readability mechanism** (red attack, blue block, green heal, per-effect status colors) — mechanically required to parse a 30-item cascade, not a cosmetic choice. Carried on both player and enemy boards.
- **Lighting = single flickering point light, hard falloff to black.** Hides art weaknesses and does coherence work across mixed asset sources. Relevant to mechanics only insofar as it sets the dark baseline the cascade punches through.
- **Tone in one line:** atmosphere is dread, mechanics are juicy; the cascade punches through the dark. The mechanical consequence is that activations must read against a dark baseline (see UI/Layout and the art doc's cascade-readability section).
## Audio — mechanical note only

*Full audio direction in the **Art Direction & Audio** doc.* The one mechanically relevant point: **per-effect-family combat sounds are a second readability channel** — the player hears their build's texture (poison hiss vs. fire crackle) without watching closely, which carries readability the visuals can't in a packed cascade. Everything else (dungeon synth, adaptive layering, sourcing budget) is art-doc material.

## UI / Layout (early sketch)

**Decision status (open):** Two live approaches — small-game-area + large-UI dungeon-crawler frame (Wizardry / Eye of the Beholder / Bard's Tale family), or a full-screen scene (Topdeck Automat-style) with the character on-screen and items arranged around them. Not attached to the framed window; the full-screen option is genuinely on the table. Specific arrangement TBD pending mockups. (Layout depth and the cramped-feel tradeoff live in the art doc.)

- First-person-style view, monsters approaching from depth (2D, not a 3D scene). Items are the game; the corridor view is mood and feedback.
- Items dominate the screen. Arranged in zones by effect family (weapon / armor / heal / status-applier have distinct regions). Auto-arranged, synergy groups visually clustered (poison items glow together when one fires).
- Items need to be bigger than feels comfortable. With huge inventory and cascade combat, individual activations get lost if items are tiny. Err toward "busier than seems right" so activations stay legible.
- Cooldown meters Bazaar-style: filling overlay on each active item. Applies to enemy items too — mutual cooldowns visible on both boards is what creates the visible-race feel.
- **Effect value shown in a color-coded panel** at the top of each item, extruding over the edge. The panel's background color encodes the effect family; the number is the value (e.g. a red panel with the damage value for a weapon). Per-effect colors as before — poison, burn, freeze etc. each have their own color, defined per-effect, not a single shared "status" color. Usually one panel; rarely an item shows more than one (a rare combining multiple effects).
  - Effect-family colors: red = attack / damage, blue = block, green = heal, per-effect colors for status applicators.
  - Status icons (when statuses are applied to actors/items) use the same per-effect color as the panel of the item that applies them.
- **Borders encode rarity:** bronze / silver / gold for common / uncommon / rare.
- Color is the readability mechanism that scales. Can't parse 30 item names in 15 seconds. Can absolutely parse "lots of red on my side, mostly blue on theirs — they're tanking, I'm bursting."
- Slow-on-hover applies to everything important: own items, enemy items, potions, enemies themselves. One consistent verb — hover, time slows, read.
- Slow-mo pauses both sides proportionally. Otherwise inspection becomes an exploit (dodge attacks by inspecting forever while enemy cooldowns freeze).
- Player portrait as character-identity anchor, separate from the combat scene.
- HP: the character portrait gets progressively more beaten-up at low HP; the value is shown as text. The visual sells damage state at a glance; the number gives precision. *(Visual treatment detail in the art doc.)*
- Potion slots distinct from item slots — tactical reserve UI, not item-cousin UI.
- **The visual identity is busy.** Many items, many cooldowns, mutual boards, status icons, particle effects, screen shake on big hits. This is intentional — the maximalist cascade is the spectacle. Don't try to "calm it down" later; the busyness *is* the look. Cognitive load is mitigated by color vocabulary, zone-based layout, and slow-on-hover, but the baseline is lots-of-stuff-animated and that's correct. *(Cascade-readability detail — how 30 activations stay parseable — lives in the art doc.)*
-----

## Items

### Shared base — Draftables

Relics, items, consumables, and enchantments share the **Draftable** contract — drafted, inspected via slow-mo-hover, surface tooltips, rarity — by **composition** (a shared definition-face + a `category` tag), *not* a parent class (see architecture's *Draftable contract*). They are distinct types differing in behaviour and presentation:

- **Item** — participates in the combat cascade. Lives on the board.
- **Relic** — persistent background modifier, outside the cascade. Distinct UI region.
- **Consumable** — limited slots, consumed on use, manually activated. Potions are the canonical type; category open to others.
- **Enchantment** — drafted and inspected like the rest, but **applied to a chosen item** rather than held in its own slot (one per item; details under *Enchantments*).
Code-sharing decision first (drafting, tooltips, inspection are common); categories stay distinct in design treatment.

### Structural note — what "no size limit" costs

This game is closest to Bazaar without the size cap, which also means without card removal/selling. That removes the thing that makes Bazaar's drafts decisions.

- Bazaar's cap = a replacement decision every pick (take this vs. what do I cut). Opportunity cost is free, structural, constant.
- No cap = an acquisition decision (is this above the usefulness floor). One-sided. "More is more" unless an item is actively bad.
- We deliberately removed the cheapest source of decision tension and committed to manufacturing all of it through synergy interactions instead. The synergy system does the structural job the cap does in Bazaar.
- Tension to stay aware of: "no cap" and "drafts stay interesting deep into a run" are in conflict. Maximalist is the chosen answer.
### How items act — active, with triggers layered on

- **Every item is active** — a timer-based tick effect (a cooldown that fires). Subtypes:
  - Weapon (damage) — single-target or AOE tag
  - Armor (block)
  - Heal
  - Apply status (regen / poison / burn / freeze / etc) — single-target or AOE where applicable
- **Triggers layer on top, not a separate kind** — "when X, do Y" pushes an item's cooldown toward firing; the item still ticks normally, the trigger accelerates / supplements it (the charges model).
- **Passive / always-on effects are not an item kind** — they're statuses (applied to actors or items), usually carried by relics. An item that confers a lasting effect does so by applying a status.
At rare tier, items can combine multiple effects (e.g. damage + heal, or weapon + status-applier). Common and uncommon items are single-purpose.

### Rarity — flat power baseline, varies by complexity not numbers

Three tiers. Color-coded (bronze / silver / gold borders). Drop rate weighted by depth (later drafts = better odds).

Item numerical power is roughly flat across tiers. Rarity varies by complexity, specificity, and build-defining-ness:

- **Common:** simple, single-purpose, broadly useful (damage tick, basic block). Workhorses. Trigger-fuel for the cascade.
- **Uncommon:** conditional or interactive (triggers on poison applied, scales with item count, requires another item type). Connection-makers.
- **Rare:** build-anchors. The item that turns "I have poison stuff" into "poison is my strategy." Each rare is a build-completion event.
Why not Bazaar-style scaling rarity: if rarity meant bigger numbers, low-rarity items would become deadweight late, players would auto-take any high-rarity item regardless of synergy (rarity > fit), and the late game would collapse into the Vampire Crawlers failure mode. Power-by-complexity preserves the cascade identity — late-game rares amplify the early commons rather than replacing them.

Items that are purely "+X stronger version of common item Y" don't exist as items. Those become enchantments. Numerical scaling lives in the enchant layer, not the rarity layer.

### Synergies

Cross-item interactions are the core decision mechanism. Example: *when you apply poison, gain 1 block. Your poison is applied twice.*

This makes the draft decision "does this connect to what I have" rather than "is this strong" — the decision density carrier.

### Enchantments

*(A subclass of Draftable — see Items: drafted + inspected like the rest, but applied to a chosen item rather than held in its own slot.)*

- Modifiers attached to items (e.g. "when this item deals damage, apply poison").
- **Rarity tiers (common/uncommon/rare)**, same as items. Higher tiers offer more dramatic modifiers.
- **One enchant per item.** Each item can hold a single enchantment at a time.
- May use the status system as an implementation tool when the effect is status-shaped; not defined as statuses.
- Enchants also absorb pure-numerical upgrades (the rarity model rules these out as items). A common item with a "+50% trigger value" enchant is the upgrade path for that item. Spire's card-upgrade system, ported here.
### Duplicates

Stack independently. Two of the same item = effect fires twice. Reinforces the cascade / many-small-items identity.

### Inventory

- Huge by genre standards. Maximalist — lean into this as a selling point.
- No spatial puzzle. Slots are uniform.
- Auto-arranged, clustered by type. Synergy groups visually cluster (poison items glow together when one fires).
- Item power philosophy: many small > few big. Individual items modest, the cascade is the power.
### Item count targets

- Launch pool goal: ~100 items. Starting target, refine via prototype.
- Run end-state: ~20-25 items in inventory by final boss. (Capped by draft count — with no skip, you take at most one item per draft, and not every encounter is a draft.)
### Progression arc — damage, block, scaling

Every build needs three things across a run: damage, block, and scaling. They aren't sequential phases — you want all three working most of the time. There's only a soft, natural tilt over the course of a run:

- **Damage** matters most early, when the engine isn't running yet and raw output is what gets you through fights.
- **Block** matters throughout — it buys time while the engine ramps and keeps mattering wherever fights last long enough for incoming damage to bite.
- **Scaling** (multipliers and cascade enablers) is worth less early because there's nothing built to multiply yet, so it naturally rises in value as the engine grows.
The tilt is a consequence of the engine's state, not a rule that early items expire.

Mechanism — how the tilt gets created:

- Encounter design is primary, not item decay. Fights shift what wins — threshold checks (can you spike), then sustained checks (defensive layers, pressure over time), then engine checks (big HP, only die to compounding). Draft priority shifts because what wins fights changed, not because early items rotted.
- Escalation, not replacement. Early damage items must double as trigger-fuel the later cascade keys off. A "deal 3 on tick" item becomes the heartbeat that enchants later turn into an avalanche. One pool, early items legible/immediate, late items multiplicative on what early items do. Don't design disjoint early/late pools.
- Item scaling-profile tags as seasoning, not the primary mechanism.
- Prototype failure test: late in a run, can you trace an early pickup still meaningfully feeding the cascade? If yes, the arc works. If it's doing nothing, you built replacement (the bad half of Spire without the mechanism that justified it).
- Block-specific failure mode: if mid-run fights resolve fast enough that block never matters, block items become trap picks and the arc collapses to damage→scaling. Mid-run enemy design has to demand block, not just permit it. Tuning constraint, not content.
-----

## Status System (shared primitive)

A common engine for time-bounded or stackable modifiers — dots (poison/burn), regen, freeze, vulnerable, weak, damage buffs, defense buffs, cooldown changes, and similar effects that have a target, a count/stacks, and a behavior.

Used by other systems (enchantments, relics, potions, items, enemy abilities) when those systems need this kind of modifier. Not the underlying nature of those systems — enchantments, relics, potions are gameplay categories with their own concerns; statuses are one of the tools they reach for.

### Definition

A status effect is (target, count/stacks, behavior).

- **Target:** an actor (player or enemy) OR an item (player item or enemy item). Dual targeting is the key extension over Spire (whose cards aren't persistent enough to be targeted).
- **Count/stacks:** numeric value. Some persist until removed, some count down to expiry.
- **Behavior:** what the status does — when it triggers, what it modifies, interactions with damage/healing/cooldowns.
### Item-targeted statuses

Persistent items make item-targeting natural in a way Spire's transient cards don't allow:

- "+2 damage on this specific item" (long-duration status on an item)
- "This item's cooldown is 50% reduced for 5 seconds" (timed status on an item)
- "This item triggers twice on its next activation" (charge-count status on an item)
- "This item is silenced for 3 seconds" (negative status on an item)

*Lifetime:* item-targeted statuses are **combat-scoped** — they last only the fight (cleared at fight end), like every status. A **permanent** item modifier (a lasting +2 damage) is an **Enchantment**, not a status; statuses are the *temporary* combat layer (decision #26).
Bazaar-shaped — items have their own status layer parallel to actors.

### Surface design

Players should feel that poison and strength and freeze are different kinds of things even though the engine treats them identically:

- Distinct icons per status type
- Color-family-coded (red = damage, blue = defense), consistent with item panel colors
- Surface naming preserves intuition
### What it doesn't do

- Doesn't replace items, enchantments, relics, or potions as design categories.
- Doesn't claim every effect in the game is a status. Many effects are direct (potion deals 20 damage; relic grants +1 potion slot; enchant changes an item's trigger condition). Statuses are one tool those systems can use, not the basis of them.
### Asymmetric acquisition

Wanting a status "enemies get often, players rarely" (e.g. strength) is a design choice about acquisition rates — same mechanic, different exposure tuning by source. No special-case code; tune at source.

### Stats deliberately deferred

Specific stat-like statuses (strength/weak/vulnerable equivalents) are not designed yet. Open problem to resolve in prototype: any "flat damage modifier" status interacts badly with this game's high-trigger-count cascade — a +N status that hits every trigger from a fast item gets applied 15x per fight, from a slow item 3x, making fast items dominant. Constraint for stat design: damage-scaling statuses must not make fast items strictly dominant over slow items. Percentage-based, slowest-item-targeted, charge-budgeted, or no-flat-modifiers-at-all are all candidate answers. Resolve in prototype.

-----

## Relics

Persistent equipped effects, distinct from inventory items in presentation. A subclass of Draftable (see Items).

- **Rarity tiers (common/uncommon/rare)**, same scheme as items. For relics, rarity is more arbitrary and feel-based than a power ladder — it's not a clean "higher tier = bigger effect" scale the way it is for items.
- **Acquisition sources:**
  - One guaranteed relic per act, at the act midpoint.
  - One relic per elite engaged (1-5 elites offered per act; player chooses which to engage).
  - One relic from each defeated boss (3 per run — 2 mid-bosses + final).
  - Full rests between acts don't grant relics — they're the heal beat.
  - Total: roughly 8-18 relics per successful run depending on elite engagement, including the starting relic.
- Distinct UI presentation from items — background power, not foreground play.
- Some relic effects use the status system; others are direct attribute changes or rule modifiers.
## Consumables

Tactical consumable reserve, consumed on use. Potions are the canonical consumable. *(Subclass of Draftable — see Items.)* Adapted to auto-combat via slow-mo-on-hover.

- **3 potion slots.** Found primarily in drafts. Consumed on use.
- **Use during combat.** Click to throw. Effects are tactical: heal, instant block, freeze enemies, instant damage, apply status to all, trigger-all-items-once, etc.
- **Slow-mo-on-hover.** When the player hovers over a potion during combat, the game slows to ~5% speed and the tooltip shows. Gives deliberation time without breaking the auto-combat thesis. Agency is opt-in.
- **Partly answers the boss-input question.** Players naturally hoard potions for bosses; slow-mo gives bosses the deliberation space pure auto-combat lacks.
### Draft structure

Reward draft is 1-of-3. Each slot is usually an item; each slot has a low chance (exact % TBD) of instead offering an enchant or a potion.

- Player picks one of the three. No skip — there's no penalty for taking more items, so taking one is always correct. The decision is which of the three, judged on synergy.
- A potion taken when potion slots are full means dropping one to make room.
- An enchant taken is immediately applied to a chosen item (one enchant per item).
### Items vs potions

Risk: potions become "consumable items" in player perception and the distinction collapses. Frame around: items are your engine, potions are your reserve for moments the engine can't handle. Separation has to land in UI (distinct presentation, slow-mo activation), acquisition pacing (rarer than items), and tone (tools you reach for vs. machinery you've built).

-----

## Encounters and the choice layer

All non-default progression beats in the corridor go through one system. Regular fights, elites, non-combat events — all encounters. The choice layer surfaces 2-3 options as the player approaches, picks one, that encounter resolves.

Why this exists: a single linear corridor structurally can't give Spire's branching routes (Spire's route-planning depth comes from choosing between forking paths, which we deliberately don't have). The corridor stays linear and the floor ahead is visible on the map; what's absent is branch-selection. The substitute for that lost agency: present options at point-of-arrival. Deliberately thinner than Spire — tactical, not strategic. A full routing layer would also fight the design's tone. Don't try to recover all of Spire's depth, it'd be a foreign organ here.

### Structure

- **Two-tier choice (Bazaar-inspired):** pick a location (one-line frame, e.g. "A flooded antechamber"), then a choice within it. Gives agency over an auto-advance path; front-loads anticipation; scales content combinatorially from modest authored content.
- **Encounter types in the pool:**
  - Regular fights (the default)
  - Elites (optional engage/skip with telegraphed demand + higher reward + guaranteed relic)
  - Non-combat events (lore + binary choice with tradeoff)
  - **Small rest encounters** — in-act partial-heal beat. One guaranteed per act. No relic (the guaranteed relic is the midpoint drop).
- **Full rest** — automatic post-act-boss beat, not a choice-layer encounter. Full HP restore. Plays unconditionally between acts as the act transition. Brief narrative/visual beat — not a decision moment.
- Short prose. Location = one line. Options ≈ binary, clear tradeoffs. Not Spire-tier prose.
- Pool target: ~30 designed encounters across all types — will probably change. Doubles as world-building delivery.
- Frequency of choice points: tunable in prototype. Probably multiple per act.
### Elites within the encounter system

Elites are one encounter type, not a separate system. When the choice layer offers a path leading to an elite:

- Demand is telegraphed (e.g. "high single-target burst," "block-heavy survival," "applies poison — bring cleanse"). Decision is informed.
- Reward asymmetry: engaging an elite pays meaningfully better than a regular fight (relic, guaranteed rare item, extra enchant). Skipping (taking a different choice-layer option) is safe but gives less.
- Real decision only if preparation is costly. If the player's draft economy gives them enough flexibility to be ready for every elite they see, elites become free rewards — no decision. The draft has to be tight enough that preparing for an elite means not preparing for something else. Tuning constraint.
- **1-5 elite paths offered per act.** Player engages as many as they choose via the choice layer; skipping costs the elite reward but is always available.
Why this matters: elites are where the damage-block-scaling triad becomes a live decision instead of a passive arc. The progression arc is the shape; elites are where the player commits to a position on that arc.

### Telegraphing

The entire viability of the choice layer.

- **First-run legible.** Not "learnable over runs." If it takes 3 runs to learn what an icon means, those first runs it's noise. Match Spire's immediate iconographic clarity (fire=rest, monster=fight, ?=known gamble).
- **Telegraph the category, not the contents.** "Combat-heavy, item reward" vs "safe, healing/economy" vs "risk, high reward." Uncertainty lives in the specifics within a category, never in what category this even is. (Same principle as Bazaar's "you roughly know what you're getting.")
- **Options must trade against run state.** A heal is worthless at full HP and vital when low; a gamble is right when behind, wrong when ahead. Author options so their value depends on the player's current HP/build/resources.
### Keep it cosmetic-with-teeth

The corridor stays single and linear. What the choice changes is the reward/encounter type of the next beat, not the corridor's structure. The choice layer doesn't smuggle branching-corridor scope back in.

-----

## Characters

Minimum viable character system: portrait + signature starting relic + small starting item set. Optional passive trait only as a property of the starting relic; no separate system.

- One shared item pool across all characters. Character defines flavor of start, not different game.
- Starting items: 2-3 items from the regular pool, chosen to anchor an archetype. (E.g. "starts with Burning Coal + Slow Drip" teaches a fire/dot build from turn 1.) Drawn from the regular pool — no per-character bespoke items. Battledraft scope trap.
- Default character has the least-twisted starting relic + most generic starting items — teaches the loop.
- Unlockables get progressively weirder starting relics + more archetype-specific starting items.
- Starting relics should be the most build-defining relics in the game. Take more time on these than regular relics.
- **No hidden draft weighting toward character archetypes.** Character bias is expressed visibly through starting items and relic. Hidden weighting on future drafts is rejected: it collapses the synergy decision (drafts pre-filter to your archetype = no real choice), punishes early experimentation, hides mechanics, reduces variance. If guided drafts are wanted later, do it via explicit milestone commitment moments (player picks an archetype at an act break), never hidden bias.
- Asset reality check: verify candidate monster pack includes matching front-facing portraits, or budget for a separate portrait pack.
-----

## Meta-progression

- **Primary: pool unlocks.** Meta-tree adds items, characters, relics, encounters, depth.
- **Secondary: run modifiers** (character selection, possibly difficulty / starting bonuses).
- **Deprioritize: pure stat boosts.** Vampire Crawlers late-game-collapse problem.
Core principle, ongoing discipline: meta progression adds expressive options, never sufficiency. Unlocks introduce new items / synergies / ways to solve the coverage triage. Unlocks do not grant flat permanent power ("+10% damage forever," "+1 starting HP per level"). Flat-power unlocks are the easiest kind to ship and exactly what lets late-meta players ignore the coverage and synergy constraints — they make the game play itself. Every meta-unlock proposed must be evaluated against this rule. Recurring decision, not one-time.

Meta-tree pacing must match the death curve — early runs end fast and unlock often, late runs slow down. Tune during playtest.

-----

## Scope target

- 3-4 hours total playtime to beat. Single prestige layer.
- Solo dev. Asset-driven art. Godot 4.
- Market timing: piggyback on Vampire Crawlers wake before it saturates.
-----

## Open questions

1. **Boss signature mechanics.** Each needs one to feel different without requiring input layer. Partly resolved: potions + slow-mo-on-hover provide tactical input on bosses; mutual-cascade boards add tactical reading. Confirm in prototype.
1. **Combat readability at scale.** How exactly does the player parse a 30-item cascade in 10 seconds? UI design problem. Zone-based layout + glowing synergy clusters + clean number popups + readable cooldown rings — but need to see it work.
1. **Auto-combat engagement across ~45 encounters per run.** Provisionally yes, based on Loot Loop precedent. The central assumption of the design. Prototype answers it.
1. **Setting / theme — resolved.** Dark fantasy or classic dungeon. Dungeon synth soundtrack, super dark and moody, desaturated palette but juicy mechanics. Asset pack survey now scoped to medieval/gothic/horror packs that match the aesthetic.
1. **Walk pacing.** Walk can't be dead time. Footsteps, atmosphere noises, environmental cues, occasional telegraph. Design once setting is locked. (Open: whether to keep camera bob — coherent now that movement is a walk rather than a glide.)
1. **Terminal-failure stance — resolved (Spire stance).** Drafts and play matter for survival; a bad draft chain can kill a run. The game is *beatable from run 1* on a fresh save with skill and luck. Meta-progression makes the game easier and adds variety/replayability but is not required for completion. Difficulty tunes to "achievable but punishing on a clean save." Death feels like "I drafted/played that wrong," not "I haven't unlocked enough yet."
1. **Item pool composition.** ~100 items is a starting target. Real number derives from "how many archetypes are we committing to, how many items does each archetype need to feel real." First design question to answer once prototype work starts — drives every item-design decision downstream. Test in prototype: does the last draft of a run feel like a decision or a treadmill?
1. **Onboarding.** With status engine, enchants, potions, relics, characters, elites, choice layer, AOE/single-target distinction, color vocabulary, slow-mo, cooldowns — a player parachuted into draft 1 is overwhelmed. Tutorial? Drip-feed unlocks? Genre literacy assumed? Real design question, currently absent.
1. **Relics as items.** Open whether to collapse mechanically. Probably same underlying type with different presentation. Resolve in prototype.
1. **Starting state — TODO.** What does the player start a run with beyond character (portrait + starting relic + 2-3 starting items)? Starting HP value? Starting potions (probably 0)? Other resources? Not yet specified.
1. **Block vs. damage-over-time — resolved.** Whether an effect bypasses block is a **per-effect `unblockable` flag** (varies by DoT — not all DoT bypasses). Specifics are per-effect content.
-----

## Pitfalls / self-notes

- **Battledraft lesson.** Don't design the full item file upfront. Small launch pool, few synergy tags, build prototype around those. Add more after the core loop is fun.
- **Scope creep watch.** Combo items, character pools, encounter writing, boss bespoke mechanics, enemy variety — all fun to design, easy to over-invest in. Enemy variety especially: "make until it feels like enough" is the right method but also the biggest open-ended art-and-design cost in the doc. Hold each to the "easy multiplier" bar.
- **Constraints did the work.** Don't relax constraints later just because they were "for the prototype." The constraints are the game.
- **Don't copy Spire patterns whose mechanism you removed.** Spire's best feelings (routing depth, early-cards-become-deadweight, take-vs-cut tension) emerge from constraints this game deliberately discards (branching routes, deck dilution, size cap). Copying the content without the structure delivers the bad half (regret, flatness) without the half that justified it. Every time a Spire idea is admired, ask "what mechanism made that bite, and do I have it?" If not, manufacture an equivalent from a mechanism this game does have (almost always: encounter design).
- **Reject hidden systems.** Hidden draft weighting toward existing build / character archetype was rejected. Players don't perceive hidden help; they only perceive failure. Bias goes in visible places (starting items, explicit milestone commitments, named archetypes), never in opaque pool reweighting.
- **Keep auto-targeting predictable.** Leftmost rule, no exceptions, even when it "should" do something cleverer. The moment auto-target makes a "smart" decision the player didn't want, the AI feels like an opponent. *(This is the **actor**-targeting rule. Targeting an enemy *item* — silence, item-debuffs — is a separate axis that defaults to **random** selection, provisional pending testing; random isn't the targeter being "smart," it's a different decision the leftmost rule doesn't cover.)*
- **"Everyone the same" is the laziest fight composition.** Three identical enemies in a row is fine occasionally; if it becomes the default group-fight, AOE strictly dominates focus damage for that comp and the fight stops being a decision.
- **Editorial note to self: avoid emphasis-word inflation.** Earlier drafts of this doc overused "load-bearing," "critical," "non-negotiable," "INVIOLABLE," "READ THIS" and similar. When everything is emphasized, nothing is. Write the design clearly; let the prose carry the weight. If something is genuinely structural, say it once in normal voice.
-----

## Next concrete steps (when AMTKAG ships)

1. Survey monster asset packs — scoped to dark fantasy / classic dungeon / gothic horror.
1. Build the prototype loop **as a playable itch.io build** (not just a private cascade test): one corridor segment, a few placeholder items, one+ enemy, the draft, plus the run controller and encounters/events tying fights together — and localization wired from the start. Aim for something shippable to itch, then play a short run end-to-end.
1. Watch the prototype. Is the cascade satisfying with placeholder art, no progression layer, no meta? If yes, design works. If no, combat needs input or items need richer interaction.
1. Only then: scale to ~25 items, real combat tuning, real corridor art, encounter writing.
-----

*End of snapshot. If you're reading this in 3 months and arguing with past-you about a decision: the decision is captured here. Re-litigate only if you have new information, not new enthusiasm.*
