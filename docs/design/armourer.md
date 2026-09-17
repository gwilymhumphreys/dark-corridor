# Armourer — Working File

> The roster's **on-ramp / starter** character. Working doc — add cards as they come, cull to a
> pool later. Targets in [`card_pool_targets.md`](card_pool_targets.md), held loosely. Promoted from
> the [parking lot](character_ideas.md) 2026-07-04 (owner); its mechanical ancestor is the parked
> *Spiked Shield / Retributive Shield* entry — this is the **simple** use of shield, that one the spicy.

**Concept (owner):** a big **shield**-oriented fighter — a figure who has fused overlapping bits of
scavenged armour to themselves (helmets, breastplates, greaves, all layered). Basic weapons and
armour, one clean twist: **stack armour, then spend it.**

**Role — the low-load anchor (owner, 2026-07-04).** Deliberately the roster's **on-ramp** (the Slay
the Spire *Ironclad* slot): the one character that imposes little new-concept load, so a new player
learns *this game's* systems — fixed-step auto-combat, cooldown Tickers, drafting — before a bespoke
resource engine is layered on top. Even a genre veteran hasn't played *our* combat model; the anchor
teaches it. **This is a `legibility-load` choice, not a `weirdness` choice** — the two are separate
budgets (see [`character_ideas.md` → Complexity vs. distinctness](character_ideas.md)): the Armourer
is mechanically light but its fiction can stay distinct.

**Successor to the Wanderer placeholder.** "The starter" most likely means it **replaces `wanderer`**
as the roster-leading / autostart / autotest-baseline character (the Wanderer's def exists to be
replaced by a real character). Confirm the role when it's built. Once the Armourer + a second real
character are solid, both the `wanderer` and `duelist` placeholders can go.

**Name:** *Armourer* is the owner's **working concept label** (like *Fleshmancer* was) — a Vermis-
register display name (oblique, mournful, does not telegraph the mechanic) comes later. Internal
id / file stay `armourer` until renamed.

**Affordance — the highest on the roster.** *Armour = shield* is about the tightest theme→mechanic
map that exists (a player guesses the mechanic from the fiction alone — the affordance screen in
[`character_ideas.md`](character_ideas.md)). That legibility is *why* it's the right anchor. The one
place to be deliberate is the **spend side**: "spend armour → deal damage" isn't as self-evident as
"armour = defence," so lean the spender fiction on something that affords it — a **shield bash**,
**hurling a plate**, a **guard-break counter** — so the player intuits "this attack eats my shield."

**Fiction — relaxed for the on-ramp.** The overlapping-fused-plates image reads instantly; kept as a
**scavenger in layered armour** (not fused body-horror), which also dodges two collisions the parking
lot flagged: the **Mech's** flesh-fused-to-metal body and the **Fleshmancer's** board-of-parts. The
overlapping plates stay pure visual flavour; no horror needed.

---

## Structure — 3 overlapping archetypes (goal, held loosely)

Aim for **~3 archetypes that overlap** (a card can serve two) — the pool-breadth goal, not a quota
(see [`card_pool_targets.md`](card_pool_targets.md)). Two are decided:

1. **Spend armour (decided).** The signature engine: build shield (armour), then spend it — an attack
   or effect that **consumes shield** for its payoff. Shield stops being only defence and becomes
   *ammo*, with a real decision baked in: **spending it trades away your safety** (offense vs.
   defence on one resource — not win-more).
2. **Big slow weapons + the empower payoff (decided 2026-07-09).** The signature weapons thread: a
   ladder of **big, slow weapons** (5s / 6s / 7s cooldowns, *similar* DPS) whose payoff is an
   **empower** skill that doubles the next **weapon attack**. Because per-hit size (not DPS) is what
   the empower rewards, the three form a **per-hit ladder** — at equal DPS the slowest has the
   biggest single hit, so it's the best thing to double. This *inverts* "slow = weak": the slowest
   weapon is the most prized. Clean role that falls out: big doubled hits **overkill** small enemies,
   so the build is **boss/elite-focused, soft vs. swarms**. See *The empower engine* below.
3. **TBD — candidate: a strength / scaling line.** A basic damage-scaling idea (owner floated this).

Candidate 3 stays open — "strength or something, tbd" (owner). Keep the non-signature threads
**simple**: this is the low-load character, so they should be the kind a player reasons about at a
glance.

## Engine seam — shield-as-fuel is nearly free (verified 2026-07-04)

- **Shield is a `PoolStatus`** (`src/content/statuses/shield_status.gd`): an absorb pool that soaks
  incoming damage and is removed when emptied. Stacks additively on reapply. **Combat-scoped** — it
  resets every fight (#26), so any *cross-run* "layer up your armour over a descent" would be a
  relic/enchant, not the shield status.
- **Spending shield rides the built consume seam.** The Spore Druid's Mass fuel uses
  `StatusManager.consume(target, id, amount)`, gated by each status's `is_fuel()`. `Spores` opts in
  with a one-line `is_fuel() -> true`; **shield does not (yet).** So "spend N shield for an effect" is:
  make shield fuel-eligible (the one override) + author the spender items — **no new engine.**
  Consuming shield spends its absorb `count`, i.e. spending armour literally removes that defence —
  which *is* the intended tradeoff.
- **Shield generators are a solved pattern.** Plain self-shield items already exist (the Fleshmancer's
  bone spread — Rib / Femur / Skull); the Armourer's armour pieces follow the same shape.

## The empower engine — the weapons payoff (decided 2026-07-09)

**Mighty Blow** *(placeholder name — owner's to rename)* — a **skill** (an action, not an object: the
Armourer's "do something" slot, the martial twin of the Elementalist's spells). It **charges** (a
plain cooldown — a metronome, decided 2026-07-09) and each fire applies a self-buff: **double the
next weapon attack**.

- **Weapon-scoped** (owner) — only a *weapon* attack is doubled; a spell/skill attack wouldn't
  benefit. That scoping is exactly what the `weapon` tag is for.
- **Stacks by proc count** (owner — "the default for triggered effects like this"): a **consumed
  counter** (like shield / spores — no timer, persists until spent). **Consume rate (decided):** one
  charge per weapon attack — banking N charges doubles the next N weapon attacks (not all-charges-on-
  one-hit, which would be a spiky ×2ⁿ nuke).
- **The auto-combat twist that makes the archetype:** you can't *choose* which attack is "next" — it
  lands on whatever weapon is off cooldown first. So **board composition is the control**: few, big
  weapons ⇒ "next weapon attack" is reliably a big hit. Bad with fast weapons, great with big ones —
  that emergent constraint *is* the deckbuilding identity.
**Starting numbers** *(placeholder — `/tune`'s job; names are the owner's)*. Following the built DPS
curve `DPS ≈ cooldown + 3` — the mild ascent that keeps DPS "similar" while per-hit climbs:

| Cooldown | DPS | Per-hit | Doubled |
|---|---|---|---|
| 5s | 8 | 40 | 80 |
| 6s | 9 | 54 | 108 |
| 7s | 10 | 70 | **140** |

Per-hit climbs while DPS stays close, so the 7s is the prime empower target and a doubled 7s (~140)
is the boss-breaker that defines the build. **Mighty Blow's cooldown** starts ~5s — the uptime knob
(slower rations the empower, faster banks charges).

- **Open:** the three weapons' + Mighty Blow's names (owner's); final numbers + Mighty Blow cadence → `/tune`.

**Terminology (settled):** *"attack"* = the act of dealing damage; *"weapon attack"* = an attack from
a weapon-typed item. No bespoke jargon.

**Type tags:** the game-wide item-type taxonomy (decision #34 / [`../systems/item.md`](../systems/item.md))
— inert synergy labels `weapon / armour / spell / skill / trinket`, an array per item. The Armourer
surfaces **weapon** + **skill** (kept lean — it's the on-ramp).

**Engine seam the empower needs** (verified 2026-07-09; **BUILT — decision #35, see *Authored so far***): the doubling happens at fire time
(`Item._resolve_effect` → `StatusManager.modify_outgoing`), but that hook gets only the **actor**, not
the firing item — so the item's `types` must be threaded in to tell a weapon attack from a spell
attack. And `modify_outgoing` doubles as the **read-only tooltip preview** (`Item.display_value`), so
it must stay pure — the **consume** (spend a charge) belongs on the real-fire hook
`on_owner_item_fired`, not in the modifier. Weak dodges this (blanket, no scope, no
consume); this is the first type-scoped one-shot synergy, so build the seam cleanly — future
"your weapons / skills…" effects reuse it.

## Watch / open

- **Win-more guard (carry forward).** The trap for a shield character is payoffs that key off
  **shield-on-hand** (strongest when you're already safe — e.g. "deal damage equal to your shield"
  while *keeping* it). The cure: tie payoffs to **spend / absorbed-damage flow**, not the stockpile.
  Consume-to-hit avoids it for free. (The parked *Spiked Shield* entry worked this out in full.)
- **Which are archetypes 2 and 3?** Weapon-synergy and strength/scaling are candidates, not decided.
- **Does it become the new default character?** (Replacing `wanderer` as autostart + autotest
  baseline.) Likely yes — confirm on build.
- **Relationship to the parked shield character.** *Spiked Shield / Retributive Shield* is the
  **spicier** use of shield (thorns / charge off absorbed damage — needs an unbuilt on-absorb seam).
  Only one shield character likely ships; the Armourer (stack/spend) is the one being pursued. That
  engine is salvageable as a relic / item / later variant, not lost.

## Authored so far

**The empower engine + the 3 big weapons are BUILT (2026-07-09) — authored but UN-POOLED.** The
fire-pipeline **seam is in** (decision #35): the firing `Item` is threaded into `modify_outgoing`
(kept pure — it also runs the tooltip preview) and `on_owner_item_fired` (the real-fire consume), so
a status can scope to a weapon attack via `item.def.types.has(ItemType.WEAPON)`.

- **`EmpoweredStatus`** (`src/content/statuses/empowered_status.gd`, id `empowered`) — a consumed
  counter: `modify_outgoing` doubles a `weapon`-tagged attack payload while a charge is banked (pure,
  ×2 of ONE attack); `on_owner_item_fired` spends exactly one charge per weapon attack (banking N
  doubles the next N). Registered in `StatusRegistry`. `EMPOWER_MULT` = 2.0 (`Balance`, placeholder).
- **Mighty Blow** (`mighty_blow`, `[skill]`) — a plain-cooldown metronome that applies `empowered`
  to self on fire (banks 1 charge, stacks). Cooldown `Balance.MIGHTY_BLOW_COOLDOWN` (placeholder).
- **The 3 big weapons** (`armourer_broadaxe` / `armourer_warhammer` / `armourer_greatsword`, all
  `[weapon]`) — single-target, opponent-leftmost, 5s/6s/7s, 40/54/70 damage (all `Balance` consts,
  placeholders for `/tune`). PLACEHOLDER names (owner's to rename).

All four are authored in `ItemCatalog` (+ registered in `_build()`) but deliberately **NOT in any
item pool or the colorless pool** (per-character pools, #27) — there is no Armourer character yet, so
they are drafted by nothing. **Still to build:** the `CharacterCatalog.ARMOURER` def + its starting
3-item kit (a shield generator, a shield-spending attack, a weapon — the floor the other characters
get), and the shield-spend archetype (shield made fuel-eligible + spender items — the "nearly free"
seam above).
