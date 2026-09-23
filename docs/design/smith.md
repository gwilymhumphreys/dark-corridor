# Smith — Working File

> The roster's on-ramp character, and the one the character-select screen will lead with.
> Promoted from the [parking lot](character_ideas.md) 2026-09-21 (owner), where it was filed as
> *Executioner / Blacksmith*. It **absorbs the former Armourer**: that character's role, its
> shield stack-and-spend pillar, its empower engine and its authored items all moved here, and
> `armourer.md` was retired into this file. Working doc — add cards as they come, cull to a pool
> later. Breadth signals in [`card_pool_targets.md`](card_pool_targets.md), held loosely.

**Concept (owner):** a straightforward martial character built from weapons, armour and skills.
The figure is a smith and a fighter: basic equipment, improved during the fight by the person who
made it.

**The defining constraint — no second resource.** Every other roster concept accumulates and
spends something the player tracks separately: spores, chunks of flesh, heat, mana. This one does
not. Its skills buff its own weapons and armour over the course of a fight, so what accumulates
sits on the items rather than in a counter beside them. That is the identity, and it is a
different answer to the [resource question](character_ideas.md) rather than an absence of one.

**Role — the low-load anchor.** The Smith is the roster's on-ramp, so a new player learns this
game's systems — fixed-step auto-combat, cooldown Tickers, drafting — before a bespoke resource
engine is layered on top. Even a player who knows the genre has not played this combat model. This
is a legibility-load choice, not a weirdness choice: the two are separate budgets (see
[`character_ideas.md` → Complexity vs. distinctness](character_ideas.md)), so the Smith can be
mechanically light and still have a distinct fiction.

**Roster position (owner, 2026-09-21).** The Smith is `CharacterCatalog.DEFAULT` — the
autostart, the save-resume fallback and the autotest baseline — because it is the character being
balanced first. It is **first** in `CharacterCatalog.ids()`, so it leads the select screen
(added 2026-09-23).

**Name:** *Smith* is the owner's working concept label, as *Fleshmancer* and *Armourer* were. A
display name in the same register as the rest of the roster comes later. The internal id and this
file stay `smith` until renamed.

**Fiction.** A scavenger in layered, overlapping scavenged armour — helmets, breastplates, greaves
— who repairs and improves it as the fight runs. Not fused body-horror, which keeps it clear of
the Mech's flesh-and-metal body and the Fleshmancer's board of parts. Grim-trade rather than
body-horror also gives the roster's tone some range, which the parking lot flagged as
consolidating around flesh.

**Affordance.** Armour reading as shield is about the tightest map from fiction to mechanic
available, and that legibility is why this is the right on-ramp. The place to be careful is the
spend side: "spend armour, deal damage" is not as self-evident as "armour defends you", so the
spender items want fiction that affords it — a shield bash, a hurled plate, a guard-break counter
— so the player expects the attack to eat their shield.

---

## Structure — the card directions (owner, 2026-09-21)

The pool is built from three item kinds — **weapons, armour and skills** — with the skills doing
the work of turning a board into a build. Four threads, which overlap on purpose:

1. **Go tall.** Skills that buff a single weapon, or that pay a bonus while you hold only one
   weapon. The reward for committing the board to one big thing.
2. **Go wide.** Skills that buff all weapons at once, and other support for a board of many
   weapons or tools.
3. **Armour.** Skills and items that use armour in interesting ways, not just as a defence total.
   The decided line here is stack and spend: build shield, then consume it for a payoff, so shield
   becomes ammo and spending it trades away safety.
4. **Cross-cutting cards.** Cards that take advantage of more than one of the above at once. These
   are what make the threads a web rather than three separate decks, and they are where a draft
   choice gets interesting.

Go tall and go wide pull against each other on purpose, the way the Spore Druid's Mass and Self
do.

**Watch — do go tall and go wide both stay viable?** That is only a real draft decision if tuning
keeps both halves playable. The usual risk is that one quietly dies and the choice turns out to be
fake.

**Plain items are few and each has a role (owner, 2026-09-23).** The pool should not carry many
weapons or armour pieces with no other effect. A few are fine, as long as each fills a different
role rather than differing only in speed.

**Weapon kinds lean towards a side effect (owner, 2026-09-23).** A loose guide for the Smith's
weapons, not a rule every item must follow:

| Weapon kind | Leans towards | Why it fits |
|---|---|---|
| Daggers | Bleed | Fast hits set off the bleed they apply. |
| Blunt weapons (hammers, maces) | Decharge | A heavy blow knocks an enemy item's cooldown bar back. The Warhammer is the first. |
| Smithing tools and forges (poker, tongs, forges) | Burn | Heated metal from the forge. |
| Acid (jar, bath) | Poison | Smiths use acid to clean and etch metal, and poison's double shield drain reads as acid eating through armour. |

This is flavour for authoring only; the game does not know an item's weapon kind. It applies to
the Smith for now, and other characters may or may not follow it.

Keep the non-signature threads simple. This is the low-load character, so they should be the kind
a player can reason about at a glance.

### Poison, bleed and burn are available to everyone (owner, 2026-09-21)

This is a **roster-wide** intent recorded here because it came up with the Smith, not a Smith
feature: every character should have some access to poison, bleed and burn, so those three are
always an option for a build, and they carry cross-cutting synergies of their own. The Smith's
share of it fits the fiction — a smith heats, sharpens and poisons what it makes — but the rule
belongs to the whole roster. Where it is implemented, in the colorless pool or as a handful in
each character's own pool or both, is still open; see
[`per_character_pools.md`](per_character_pools.md).

## Engine seams — what each direction costs

Verified against the code 2026-07-04 and 2026-09-20.

| Direction | Cost |
|---|---|
| Go wide | Free. An actor-targeted status scoped by item type tag already works (decision #35); `EmpoweredStatus` is the working example. "All my weapons hit harder for the rest of the fight" is authoring only. |
| Go tall | Built for attack damage (2026-09-23): an item-targeted status can raise one item's attacks ([`../systems/mechanics.md`](../systems/mechanics.md#attack-bonuses)); the Deep Forge uses it. The other half, a bonus while you hold only one weapon, is a board-count condition, which nothing reads today. |
| Armour (stack and spend) | Nearly free. Shield is a `PoolStatus` (`src/content/statuses/shield_status.gd`), and spending it rides the built consume seam `StatusManager.consume`, gated by each status's `is_fuel()`. Spores opts in with a one-line override; shield does not yet. So this is that one override plus the spender items. Consuming shield spends its absorb count, which is the intended tradeoff. |
| Cross-cutting cards | Free where they combine things that already read — type tags, mechanic ids, target filters. Otherwise they inherit whatever the threads they join need. |

Shield is combat-scoped (decision #26), so it resets every fight. Anything that layers armour up
across a descent would have to be a relic or an enchant, not the shield status.

Shield generators are already a solved pattern — the Fleshmancer's Rib, Femur and Skull are plain
self-shield items, and the Smith's armour pieces take the same shape.

**"Armour that does damage" has three readings with very different costs.** An `armour`-tagged
item whose effect is an attack is free, because type tags are inert labels. Spending shield for
damage is the nearly-free consume seam above. Thorns, or damage when your shield absorbs, needs
the unbuilt on-absorb seam and belongs to the parked Spiked Shield entry.

**"Skills" means something specific here.** There is no player-activated action in this combat
model; every item owns a cooldown ticker and fires itself, and `skill` is an inert label. So a
skill-heavy pool means items whose effect is a self-buff or utility on a metronome, like Mighty
Blow. That is authorable now. Making a skill a button the player presses would be a large systems
change.

## The empower engine — the first weapons payoff

**Mighty Blow** (placeholder name — owner's to rename) is a skill on a plain cooldown. Each time
it fires it applies a self-buff that doubles the next weapon attack.

- **Weapon-scoped.** Only a weapon attack is doubled; a spell or skill attack does not benefit.
  That is what the `weapon` tag is for.
- **Stacks by proc count.** A consumed counter, like shield or spores: no timer, it persists until
  spent. One charge is spent per weapon attack, so banking N charges doubles the next N attacks
  rather than multiplying one hit.
- **Board composition is the control.** You cannot choose which attack is next — it lands on
  whichever weapon comes off cooldown first. Few big weapons make "the next weapon attack"
  reliably a big hit. The archetype is bad with fast weapons and good with big ones, and that
  constraint is the deckbuilding identity. It is written as a go-wide effect but rewards a tall
  board, which makes it an early example of a cross-cutting card.
- **The role that falls out.** Big doubled hits overkill small enemies, so the build is aimed at
  bosses and elites and is soft against swarms.

The three weapons sit on the item budget curve ([`item_heuristics.md`](item_heuristics.md)), so
per-hit climbs while damage per second climbs more slowly and the slowest weapon is the prime
empower target. Mighty Blow is priced against the slowest weapon it can reach rather than an
average one, because a charge is worth whatever it doubles. That sets its cooldown: one cooldown
cycle adds one weapon's per-hit damage, so the cooldown has to be the one whose budget equals the
biggest per-hit the Smith can reach, which is the slowest weapon's. The numbers are on each item's
file in `content/items/smith/`; the doubling is `Balance.EMPOWER_MULT`.

**Terminology:** "attack" is the act of dealing damage; "weapon attack" is an attack from a
weapon-typed item.

**Type tags:** the game-wide taxonomy (decision #34, [`../systems/item.md`](../systems/item.md)) —
inert labels `weapon / armour / spell / skill / trinket`, an array per item. The Smith surfaces
**weapon**, **armour** and **skill**.

**The seam the empower needs is built** (decision #35). The doubling happens at fire time, in
`Item._resolve_effect` → `StatusEffect.outgoing_bonus`, and that hook receives the firing item
as well as the actor, so a status can tell a weapon attack from a spell attack. `outgoing_bonus`
also runs the read-only tooltip preview (`Item.display_value`), so it stays pure; spending a
charge belongs on `on_owner_item_fired`, which only runs on a real fire.

## Watch / open

- **Win-more guard.** The trap for a shield character is payoffs that key off shield on hand,
  which are strongest when you are already safe: "deal damage equal to your shield" while keeping
  it. Tie payoffs to spending, or to damage absorbed, rather than to the stockpile. Consume-to-hit
  avoids the problem for free. The parked Spiked Shield entry worked this out in full.
- **Distinctness from the Fleshmancer.** The Fleshmancer is the item-economy character: its
  attacks create Chunks of Flesh on its own board and other cards eat them. If the Smith forges
  items onto the board and consumes them, it is the same machine in a different costume. The
  distinction available is that the Fleshmancer makes disposable fodder in bulk while the Smith
  improves one thing durably, which also feeds go tall. It has to be chosen deliberately.
- **Weapons acting on each other.** The retired Blade Mage left the temper, consume and merge
  weapon-interaction ideas unclaimed, and the bar with them: every character holds weapons, so
  "lots of weapons" is not an identity unless the weapons act on each other. Smith has native
  verbs for that — forge, temper, reforge, consume one weapon to improve another.
- **Relationship to the parked shield character.** Spiked Shield / Retributive Shield is the
  spicier use of shield, with thorns or a charge built off absorbed damage, and it needs an
  unbuilt on-absorb seam. Only one shield character is likely to ship, and the Smith is the one
  being pursued. That engine stays available as a relic, an item, or a later variant.
- **Portrait.** `warrior_nb.png` is a placeholder, picked because the bearded figure in a riveted
  helmet and plate reads close enough to the layered-armour fiction. The owner's to swap.

## Authored so far

**Location:** the character in `content/characters/smith.gd`, one file per item in
`content/items/smith/`, the status in `src/content/statuses/empowered_status.gd`.

The empower engine, the three big weapons and the four armour items are built and in the Smith's
pool. The names are placeholders; the numbers are on the budget curve.

- **`EmpoweredStatus`** (id `empowered`) — a consumed counter. `outgoing_bonus` doubles a
  `weapon`-tagged attack while a charge is banked and stays pure; `on_owner_item_fired` spends one
  charge per weapon attack. Registered in `StatusRegistry`.
- **Mighty Blow** (`mighty_blow`, `[skill]`) — a plain-cooldown metronome that applies `empowered`
  to self, stacking.
- **The weapons** (`broadaxe`, `warhammer`, `greatsword`, `dagger`, all `[weapon]`) —
  single-target, opponent-leftmost, priced on the budget curve. Cooldowns follow the weapon
  cooldown guide in [`item_heuristics.md`](item_heuristics.md). The Broadaxe and Greatsword are
  two-handed and plain. The Warhammer is one-handed, at the slow end of the range, and also
  decharges one random enemy item (owner, 2026-09-23), so it slows the enemy as well as hitting.
  The Dagger is a fast one-handed weapon that deals damage and applies bleed, the first of the
  daggers-lean-towards-bleed guide (owner, 2026-09-23).
- **Iron Maiden** (`iron_maiden`, uncommon, no type yet) — a slow item that only applies bleed,
  spending its whole budget on it (owner, 2026-09-23). It is not clearly a weapon, and the
  existing types do not fit it; which type it gets is open.
- **Smithing tools** (`tongs`, `poker`, no type yet) — burn-only items, following the
  smithing-tools-lean-towards-burn guide (owner, 2026-09-23). The Tongs are fast and the Poker
  slower, both on the leftmost enemy.
- **The two forges** (`deep_forge`, `wide_forge`, rare, no type yet; working names) — slow items
  that burn every enemy and buff the Smith's attack items for the rest of the fight (owner,
  2026-09-23). The Deep Forge gives one random attack item +50% attack, which goes tall; the Wide
  Forge gives every attack item +10 attack, which goes wide. "Attack item" means any item with the
  attack mechanic, not only weapons. The bonuses are unpriced.
- **Acid** (`jar_of_acid`, `acid_bath`, no type yet) — poison-only items (owner, 2026-09-23). The
  Jar of Acid is fast and the Acid Bath slow, both on the leftmost enemy.
- **Bloodletting** (`bloodletting`, no type yet) — applies bleed, and charges itself 1 second
  whenever the Smith applies poison (owner, 2026-09-23), so it links the acid items to bleed. Its
  own bleed does not charge it. The trigger is priced by the trigger row in
  [`item_heuristics.md`](item_heuristics.md#spending-the-budget).
- **The four armour items** (`vambraces`, `sallet`, `kite_shield`,
  `breast_plate`, all `[armour]`) — plain shield-to-self on a rising cooldown and shield
  ladder, the defensive counterpart to the weapon ladder. Names come from
  [`item_name_reference.md`](item_name_reference.md) and are the owner's to change.

The Smith opens on **one weapon, one skill and one armour item**, drawn at random from its pool at
run start (`starting_item_types`). Which three it gets changes every run.

**Still to build:** the rest of the armour line (shield made fuel-eligible, then the spender items
that turn shield into attacks), the go-tall skills and the item-targeted modifier they need, the
cross-cutting cards, the poison, bleed and burn access, the signature starting relic, a portrait,
and enough pool depth to draft.
