# Echoes of Eternity — five-wave trial

**Stage 5b: `0.7.0-nexus5b` / Android code 33 passed 19,776 native checks across 142 modes and 120 suites, including seventeen independent restart readers, plus import, 62 strict loads and 120 startup frames.** This is verified source, not a claim of rendered/device acceptance, an APK or installation on a phone. See [validation evidence](nexus-stage5b-validation.md), [Android checks](nexus-stage5b-android.md) and [the staged plan](nexus-realms-plan.md).

The Ascension gallery's Echoes gateway leads to a bounded solo/AI-party combat trial. Normal admission requires completing Depth 3 and successfully extracting; the existing offline TEST ACCESS switch can bypass that entry requirement without awarding a clear. The same human character, Guardian/Mystic party, weapons, cameras and combat rules remain in use.

## Court and flow

The original native-mesh spectral court has a 24 m radius, clear central combat space, low perimeter walls, three silver/violet arches, two obelisks and distant floating fragments. The southern alcove contains the arrival, trial shrine, five searchable-cache positions and return source. Existing directional lighting and static batching are reused; no extra local lights, particle systems or per-frame decorative processing are introduced. A separate native budget measured 973 world nodes and 12,014 allocated instance-weighted triangles in the admitted empty court, rising to 1,412 nodes/20,362 triangles after five waves with five unclaimed caches. These are geometry inventories, not frame-rate claims or finished production artwork; see the report for measured scope.

Approach the southern trial shrine and choose **START WAVE 1**. Each subsequent wave requires a deliberate **CONTINUE** during its break; closing a panel does not advance the trial. Spawn markers warn for at least two seconds. The director requires supported floor/capsule space, an escape route and at least six metres from the party. If the authored sockets are occupied, move away and let the same wave retry; no enemy or reward is rerolled to bypass a blocked spawn.

| Wave | Original enemies | Break |
| --- | --- | --- |
| 1 | Two Skeleton Warriors | Continue when ready |
| 2 | Skeleton Warrior and Goblin Archer | Choose one boon, then Continue |
| 3 | Two Skeleton Warriors and Goblin Archer | Continue when ready |
| 4 | Corrupted Golem, Skeleton Warrior and Goblin Archer | Choose one boon, then Continue |
| 5 | Existing Rootwarden echo, alone | Search rewards and return |

The five rosters contain eleven original actors, capped at three ordinary enemies or one boss at a time. Their existing attacks, telegraphs and hit/death rules are reused. The Rootwarden echo is not a new boss, Ancient encounter or Rootbound completion.

After waves 2 and 4, choose **Echo Force: +6% damage** or **Restoring Rhythm: +12% stamina regeneration**. A choice can repeat, giving maximum multipliers of 1.12 damage or 1.24 regeneration after both breaks. The effect applies only to the admitted living human player during this visit. It does not refill health/stamina, reset cooldowns/revives, change equipment statistics or buff companions. Leaving, death or invalidating the visit retires the effects; camera changes and a healthy same-visit recovery must preserve them. These boundaries passed the scoped native integration tests; human combat-balance review remains.

## Search, secure and return

Each fully cleared wave registers one searchable cache in the southern alcove. Use the existing **Search**, **Take** and **Take All** interface. Only searched and taken existing Depthmarks, root fiber or Mooncap Tonic enter the shared unsecured bag; completion does not automatically collect cache contents. Rewards use the existing inventory capacity checks and source receipts. All five caches use the existing reinforced presentation, without claiming a new boss-exclusive loot pool.

Before the fifth wave is complete, the return source offers **ABANDON & RETURN**, losing only this visit's unsecured rewards. After all five waves, **SECURE & RETURN** saves taken rewards and the activity result before returning to the Nexus. The review warns about unclaimed caches. Closing the card continues the visit. A failed save must keep the run retryable; a completed save with a failed physical return must offer return recovery without settling a second time.

The trial grants no character/companion XP, new trophy, mask, pet, Realm Mastery, seal or dungeon-depth clear. It must not advance Rootbound/Rootwarden achievements, merchant rotation or pet-secret statistics. Existing secured equipment, pets, home identity and displays remain owned.

## Records and saves

The update migrates supported saves to **profile 13 / activity namespace 2**, retaining **home namespace 3**. The existing Beastwilds v1 plan, records and outstanding ticket retain their original identity. A closed activity catalog admits only Beastwilds and Echoes; Rootbound keeps its original authority.

Both activity rows share one monotonic serial and at most one open visit ticket. Echoes records entries, completions, deaths, abandonments, highest verified wave, best score, secured DM, best successful completion time and last completed serial. Wave/score records derive from contiguous actual deaths; partial failure can record a reached wave but cannot secure its bag. Scores are local records, not ranked standings. An interrupted ticket is retired against its original activity when the next permitted visit begins.

Loading does not rewrite the file. The first valid migration write preserves exact original bytes in `.pre-v13.bak` alongside earlier backups; unknown future fields remain protected. Entry reserves a final save revision, so optional persistence cannot consume the last settlement write. Existing item UIDs/modifiers, Depthmarks' saved `gold` field, depths, pets, companions and home displays must remain intact. Runtime enemies, boons and unsecured loot do not resume after process eviction.

## Limits and next work

This checkpoint is five finite waves, not endless survival or online cooperation. It adds no boss artwork/audio, new combat mechanics, difficulty ladder, survival trophies, enchantments, online scoreboards or matchmaking. Masks of the Abyss remain explicitly user-deferred. Gilded Vault, Titan's Gate, Shattered Rift, Guild Conquest, Chaos Gate and Forbidden Gate remain unavailable. Physical Android comfort, rendered readability, sustained performance and human combat-balance review are still required.
