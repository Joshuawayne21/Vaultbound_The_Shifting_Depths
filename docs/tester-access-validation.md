# Offline test access — validation

Build `0.7.0-test1`, Android version code 26, profile v11 passed **3,562 checks across 38 runtime modes and 31 suites**, including six independent restart readers. Import, 31 strict script loads and a 120-frame startup passed. Root independently verified all 41 accepted logs, the frozen source and resource references.

The single accepted source is `4364b531aac9a9cbb5ff9346efaf25f99b472882a0fe74f7cbf54787d1cc4ccb`, run `/workspace/scratch/vaultbound-home-stage5-validation/tester-access/focused-qru2y44z`. The [machine-readable report](tester-access-test-results.json) records commands, results, log hashes, source/protection manifest hashes and exact scope. No physical Android or rendered visual test is claimed.

## Preservation

The baseline is local commit `600e6ee82349ea948a9c0186fc85fb4e0ca5a2d6`. The verified backup `/workspace/backups/vaultbound-before-home-stage5/accepted-home4.bundle` has SHA-256 `9e3fb277cfd1bf82c295c3680a2b56ee03e5fa92d6d2b3f786ee52a685297d59`; it preserves project history, not phone saves. All 894 protected files remain unchanged. The separately recorded player script change carries the normalized tester flag into its existing stat cache so above-level owned equipment resolves consistently. Historical reports, catalog IDs and existing UIDs are preserved.

Profile v11 adds an explicit default-OFF setting without changing home namespace v3 or granting progress. The first migrated save retains exact original bytes in `.pre-v11.bak`; earlier backups remain. Invalid/future access records retain read-only protection.

## Accepted checks

| Area | Result |
| --- | --- |
| Pure access policy, migration, unsupported fields, backup preservation | 115 checks |
| Actual Game/session, above-level equipment stats without refilling health/stamina, generated Depth 6 boss/extraction, safe return after OFF | 41 checks |
| Separate-process access save/restart | Writer 3 / reader 5 |
| Native mobile Settings input, review/confirmation, repeated/stale/cancelled gestures, focus/write failures and layout | 42 checks |
| Relevant retained home/depth/economy/loadout/save/mobile/accessibility tests | 3,356 checks across 33 modes |

The five new modes total 206 checks. Retained counts did not decrease; smoke increased from 1,034 to 1,035. Earned levels/unlocks, existing item/pet ownership, currencies, costs, capacity and talent-point rules remain enforced. An unearned-depth test extraction cannot advance the sequential unlock ladder. Unfinished content remains unavailable. Existing Spiritweaving achievement requirements remain unchanged in this checkpoint.

An initial parse-only development run failed on a dangling continuation in the session return guard and a fixture variable requiring explicit Dictionary typing. Both were corrected; its results are excluded. The complete accepted gate then ran on one frozen source without errors. Import-only sandbox socket notices are identified separately. Host runtime of 177.759 seconds is not an Android frame-rate measurement.

## Device review

Follow [the access instructions](tester-access.md) using a backed-up profile: verify default OFF, enable/save/restart, enter implemented gated content, inspect actual equipment bonuses, review OFF cleanup, then return/restart. Owned gear above the real level is unequipped rather than removed; unearned appearance/display references revert without losing pets or items. Check both cameras and touch comfort on the intended phone.

This is an offline development feature, not an online account entitlement. No phone save was opened remotely. New Home Stage 5 rooms, future city architecture, rendered composition, Android frame pacing and signed APK export are outside this gate.
