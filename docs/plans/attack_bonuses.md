# Plan: attack bonuses on items, and one rule for combining bonuses

**Status:** shipped (2026-09-23). The system is described in
[`systems/mechanics.md`](../systems/mechanics.md#combining-bonuses).

The Smith's two Forges give their own side's attack items a bonus that lasts the rest of the
fight: one gives +50% attack to a random attack item, the other gives +10 attack to every attack
item. Neither can be built today, because an item's damage is only changed by its enchant and by
statuses on its owner, never by statuses on the item itself (the "go tall" engine cost in
[`design/smith.md`](../design/smith.md), and the "Not implemented: item-targeted value
modifiers" note in [`systems/item.md`](../systems/item.md)). This plan adds that, and replaces
the current way modifiers combine with the owner's rule.

## Decisions from the owner (2026-09-23)

- **Combining rule.** Percentage bonuses are added together when positive and multiplied
  together when negative, and the two groups are worked out separately.
- **Duration.** A Forge bonus lasts for the rest of the fight.
- **Pricing.** The bonuses are unpriced for now.
- **Targets.** "Attack items" means any item with the attack mechanic in its `mechanics` list,
  not only items typed as weapons.
- **Two Forges.** One gives +50% to a random attack item, the other +10 to all attack items.

## The combining rule

An attack's value at fire time becomes:

```
(authored value + flat bonuses) × (1 + sum of positive percentages) × (product of negative multipliers)
```

- **Flat bonuses** are added first, so a percentage bonus also scales them. This is a proposal:
  the owner has not said which comes first.
- **Positive percentages** today are Empowered (+100%, from `Balance.EMPOWER_MULT`) and an
  enchant's `value_mult` above 1. With this plan they are added, so Empowered plus a +50% enchant
  is ×2.5, not ×3 as now.
- **Negative percentages** today are Weak (`Balance.STATUS_WEAK_DAMAGE_MULT`). Two negatives
  multiply, so two −25% effects give ×0.5625.
- **Crit stays outside the rule.** It multiplies the final value after everything else, as now
  ([`systems/mechanics.md`](../systems/mechanics.md#crit)). Proposal; the owner can fold it in.
- **Incoming damage (Vulnerable) stays a separate stage** on the target, applied when the hit
  lands. The same rule is used inside that stage, which only matters once a second incoming
  modifier exists.
- **Enchants apply to every value an item fires**, not only attacks, so a shield item's enchant
  still scales its shield. Statuses still scale attacks only.

## Engine changes

1. **Statuses report a contribution instead of transforming the value.** `StatusEffect` gets
   `outgoing_bonus(target, item) -> Dictionary` returning `{'flat': float, 'percent': float}`,
   where `percent` is signed (+1.0 for Empowered, −0.25 for Weak). It replaces
   `modify_outgoing`. It stays pure, because the tooltip preview calls it.
2. **`StatusManager.outgoing_value(actor, item, value)`** collects the contributions from the
   owner's statuses and the firing item's own statuses, adds the enchant's `value_mult` as a
   percentage, and applies the formula above. `Item._resolve_effect` and `Item.display_value`
   both call it, so the tooltip shows the raised value with the changed-value highlight.
3. **Two new mechanics, each backed by an item status**, in the same way poison is a mechanic
   backed by an actor status. Their ids and names are placeholders for the owner to rename:
   - `attack_bonus` (+N attack) → `AttackBonusStatus`, `outgoing_bonus` returns `{'flat': count}`.
   - `attack_percent_bonus` (+N% attack) → `AttackPercentBonusStatus`, returns
     `{'percent': count / 100}`.
   Both only apply to the item they sit on and only to its attack effects. Re-applying adds to
   the count, which matches the additive rule. Neither has a timer, and statuses are cleared at
   the end of a fight (decision #26), so the bonus lasts exactly one fight.
   Making them mechanics puts them in items' `mechanics` lists, the keyword cards, the
   `IconSlots` icon choice and the target filters, which statuses outside the set do not get.
4. **Pricing.** `ItemPoints` returns 0 for both mechanics. They are added to "What this leaves
   unpriced" in [`design/item_heuristics.md`](../design/item_heuristics.md), and the item
   browser already marks a card with unpriced effects.
5. **Tooltip wording.** An effect aimed at `OWN_ITEM_RANDOM` or `ALL_OWN_ITEMS` with a mechanic
   filter already reads as "a random attack item of yours" / "all your attack items"
   (`TooltipContent._shape_text`). Check that the phrase reads correctly for these two effects
   and that the value shows as "+10" and "+50%".
6. **Icons.** Pick candidates for the two new icon slots in `assets/icons/mechanics/<slot>/`
   ([`systems/mechanics.md`](../systems/mechanics.md#iconslots)).

## Content

- `content/items/smith/forge.gd` keeps its burn on every enemy and adds
  `ItemEffect.make('attack_percent_bonus', 50.0, ItemEffect.Shape.OWN_ITEM_RANDOM)` with a target
  filter on the attack mechanic.
- A second rare Forge (placeholder id and name, for the owner to rename) has the same burn and
  `ItemEffect.make('attack_bonus', 10.0, ItemEffect.Shape.ALL_OWN_ITEMS)` with the same filter.
- `OWN_ITEM_RANDOM` and `ALL_OWN_ITEMS` leave out the firing item, which does not matter here
  because the Forges have no attack.

## Tests

- The combining rule: flat then percentage; positives added; negatives multiplied; the two groups
  separate; enchant counted as a positive percentage; crit still last. Fixture items only
  ([`systems/testing.md`](../systems/testing.md)).
- An item status raises only its own item's attacks, not its other effects and not other items.
- Re-applying a bonus adds to it.
- The tooltip's `display_value` shows the bonus without changing any state.
- Update the existing tests that call `modify_outgoing` directly (`test_status_effect.gd`,
  `test_status_manager.gd`, `test_empower.gd`) and the Empowered-plus-Weak composition test,
  whose expected value follows the new rule.

## Docs to update when it ships

- `systems/mechanics.md`: the two new mechanics, and the combining rule.
- `systems/status_manager.md` and `systems/item.md`: the new modifier call, and remove the
  "Not implemented: item-targeted value modifiers" note.
- `design/smith.md`: the "go tall" engine cost is paid.
- `design/item_heuristics.md`: the two unpriced mechanics.
- `decision_log.md`: the combining rule.

## Answers from the owner

1. Flat bonuses come first, then percentages.
2. Crit stays outside the rule and multiplies at the end.
3. The forges are the Deep Forge (+50% to a random attack item) and the Wide Forge (+10 to all
   attack items), working names. The mechanics keep placeholder names.

## Differences from the plan

- `StatusManager.outgoing_value` became two calls: `outgoing_bonuses(actor, item)` gathers the
  statuses' bonuses and `combine(value, bonuses)` applies the rule. The enchant is added in
  `Item._scaled_value`, which both the fire and the tooltip preview use.
- The incoming stage (Vulnerable) was left as it is. It has one modifier, so the rule would change
  nothing there yet.
- `ItemPoints.is_priced(effect)` was added, and the item browser uses it to mark unpriced effects
  instead of keeping its own list.
