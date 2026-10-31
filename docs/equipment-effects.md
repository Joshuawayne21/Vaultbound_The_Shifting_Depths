# Bounded equipment effects — Milestone 5.6

The equipment policy in `resources/progression/equipment_effects.tres` defines
modifier weights, rarity ranges, per-item limits and total effect caps. It is a
standalone Resource without inventory, save, scene or camera dependencies.

| Effect | Per-item base + roll maximum | Equipped total maximum | Behavior |
| --- | --- | --- | --- |
| Critical chance | 5% | 20% | One roll per committed attack; critical damage is 1.5×. |
| Lifesteal | 1.5% | 4% | Actual enemy health lost, at most 4 HP restored across an entire attack. |
| Block strength | 5% | 20% | Reduces the remaining blocked damage; guard cost, facing and guard break remain. |
| Ability cooldown reduction | 5% | 15% | Applies to the two abilities when they start; cannot shorten below the action duration. |

Health, stamina, damage, armor and regeneration retain their existing limits.
Enhancements scale these five base stats by `1 + 0.08 × rank`, using the shared
enhancement policy's rarity cap. Rolled bonuses and the four proc effects never
multiply with enhancement. Normalized combat stats remove every earned effect.

Common and Uncommon new equipment has no random modifier. Rare and Epic has one;
Legendary, Mythic and Ancient Relic has two distinct modifiers. Local seeded RNG
makes new-instance rolls reproducible. Proc rolls use the headroom left by an
authored base effect, so a capped base effect cannot receive a useless same-stat
roll. Existing instances retain their saved modifiers; migration does not reroll.

## Combat integration

`PlayerCombat` captures one source-bound effect context at the attack's active
edge. The context contains only numbers and booleans and lives in a bounded
256-entry local combat ledger. Critical damage is calculated before projectile
creation. Melee, area attacks and later projectile impacts share the same attack
ID, critical result and lifesteal allowance. Switching cameras or loadouts cannot
redraw that result. Repeated active-edge calls cannot create another projectile
or sweep. An interrupted windup creates no effect context.

`CombatRules.apply_hit` retains its existing signature and hit-attempt receipts.
After an accepted hit, it measures the enemy's finite health before and after
damage. This excludes armor reduction and overkill from healing. Practice
targets, walls, dead/inactive/returning enemies, boss wards, duplicate hits and
dead or travel-disabled attackers restore no health. Healing allowance is
reserved before the player callback, so nested hit callbacks cannot exceed the
per-attack budget. A full-health actor does not bank unused healing for later.

Cooldown reduction never alters stamina costs, windup, active or recovery timing,
ordinary/heavy attack cooldowns, dodge, weapon switching or an already running
cooldown. Guardian and Mystic continue using the shared combat controller with
their existing tuning; they do not inherit the player's equipment effects.

## Unsupported effects and authority

Fire, frost and poison resistance are not enabled. The existing `kind` hit field
describes presentation or attack mode; even archer projectiles use `magic` there.
It is not an elemental damage taxonomy. No resistance consumable or affix is
represented as functional without typed damage and actual matching encounters.

This remains offline local simulation. The source-bound attack context and
confirmed-damage callback are authority boundaries to move to a future server,
not protection against editing local files or client code. No multiplayer,
client-trusted remote rewards or PvP kill-reward system is implemented.

## Verification

Run the focused contracts with:

```sh
godot4 --headless --path . --script tests/equipment_effects_test.gd
```

The suite checks seeded rolls, caps, headroom, invalid values, normalized stats,
upgraded versus unscaled effects, actual armored/overkill damage, shared healing
budgets, exclusions, bounded context ownership, real guard/cooldown costs,
projectile/sweep deduplication, camera toggles, walls and interrupted windup.
The separate effects integration suite covers saved equipment, a critical staff
projectile across a loadout change, and real service/restart behavior.

Physical Android review is still required: read effect percentages in the item
tooltip, attack real monsters in both views, switch weapons after a staff cast,
observe critical feedback and gradual health recovery, compare shield damage and
ability cooldowns, then extract and restart. No physical device testing is claimed.
