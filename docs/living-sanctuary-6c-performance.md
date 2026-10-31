# Living Sanctuary 6C structure and host measurements

Seven isolated processes completed cleanly on Godot 4.6.3, Linux headless Compatibility: three fresh production profiles for preserved 6B, three for frozen 6C, and one 6C run retaining validation construction records. [Raw measurements](living-sanctuary-6c-performance-results.json) include the exact inspector source, source signatures, commands, log paths and hashes, and individual timing samples. The 6C source matches the [full regression gate](living-sanctuary-6c-test-results.json); both sources and the inspector remained unchanged during measurement.

## Native scene resources

Every process sampled the real city and actual seed-23 expedition at Low, Medium and High. These structural counts were identical across the three production processes:

| World / source | Nodes | MultiMesh batches | Retained instances | Enabled instances L/M/H | Inspectable retained triangles | Inspectable enabled triangles L/M/H |
|---|---:|---:|---:|---|---:|---|
| Sanctuary, 6B | 2,109 | 110 | 1,602 | 1,367 / 1,447 / 1,518 | 67,738 | 64,078 / 64,382 / 64,650 |
| Sanctuary, 6C | 2,265 | 146 | 2,350 | 1,713 / 1,995 / 2,254 | 80,402 | 69,122 / 73,514 / 77,266 |
| Rootbound seed 23 (10 rooms), 6B | 1,884 | 144 | 6,694 | 1,305 / 1,377 / 1,441 | 183,533 | 38,278 / 40,598 / 42,902 |
| Rootbound seed 23 (10 rooms), 6C | 1,895 | 154 | 7,022 | 1,357 / 1,429 / 1,495 | 188,721 | 39,434 / 41,754 / 44,066 |

Enabled means visible in the scene tree with the selected instance count. These are neither camera/frustum/LOD results nor draw calls. Mesh counts exclude generated label glyph geometry; triangle totals also exclude ImmediateMesh and meshes containing nontriangle surfaces because their topology/readback is not covered by the native probe. The excluded retained geometry instances were 10 in the city and 4 in Rootbound, with none enabled at these observations. There were 32 and 17 Label3D nodes respectively. Shader work, overdraw and shadow passes are not counted.

The city retained exactly 260 collision objects and 260 collision shapes in both versions; Rootbound retained 234 of each. Each world kept one existing environment and one light. City processing nodes rose from 5 to 7, and Rootbound from 4 to 5. The city allocated one audio player in 6C, with playback disabled and zero PCM bytes until sound is explicitly enabled. The focused/full scenery gate separately checked the enabled 66,150-byte sound buffer and cleanup.

The new garden retains 560 instances in 24 batches, with 280 / 424 / 560 selected by quality. The panorama contains 16 geometry nodes, including 8 tree MultiMeshes selecting 48 / 72 / 96 trees, 12 baked cliff/ruin forms and 4 water reaches. Its inspectable triangle counts are 3,336 / 4,776 / 6,216 and its cutoff is 180 m. Independently recomputing every panorama mesh bound from actual setter-input records gave a minimum radius of **60.0 m**, outside the protected 56 m radius. Construction assertions and the full scenery suite also protect the district approaches, ramps and ring roads.

## Host CPU observations

Each table row pools 300 observations across three fresh 6C processes. Each process used 10 warmups then 100 synchronous GDScript method calls at the fixed spawn/camera state, including Callable and timer overhead. These are not frame times, traversal costs or worst-case allocator measurements. Activity counters in raw snapshots include these synthetic calls and do not establish update cadence.

| 6C method / world | Quality | Median µs | p95 µs | Maximum µs |
|---|---|---:|---:|---:|
| Resident activity / city | Low | 7 | 8 | 26 |
| Resident activity / city | Medium | 18 | 19 | 210 |
| Resident activity / city | High | 24 | 25 | 115 |
| Fauna allocator / city | Low | 20 | 32 | 172 |
| Fauna allocator / city | Medium | 23 | 24 | 62 |
| Fauna allocator / city | High | 37 | 43 | 143 |
| Fauna allocator / Rootbound | Low | 35 | 42 | 135 |
| Fauna allocator / Rootbound | Medium | 38 | 46 | 95 |
| Fauna allocator / Rootbound | High | 43 | 67 | 252 |

One Medium startup observation was taken per process after the settings setup; it includes world construction and ordinary fade timing. 6B ranged from 748.5 to 777.6 ms (median 772.5); 6C ranged from 784.9 to 833.7 ms (median 799.1). This small host sample does not establish a performance regression or device loading target.

## Retained data and memory limits

Production kept **zero validation transform records** for city scenery and Abyss dressing. Canonical fauna data is deliberately retained for the 2 Hz eligible-slot allocator: 16 records in the city and 40 across the ten-room expedition. Each record contains a transform and two colors; the float payload is approximately 80 bytes per record before Variant/dictionary/container overhead. The manager admits at most 32 regions × 4 records and activates at most 4 / 8 / 12 wings by quality, further restricted by distance/frustum and the ambient-density choice.

The opt-in capture held 656 city and 3,519 Abyss transform records. After all measurements, the disposable capture process removed only validation metadata, leaving render inputs and canonical fauna records intact. The immediately observed net static-allocator decreases were **26,360 bytes** for the city and **115,700 bytes** for Rootbound. These are net allocator observations on removal, not total capture overhead or serialized matrix sizes.

Whole-process static allocator observations were:

- Sanctuary: 6B 55,716,515 bytes; 6C 57,064,881 bytes (median of three Low observations).
- Rootbound seed 23 (10 rooms): 6B 59,958,278 bytes; 6C 61,266,409 bytes (median of three Low observations).

These point samples include scripts, the game shell, caches and growing inspector results. They do not isolate world allocation, resident memory or GPU memory. They must not be used to infer the validation-record cost from differences between processes.

The headless native ArrayMesh vertex/AABB and BoxMesh triangle probes passed. The same probe confirmed mismatched MultiMesh transform readback and empty buffers in this dummy renderer; development inspection observed identity transforms. Panorama placement therefore uses captured construction inputs; no cosmetic placement is inferred from those getters in either version. Earlier 6B cosmetic tests relying on that readback were weaker than their descriptions implied, while native physics/navigation evidence is separate.

No image was produced by the optional software-capture attempt. Rendered appearance, physical Android behavior, sustained 30/60 FPS, thermal behavior, sound quality and APK export remain unverified; see the [manual Android checklist](living-sanctuary-android.md).
