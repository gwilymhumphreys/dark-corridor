# Lexicon

The words used for the game's parts, in code, docs and chat. Use a word only in the sense given
here. When a new term is needed, add it here in the same change, and check it does not already mean
something else.

## Items and firing

| Term | Meaning |
|---|---|
| **Item** | One thing on a board. It fires on its own cooldown. `ItemDef` is the authored definition; `Item` is the copy in play. |
| **Board** | The items an actor holds in a fight. |
| **Cooldown** | The seconds an item takes to fill its cooldown bar and fire. Always a whole number (see [authoring.md](authoring.md)). |
| **Cooldown bar** | An item's progress towards firing, shown as the fill over its icon. |
| **Fire** | An item acting when its cooldown bar is full: every one of its effects happens, then the bar starts again. |
| **Effect** | One thing an item does when it fires (`ItemEffect`): a mechanic with a value, or a status to apply with an amount, aimed at a target shape. |
| **Trigger** | An event an item listens for that adds seconds to its own cooldown bar each time it happens (`ItemDef.trigger_subs`). |
| **Type tag** | A label on an item (`weapon`, `armour`, `spell`, `skill`, `trinket`). It does nothing by itself; other items and statuses can refer to it. |
| **Value pill** | The number on the top edge of an item's icon. There is one for each mechanic effect; a status effect has none. |

## Mechanics and statuses

| Term | Meaning |
|---|---|
| **Mechanic** | A named kind of effect with its own icon and rules: attack, shield, heal, poison, burn, bleed, charge, decharge and others ([mechanics.md](../systems/mechanics.md)). |
| **Attack** | The attack mechanic: dealing damage to a target. |
| **Weapon attack** | An attack from an item with the `weapon` type tag. |
| **Charge** | The charge mechanic: adding seconds to an item's cooldown bar so it fires sooner. The word means only this. |
| **Decharge** | The decharge mechanic: taking seconds off an item's cooldown bar. |
| **Status** | Something that sits on an actor or an item for the rest of a fight, or until it runs out, and changes what happens (`StatusEffect`). Poison, shield and Empowered are statuses. |
| **Stack** | One unit of a status's count (`StatusEffect.count`). Applying a status adds stacks; a status can lose or use up stacks. Mighty Blow adds one stack of Empowered, and each attack uses one up. |

## Pricing

| Term | Meaning |
|---|---|
| **Point** | The unit items are priced in. One point is one damage from a single-target attack ([item_heuristics.md](item_heuristics.md)). |
| **Budget** | The points an item may spend, worked out from its cooldown and rarity (`ItemPoints.budget`). |
| **Spend** | The points an item's effects actually cost (`ItemPoints.spend`). |
