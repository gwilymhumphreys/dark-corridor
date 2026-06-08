# Character Ideas — Parking Lot

> **Uncommitted.** A holding pen for character/class concepts so they don't get lost.
> Nothing here is decided, scheduled, or implied to ship. Ideas graduate to their own
> working file (like [`spore_druid.md`](spore_druid.md)) only when the owner
> chooses to pursue one — most should stay parked.
>
> Read each through the **recombination** lens ([`influence_dcc.md`](influence_dcc.md)):
> fuse two recognisable things from different domains so both stay recognisable, and let the
> fused premise *be* the signature mechanic — not a fantasy-trope class with a paint job.
>
> **Promotion has a real cost.** Each character carries its **own item pool** (decision
> #27, [`per_character_pools.md`](per_character_pools.md)) — a full breadth target
> ([`card_pool_targets.md`](card_pool_targets.md)) of ~18–22 authored items. So the bar
> isn't "is it cool," it's "does it earn a whole pool — a distinct way to play no other has."
>
> Sounding-board notes (**Fusion / hook**, **Risk / open**) are *options to react to*,
> not proposals — pitched, not chosen.

---

## Spore Druid — **promoted**

Has its own working file: [`spore_druid.md`](spore_druid.md). The first character.
Listed here only so the parking lot reads as the full set. Fusion: fungus meets druid → a
status-identity engine (spores), not warrior/mage/rogue.

---

## Blade Mage / Steel Mage — *parked*

- **Concept:** lots of weapons — plays like a fighter but isn't a "fighter" trope class.
  Working name "Steel Mage" or similar.
- **Fusion / hook:** a *mage* whose spells **are** weapons — doesn't equip and swing steel,
  but conjures / suspends / launches it. The fusion is "arsenal as spellbook." Candidates:
  weapons that temper or consume each other, a forge/whetstone sub-engine, blades that stack
  into one big strike.
- **Risk / open:** the whole game is already item-boards of weapons — *every* character holds
  weapons. So "lots of weapons" isn't yet an identity; it needs the weapons to do something to
  *each other* (temper, consume, combine into one strike), not just the baseline board with the
  volume turned up. That's the design problem to crack before this graduates.

## Wizard — *parked (resource-economy character)*

- **Concept:** a wizard of some sort with a **mana** mechanic. Owner's reframing: card games
  spend cards/energy as resources; we don't have those — we inherit **time** (cooldowns) as our
  one natural resource. So a mana layer isn't a duplicate clock, it's a *second, added* resource
  with **producers and consumers you balance**. Starting point: one given resource (time), and
  items that manipulate a second.
- **Fusion / hook:** mana is a **stock** economy (a shared pool that fills and dumps) layered on
  top of the **flow** economy (cooldowns, decentralized + automatic). It *couples the board*
  in a way cooldowns can't — one item's output is another's fuel through the pool. Distinct from
  the druid too: the druid's stock lives **on a target** (spores → Mass); the wizard's stock
  lives in a **player-side pool**. Different location, different coupling — no collision. See
  [Cross-cutting](#cross-cutting--resource-economies).
- **Risk / open:** the engine is sound and unclaimed; "generic" has collapsed from *mechanical*
  to *cosmetic*. The only generic thing is the **word "mana"** and a bland caster. Gate is
  flavour, not mechanics — give the stock a grim identity (blood, pressure, charge, rot, debt)
  and a grim spender. Owner's original instinct ("if the flavour's unique enough") was the whole
  ballgame.

## Black Hole — *parked*

- **Concept:** a person who replaced their head / eyes / brain with a **black hole**. Gravity
  magic, void, or similar.
- **Fusion / hook:** body horror meets cosmic void — reads instantly and lands grim, very on-tone
  for the bestiary touchstone. Signature mechanic = **pull / singularity**: drag enemies, displace,
  crush, swallow. Note it could reuse the already-built **consume** mechanism (the spore engine's
  Mass fuel) for a "feed the void" payoff — gravity as a consumer rather than a damage type.
- **Risk / open:** strongest tone fit of the batch; the design question is what "gravity" *does*
  mechanically that block/damage/status don't already cover — what's the void's unique state.

## Mechanic — *parked (owner-flagged overdone)*

- **Concept:** a little creature piloting a mech. Owner's flag: maybe overdone — what makes it
  interesting?
- **Fusion / hook:** the trope is overdone when the mech is just "big robot." De-trope by making
  the **pilot and the machine grim and specific**: a tiny, fragile creature in a scavenged,
  failing rig — or the "mech" is something horrible being puppeted (a corpse, a caged beast, a
  dead god's body). The interesting play is **maintenance under fire** — patch/jury-rig/overheat
  as the engine, parts that break mid-fight, held together with spite — not "stomp."
- **Heat (the resource hook):** a MechWarrior-style heat economy — **capacity** and
  **dissipation** as *separate* properties, and **every weapon adds heat when it fires**. It's a
  *pressure* resource (you fight to keep it **low**), the inverse of the wizard's mana — which is
  exactly what makes it a distinct character despite both being pool-stocks. See
  [Cross-cutting](#cross-cutting--resource-economies) for the polarity / two-knob / global-vs-
  bonded-pair axes. Owner flag: a route to consider, not chosen. (A *bonded-pair* heat
  sink↔weapon variant is the richer-but-heavier structure — it needs an item-link primitive the
  engine doesn't have.)
- **Risk / open:** if it stays "robot," it's a generic-class fail like the wizard. The creature +
  the failing-machine relationship is what would carry it.

---

## Cross-cutting — resource economies

A chassis several ideas share — worth holding as its own lever rather than re-deriving per
character. A "resource" character isn't one knob; it's a few independent **axes**, and different
combinations *feel* like different characters. We start with one natural resource — **time**
(cooldowns/Tickers), a **flow**: decentralized, automatic, no pool you spend from. A "resource"
character adds a *second* resource as a **stock** that items produce and consume, coupling the
board through an economy (one item's output is another's fuel) in a way flow can't.

**The axes**

- **Polarity / trend.** *Savings* — want it **high**, build-then-dump, soft failure (mana,
  spores → Mass). *Pressure* — want it **low**, use pushes **up**, a **ceiling** punishes → shed
  it (heat). *Depletion* — want it **high**, use pushes **down**, a **floor** gates → refill it
  (ammo; **HP**, whose floor is *death*). Heat and ammo are mirrors: one use-driven economy
  failing at opposite ends.
- **Location.** *On a target* (spores) · *player-side pool*, one shared gauge (mana, heat,
  void-mass) · *per-item*, N small gauges (ammo — empty = that item goes **silent** mid-fight, so
  the pool needs reloaders or it stalls) · *on the Actor*, the pre-existing universal one (HP).
- **Timescale.** *Combat-scoped* — resets each fight, the default (cf. statuses #26): spores,
  mana, heat, ammo. *Run-scoped (meta)* — persists in run-state across encounters (the
  relic/enchant persistence layer): **gold**, cached in fights and spent at shops, shifting the
  decision horizon from tactical to economic. **HP is both** — in-fight buffer *and* run-level
  attrition.
- **Two knobs.** A use-driven resource splits into **capacity + refill rate**: heat = capacity +
  dissipation, ammo = max-ammo + reload-rate, HP = max-HP + regen. Two draft axes off one number.
- **Support family.** Each pressure/depletion resource drags a no-offense role into its pool —
  venter (heat), reloader (ammo), lifegain (HP), shop-sink + generators (gold). Picking the
  resource commits you to authoring its support family (cf. Mass needing appliers).
- **Coupling & engine cost (light → heavy).** Global meter (one gauge, all items r/w — light,
  likely a player-side status + on-fire hooks + threshold; **check**) · per-item reload (a
  reloader **targets** an item — the friendly twin of HEX_BOLT's built `OPPONENT_ITEM_RANDOM`; the
  charge counter + empty-gate + restore-ammo effect are new) · bonded pairs (item↔item links — needs
  a new **bond primitive**) · economy subsystem (gold — shops + sink + run-state, the heaviest; a
  game-structure decision).

**Resources so far**

| Resource | Trend | Location | Timescale | Support | Engine cost |
|---|---|---|---|---|---|
| Spores | savings | on target | combat | appliers | **built** |
| Mana | savings | player pool | combat | generators | new pool |
| Heat | pressure (ceiling) | player pool | combat | venters | light–med (**check**) |
| Ammo | depletion (floor) | per-item | combat | reloaders | med (HEX_BOLT path + gate) |
| Gold | savings → spend | run-state | **run / meta** | shop sink + generators | **heavy** (subsystem) |
| HP | depletion (**death**) | the Actor | **both** | lifegain | **~free** (exists) |
| Allies | build + attrition | roster *(object)* | combat / run if persistent | healers, death-payoffs | summon mechanism **built**; costs board space |
| Items / potions | build → consume | board *(object)* | combat | the item-makers | mid-fight board mutation (**check**) + loop guard |

**Number vs object resources.** Most resources above are a **number** (mana, heat, ammo, gold, HP).
**Allies** and **items/potions** are **objects** — the resource is a live *game entity* (an Actor,
an Item) spawned and consumed on the board. Three consequences:

- **They nest + compose.** An object carries its own sub-state, itself a resource: an **ally** is a
  symmetric Actor with its own **HP** (which depletes) and its own **board** — so it can run *any*
  other resource (an ally holding ammo, a summon you sacrifice for a burst, a thrall venting heat).
  Object resources stack *on top of* the number ones rather than competing with them.
- **They reuse big systems, not a new counter.** Allies ride the **already-built** summon /
  mid-fight roster mechanism ([`spore_engine_prd.md`](../project/spore_engine_prd.md)) on the
  symmetric Actor — the druid's Summon pillar is one instance. Items/potions ride the **Item board
  + Consumable** path. So the cost isn't a new pool — it's **board/screen space** (the framed view
  shows ~1–2 bodies today) and **mid-fight board mutation** (adding an Item to a live board — a
  cousin of roster-add; **check** it's wired).
- **Objects that make objects invite loops** (items spawning items, allies spawning allies). The
  tick is already designed not to loop (accrual-only triggers, the Bazaar lesson —
  [`combat_prd.md`](../project/combat_prd.md)), but a cascade that never settles is the balance
  risk to watch. Obvious homes to avoid: allies → *necromancer*; items → *artificer / alchemist*.

**Two reframes**

- **Gold's cost is a subsystem, not a character.** It needs shops-as-encounter + a sink + gold in
  run-state — a *game-structure* decision above the character layer (mind the Battledraft scope
  trap, [`per_character_pools.md`](per_character_pools.md)). But **if** that economy exists for
  everyone, a "greed" character is cheap: a pool of gold-**generators** (trade power → cached
  gold) + gold-**spenders** (gold as in-fight ammo — spicy, can death-spiral).
- **HP is gold's inverse — nearly free, highest-stakes.** Reuses the Actor's life total +
  heal/regen/max-HP, no new pool; double-booked as both the resource *and* the lose-condition —
  which is the tension. It's the druid's masochist Self sub-line ([`spore_druid.md`](spore_druid.md))
  generalized, with the same knife-edge (too cheap = free power, too costly = a trap).

**Screen for the trawl — `resource + theme`.** A resource is a reusable part, not an identity. A
character is a resource dressed in a theme, and it passes only if both land:

1. **Resource** — place it on the axes (polarity / location / timescale / coupling): tells you its
   cost + what it collides with.
2. **Theme** — the fiction it wears. Recombination ([`influence_dcc.md`](influence_dcc.md)): every
   resource has an **obvious home** — the theme everyone already pictures for it. Put it **anywhere
   but there**, so resource and theme come from different domains and you can still see both. The
   obvious pairing isn't wrong because it's copied — it's weak because both halves share a domain,
   so the two don't really fuse.
   - HP on a **warrior** = the obvious home (StS Ironclad) — *don't*.
   - HP on a **vampire / blood mage** = on-theme but **single-domain** (life-drain is the expected
     pairing — evocative, but it's one idea, not two).
   - HP on a **fleshmancer** (flesh as crafting substrate — necromancy meets sculpture) or a
     **priest** (bleeds for miracles — piety meets gore) = real recombination, two distant domains;
     priest is spiciest + most on-tone.
   - Every resource has one to avoid: heat → mech, mana → wizard, ammo → gunner, gold → merchant.
     **"No generic classes" = "don't put a resource on its obvious home."**

A resource isn't one move — it's a **space**. A character's pool fills with many items that touch the
resource different ways: spend it (several ways), generate it, convert it, or just **manage** it
(heat). The design work is populating that space across a pool, not pinning the character to a
single signature action.

---

## To add

- **D&D subclass trawl** (owner) — mine subclasses for more seeds; drop concepts here as they come.
