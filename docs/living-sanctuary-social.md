# Sanctuary social presentation — 6D

This build is offline. It has no authenticated human accounts, network player replication, chat transport, friends, reports service or live trade invitations. The social interface is a local prototype; none of its self-preview rows are delivered to another device.

## Player-facing behavior

The HUD opens chat and a nine-action emote wheel. Chat has LOCAL, WORLD and PARTY tabs, independent temporary drafts, a bounded scrolling transcript, unread indicators and display preferences. LOCAL offers **PREVIEW · DEMO**. It creates a row from **You · LOCAL DEMO** on this device only. WORLD and PARTY retain editable drafts but cannot send. No synthetic strangers or global conversations are inserted.

The compact transcript can be hidden without removing the chat launcher. Font sizes are 14, 16 and 18 logical pixels; timestamps can be hidden. The existing global UI scaling and reduced-motion settings remain separate. Native text controls are used for typing and selection. Android keyboard appearance, composition, Back handling and comfortable touch layout still require physical-device testing.

The wheel provides wave, cheer, dance, sit, point, bow, laugh, celebrate and inspect. These are original procedural poses on the existing character pivots, not imported motion-capture animations. They are finite visual actions with no combat, movement, currency or progression bonus. Movement, combat, accepted damage, weapon changes, downing, revive, travel and input resets cancel them. Camera switching does not reset gameplay to play an emote. Reduced motion uses a recognizable static pose with the same finite duration.

Inspection is limited to actual recruited AI members of the current party, labeled **LOCAL AI COMPANION**. The card describes their existing public gameplay state. It does not invent a human identity or imply that Invite, Trade, Friend, Mute or Report has an online recipient. Authenticated human inspection and nearby emote replication remain backend work.

## Storage and limits

- The Game shell owns one social session across scene travel. Drafts and at most 60 preview rows exist only in memory and disappear when that session ends. There is no transcript file, delivery queue or retry-on-reconnect operation.
- Text is plain, at most 256 Unicode characters and 1,024 UTF-8 bytes. Control characters, extra lines and explicit directional overrides are rejected; ordinary Unicode text is retained.
- Local previews are limited to one per second and five per ten seconds using monotonic elapsed time. Device calendar changes cannot release that limit. Displayed timestamps are explicitly device-sourced.
- A pending submission token is consumed before validation or callbacks. Channel changes and lifecycle exits invalidate pending submissions. Replaying a token cannot append another row.
- Only display preferences persist in the separate version-one `user://vaultbound/social_settings.cfg`. Writes are validated before publication; unsupported future versions are protected. This file does not contain accounts, chat history, item ownership, earned Depthmarks or visual settings.
- Progression remains version four in 6D. Social previews, emotes and inspection do not migrate or rewrite the player profile.

These are offline prototype limits, not server security. A modified client could change its own preview. It cannot be treated as an authority for future shared chat or player identity.

## Required online contract

Before online enablement, the authenticated server must derive sender identity from the connection, validate message limits independently, and select recipients itself. LOCAL routing must use authoritative world/session and spatial membership; WORLD must stay inside the chosen server/world; PARTY must use the current authoritative roster and reject stale membership. Client-supplied sender names, positions, account IDs and party IDs are insufficient proof.

Network emotes require a supported emote ID, authoritative actor ownership, admissible actor state, rate limits and interest management. Inspection exposes only approved public appearance, title, visible equipment and selected cosmetic pet fields. Inventory contents, credentials, private identifiers and account metadata must not be included.

Mute/block enforcement, spam controls, configurable filtering and report intake must be implemented and tested before those actions are enabled. A report needs a real message or actor reference and an authenticated submitter; a disabled button is not a moderation service. Persisted moderation evidence needs a separately reviewed access and deletion policy.

The current retention policy is **session-only local memory, no server history**. Any future server retention interval must be configured explicitly, documented to players, and tested with deletion and access controls. Do not silently upload local drafts or historical preview rows when an online adapter is added.

The later 6F exchange contract and 6G authority gate must establish authenticated accounts, durable transactions and shared persistence independently. No public hosting, real marketplace or billing is enabled by 6D.
