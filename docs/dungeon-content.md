# Registered dungeon content

7D.1 established registered encounter identities and shared scheduling. The
[validated 7D.2 checkpoint](milestone-7d2-validation.md) adds actual
Thornmarshal and Mycelial Cantor controllers, an Ascendant Thornmarshal pattern
and an optional Root Bark Champion to Rootbound. Read the [encounter guide](rootbound-encounters.md)
for selection rules and mechanics. The [7D.3 event batch](rootbound-events.md)
adds spike lanes, spore patches, a destructible hive and finite horde. Additional
themes, trap families and Ancient encounters remain later work. [7D.5 Crystal](glimmering-crystal-abyss.md) adds the first additional executable theme. The [7D.4 Return springs](dungeon-return-springs.md) now provide safe early exits without completing a floor. Headless validation does not
replace physical Android play-testing or rendered visual review.

## One issued expedition

The Rootbound progression track keeps its existing `biome_id: rootbound_abyss`. A separate `theme_id` identifies the executable scenery and encounter theme. This distinction preserves old depth unlocks while allowing later content batches to vary a floor's environment. Depth 1 still uses Rootbound and its actual Rootwarden.

`VaultDungeonContent.resolve_run_plan(seed, depth)` selects registered, enabled definitions and resolves a detached plan. The plan contains the seed, floor, content/theme/boss versions, actual boss variant, enemy tuning, event limits and explicit reward/pet profile identities. Its presentation includes the existing fourteen module mappings and resolved material, shader, native texture and environment parameters. Neither the portal UI nor a loot cache chooses a scene path, boss, reward table or multiplier.

Session admits a content run through `begin_content_run`; Abyss independently prepares it through `configure_content`. Game compares both full plans and the separate depth policy during travel. Public getters return detached copies. The original `begin_run`, `begin_depth_run`, `generate` and `generate_for_depth` remain compatibility paths for explicit fixtures; production travel uses the content path. `generate_for_run` adds content metadata without changing configured topology version 2 or the bounded seed mixer.

Content version 5 retains the boss, event and Return spring contracts and freezes theme selection, ordinary encounter composition, trap/discovery policies and native arena profiles. Depths 1–5 remain Rootbound; higher depths use a dedicated seeded 60/40 Rootbound/Crystal draw. Plans contain only the selected theme's actual producers. All eligible pools must validate before preview and admission; unavailable content never silently falls back. `RoomContentPlanner` derives optional placement from that plan and
the generated layout. The world privately admits the actual room after native
floor, body and route checks; an unsafe optional slot is omitted. These probes
exclude the retained previous world's collision and require ground belonging to
the candidate room. Game checks physical admission before replacing its safe
world, and checks identity again through the final fade. The portal's possible
boss preview performs no random selection or admission.

The actual Rootwarden scene/controller, attacks, modifiers, collision and appearance remain in place. Its identity adapter captures all twenty-two exported tuning values, reconstructs private data, and applies the existing floor factors once. Existing enemies likewise receive their admitted tuning. Frozen presentation reconstructs materials once per world and shares them across rooms; it does not generate new meshes every frame. Resource definitions author later runs rather than reinterpret an admitted one.

## Death identity and rewards

The world privately registers an actual actor reference, room, spawn ordinal, generation and approved descriptor. Death admission checks that actor, its expected parent, current world/run, death state and zero health. Actor metadata and a cache's visual category are not reward authority.

Descriptors distinguish ordinary actors, the required boss, optional encounters
and support actors. Only the registered required boss can complete the floor
objective. Support actors have no independent reward, pet finding, XP or discovery
grant. The optional Champion uses its own registry and source; its elite cache
cannot unlock extraction.

Only `rootwarden_legacy` resolves the existing Rootwarden loot and Rootling findings. An unknown boss or profile is rejected rather than falling through to that reward. Rootbound ordinary, stronger and elite sources retain their existing tables. Crystal uses three separate ordinary tables and four named encounter tables, with no Rootbound-exclusive or pet fallback. Rewards still use the original loot sampler, source restrictions and catalog-value validation; approved results enter the existing one-claim ledger before callbacks. Searching never rolls again. Live catalog/economy hot reload is not supported by this prototype.

The three new encounter tables use explicit `encounter:<definition_id>` sources
and existing items. Their labels come from admitted source presentation IDs, not
from a cache choosing a reward. None grants Rootwarden-exclusive encounter loot
or pet findings. New required bosses and Champion apply the frozen floor factors
once, independently of ordinary enemy room-distance and elite scaling.

## Shared encounter limits

One world-owned scheduler accounts for six active nonboss actors including
support, one required/optional boss lease, two environmental hazards and one
warned environmental event. Pending reservations consume capacity. Existing
awareness events reserve before their full warning; cancellation releases
capacity and a later attempt must warn again. Unrelated trap casts cannot consume
an event's reserved hazard window. Room changes, safe areas, boss admission, run
replacement and world exit cancel incompatible work.

Boss admission suspends ordinary actors before boss damage becomes active. Native
Rootbound hazards retain their existing pool. Cantor's actual support actors are
registered inactive, then admitted through its reserved source and cast. A full
3.5-second warning precedes the native floor, capsule, route, occupancy and
all-party-distance recheck. Public summon sockets are world coordinates; the
scheduler converts them to private room coordinates and the manager applies one
spawn lift. Cantor consumes one attempt per phase, with at most two live defenders
and four admitted across the encounter. Failure is harmless and consumes the
attempt. Owner death, room exit or source invalidation cancels support without
counting it as a kill. Rootwarden keeps its original activation behavior.

## Return spring source proof

The private planner reserves Return rooms before optional Champion and event placement. It preserves native modules, roles, ordinary packs and all connectors. Long layouts guarantee one or two sources; short-main-route fallback honestly uses a distant nonhidden branch for the second. Each source needs actual native floor, body, chest-front approach and route admission. Public markers and advisory safety never authorize a transaction.

Fresh safety checks require verified local pack deaths, a resolved initial trap opportunity and no relevant pending damage, hostile actor or incoming projectile. Legacy and ordinary attack dispatch observations cover callbacks still on the stack; malformed safety results deny. Native room/source poses and the complete issued world identity remain bound. Unassigned global awareness queues do not block a clear local source.

`secure_early` saves collected rewards, eligible discoveries and kill-only XP once, without full-clear statistics or depth unlocks. Private accepted-source identity, a closed run and Game's transition ownership are rechecked through deferred travel and final fade. Failed saves leave the active bag; failed arrival after saving leaves a travel-only retry. A replacement run cannot inherit an old return. Profile v7 retains its existing shape. See [mechanics and limits](dungeon-return-springs.md).

## Rootbound event source proof

D3 assigns independent deterministic optional slots after Champion placement. Hazard pools retain two wrappers. Typed hazard admission reserves warning capacity without cancelling existing ordinary attacks merely to make space. Hives and hordes suspend ordinary activity and use full 3.5-second spawn/resume warnings; reservations count toward the shared limits. Legacy ordinary warnings are not represented as using a new global four-shape cap.

The private event registry binds the actual core, committed wave actors and verified deaths to one issued run. Pausing retains those actors, health and identities, cancels their attacks and owned projectiles, and requires a fresh warning. Missing actors are never substituted for kills. Core-only completion grants no shell kill XP; hordes require all committed waves. Terminal proof produces one aggregate cache/kill credit/record, while individual event members produce no independent rewards. Existing v7 records accept the two registered event identities.

The opaque hive uses physical, camera and stationary-obstacle layers. Cached companion routes invalidate on actual body admission/removal. Gameplay line-of-sight and projectile sweeps include that obstacle; a direct ray may hit its intended target, but cannot ignore a different intervening core. Ordinary enemies retain their prior collision bits and add the stationary obstacle. Floor probes keep the original world layer.

See [exact event timing, selection and rewards](rootbound-events.md). Resource edits affect future issued content; the approved v1 hazard/event tuning tuples are fixed, rather than freely retunable exports.

## Attack footprints and projectile lifetime

New explicit warnings share circle, capsule, sector and annular-sector definitions between display meshes, analytic hit footprints and companion avoidance. The analytic annular safe center remains empty. Meshes approximate curved edges with triangles; an enabled annular attack must also clip the inner hole in its local warning material so inner chords do not shade safe space. This batch does not enable such an attack. Navigation checks whole segments, including leaving an initially occupied shape without re-entering it. Candidate escapes remain bounded and use the existing floor, body-clearance and route checks. Guardian and Mystic keep reaction delays, committed actions and ordinary behavior; legacy warnings keep their original path.

Typed escape candidates and full dodge routes additionally check the companion's
actual collision shape against its current nonstatic collision mask. This keeps
a nominally safe point from routing through an enemy body. These bounded checks
run at the existing decision edges, outside the persistent static-geometry cache.
Ordinary path planning and its throttling remain unchanged.

New encounter projectiles can opt into a five-integer cast identity: run generation, source instance, cast serial, stage and attack ID. The source validates current lifetime and each target's eligibility, arena, height and line of sight. Cancellation makes the projectile inert and hidden before deferred deletion; its reported flight state cannot keep a stale warning corridor alive. The general projectile seam supports bounded flight ownership; the Crystal Wraith specifically retires every owned flight before recovery. Its two actual bolts share one attack ID and do not also deliver ground-lane damage.

The first new Rootbound controllers use melee/ground attacks and summons, not
boss projectiles. Their active damage authority ends at recovery; a retained
attack label for presentation or exposed armor does not retain damage authority.

Hit callbacks can end an encounter or remove a world. Guards run again before further damage and projectile feedback. Already delivered damage remains accepted, while removed targets no longer receive feedback through stale references. Empty-token player/staff/archer projectiles retain their existing ray sweep, muzzle-wall correction, splash and lifetime behavior. This is local gameplay authority, not authenticated multiplayer security.

## Crystal stages and hazards

Version-two attack definitions issue each stage explicitly. The first active window retires before a harmless gap, then stage two receives a new attack ID and full independently admitted warning. A pending gap blocks a local Return without inventing an AI danger zone. Cancellation or a changed source removes the pending continuation. Wraith relocation checks its actual capsule along a grounded route and stops at live obstructions.

The typed resonance hazard uses the existing two-wrapper pool. Initial traps and awareness events have distinct private ownership records; an awareness event transfers its already-held reservation after the full event warning. Each hazard then gives its own full warning and finite pulse edges, discarding delayed-frame overrun. A final harmless visual tail remains an unresolved initial opportunity until actual retirement. Terminal identity and damage-dispatch observations prevent old callbacks from authorizing Return or changing a replacement cast.

New Crystal presentation uses fourteen separate native scenes on the retained grid and connection anchors, shared material roles and bounded instanced decoration. Native scene/actor validation checks collision and posed bounds; geometric envelope arithmetic alone is not admission. The static art and room counts are not a claim of rendered beauty or Android frame rate.

## Save compatibility

Profile v7 adds a small `encounter_records` namespace alongside the existing four-ID monster journal. It records secured theme discoveries and boss encounters, with counts, highest recorded floor, first recorded revision and local discovery time. Full extraction saves these with loot, pets, XP and depth unlocks. A valid Return spring can secure eligible pending records and collected rewards without a full-clear bonus or depth unlock. Pending records are lost on death or abandonment; failed saves remain retryable.

7D.2 keeps that save shape and adds exact encounter IDs. A validated Ascendant
Thornmarshal defeat derives one journal-only subset observation alongside its
base record. Its count and highest depth cannot exceed the base, and its first
revision cannot precede the base. It is never another kill, reward or objective.
The Crystal Refracted Conductor uses the same derived-only observation rules alongside its base encounter. Neither variant grants a second reward. No historical variant record is inferred from old items or completions. These
new records are available in the saved profile; their dedicated Hall/journal
interface remains for 7G.

Migration preserves inventory instances, Depthmarks, enhancements, loadouts, talents, companions, pets, Hall selections and v6 depths. Historical Rootwarden discovery is marked as predating tracking; it does not invent an old kill count, floor or date. Existing successful Rootbound completion can prove a theme discovery. Unknown future encounter/depth data is preserved read-only before backup fallback. The first migrated write retains exact old bytes through the existing pre-version backup mechanism.

Dates use the local device clock for display only. They do not decide rewards, rotations or eligibility. Local files remain editable development persistence; online authority, accounts, database transactions and ranked results are not implemented here. Active ordinary expeditions still do not resume after the process closes.

## Verification boundaries

The stage gate covers definition/schema validation, old/new module equivalence, registered source grants, pending event capacity, actual warnings and cancellation, both cameras, real companion escapes, projectile callbacks, rich save migration and independent restarts. Current measured results belong to the stage validation report, not this architecture guide.

Rendered visual review, physical Android touch/keyboard behavior, sustained frame rate, thermal behavior and final difficulty balance require device play-testing. Follow the [Android checklist](milestone-7-android.md) and retain the [depth rules](dungeon-depths.md). No online service or new playable biome is implied by a reserved interface.
