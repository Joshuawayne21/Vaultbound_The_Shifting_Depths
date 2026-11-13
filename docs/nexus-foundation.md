# Nexus of Realms — foundation

**Build `0.7.0-nexus2` / Android code 31 passed 11,226 native checks across 49 modes and 47 suites.** The separate hall, guarded activity cards and existing gameplay routes are the accepted Stages 2–4 foundation. See [the validation report](nexus-foundation-validation.md) and [Android route](nexus-foundation-android.md). Rendered visual quality, physical Android testing and installation on a player device are not claimed.

The foundation introduces a separately loaded northern Nexus interior, ten individually styled activity gateways, a shared interaction card and guarded routes into existing gameplay. It does not complete ten new activities. Abyssal Descent uses the existing progressive PvE expedition; Bloodspire offers existing NPC combat practice. The other eight activities show their intended identity and an explicit unavailable reason, with entry disabled.

## Finding the hall

Walk to north district A and use **NEXUS OF REALMS · ENTER**. The existing `rootbound_abyss` city-map identity becomes the hall entrance; the dungeon itself remains the existing expedition destination behind Abyssal Descent. The nearby Realm Routes/Records and Party Preparation/Practice boards describe actual availability. They do not award contracts or start matchmaking. The Practice Sentinel remains on the city training court. Existing practice-dungeon and combat-practice gameplay move behind the Nexus instead of being deleted.

The separate hall keeps the larger portal architecture out of the already populated Sanctuary scene. It has a circular ivory/blue/gold shell, a central Conduit, open circulation and three galleries: Adventure, Conflict and Ascension. The Conduit is a secondary visual receiver using shared Prismheart styling; it is not a second Living Prismheart actor, economy or reward source. All art is original native-mesh prototype work pending rendered review, not finished sculpted models.

The southern return gateway leads to the same Sanctuary. The small Sunken Vault practice gate retains the existing practice dungeon and its Sanctuary return. Bloodspire local practice is configured to return to the Nexus. Abyssal extraction, early return and death retain their existing Sanctuary/progression rules. The western Personal Sanctuary portal remains in the city and continues to use the same home ID, rooms, collections and displays.

## Gateway availability

The proposed depth prerequisites below describe future activity design. They do not unlock unfinished worlds, create achievements or grant Realm Seals. TEST ACCESS cannot enable unavailable activities.

| Gallery | Gateway | Native visual family | Current foundation route / proposed requirement |
| --- | --- | --- | --- |
| Adventure | Abyssal Descent | Dark runed buttresses, cyan/blue veil | Existing progressive expedition. Depth 1 open; deeper depths follow the existing preceding-clear-and-extraction rule. |
| Adventure | Beastwilds | Living wood arch and plants | Unavailable: tracking, discoveries and pet reward settlement need implementation. Proposed Depth 2 clear. |
| Adventure | The Gilded Vault | Golden keys and chest plinths | Unavailable: puzzle expedition and reward settlement need implementation. Proposed Depth 5 clear. |
| Adventure | Titan's Gate | Titan faces and heavy chains | Unavailable: boss encounters and party requirements need implementation. Proposed Depth 10 clear; current party remains one local player plus up to two AI. |
| Conflict | Bloodspire Arena | Crimson crossed blades and banners | **Local NPC practice only** through the existing Proving Grounds. No PvP match, rating, ranked reward or human opponent is fabricated. |
| Conflict | Shattered Rift | Broken dimensional fragments | Unavailable: multi-team extraction and authenticated services are absent. Proposed Depth 12 clear and PvP introduction. |
| Conflict | Guild Conquest | Blue/silver guild battlements | Unavailable: guild eligibility, objective battles and authenticated services are absent. A future War Room must use this same activity identity. |
| Ascension | Echoes of Eternity | Silver/violet spectral spires | Unavailable: waves, upgrades, boss breaks and reward settlement need implementation. Proposed Depth 3 clear. |
| Ascension | Chaos Gate | Prismatic shards | Unavailable: configured local event gameplay must precede an online schedule. Proposed Depth 5 clear. |
| Ascension | Forbidden Gate | Large obsidian/gold statues and chains | Unavailable: endgame realm and four earned PvE Realm Seals need implementation. Proposed Depth 20 clear. Chains are presentation, not a completed progression/unlock animation. |

Each gateway uses its own catalog-owned visual profile and ornament family. The common existing portal card remains touch-oriented and requires an explicit **ENTER** action. Available expedition entry retains the reviewed depth selector, policy/version checks, party summary, actual content preview and existing records. Unavailable entries give a reason and cannot travel. The foundation does not implement a full new artwork browser, matchmaking flow, mastery display, activity achievements or dedicated portal audio assets.

## Authority and save boundaries

Activity intent lives in `resources/realms/*.tres` and `scripts/realms/realm_catalog.gd`. The catalog has a small explicit released-route allowlist. Merely editing a resource's release flag cannot make an unfinished destination available. Major gateways and the two auxiliary portals are enrolled from their original nodes by the Nexus world; original identity, direct parent, exact script, transform and route/profile tuple remain required. Clearing a major activity ID must not turn it into a valid legacy route.

`Game` validates active-world context, actual source, reach, line of sight, player/combat state, reviewed route and existing depth policy before opening a card and again immediately before deferred travel. Arrival checks require the hall's actual authored floor and clear capsules for player/Guardian/Mystic. A failed load/arrival must leave the old published world and state usable. These are local guard boundaries; they are not an authoritative online server.

This foundation adds no profile schema, item definitions, currency, mastery counter, seal ledger or reward authority. Profile v11/home namespace v3, secured item UIDs, Depthmarks' retained `gold` field, companions, pets, home identity and display references stay under existing services. Browsing cards must leave exact secured save bytes unchanged. The eight unavailable activity definitions cannot claim Rootbound completion or use its reward provenance.

The user deferred Masks of the Abyss integration. Existing mask-named collectibles stay intact; F–S condition, Abysmal rarity, powers and drop rules are not invented. There is no new online deployment, billing, paid asset or external service. Existing Exchange custody remains explicitly DEMO and separate from gameplay progression.

## Mobile budget and required review

Authored hall limits use one shared directional light, zero added local lights, static spatial batching and existing quality/reduced-motion preferences. The Conduit uses a bounded driver, at most twelve sparks and existing ambient density; ambient motes cap at twenty-four. The separate native inventory measured 2,459 world nodes and 48,836 allocated instance-weighted triangles, with zero local lights and thirteen enabled world process nodes. These are scene-tree measurements, not GPU costs. Shared animated portal base art remains separate from immutable baked ornaments; physical device rendering still needs review.

The accepted native gate checked collision and real player/companion traversal around the Conduit and to every gate, both camera modes and presets, registered-source/tampering rejection, unavailable-entry denial, existing depth admission and settlement, practice/return routes, save isolation and retained city/home/service regressions. These results do not establish rendered performance. The Android checklist must separately cover wall/veil flicker, effects, labels, loading pauses, thumb reach, reduced motion, memory and sustained frame times.

## Work after this checkpoint

The next gameplay stage is incremental Beastwilds, Echoes and Gilded Vault work. Each needs a real playable loop and independent completion/settlement identity before enabling its catalog route. New pet provenance, records or reward data require explicit compatible normalization/migration and failure/restart tests. Titan, Realm Mastery/Renown, seals, rewards and later event/endgame activities follow the ordered plan. Competitive activities require an authenticated authority/database phase; no hosting, payment credentials or deployments are presumed authorized.
