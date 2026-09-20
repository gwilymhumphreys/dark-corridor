# Decision — Per-Character Item Pools

> Departs from the original single-shared-pool plan (design.md: “one shared item pool across all characters”). Test it like everything else.

## The problem with one shared pool

A 1-of-3 draft with no hidden weighting can only reliably feed a build if the pool has **few synergy directions** — too many and each draft is unlikely to offer something that connects, so the pool goes thin. But few directions caps the whole game’s range. The shared pool forces a choice:

- **Few directions** → drafts connect, but the game is narrow.
- **Many directions** → range, but drafts stop connecting (or you cheat with hidden archetype weighting — already rejected: design.md, “no hidden draft weighting”).

There’s no setting that gives both from one pool.

## The fix

**Per-character pools.** Each run exposes only one character’s directions (so drafts stay focused and connective), while the game holds N× that across the roster (so it has range). The tradeoff dissolves because focus and range now live at different scopes — per-run vs. per-game.

Consequence: pools can be **smaller per character** (a few coherent directions each, not one giant pool spanning all of them), and the character’s identity goes deep in ways a shared pool can’t — unique synergies that wouldn’t fit alongside everyone else’s.

## Scope effect

- **More at release** — multiplies the most content-heavy layer across the roster. Real cost; offsets the lean-content ethos.
- **Less for demo/playtest** — one character’s small, coherent pool is *less* content than a slice of a 100-item shared pool, **and a sharper test**: three coherent directions answer “is the draft a decision” cleanly, where a thin slice of a shared pool reads as incoherent.

## Hybrid considered and rejected

A shared neutral pool of workhorse commons (StS colorless model) + per-character synergy/anchors — to cut the scope multiplier. **Rejected:** it works for StS because StS’s neutral cards are thematically null. Ours wouldn’t be — a character pays an onboarding tax for a strong identity (e.g. the spore Druid), and generic shared commons fight that identity. The “answer the combat questions before synergy” need is met *within* the character’s own pool (its spore appliers are also its damage and shield), so a neutral layer isn’t required and costs identity.

**Refinement (2026-06-07): the colorless *layer* is what’s rejected — not colorless *items*.** Dropping the hybrid means we don’t lean on a shared neutral commons tier as the *structural* scope-saving device. It does **not** ban individual colorless items: some items may still be colorless — character-agnostic utility, or an item that simply fits several characters’ pools — where they earn their place. The line to hold: colorless items can’t quietly grow into the workhorse-commons crutch the model above rejects, or the hybrid is back through the side door. So colorless is allowed as the *exception that earns it*, never the *default tier characters depend on*. Held loosely; test in prototype.

## Build impact

**None to systems.** `Draft` already pulls from “the pool” and is category-blind (architecture: Draftable contract). Scoping the pool to a character is a content-organisation change, not a systems change.

## Poison, bleed and burn reach every character (owner, 2026-09-21)

Every character should have some access to poison, bleed and burn, so those three are always an
option for a build rather than one character's property, and so they carry synergies that cut
across characters.

This sits on top of the model above rather than replacing it: the three are damage-over-time
mechanics any pool can hold, not a workhorse commons tier, so it does not reopen the hybrid
rejected above. The line to hold is the same one — this stays a handful of shared axes, not a
neutral layer characters depend on.

**Open:** whether the access comes from the colorless pool, from a few appliers authored into each
character's own pool, or both. Authoring them per character keeps each one in that character's
fiction, which the colorless route cannot do; the colorless route is less work and guarantees the
access is really there. Undecided.

## Watch

- **Directions per character is a starting peg, not a number.** Too few → drafts forced; too many → dilution returns inside one character. Interacts with skip-for-gold (#33) / no-cap in ways paper can’t predict — resolve in prototype.
- **Hold the line on what gets split.** Per-character *item pools* — yes. The pull toward per-character *everything* (relics, enemies, bespoke commons) is exactly the Battledraft scope trap (design.md). Enemies stay a shared pool; only the layer that actually needs depth gets split.
