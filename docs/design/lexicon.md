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
| **Trigger** | An event an item listens for that adds seconds to its own cooldown bar each time it happens (`ItemDef.trigger_subs`). A relic's trigger fires the relic instead. |
| **Relic** | An item with no cooldown: it fires only when one of its triggers happens, and its passives hold for the whole fight. The run owns the player's relics; in a fight they sit apart from the board (`RelicDef`, `Actor.relics`). |
| **Passive** | A relic ability that is always on for the whole fight, written like an item effect (`RelicDef.passives`). Not a status. |
| **Run trigger** | A relic ability outside fights: when a run event happens (the relic is picked up, a fight is won, a draft is skipped), its run effects change the run (`RelicDef.run_triggers`, `RunEffect`). |
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

## Characters

| Term | Meaning |
|---|---|
| **Class** | The kind of character a playable character is, shown under its personal name on the select screen and in the Class field of the player's panel, for example Rot Shepherd (`CharacterDef.class_key`). |

## The run and the map

| Term | Meaning |
|---|---|
| **Act** | One part of a run, ending in a boss. The player is fully healed between acts. |
| **Beat** | One encounter along an act, in order (`RunManager.position`). |
| **Square** | A beat shown on the map: a fight, an elite fight or the boss (`RunMap.SQUARES`). Every square has a choice of encounters before it. |
| **Choice of encounters** | The beat before every square, where three encounters are offered as cards in the corridor and the player picks one or walks past for a little gold (`RunManager.pending_choice`). |
| **Event** | An encounter with prose and a choice of options, and no fight. It is offered in the choice of encounters. |
| **Event option** | One choice inside an event: its effects on the run and the conditions it needs. An option whose conditions fail is not shown (`EventOptionDef`). |
| **Run effect** | A change to the run made outside fights by an event option or a relic's run trigger, such as healing, gold, or gaining an item (`RunEffect`). |
| **Run flag** | A named whole number the run remembers, set by run effects and read by conditions, so a later encounter can react to an earlier choice. Never shown to the player (`RunManager.flags`). |
| **Encounter rarity** | How often an encounter is offered before its weight rules: common or rare (`EncounterDef.rarity`). |
| **Condition** | A yes-or-no question about the run, such as whether the board holds an item (`RunCondition`). |
| **Requirement** | A condition an encounter needs to be offered at all (`EncounterDef.requires`). |
| **Weight rule** | A condition that multiplies how likely an encounter is to be offered while it holds (`EncounterDef.weights`). |
| **Elite fight** | A harder fight that rewards a relic and a draft. Two per act, at fixed squares. |
| **Reward encounter** | An encounter offered before a fight, with no fight, where the player picks one of the goods drawn from its stock (`EncounterDef.Type.REWARD`). The placeholder reliquary offers three relics. |
| **Potion** | A thrown, one-use reserve held in the potion row. Its definition is an item definition, so it is shown and tooltipped like an item (`ConsumableDef`). |
| **Relic pool** | The reward relics the player does not hold yet (`RunManager.relic_pool`). Every relic reward draws from it, so a relic is never had twice. |
| **Shop** | An encounter offered from the left card before a fight, with no fight, where the player buys goods drawn from its stock with gold, then leaves (`EncounterDef.Type.SHOP`). |
| **Stock entry** | One line of what a reward encounter or a shop offers: items (optionally only some item types), relics or potions, and how many (`StockEntry`). |
| **Reroll** | Paying gold in a shop to draw all of its goods again. Each reroll in a visit costs more (`RunManager.reroll_shop`). |
| **Sell** | Taking an item off the board for part of its shop price in gold, at any time outside a fight (`RunManager.sell_item`). Relics and potions are not sold. |
