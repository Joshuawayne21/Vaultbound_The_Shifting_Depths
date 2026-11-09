# Rootbound hazards and finite encounters

This guide describes the accepted **7D.3 Rootbound event batch**, covered by [headless validation](milestone-7d3-validation.md). Physical Android play-testing and rendered art review remain pending.

The batch extends the existing Rootbound world, room modules, shared combat, companions, searchable caches and extraction. It does not add another inventory, change Depthmarks, or turn optional encounters into required floor objectives. The later [7D.5 Crystal theme](glimmering-crystal-abyss.md) has its own resonance hazard, and [7D.6 Ember](crimson-ember-temple.md) adds flame vents and one optional dormant mine. The later [7D.7 rolling-stone batch](rootbound-rolling-stone.md) adds one Depth 6+ optional Rootbound trap, with its own full warning and swept contact. Its first-entry attempt differs from the D3 hazard attempts described below, and it grants no event reward. Further themes, trap families and Ancient encounters remain later work. The hive/horde rules below apply to Rootbound. The later [7D.4 Return springs](dungeon-return-springs.md) can secure collected event rewards without completing the floor.

## Selection and readable hazards

Selections use separate deterministic streams and the issued content plan. The original layout and Champion selection retain their own streams. Room availability and physical admission can omit an optional feature; unsafe locations are never forced into a path, entrance, boss arena or extraction chamber.

| Feature | Initial eligibility and chance | Limit |
| --- | --- | --- |
| Spike lane | Depth 2+, 50% per eligible thorn-trap room | Two rooms per run |
| Spore patch | Depth 2+, one 35% opportunity when an eligible grove exists | One room per run |
| Spore Hive | Depth 6+, one 35% opportunity when an eligible off-main grove remains after Champion placement | One room per run |
| Rootbound Horde | Depth 6+, one 5% opportunity in an eligible ordinary combat room | One event per run |

The spike lane warns for 1.8 seconds before a 0.45-second damage window. Its six-metre center line and 0.65-metre radius use the same analytic shape for warning and hits. A single attack ID permits at most one attempted hit per member, including an invulnerable dodge attempt.

The 1.6-metre spore patch warns for two seconds and remains active for three. It can deliver at most three small pulses, at least one second apart. A long frame cannot bunch pulses together or extend the damage lifetime. It does not apply an unimplemented poison status. Both hazards use the frozen floor damage factor once and retain height, wall-obstruction and source checks.

The v1 hazard and event definitions validate the approved authored tuning tuples. They are reusable registered resources, but arbitrary numeric retuning is not yet supported; later content must version and validate its bounds.

Each selected room hazard has one automatic attempt after its warning appears. Leaving consumes that attempt and cancels its damaging state. Existing awareness roots retain their established behavior.

## Optional hive

The hive is a grounded, destructible object with 160 base health before the floor factor. It occupies a surveyed edge location and has matching physical and camera collision. Companions do not automatically disturb a dormant hive. The player can attack it with the existing sword or staff, or issue Attack Target; after a valid hit, companions can assist.

Damaging the core can release two sequential waves of two defenders. The first wave uses a skeleton and archer. The second becomes eligible below half core health and after the first wave's actual deaths; from Depth 11 it substitutes an ordinary golem for the archer. Each wave has a full 3.5-second warning. Unsafe spawn positions never force an enemy onto a party member.

Destroying the core cancels defenders that have not spawned. A fast core-only defeat can earn the modest base cache, with no monster kill credit or XP for the core. Every defender that actually spawned must die before that event can pay out. Missing, culled or cancelled actors do not count as kills. The core never supplies lifesteal.

## Finite horde

A selected horde can begin only after its room's original ordinary enemies have verified deaths. It has two waves: two members per wave when solo, or three with a two/three-member party. That roster freezes on activation; downing a companion or changing distance cannot shrink the required count. From Depth 11, the second wave replaces its last skeleton with an ordinary golem.

Each wave receives a 3.5-second warning, then rechecks the complete spawn group. The next wave waits for all actual first-wave deaths. After two unsafe warned attempts, an unspawnable wave ends the event harmlessly without an aggregate reward. Completing all four or six actual members yields one cache.

Neither event spawns an elite or separate hive guardian in this batch. Members reuse the current skeleton, archer and golem systems. No member independently awards loot, currency, pet findings, journal records or XP.

## Leaving, returning and party behavior

Leaving an event room pauses the same surviving actors with their existing health and identities. Their pending attacks and owned projectiles cancel before room processing is disabled. Returning requires a fresh 3.5-second warning and new attack windups; it cannot resume an old attack at its damaging edge. An actor that disappears without verified death evidence cannot be replaced to manufacture completion.

New spawns stay more than six metres from current party members, including downed members, and pass native floor, body, occupancy and escape-route checks. Companion navigation accounts for the stationary hive body; cache invalidation happens on actual admission/removal rather than every frame. Both camera modes use the same gameplay state and damage rules.

## Rewards and saving

| Completed source | Base Depthmarks | Weighted item rolls |
| --- | ---: | ---: |
| Spore Hive | 18–28 DM | 2 |
| Rootbound Horde | 32–48 DM | 3 |

The current floor reward factor scales DM once. These source-specific tables use existing Rootbound materials and supplies, with no guaranteed item. They cannot issue elite fragments, Rootwarden-exclusive items, Ancient materials, future-boss trophies or pet findings. The item catalog remains 350 noncurrency definitions plus the existing currency record.

One validated terminal event creates one reinforced-style searchable cache. Its appearance does not mean the shell or defenders were elite enemies. Search/Take and Take All use the existing ledger; unavailable visible cache slots do not discard stored rewards. Unsearched items do not enter the player's bag automatically.

Only the event's actual defeated members contribute aggregate kill credit and honest species discoveries. The shell adds none. Full extraction retains the existing XP formulas and secures collected items, DM and pending event records in one save. A safe Return spring secures those collected rewards and eligible records with kill-only XP, leaving full-clear statistics and depth unlocks unchanged. Event completion does not defeat the required boss or unlock another depth. Death or abandonment discards unsecured progress while preserving previously secured equipment, currency, recruits and discoveries.

The existing profile-v7 shape remains. These local source and save checks support offline testing; they are not a secure online authority.

## Mobile budgets and remaining checks

The two existing hazard wrappers are reused. Registered hazards/events share active and reserved enemy capacity. New typed-hazard admission requires room for its warning and limits additional ordinary activity; it does not silently cancel an existing enemy attack merely to make space. Legacy ordinary warnings are not falsely represented as already using a global four-shape scheduler.

Native presenters use bounded original mesh families and graphics preferences. They are prototype artwork, not imported production models. Physical Android warning readability, touch comfort, frame pacing, memory and thermal behavior remain unverified. Presenter-only triangle counts are 873 for the spike lane, 648 for spores and 504 for the hive; these exclude shared warnings and room geometry. Presenters add no simulation loop, lights or navigation. Headless dummy rendering cannot read back real MultiMesh transforms, so geometry tests capture exact submitted transforms and cross-check native buffers where available. These checks establish authored bounds, not rendered beauty or device frame rate.
