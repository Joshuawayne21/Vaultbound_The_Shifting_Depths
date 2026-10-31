# Milestone 5.6 host performance and structural report

Recorded on **2026-10-31**, using **Godot 4.6.3 stable, Linux x86-64 headless**.
The game remains configured for **GL Compatibility** on desktop and Android.
The measured catalog contains **351 definitions: 300 available noncurrency
items, 50 unavailable entries and the preserved currency record**.

These measurements cover native catalog and reward CPU work in an isolated
host process. They do not measure a rendered game, Android hardware, GPU time,
draw calls or graphics memory. **30 FPS and optional 60 FPS remain device targets,
not verified results.**

## Measurement method and evidence

Seven fresh Godot processes loaded an isolated copy of the actual definition
resources, family art and native catalog/reward scripts. The project had no
autoloads or gameplay scene, and did not access a real profile. Resource import
was completed before timing. Each process verified **zero cached item definition
resources** before its first `VaultLootTable.catalog()` call. This is a cold
Godot resource cache; the operating-system filesystem cache was **not** flushed.
Script startup and import are outside the first-load interval.

Each process retained that catalog, verified shared resource identity, and made
25 further catalog calls: **175 warm samples** overall. Known and unknown
`item_for()` calls each used 30 batches of 1,000 calls per process: **210,000 calls
of each kind**. Known IDs cycled through the registry. Unknown IDs were rejected
by the actual registry membership check.

Each real `VaultMonsterRewards` source received 100 warmups followed by 1,000
individually timed rolls per process: **7,000 measured rolls per source**. The
native validation, source filtering, temporary table construction, weighted
selection and reward assembly all remain inside the timed call. Seeds/receipt
strings and timing-array storage were prepared beforehand. Results were checked
and discarded. No simplified replacement reward algorithm was used.

Other project Godot gates paused for this seven-process window. The machine
reported Linux 6.18.57, x86-64 and five logical CPUs; shared-host scheduling can
still affect timing. A preliminary run that overlapped other gates was stopped
and excluded. All measured source hashes remained unchanged during the final
run. The later presentation integration changes none of those measured catalog
dependencies; its actual integrated scripts were reviewed separately below.

Session evidence is retained outside the repository:

- Harness: `/tmp/vaultbound-m56-performance/audit.gd` and `run_audit.py`.
- Final raw samples, per-file SHA-256 hashes, logs and summary:
  `/tmp/vaultbound-m56-performance/final-20261031T211003Z/`.
- Registry SHA-256:
  `f87937f671456af13b7be7658fb43f0e5d8d2913e1737eb44097efb781230c2f`.
- Aggregate SHA-256 of the sorted source-hash map:
  `4611ba11cb444fe1703d9e19b90cb3fc32a4019cf3cf1fb7de09694ffcb55971`.

The scratch harness is session evidence, not an additional checked-in game
dependency. It imports a copy and calls the same native APIs available in the
repository. The checked-in [compact measurement data](milestone-5.6-performance-results.json)
preserves all seven per-process summaries, pooled results, exact artwork counts
and source hashes. Every measured dependency was also verified byte-for-byte
against the recorded repository commit after presentation integration.

## Native host timing

| Operation | Median | p95 | Observed range |
| --- | ---: | ---: | ---: |
| First catalog load, fresh process | 114.060 ms | Not reported: 7 samples | 106.718–121.188 ms |
| Warm catalog dictionary, retained definitions | 0.788 ms | 0.971 ms | 0.700–1.527 ms |
| Known item lookup, amortized per call | 2.593 µs | 3.155 µs | 2.364–3.956 µs |
| Unknown item rejection, amortized per call | 0.647 µs | 0.839 µs | 0.574–2.441 µs |
| Basic monster reward roll | 1.948 ms | 2.490 ms | 1.635–7.838 ms |
| Stronger monster reward roll | 2.054 ms | 2.510 ms | 1.767–6.575 ms |
| Elite monster reward roll | 2.084 ms | 2.626 ms | 1.729–9.857 ms |
| Boss monster reward roll | 1.775 ms | 2.228 ms | 1.486–7.662 ms |

Lookup percentiles describe batch durations divided by 1,000, rather than
individual-call tails. Reward percentiles pool the individually timed calls.
Seven cold samples support a median/range, not a useful tail estimate.

`catalog()` constructs a dictionary on every call. `item_for()` scans the native
ID array for membership, then uses Godot's resource loader. There is no separate
permanent catalog index/cache in this script. The warm figures require retained
resources and cannot be assumed for a call after those references are released.
The reward figures apply to the current native source tables and include their
validation cost. They are not a prediction of Android combat frame time.

The actual RPG/session call path does **not** retain the full definition catalog.
`progression_snapshot()` and `VaultInventory.describe_entries()` return copied
item metadata; `VaultItemDefinition.describe()` writes icon/model path strings,
not references to the definition. `_rebuild_journal()` obtains the full catalog
in a local array, describes it into cached UI dictionaries, and releases that
array on return. It runs on each explicit RPG refresh, including inventory and
transaction refreshes. The Hall's revision-driven completion calculation also
uses a temporary catalog. Recipe and merchant resources retain IDs/metadata,
rather than a complete item-definition array.

There is partial retention elsewhere: the Abyss script preloads
`monster_rewards.tres`, whose four-table resource graph references **249 distinct
definitions** while that script/resource remains loaded. Live chest tables can
retain additional definitions. The Sanctuary startup path supplies no explicit
full-catalog retention anchor. Resource state therefore depends on the current
scene and other live references. Some definition loads can recur on menu opens
or accepted-transaction refreshes; the journal's cached metadata alone does not
prevent them. This is bounded event-triggered work and a potential menu hitch,
not a measured per-frame stall. Neither the 114.060 ms resource-cold figure nor
the 0.788 ms fully retained figure is an actual menu-latency measurement.

The session's once-per-second expedition update returns early while modal
controls are disabled, and hidden RPG panels do not refresh from session
snapshots. Source review found no idle per-frame full-catalog reload. No new cache
was introduced from these host figures alone; repeated menu/transaction latency
remains part of device review.

## Native allocator observations

Loading and retaining the catalog increased Godot's static allocator usage by
**3,476,748 bytes (3,395.26 KiB)** and added **448 Resource objects** in every
process. These totals include the definitions and their shared dependencies.
The cumulative static allocator peak at audit end was **24.74 MiB**; it includes
the engine and harness and is not an estimate of the running game's memory.

After warmup, each source's 1,000-roll loop retained **zero additional Resource
objects**. Static allocator endpoint deltas were consistently −440 bytes for
basic, −984 for stronger, −1,528 for elite and −3,244 for boss. Thus these bounded
loops showed no positive retained allocator growth. This does not establish
absence of transient allocations or a long-running leak proof. Memory snapshots
were outside timed sections; timing arrays and receipt strings were allocated
before the reward baselines.

The harness's RSS reads returned **unavailable (`-1`)**. No RSS value or RSS delta
is reported. Static allocator usage is neither complete process memory nor
Android heap/VRAM usage. Graphics-resource memory was not measured.

## Integrated structural bounds and cache review

These observations were rechecked against the applied checkpoint 8 scripts,
including `rpg_panel.gd`, `item_inspection_panel.gd`, `item_presentation.gd`,
`item_presentation_budget.gd`, `player_avatar.gd` and `expedition_overlay.gd`.
They describe bounded work, not measured GPU savings.

| Area | Actual bound or update policy |
| --- | --- |
| Secured inventory | 40 occupied slots; eleven equipment assignments reference owned instances |
| Hall | Eight equipment stands and four relic pedestals |
| Frame-style cache | 96 shared immutable entries; decorative alpha quantized before keying |
| Item icon caches | Keyed by authored resource path; 16 distinct paths in the final catalog |
| RPG panel | No idle processing; only its one-second committed-upgrade cue enables `_process()` |
| Journal/catalog arrays | Rebuilt on explicit panel refresh; cached between redraws |
| Character preview | 296×364, static avatar, `UPDATE_ONCE` after changes; hidden/off-section viewport disabled |
| Item inspector | 384×384, one selected model, static descendants, `UPDATE_ONCE`; closing disables viewport updates |
| Item spark scheduler | One shared scheduler, eligibility refreshed every 0.25 seconds |
| Active item sparks | Low 4 / Medium 8 / High 12 total; at most three per component |
| Searchable loot views | Eight pooled views: seven regular/elite and one reserved boss view |
| Rare+ notification | One active noninteractive card and at most four queued cards |

Icon caches have no eviction cap, but normal gameplay inputs select from the
finite authored icon paths. Selection, UID and enhancement do not form new
texture keys. The final 351 definitions therefore do not imply 351 loaded icons.
See the [exact artwork inventory](milestone-5.6-assets.md).

Inventory filtering/sorting happens during requested draws and operates on the
forty owned slots; only cells intersecting the list clip are drawn. Some helpers
recompute this small filtered list during a redraw. The catalog journal caches
its metadata and sorting on `refresh()`. It still checks row positions when
drawing the larger journal. Session updates refresh the RPG panel only while
visible. The existing touch HUD separately requests redraws at most 30 times per
second; it does not cause a per-frame inventory rebuild or preview render.

Both preview viewports remain allocated when hidden. Disabling updates stops
rendering work; it does not claim to release viewport memory. The item inspector
removes authored model scripts and disables descendant processing, particles,
audio, animation and collision before tree entry. It retains the selected model
through same-model property changes. Character and item preview accents allocate
no spark mesh and never register with the world scheduler. Each preview stage
uses a shadowless directional light when rendered.

World item components reserve **three spark MultiMesh instance slots each**;
4/8/12 is the shared active/visible update budget, not total reserved storage.
Each component also has one rim and one-to-seven rune instances. The scheduler
checks visibility, camera frustum, world identity and distance up to 20 units.
Inactive components stop processing. Accents add no collision, light, shadow
casting or per-frame mesh construction. Rotation is limited to ±0.5 rad/s, bob
height to 0.08 units and bob speed to 2.0. Reduced motion freezes presentation;
reduced effects or reduced motion remove active sparks. Existing environmental
ambience budgets remain separate.

Two deliberate limits to the bounds deserve explicit treatment. The legacy
reserve preserves distinct older/unknown IDs without an entry-count cap; its
normalization and browsing scale with that migrated data. Normal new grants
cannot grow the reserve. The loot ledger retains generated source records until
the run ends, so its data scales with the finite expedition rather than the
eight-view pool alone. Each cache caps item rows and merged sources at 32.

This audit introduces no speculative optimization or changed ownership rule.
Existing world geometry and quality-tier figures remain in the archived
[Milestone 5.5 report](milestone-5.5-performance.md); they were not remeasured as
new Milestone 5.6 GPU results.

## Physical Android work still required

Follow the [Android regression and sustained performance checklist](milestone-5.6-android.md).
Test all quality tiers and UI scales, both cameras, full forty-slot inventory,
both previews open/closed, twelve populated Hall stands, enhanced high-rarity
equipment, two companions and dense encounters. Warm up and record at least
15 minutes per chosen configuration with fixed seeds/routes, then repeat with
reduced motion/effects.

Record actual FPS and frame-time spikes, draw calls, memory where tools permit,
shader errors, touch latency, heat/throttling and battery behavior on the target
devices. Establish sustained 30 FPS before assessing optional 60 FPS. No physical
Android test, rendered visual approval, APK export/signing, thermal run or
battery measurement was performed for this report.
