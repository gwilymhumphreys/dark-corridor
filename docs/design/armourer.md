# Armourer — Working File

> The roster's **on-ramp / starter** character. Working doc — add cards as they come, cull to a
> pool later. Targets in [`card_pool_targets.md`](card_pool_targets.md), held loosely. Promoted from
> the [parking lot](character_ideas.md) 2026-07-04 (owner); its mechanical ancestor is the parked
> *Spiked Shield / Retributive Block* entry — this is the **simple** use of block, that one the spicy.

**Concept (owner):** a big **block**-oriented fighter — a figure who has fused overlapping bits of
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

**Affordance — the highest on the roster.** *Armour = block* is about the tightest theme→mechanic
map that exists (a player guesses the mechanic from the fiction alone — the affordance screen in
[`character_ideas.md`](character_ideas.md)). That legibility is *why* it's the right anchor. The one
place to be deliberate is the **spend side**: "spend armour → deal damage" isn't as self-evident as
"armour = defence," so lean the spender fiction on something that affords it — a **shield bash**,
**hurling a plate**, a **guard-break counter** — so the player intuits "this attack eats my block."

**Fiction — relaxed for the on-ramp.** The overlapping-fused-plates image reads instantly; kept as a
**scavenger in layered armour** (not fused body-horror), which also dodges two collisions the parking
lot flagged: the **Mech's** flesh-fused-to-metal body and the **Fleshmancer's** board-of-parts. The
overlapping plates stay pure visual flavour; no horror needed.

---

## Structure — 3 overlapping archetypes (goal, held loosely)

Aim for **~3 archetypes that overlap** (a card can serve two) — the pool-breadth goal, not a quota
(see [`card_pool_targets.md`](card_pool_targets.md)). Only one is decided:

1. **Spend armour (decided).** The signature engine: build block (armour), then spend it — an attack
   or effect that **consumes block** for its payoff. Block stops being only defence and becomes
   *ammo*, with a real decision baked in: **spending it trades away your safety** (offense vs.
   defence on one resource — not win-more).
2. **TBD — candidate: weapon synergies.** A simple weapons thread (owner floated this) — nothing
   bespoke, the legible half of a legible character.
3. **TBD — candidate: a strength / scaling line.** A basic damage-scaling idea (owner floated this).

Candidates 2–3 stay open — "weapon synergies or strength or something, tbd" (owner). Keep them
**simple**: this is the low-load character, so its non-signature threads should be the kind a player
reasons about at a glance.

## Engine seam — block-as-fuel is nearly free (verified 2026-07-04)

- **Block is a `PoolStatus`** (`src/content/statuses/block_status.gd`): an absorb pool that soaks
  incoming damage and is removed when emptied. Stacks additively on reapply. **Combat-scoped** — it
  resets every fight (#26), so any *cross-run* "layer up your armour over a descent" would be a
  relic/enchant, not the block status.
- **Spending block rides the built consume seam.** The Spore Druid's Mass fuel uses
  `StatusManager.consume(target, id, amount)`, gated by each status's `is_fuel()`. `Spores` opts in
  with a one-line `is_fuel() -> true`; **block does not (yet).** So "spend N block for an effect" is:
  make block fuel-eligible (the one override) + author the spender items — **no new engine.**
  Consuming block spends its absorb `count`, i.e. spending armour literally removes that defence —
  which *is* the intended tradeoff.
- **Block generators are a solved pattern.** Plain self-block items already exist (the Fleshmancer's
  bone spread — Rib / Femur / Skull); the Armourer's armour pieces follow the same shape.

## Watch / open

- **Win-more guard (carry forward).** The trap for a block character is payoffs that key off
  **block-on-hand** (strongest when you're already safe — e.g. "deal damage equal to your block"
  while *keeping* it). The cure: tie payoffs to **spend / absorbed-damage flow**, not the stockpile.
  Consume-to-hit avoids it for free. (The parked *Spiked Shield* entry worked this out in full.)
- **Which are archetypes 2 and 3?** Weapon-synergy and strength/scaling are candidates, not decided.
- **Does it become the new default character?** (Replacing `wanderer` as autostart + autotest
  baseline.) Likely yes — confirm on build.
- **Relationship to the parked block character.** *Spiked Shield / Retributive Block* is the
  **spicier** use of block (thorns / charge off absorbed damage — needs an unbuilt on-absorb seam).
  Only one block character likely ships; the Armourer (stack/spend) is the one being pursued. That
  engine is salvageable as a relic / item / later variant, not lost.

## Authored so far

Nothing in code yet — concept + engine plan only. No `CharacterCatalog.ARMOURER` def, no item pool,
no items. Next small step (offered): the **core one-liner** (build block → spend it for damage) + a
**starting 3-item kit** (a block generator, a block-spending attack, a plain weapon or second armour
piece — the 3-item floor the other characters get).
