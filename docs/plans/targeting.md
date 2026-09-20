# Plan: targeting

Not built. Written 2026-09-20, after the owner asked for a targeting system that can express
"all your weapons" and "a random enemy bleed item". The design decisions here are the owner's;
anything still open is listed at the end. This plan is written to be implemented by a session
that has not seen the conversation.

Plans are not catalogued in `docs/index.md`.

## Why

An effect picks its targets through `ItemEffect.shape`, one value of a seven-value enum, resolved
by `CombatManager._resolve_targets` (`src/combat/combat_manager.gd`). The shape decides both
*which pool* to pick from (own actors, opponent actors, own items, opponent items) and *how many*
to take (one, one at random, all). There is no way to narrow the pool, so every item shape picks
from the whole board.

That means "all your weapons" and "a random enemy bleed item" cannot be authored. Adding them as
new enum values does not scale: every pool would need a copy per filter, and the filters multiply.

Two pieces of the answer already exist but are not usable for targeting:

| Piece | Where it is now | Problem |
|---|---|---|
| Item type tags (`weapon`, `armour`, `skill`, `spell`, `trinket`) | `ItemDef.types`, an array of `ItemType` consts | Read in exactly one place, `EmpoweredStatus`, which hardcodes the weapon tag. Targeting never sees it. |
| Which mechanics an item uses | Derived on the fly by `TooltipContent.keyword_ids` and `_item_uses_mechanic` | Lives in the tooltip scene, returns keyword ids gated by `KeywordCatalog`, and is not reusable by combat. |

The existing narrower request is recorded as open in `systems/item.md` and `systems/mechanics.md`:
scoping which items charge and decharge can pick. This plan covers that as a side effect.

## Words used here

- **Pool** — the set of candidates a shape draws from before anything is narrowed: the owner, the
  living opponents, the owner's other board items, or the living opponents' board items.
- **Filter** — a test applied to each candidate in the pool, keeping only those that pass.
- **Pick** — how many of the survivors become targets: the leftmost one, one at random, or all.
- **Target filter** — the authored object holding a filter's conditions.

## The design: pool, then filter, then pick

`_resolve_targets` splits into three steps. The shape keeps deciding the pool and the pick; a new
optional filter sits between them.

- Unfiltered shapes behave exactly as they do today.
- A filtered shape builds the same pool, drops the candidates that fail the filter, then picks from
  what is left.
- An empty result after filtering behaves like an empty pool does today: no delivery is spawned and
  the effect does nothing that fire. No new fizzle path.

"All your weapons" is `ALL_OWN_ITEMS` with a filter on the weapon type tag. "A random enemy bleed
item" is `OPPONENT_ITEM_RANDOM` with a filter on the bleed mechanic. The shape enum does not grow.

### What a filter can test

A target filter holds a flat list of conditions and one match mode.

A condition names either a **type tag** (matched against `ItemDef.types`) or a **mechanic**
(matched against the item's authored mechanics list, below). The mode is **all** or **any**:

- **all** — the candidate must satisfy every condition. "All your poison weapons" is the weapon tag
  and the poison mechanic, mode all.
- **any** — the candidate must satisfy at least one. "All your weapons or spells" is the weapon tag
  and the spell tag, mode any.

One flat list with one mode is deliberate. Two lists, one per kind, would force the two kinds to be
combined with "and" and make "a weapon or a poison item" unauthorable. The cost is that nesting is
not expressible: "a weapon or a spell, that also uses poison" cannot be written as one filter. If a
card ever needs that, author it as two effects, or add grouping to the filter then. Do not build
grouping now.

An **empty condition list is allowed and means no filtering** — the same targets as today. That is
what a filter field defaulting to null already does, and it means an author can add a filter object
and fill it in later without the item breaking in between.

A condition naming an id that does not resolve is an authoring mistake, caught by the sweep in
Validation.

### Several enemies

The opponent-item pool already spans every living enemy: `_all_opponent_items` walks
`_living_opponents` and concatenates their boards, and `_random_opponent_item` draws one item from
that combined pool. Nothing here changes that, and the filter is applied to the combined pool, so
a filtered pick can land on any enemy that holds a matching item.

What that means is that the draw is **flat across items, not across enemies**: an enemy holding
four items is four times as likely to be hit as an enemy holding one. Keep that. It is the current
behaviour, it is the reading a player gets from "a random enemy item", and the alternative — pick
an enemy, then pick one of its items — makes a single item on a nearly empty board as likely as
any one of a full board's, which is harder to reason about. The point is that this is now a
deliberate choice rather than an accident of how the helper was written; say so in the code comment
and in `systems/item.md`.

Two consequences of filtering to watch for, both of which need a test:

- A filter can empty one enemy's contribution and not another's. The pick must draw from the
  filtered pool, never filter after drawing, or a fire aimed at "a random enemy bleed item" would
  do nothing whenever the draw happened to land on a non-matching item.
- A dead enemy's board is already excluded, because the pool is built from the living opponents.
  Filtering does not change that, and an enemy that dies while a delivery is in flight still
  fizzles through the existing `_target_alive` check.

The own-board shapes stay limited to the firing actor's own board and do not reach an ally's or a
summon's, which is the existing documented rule. Whether "all your weapons" should include a
summoned ally's board is a separate question and is not part of this plan.

Filters apply to **item** pools only in this plan. Actor pools (`OPPONENT_LEFTMOST`,
`ALL_OPPONENTS`) keep their current behaviour and ignore any filter, because filtering actors —
"the leftmost enemy with poison" — changes the predictability rule that leftmost targeting exists
for, and the owner has not asked for it. The filter object and the resolution step are written so
an actor condition can be added later without moving anything; a filter set on an actor shape
should push a warning once, in the same style as `_warn_unhandled_shape`, so it is not a silent
no-op.

## The mechanics list is authored, not derived

An item gets a new authored field listing the mechanic ids it uses. This is the owner's call and
the recommendation, because deriving it from the effects cannot answer these on its own:

- Poison, burn, bleed and regen are delivered as `MECHANIC` effects naming the mechanic, but weak,
  vulnerable, blind and silence are `APPLY_STATUS` effects naming a status. A derived set has to
  union two fields that mean different things.
- An item whose trigger subscribes to poison charges off poison but never applies it. Whether that
  makes it a poison item for "your poison items" is a judgment call, not a fact about the data.
- An item that spends spores as fuel, and an item that creates a bleeding dagger rather than
  bleeding anything itself, are the same kind of judgment call.
- An enchant can add a rider at runtime, so a set derived from the definition is already incomplete
  for that instance.

Each of those is a decision about what the item *is*, and the author is the one who knows. Deriving
picks an answer silently and gets some of them wrong.

### There is no rule above the floor — the author decides

The owner's decision, 2026-09-20: do not write a rule set for the awkward cases. An item that
charges when poison is applied **is** a poison item; an item that creates a bleeding dagger is
**not** a bleed item. Those two look like they should follow from one principle and they do not,
and any rule that produced both would need exceptions for fuel, for summons, for enchants and for
whatever the next mechanic is. Rules like that get out of hand and stop matching how the cards
actually play.

So there is one mechanical floor, checked by the sweep, and everything above it is the author's
call, item by item:

**The floor** — if an effect on the item deals or applies a mechanic, that mechanic is listed. An
item that deals poison damage is a poison item under any reading, so this is not a judgment call and
the check can enforce it.

**Above the floor** — the author may list anything else the item should count as. Reacting to a
mechanic, spending it as fuel, creating an item that uses it: list it when the item reads as that
kind of item to a player building around it, leave it off when it does not. Nothing checks this and
nothing should.

The question the author is answering is "should *your poison items* pick this one up", not "does
this item technically contain the word poison". That is a question about how the card plays, which
is why it belongs to the person writing the card.

This also means the list is genuinely the item's identity rather than a summary of its effects,
which is what makes it worth having as a separate field.

### The list is sorted alphabetically

The authored list is always written in alphabetical order by mechanic id, and the sweep enforces it.
The reason is the tooltip: the list is what seeds the keyword column, so if the order were free,
the same two mechanics would appear in different orders on different items depending on how each
was typed, and reordering an item's effects would quietly move its keyword cards around. Alphabetical
is arbitrary but fixed, which is the property that matters — a player sees the same mechanic in the
same relative place on every item.

Sort in the source file rather than sorting at read time, so what is authored and what the player
sees are the same thing and a diff is readable. The tooltip reads the list in order and does not
re-sort it.

### Consequences for the tooltip

`TooltipContent.keyword_ids` currently derives every chip by walking the effects. It gains the
authored list as its first source but keeps the rest of its derivation, because the authored list
holds **mechanic ids only** and the column shows more than mechanics. Build the column in three
parts, in this order:

1. **The authored mechanics list**, in its alphabetical order.
2. **The derived non-mechanic ids**, exactly as derived today and in the same effect order: an
   `APPLY_STATUS` effect's `status_id`, an effect's `consume_id`, and a trigger subscription's
   string filter. These are statuses such as weak, vulnerable, blind and spores. **They must keep
   being derived** — dropping this step would silently remove those keyword cards from every item
   that applies a status, which is most of the catalog.
3. **The structural keywords**, `kw:aoe`, `kw:trigger`, `kw:item_target`, `kw:unblockable`,
   `kw:fuel`, `kw:summon`, `kw:reclaim` and `kw:enchant`, in the existing fixed
   `KeywordCatalog.MECHANIC_ORDER`. These are properties of an effect's shape and flags, not
   mechanics, so they stay derived.

The existing dedupe in `_add_keyword` handles an id that appears in more than one part, so a
mechanic authored in part 1 is not added again by part 2. The `KeywordCatalog` gate is unchanged: an
id with no catalog entry produces no card.

Two things fall out of this. The tooltip and targeting agree on what an item is by construction, and
the mechanic chips sit in the same relative order on every item because the list is sorted.

**Crit is part of the authored list.** `keyword_ids` today adds the crit keyword when
`crit_chance > 0`. That derivation goes away: an item with a crit chance lists `crit` like any other
mechanic, and the floor check enforces it, since it is mechanical rather than a judgment call. This
keeps one answer to "what mechanics does this item use" rather than one answer plus a special case.

## Changes, file by file

**New — `src/content/items/target_filter.gd`, `class_name TargetFilter`**

Holds the condition list and the match mode, plus one method answering whether a given `Item`
passes. The method reads `item.def` only, so it is pure and safe to call from a preview path. A
definition's filter is shared by every instance of that item; treat it as read-only after authoring.

A condition is a small typed thing rather than a bare string, because the same id could in principle
name both a tag and a mechanic; make which kind is meant explicit at authoring time rather than
guessing by looking the id up in both places.

**`src/content/items/item_def.gd`**

Add the authored mechanics list, an `Array[String]` of `MechanicRegistry` ids, defaulting to empty.
Document it as the answer to "what does this item do", used by targeting and by the tooltip.

**`src/content/items/item_effect.gd`**

Add the optional target filter field, defaulting to null. Update the class comment, which currently
says the effect carries a shape and nothing else about targeting.

**`src/combat/payload.gd`**

Carry the filter through: a new field, copied in `from_effect` alongside `shape`. The filter is not
modified by the fire pipeline — it is authored data passed straight through, like the shape.

**`src/combat/combat_manager.gd`**

Rework `_resolve_targets` into pool, filter, pick. The four existing item helpers
(`_all_opponent_items`, `_random_opponent_item`, `_all_own_items`, `_random_own_item`) become a pool
builder plus a shared filter-and-pick step, so the random draw and the "leave out the firing item"
rule stay in one place each. Keep the existing warn-once behaviour for an unhandled shape and add
the warn-once for a filter on an actor shape.

**`src/content/items/item_catalog.gd`**

Author the floor on every existing item definition — the mechanics its effects deal or apply. That
part is mechanical and the sweep confirms it.

Anything above the floor is the owner's to add. Do not guess it in quietly. Where an item looks like
a candidate — it charges off a mechanic, spends one as fuel, or creates an item that uses one — add
a `# owner: consider <mechanic>` comment beside its list rather than the entry itself, in the same
style as the existing `# owner: confirm` type-tag comments. That leaves one pass of decisions for
the owner in one file, instead of a rule that decided them.

**`src/scenes/ui/tooltip/tooltip_content.gd`**

`keyword_ids` seeds from the authored list as described above.

**Show the item's type tags.** The tooltip does not display them today, which is why they read as
inert labels. Now that a filter can target them, the player has to be able to see that an item is a
weapon. Add a type line to the content dictionary `build` returns, rendered under the title in
`tooltip_panel.tscn` as its own label, above the effect lines. It is identity, not a number, so it
does not belong in the stat block with the cooldown and the crit chance. An item with no tags shows
no line. Several tags join with the same joining rule the filter phrases use, so the two read alike.

**`_shape_text` learns the filter**: the single-target line needs phrases such as "all your weapons"
and "a random enemy bleed item".

Build those from a small set of format templates — one filtered and one unfiltered template per item
shape — filled with the filter's display term, rather than one literal string per combination.
Templates stay literal `tr()` calls so they are extracted into the POT file, matching the existing
rule in `systems/localization.md`. The display term for a mechanic comes from its `Mechanic`
`name_key`; for a type tag it needs a display name, which `ItemType` does not have today — adding
one is part of this work. A filter naming several ids needs a joining rule; see the open questions.

## Validation

Add to `tests/content/test_pool_integrity.gd`, which is already the sweep that turns a bad authored
id into a test failure rather than a crash mid-fight:

- Every mechanic id in an item's authored mechanics list resolves in `MechanicRegistry`.
- Every authored mechanics list is sorted alphabetically and holds no duplicates. The failure
  message should print the sorted list, so fixing it is a copy and paste.
- Every mechanic id and type tag named by a target filter resolves, in `MechanicRegistry` and
  `ItemType` respectively.
- **The floor check**: for every item definition, the authored list contains
  - every effect's `mechanic` field, where it is set;
  - every effect's `status_id` that also resolves as a mechanic id, which covers an item applying
    poison, burn, bleed or regen through an `APPLY_STATUS` effect rather than a `MECHANIC` one;
  - `crit`, when the definition's `crit_chance` is above zero.

  These are the cases where the item plainly deals or applies the mechanic, so an omission is a
  mistake rather than a choice. The check is one-way: an item may list more than this, which is the
  whole point of authoring it, but never less.
- Nothing above the floor is checked. `consume_id`, trigger filters and created items are
  deliberately not swept, because whether they count is the author's call.

## Determinism

Filtering runs before the random draw, so a filtered random pick draws once from the narrowed pool.
Existing unfiltered items draw exactly as they do now, so their seeded runs are unchanged. A new
filtered item changes the pool size and therefore the run, which is expected.

## Tests

`tests/combat/test_combat_manager.gd` already covers each item shape directly through
`_resolve_targets`. Extend it with:

- A filter on a type tag narrowing an all-own-items pool to the weapon-tagged items.
- A filter on a mechanic narrowing a random-opponent-item pick, asserting the chosen item is one
  that carries the mechanic.
- A filter that matches nothing, asserting no targets and therefore no delivery.
- Two living enemies, where only the second holds a matching item, asserting the filtered random
  pick reaches across to it rather than failing.
- A dead enemy holding a matching item, asserting it is not picked.
- A filter combining a tag and a mechanic, asserting both conditions apply.
- The firing item is still left out of both own-board shapes when a filter is present.

`tests/content/test_tooltip_content.gd` covers the keyword column; extend it for the type line, the mechanics
seeding the column ahead of the structural keywords, and for a filtered shape phrase.

## Not in scope

- Filtering actor pools.
- Naming a specific item definition as a target, rather than a tag or a mechanic.
- Any change to how relics, enchants and consumables target. A thrown consumable uses the same
  shapes and will carry the filter field for free, but no consumable authored today sets one.
- Runtime additions to an item's mechanics list from its enchant. The authored list is definition
  data; an enchant changing what an item counts as is a separate question.
- Authoring real filtered items in `ItemCatalog`. Items are content and content is the owner's. The
  work here stops at the machinery, the fixtures and the mechanics lists on the existing items.

## Order of work

1. `TargetFilter`, the `ItemDef` mechanics list, and the `ItemEffect` and `Payload` fields.
2. The `_resolve_targets` rework, with the combat manager tests.
3. Author the mechanics lists across the item catalog, with the validation sweep.
4. The tooltip changes: keyword seeding, then the filtered shape phrases, then the POT regeneration
   step from `systems/localization.md`.
5. Add filtered definitions to `tests/fixtures/fixture_items.gd` as the worked examples — a
   tag-filtered one and a mechanic-filtered one — so the tests and the owner both have something
   concrete to read. **No filtered item goes into `ItemCatalog`**: real items are content and
   content is the owner's. The fixtures prove the machinery; the owner decides which cards use it.

## Docs to update in the same change

- `systems/item.md` — the targeting section gains the pool, filter and pick split; the item type
  tags section stops saying tags are read in one place; the definition list gains the mechanics
  list. Close the "narrowing which of your items they can pick" open item.
- `systems/mechanics.md` — close the same open item under charge and decharge, pointing at
  `systems/item.md`.
- `systems/tooltips.md` — the keyword column is seeded from the authored list.
- `decision_log.md` — a new decision recording the pool, filter and pick split and the authored
  mechanics list, with the reason derivation was rejected.
- If this ships, promote this plan to a section of `systems/item.md` rather than a new system doc;
  targeting is part of the item system, not beside it.

## Settled by the owner, 2026-09-20

- **Both "and" and "or"**, as one flat condition list with a match mode.
- **An empty condition list is fine** and means no filtering.
- **The tooltip shows the item's type tags.**
- **No rule set for the mechanics list.** One checked floor — effects that deal or apply a mechanic
  must list it — and the author's judgment above that. A charges-on-poison item is a poison item; an
  item that creates a bleeding dagger is not a bleed item.

## Open questions for the owner

1. **Display names for type tags and the joining word.** The tooltip needs "weapons", "spells" and
   so on, in the plural, and a word to join several of them — "your weapons and spells" reads
   naturally but the filter's "any" mode means or. Placeholder names can be scaffolded, but the
   words are the owner's.
2. **How the type line reads when an item has several tags.** Whether a rare tagged weapon and spell
   shows both, or whether multi-tagging should stay rare enough that it does not matter.
