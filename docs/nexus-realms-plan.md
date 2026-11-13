# Nexus of Realms — staged integration plan

**Stage 5b accepted: 0.7.0-nexus5b / Android code 33.** Echoes passed 19,776 native checks across 142 modes and 120 suites, including seventeen independent restart readers, plus import, 62 strict loads and 120 startup frames. The fourth playable major gateway supplies five finite waves, eleven original actors, two temporary choices and searched existing DM/materials; six activities remain unavailable. Profile13/activity 2 preserves Beast and home 3. See [scope](echoes-of-eternity.md), [accepted evidence](nexus-stage5b-validation.md) and [historical Beast evidence](nexus-stage5a-validation.md). Masks remain explicitly user-deferred.

The latest written brief supersedes the older blueprint's wing assignments: **north = Nexus; east = merchants/crafting; west = cosmetics/home/pets; south = guild/social and entrance**. The existing central Exchange, Living Prismheart, six shared DEMO booths and eight arch/bridge routes remain the circulation framework. Four functional wings can contain multiple existing spokes; reorganization must not delete working destinations.

## Recovery and preservation

Baseline local commit: `1c05c94fa7cb733bcc2d775db9de7874cbb7bf73`. Published main: `8275babeb3338e1fde049d6e9ad2138cd357e0de`. Matching tree: `05a1d69b70e16579d4fe43917877b518d4c4aef5`.

Verified full-history bundle: `/workspace/backups/vaultbound-before-nexus/accepted-home6b.bundle`, SHA-256 `b5023875cfdbd8b600fedbc7da6cc799a1fe570e07665505dc2d8e397a4d35f1`. This is source recovery, not a phone-profile backup. Historical home6b reports and unrelated original-worktree changes remain untouched.

Keep one player/controller, both cameras, existing Android input, real inventory and Depthmarks, all current dungeon depths/content, Guardian/Mystic, Spiritweaving, home identity/rooms/trophies and validated save writes. Do not duplicate the Exchange economy, Prismheart, Guild Conquest authority or player home. Existing safe-zone behavior remains.

## Ordered checkpoints

| Stage | Work and acceptance boundary |
| --- | --- |
| **0 — audit** | Document actual systems and absent prerequisites; verify the recoverable baseline. Commit these findings independently of unverified implementation. |
| **1 — four-wing city** | Reorganize existing services through the shared layout. Keep the central courtyard and all eight spokes/bridges; move practical vendors/forge east, appearance/home/pet services west and Tavern/recruitment/social spaces south. Establish a southern city Grand Foyer and north Nexus approach with clear signage. Validate all relocated interactions, actual routes, camera collision, arrivals and saved data. This stage does not claim ten playable activities. |
| **2 — Nexus architecture · foundation accepted** | Separate north hall, three galleries and ten distinct gateway identities around a secondary Prismheart-styled Conduit are implemented and native-tested. Same-Sanctuary return and party state are preserved. Art is original native-mesh prototyping; rendered/mobile polish remains. Ten inspectable gates do not imply ten completed activities. |
| **3 — common portal authority/UI · foundation accepted** | One configurable catalog and shared touch card bind entry to actual original sources. Native tests cover availability, reviewed/deferred route checks, generation/loading, stale input and denial without reward. The foundation distinguished eight unavailable activities from depth locks; Stage 5a enabled the third route; Stage 5b validates the fourth local route. Full matchmaking/mastery and artwork/audio presentation remain later work. |
| **4 — existing playable routes · accepted** | Abyssal uses the existing depth selector/generator/combat/reward/extraction authority. Bloodspire exposes existing NPC practice without PvP/rank progress; the auxiliary Sunken Vault retains legacy practice. Actual entry, arrival fault/rollback, reset, exit, return and retained expedition settlement passed with player/AI/pet state preserved. |
| **5a — Beastwilds · accepted first loop** | Four habitats with required trail/egg/rescue and optional forage; existing Spiritweaving ingredients/memories, no direct pet capture. Earned Depth 2 or existing offline TEST ACCESS; reviewed secure/abandon to Nexus through separate activity receipts. Profile v12/activity-v1 migration, settlement, guarded return and independent-restart tests passed; rendered/device review remains. |
| **5b — Echoes of Eternity · accepted finite trial** | Five finite waves/eleven original actors; existing solo Rootwarden at wave 5; at most three ordinary enemies or one boss. Two choices after waves 2/4: +6% damage or +12% regeneration. Explicit Start/Continue; searched existing DM/materials; safe secure/abandon and profile 13/activity 2 records. No XP, masks, mastery, new boss or online co-op. Temporary effects must expire without permanent changes. |
| **5c — Gilded Vault** | Implement a real treasure route with supported puzzles/hazards, source-verified rewards, completion/failure and return. Do not claim moving walls, mimics or locks until those mechanics exist and are tested. |
| **6 — Titan's Gate** | Implement distinct boss encounters, phases and admitted boss-specific rewards. Begin only with supported party behavior; the current three-member offline party does not satisfy proposed 2–4 human co-op. Expanded capacity/networking requires separate tests. |
| **7 — mastery/rewards/masks** | Add versioned per-activity completion/settlement, Realm Mastery and Nexus Renown data before exposing persistent rewards. Proposed 25/50 levels are configuration targets. Integrate trophies through existing ownership/display rules. Mask integration is user-deferred; do not invent F–S/Abysmal definitions or probabilities. |
| **8 — competitive activities** | Bloodspire online modes, Shattered Rift team PvPvE and Guild Conquest require authenticated accounts, server-authoritative combat/escrow/results and persistence. Build only honest local foundations before infrastructure exists. No AI can award ranked progress. Guild War Room and Nexus must reference one future Conquest activity. |
| **9 — events/endgame/instability** | Add configurable local-test Chaos events, then actual Forbidden content and compatible instability mechanics. The Forbidden unlock must use a verified floor-20 clear plus four earned seals with a complete PvE route. No reward or seal from unfinished activities. Online schedules and rare encounter rolls need authoritative admission when online. |
| **10 — integrated mobile review** | Run final import/script/load/travel/save and relevant regression checks; review both cameras, reduced effects, graphics presets and real Android play. Record measured performance separately from native geometry inventories. Publish only verified checkpoints. |

The accepted 2–4 checkpoint is a foundation: it does not satisfy the full requested ten-activity gameplay, artwork/audio, matchmaking, mastery or reward feature set. **5a — Beastwilds** is the accepted local discovery checkpoint. Echoes is the accepted finite-trial checkpoint. Gilded Vault remains unavailable; isolated drafts are not integrated or accepted gameplay. The [next-activity plan](nexus-next-activities.md) retains the proposed Gilded slice and records the narrower Echoes checkpoint. Rendered and physical Android acceptance remain pending.

Each stage ends with its own change summary, evidence, known limitations and commit. Do not proceed past a critical regression. Missing infrastructure blocks its dependent stage, not independent city, UI or offline work. No public service deployment, paid hosting, credentials or live billing should be introduced without the required authorization.

## Stage 1 layout contract

- **Center:** retain the current Exchange courtyard, six shared booths, protected Living Prismheart, ring circulation, eight clear archways and recent bridge/flicker repairs. Preserve readable sightlines and service approaches.
- **South entrance:** the city Grand Foyer is a public arrival promenade, distinct from the existing private home's Grand Foyer. The accepted default spawn is **`(0, 0.95, 31)`**, facing toward the Exchange, over the supported raised southern floor. Stage 1 checked floor/capsule/party arrival and actual bridge traversal; new architecture still requires its own checks.
- **Return arrivals:** keep `from_dungeon`, `from_abyss` and `from_hall` transforms exactly as recorded in the audit. Existing players returning from activities must not be stranded by renamed entries.
- **North:** the accepted north gateway now loads the separate Nexus; ten major gateways plus auxiliary practice/return are inside. Existing city practice-gate locations become honest route/preparation guides, retaining their identities. Existing dungeon/practice gameplay remains accessible inside the hall. A Contract Board display must describe actual supported records/tasks; a new rewarded contract system needs its own authority.
- **East:** place the existing three vendors and Blacksmith within coherent shopping/crafting space, using their existing vendor IDs and transactions. Bank and mask stations cannot advertise unsupported storage or crafting as finished.
- **West:** relocate the existing equipment preview, Personal Sanctuary entrance and single Spiritweaving terminal. Keep home destination, source registrations, owned pet data and home display slots unchanged.
- **South social branch:** retain working recruitment and social UI. Guild/ranking/Conquest information must clearly identify missing online functionality. Do not fabricate guild membership, standings or world messages.
- **Undercroft:** reserve a coherent later route only; no playable Undercroft exists to migrate. Its eventual navigation, discovery and return need an independently tested implementation.

The city may reorganize names/positions and adapt the old Forge/Tavern terrace use, but must retain traversable district connections. Tests containing intentionally obsolete coordinates should be updated to the new authored contract without removing movement, collision, no-recovery or save-preservation assertions.

## Ten gateways and honest availability

| Gallery | Gateway | Foundation status and dependency |
| --- | --- | --- |
| Adventure | Abyssal Descent | Connect existing playable progressive dungeon authority; no replacement dungeon implementation. |
| Adventure | Beastwilds | Accepted Stage 5a four-habitat discovery loop; existing ingredients/memories, no direct pet capture. |
| Adventure | Gilded Vault | New treasure/puzzle activity required in Stage 5c. |
| Adventure | Titan's Gate | New boss activity required in Stage 6; online co-op is separate. |
| Conflict | Bloodspire Arena | Explicitly local practice may reuse supported scenes. Real duel/team/ranked modes require Stage 8 infrastructure. |
| Conflict | Shattered Rift | New extraction activity and authenticated multi-team authority required. Secured gear remains protected. |
| Conflict | Guild Conquest | No current guild service or Conquest gameplay. One future activity authority must serve both entrances. |
| Ascension | Echoes of Eternity | Accepted Stage 5b finite five-wave local trial, earned Depth 3 or offline TEST ACCESS. |
| Ascension | Chaos Gate | Configured, clearly labelled local events first; real event rules and rewards required. |
| Ascension | Forbidden Gate | Unavailable until actual realm content, earned PvE seal routes and verified unlock/settlement exist. |

The foundation therefore does not complete all ten activities. Every entrance can have a real inspection interaction, distinct art and an accurate card, while unavailable gameplay has a disabled Enter action with its development/backend reason. Do not send players to empty scenes and call them playable. TEST ACCESS may bypass supported progression gates; it must not make unavailable content or missing services appear implemented.

Portal cards should share readable Android layouts and show name, gallery/activity description, current availability, requirements, party/solo options, actual difficulty/reward previews, supported records and Enter/Back. Matchmaking, mastery and rewards must show honest unavailable states until their authorities exist. All delayed/rapid input and scene-load failures must be handled without duplicate entry or rewards.

## New activity settlement and saves

The accepted layout stages preserved profile v11/home v3. Stage 5a introduces profile v12/activity-v1 with explicit migration backups, future-data protection, restart fixtures and atomic save-before-publish behavior; home v3 is retained. Stage 5b migrates profile 13/activity 2, preserving the original Beast row/ticket and adding Echoes under one shared serial/open-ticket boundary. Its pre-v13 backup and cross-activity restart behavior passed native verification. New activity records must include admitted activity identity, instance/generation, completion source, receipt and settlement outcome. Validate definitions, quantities, ownership, capacity and repeat claims through the existing economy/inventory boundary.

Beastwilds, Echoes and Gilded completion cannot impersonate Rootbound boss death, extraction or depth progression to obtain convenient grants. Each activity needs its own trusted completion rules. Temporary upgrades cannot mutate secured equipment; trophy display references must not duplicate or consume owned items. Offline code is not secure online authority, even when it uses the same reusable transaction interface.

## Required verification and reporting

Use isolated disposable profiles. Validate fresh Godot import, strict changed-script loads, scene startup and references; actual walking/collision/camera routes; touch input and entry cancellation; all existing service interactions; companion following and return; home identity/displays/pets; save/restart/failure and duplicate-input rejection. Run relevant baseline suites plus new behavior-specific tests. Record deliberate coordinate changes and any old expectations replaced.

The new default arrival, southern foyer, east/west service approaches and north Nexus route require native formation/floor tests and continuous movement checks. Re-test both camera perspectives and Low/Medium/High around the courtyard and relocated buildings. Preserve essential collision/visibility across presets; decorative density must not change competitive sight blockers.

Report playable activities, unavailable cards, file changes, exact test scope, save-schema effects and asset/backend limitations after each accepted stage. Rendered appearance, wall motion, touch/keyboard comfort and sustained Android frame time, thermals and memory require real device evidence. Do not reuse prior screenshots, test counts or performance goals as proof of the new layout.
