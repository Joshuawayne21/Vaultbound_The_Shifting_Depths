# Registered dungeon content

7D.1 extends the existing Rootbound expedition with registered encounter identities and shared scheduling. It is the first integration batch of 7D. **Only the existing Rootbound theme, Skeleton, Goblin Archer, Corrupted Golem and Rootwarden are enabled in this batch.** The new interfaces are not a claim that additional bosses, biomes, summons, hives or hordes are already playable.

## One issued expedition

The Rootbound progression track keeps its existing `biome_id: rootbound_abyss`. A separate `theme_id` identifies the executable scenery and encounter theme. This distinction preserves old depth unlocks while allowing later content batches to vary a floor's environment. Depth 1 still uses Rootbound and its actual Rootwarden.

`VaultDungeonContent.resolve_run_plan(seed, depth)` selects registered, enabled definitions and resolves a detached plan. The plan contains the seed, floor, content/theme/boss versions, actual boss variant, enemy tuning, event limits and explicit reward/pet profile identities. Its presentation includes the existing fourteen module mappings and resolved material, shader, native texture and environment parameters. Neither the portal UI nor a loot cache chooses a scene path, boss, reward table or multiplier.

Session admits a content run through `begin_content_run`; Abyss independently prepares it through `configure_content`. Game compares both full plans and the separate depth policy during travel. Public getters return detached copies. The original `begin_run`, `begin_depth_run`, `generate` and `generate_for_depth` remain compatibility paths for explicit fixtures; production travel uses the content path. `generate_for_run` adds content metadata without changing configured topology version 2 or the bounded seed mixer.

The actual Rootwarden scene/controller, attacks, modifiers, collision and appearance remain in place. Its identity adapter captures all twenty-two exported tuning values, reconstructs private data, and applies the existing floor factors once. Existing enemies likewise receive their admitted tuning. Frozen presentation reconstructs materials once per world and shares them across rooms; it does not generate new meshes every frame. Resource definitions author later runs rather than reinterpret an admitted one.

## Death identity and rewards

The world privately registers an actual actor reference, room, spawn ordinal, generation and approved descriptor. Death admission checks that actor, its expected parent, current world/run, death state and zero health. Actor metadata and a cache's visual category are not reward authority.

Descriptors distinguish ordinary actors, the required boss, optional bosses and support actors. Only the registered required boss can complete the floor objective. Support actors have no independent reward, pet finding, XP or discovery grant. Optional bosses cannot unlock extraction merely because their cache looks like a boss chest; they remain unavailable until their own content is implemented.

Only `rootwarden_legacy` resolves the existing Rootwarden loot and Rootling findings. An unknown boss or profile is rejected rather than falling through to that reward. Ordinary, stronger and elite sources retain their existing tables. Rewards still use the original loot sampler, source restrictions and catalog-value validation; approved results enter the existing one-claim ledger before callbacks. Searching never rolls again. Live catalog/economy hot reload is not supported by this prototype.

## Shared encounter limits

One world-owned scheduler accounts for six active ordinary actors, one boss lease, two environmental hazards and one warned environmental event. Pending reservations consume capacity. Existing awareness events reserve before their full warning; cancellation releases capacity and a later attempt must warn again. Unrelated trap casts cannot consume an event's reserved hazard window. Room changes, safe areas, boss admission, run replacement and world exit cancel incompatible work.

Boss admission suspends ordinary actors before boss damage becomes active. Native Rootbound hazards still use their existing pool and readable local telegraphs. The future summon interface explicitly rejects requests in this batch: Rootwarden has no summon attack, and no support actor is secretly spawned. Actual summons, hive waves and hordes require their own finite budgets, valid sockets and runtime tests in later 7D batches.

## Attack footprints and projectile lifetime

New explicit warnings share circle, capsule, sector and annular-sector definitions between display meshes, analytic hit footprints and companion avoidance. The analytic annular safe center remains empty. Meshes approximate curved edges with triangles; an enabled annular attack must also clip the inner hole in its local warning material so inner chords do not shade safe space. This batch does not enable such an attack. Navigation checks whole segments, including leaving an initially occupied shape without re-entering it. Candidate escapes remain bounded and use the existing floor, body-clearance and route checks. Guardian and Mystic keep reaction delays, committed actions and ordinary behavior; legacy warnings keep their original path.

New encounter projectiles can opt into a five-integer cast identity: run generation, source instance, cast serial, stage and attack ID. The source validates current lifetime and each target's eligibility, arena, height and line of sight. Cancellation makes the projectile inert and hidden before deferred deletion; its reported flight state cannot keep a stale warning corridor alive. Normal recovery can retain an already authorized airborne cast until bounded expiry.

Hit callbacks can end an encounter or remove a world. Guards run again before further damage and projectile feedback. Already delivered damage remains accepted, while removed targets no longer receive feedback through stale references. Empty-token player/staff/archer projectiles retain their existing ray sweep, muzzle-wall correction, splash and lifetime behavior. This is local gameplay authority, not authenticated multiplayer security.

## Save compatibility

Profile v7 adds a small `encounter_records` namespace alongside the existing four-ID monster journal. It records secured theme discoveries and boss encounters, with counts, highest recorded floor, first recorded revision and local discovery time. Actual successful extraction saves these with loot, pets, XP and depth unlocks. Pending records are lost on death or abandonment; failed saves remain retryable.

Migration preserves inventory instances, Depthmarks, enhancements, loadouts, talents, companions, pets, Hall selections and v6 depths. Historical Rootwarden discovery is marked as predating tracking; it does not invent an old kill count, floor or date. Existing successful Rootbound completion can prove a theme discovery. Unknown future encounter/depth data is preserved read-only before backup fallback. The first migrated write retains exact old bytes through the existing pre-version backup mechanism.

Dates use the local device clock for display only. They do not decide rewards, rotations or eligibility. Local files remain editable development persistence; online authority, accounts, database transactions and ranked results are not implemented here. Active ordinary expeditions still do not resume after the process closes.

## Verification boundaries

The stage gate covers definition/schema validation, old/new module equivalence, registered source grants, pending event capacity, actual warnings and cancellation, both cameras, real companion escapes, projectile callbacks, rich save migration and independent restarts. Current measured results belong to the stage validation report, not this architecture guide.

Rendered visual review, physical Android touch/keyboard behavior, sustained frame rate, thermal behavior and final difficulty balance require device play-testing. Follow the [Android checklist](milestone-7-android.md) and retain the [depth rules](dungeon-depths.md). No online service or new playable biome is implied by a reserved interface.
