# Milestone 5.6 asset status

The final registry contains **351 definitions: 350 noncurrency items, of which
300 are available and 50 are unavailable, plus the preserved currency record**.
Definition count is separate from artwork count. The project uses original
shared SVG icons and native primitive family models; it does not contain 350
individual item illustrations or models.

## Catalog and artwork counts

| Group | Definitions | Available | Unavailable |
| --- | ---: | ---: | ---: |
| Weapons | 50 | 24 | 26 |
| Armor | 85 | 85 | 0 |
| Accessories | 35 | 35 | 0 |
| Valuables | 80 | 80 | 0 |
| Materials | 45 | 37 | 8 |
| Consumables | 25 | 19 | 6 |
| Trophy artifacts | 30 | 20 | 10 |
| Noncurrency total | 350 | 300 | 50 |
| Currency compatibility record | 1 | 1 | 0 |

The following are exact definition metadata totals, including currency. They
describe each record's artwork status, rather than distinct files:

| Metadata | Definitions |
| --- | ---: |
| `icon_art_status = original_family_icon` | 319 |
| `icon_art_status = catalog_placeholder` | 32 |
| `model_art_status = shared_family_placeholder` | 254 |
| `model_art_status = not_applicable` | 71 |
| `model_art_status = missing` | 26 |

There are **17 item SVG files** in `assets/items/`; definitions reference **16
distinct paths**. The preserved `gold.svg` file is unused by the current
definitions; the currency record uses `depthmark.svg`. The application icon is
an additional SVG outside that directory. Six unavailable consumables share the
potion symbol but explicitly mark it as a catalog placeholder. Thus 32 records
have placeholder status even though only 26 use the generic `catalog.svg` path.

There are **12 native family display scenes**, referenced by 254 definitions.
All are shared prototype models. Materials, consumables and currency account
for the 71 records with no applicable display model; 26 unsupported future
weapons have missing models.

| Shared family | Referencing definitions | Icon / native display scene |
| --- | ---: | --- |
| Relic | 111 | `relic.svg` / `relic.tscn` |
| Armor | 15 | `armor.svg` / `chest.tscn` |
| Helmet | 15 | `helmet.svg` / `helmet.tscn` |
| Boots | 15 | `boots.svg` / `boots.tscn` |
| Shield | 14 | `shield.svg` / `shield.tscn` |
| Sword | 13 | `sword.svg` / `sword.tscn` |
| Gloves | 13 | `gloves.svg` / `gloves.tscn` |
| Leg armor | 13 | `leg_armor.svg` / `leg_armor.tscn` |
| Accessory | 12 | `accessory.svg` / `accessory.tscn` |
| Staff | 11 | `staff.svg` / `staff.tscn` |
| Necklace | 11 | `necklace.svg` / `necklace.tscn` |
| Ring | 11 | `ring.svg` / `ring.tscn` |

The relic family is shared by 80 valuables, 30 trophy artifacts and the legacy
reliquary accessory. The remaining icon paths are material (45 definitions),
potion (25), generic catalog (26) and Depthmark (1). Family icons live in
`assets/items/`; display scenes live in `scenes/items/`.

## Missing production assets and unavailable content

The 26 missing weapon models correspond to five greatswords, four dual blades,
five spears, five bows, four scythes and three magical gauntlets. These families
also lack implemented combat. They remain unavailable and cannot be granted,
equipped or enhanced. Supported weapon combat remains sword/shield and staff.
Eight future materials, six unsupported consumables and ten future-encounter
trophies are also unavailable; having shared artwork does not enable their
mechanics or acquisition sources.

The player, companions, service characters and previews continue to use
`scripts/player/player_avatar.gd` with original Godot primitive meshes and
procedural rigid-pivot poses. No imported `.glb`, `.gltf`, `.fbx`, `.blend` or
`.dae` model, production skinned rig or authored animation clip set is included.
Individual fitted armor, independent skinned elbow/knee joints, facial/finger
animation and cloth simulation remain absent. The existing rounded native
surfaces and pose blending improve prototype presentation without supplying
those assets.

A future production replacement still needs a licensed compatible humanoid rig,
skin weights, hand sockets, fitted armor, sword/shield and staff grips, and idle,
walk, run, dodge, sword attacks, block, cast, stagger and death clips. Preserve
the current controller, capsule, attack timing and attachment transforms when
integrating it. See [character presentation](character-presentation.md).

## Provenance and review boundary

No paid or external asset pack was purchased, downloaded or introduced by this
milestone. The existing provenance statements cover original project SVGs,
native meshes, procedural poses and shaders. World surfaces retain the two
original 128×128 procedural grain textures described in the
[Milestone 5.5 report](milestone-5.5-performance.md). Placeholder synthesized
sound also remains part of the prototype.

The integrated checkpoint 8 presentation adds original native rims, rune
patterns and bounded spark meshes around the shared art. Its actual scripts
were rechecked after application. It supplies no production rig, authored clip,
individual trophy sculpture or unique item model. The seven-process native
catalog audit independently confirmed all artwork counts above; its source
hashes and evidence are recorded in the [performance report](milestone-5.6-performance.md).

Source/resource validation establishes availability and references. Physical
Android review must still assess silhouettes, clipping, framing, icon clarity,
shader appearance and animation feel. See the [Android review](milestone-5.6-android.md)
and [performance report](milestone-5.6-performance.md).
