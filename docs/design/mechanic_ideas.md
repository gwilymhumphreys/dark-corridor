# Mechanic Ideas — Parking Lot

> **Uncommitted.** A holding pen for *mechanics* sampled from other games (the way
> [`character_ideas.md`](character_ideas.md) parks character concepts). Nothing here is
> decided or scheduled. A mechanic graduates only when the owner attaches it to a character /
> status / item and chooses to build it — most should stay parked. Ideas that close move to
> [Retired](#retired) with the reason and anything salvageable.
>
> **Mechanics vs. characters.** A character is a *resource dressed in a theme*
> ([`character_ideas.md` → resource economies](character_ideas.md#cross-cutting--resource-economies));
> a mechanic here is a smaller part — a status rule, a trigger, a cost — that could slot into a
> character's pool or the shared baseline. Record the **source game**, the **rule as seen**, and a
> sounding-board read (where it fits our built systems, what it would cost to wire).
>
> Sounding-board notes (**Read**, **Engine cost**, **Open**) are *options to react to*, not
> proposals — pitched, not chosen.

---

## Bleed — *built (source: grail, 2026-06-21)*

- **Rule as seen:** each time an item activates, the holder takes damage equal to **bleed**, then
  bleed is reduced by 1. A stacking value that pays itself down as the board fires.
- **Direction (owner, 2026-06-21): an ENEMY debuff you apply, with synergies around it.** Bleed
  reads better as something you put *on the enemy* (its own attacks bleed it out) than as a status
  on yourself. (A self-bleed version was considered and set aside for *this* mechanic — not a
  blanket rule against self-statuses.) So: you stack bleed on the enemy, and the enemy's own attacks
  bleed it out.
- **Read — attack-paced (a new clock for us).** Existing statuses run on *time* (poison/burn) or
  *incoming damage* (shield); bleed advances when the **bleeding actor is hit by an attack** — the
  enemy's incoming damage cashes it out. Because of the `−1`, one application is a fixed triangular
  burst (bleed 5 → 5+4+3+2+1 = 15 over five attacks landing on it, then gone): fixed **total**, but
  the **rate** tracks how often it is struck — gushes against a fast multi-attacker, trickles against
  a slow one-big-hit boss. Good texture (rewards reading the enemy), a feast/famine balance watch.
- **The `−1` paydown is the engine for synergy.** Left alone, bleed winds down to nothing, so the
  synergy space is *fighting the decay* two ways: **burst** (dump a big stack so the triangular
  total is huge) vs. **sustain** (re-apply faster than it pays down → a standing wound). Two
  draftable sub-strategies off one status.
- **Synergy space ("around it"):**
  - **Appliers** — stack bleed (the spore-applier equivalent); fast-small vs. slow-big appliers
    split the burst / sustain poles.
  - **Payoffs / cares-about-bleeding** — items that key off the enemy *being* bled or off a bleed
    tick ("+X vs. a bleeding enemy"; "when it bleeds, gain shield") — the distinct-status-cares
    mechanism, like the Spore Druid's spread cards.
- **Built (2026-06-22; trigger changed 2026-09-17).** `BleedStatus` + the actor-level
  `on_holder_attacked(target, ctx)` hook: the Combat manager runs the target's statuses through it
  when an **attack lands on the target** (the attack mechanic's `land`, only if the target survives).
  The bite goes through `take_damage` carrying the applier's flags, so an UNBLOCKABLE bleed bypasses
  the holder's own shield (#5); it shows a DoT-style wall visual + a combat-log line — like a poison
  tick, it publishes **no** bus event, so a future bleed *payoff* would read a hook, not a
  subscription. First applier: **Bone Spear** (Fleshmancer pool; 6s, damage + 3 bleed, unblockable).
  Tempo reading = how often the holder is **struck** (the original reading was the holder's own item
  fires; the trigger moved to attacks received in the mechanics plan).
- **Open / tune:** the **Fleshmancer** is its tentative home but uncommitted (see
  [`character_ideas.md`](character_ideas.md)); Bone Spear's numbers are placeholders (`/tune`); bleed
  defaults **unblockable** via the applier flag (a blockable applier could omit it — the lever is
  per-effect); no dedicated bleed colour yet (reuses DAMAGE — owner's tint).

---

## Curses — *parked (source: Slay the Spire, 2026-06-21)*

- **Source rule:** items that carry a **negative effect**. In Slay the Spire a curse is a card you
  don't want — clogs the deck, often unplayable, sometimes with an active downside; acquired from
  events / certain enemies, scrubbed at shops/events.
- **Translation to us — board-slot cost, not hand-clog.** We have no deck/hand; items sit on the
  board and auto-fire on cooldowns. So a curse's cost isn't deck dilution — it's **a board slot
  occupied** + a bad effect on a timer. Board space is the scarce resource, so a slot doing
  something *negative* (or nothing) is the penalty.
- **Two readings:**
  - **Pure curse (forced negative):** an item you're saddled with — buffs the enemy, debuffs you
    each fire, or just wastes a slot. From events (a Faustian reward) or boss/enemy afflictions;
    the play is mitigate-or-remove. Never appears as a draft reward (StS curses aren't card
    rewards).
  - **Tradeoff item (net-positive with a downside):** a strong item carrying a curse-like tax —
    "big hit but you take some," "fast weapon but it Weakens you." Draftable *because* the upside
    pays for it. (A natural home for a negative **self-status**, now that those aren't off the
    table.)
- **Reuses what's built.** A negative effect is just an ItemEffect (self-damage already exists; an
  effect could heal the enemy, debuff your own board, etc.). A curse that **wears off** could ride
  the new Decay use-status ([`item_creation_and_decay.md`](../systems/item_creation_and_decay.md)) —
  a temporary affliction that expires after N activations — instead of needing a removal service.
- **Open:** the acquisition path (grant a run-scoped board item *outside* the draft — check it
  exists); removal vs. self-expiry; whether curses are a shared category (from events + enemies,
  any character) or character-flavoured; how a forced item interacts with a full board.

---

## To add

- Mechanics from other games as they're sampled — record the source, the rule as seen, and the read.

## Retired

> Ideas taken off the bench — kept so they aren't re-pitched from scratch, with the reason. A
> retired mechanic's good parts get credited to wherever they went.

*(none yet)*
