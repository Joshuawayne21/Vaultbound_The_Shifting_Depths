# Milestone 7 — Android acceptance checklist

Use a committed, validated stage checkpoint. No physical Android, GPU or sustained frame-rate result is claimed by this checklist. Keep the existing [Living Sanctuary checks](living-sanctuary-android.md) for combat, touch, equipment, companions, pets, portals and safe save handling.

## Import and preserve progress

1. Back up your existing `user://vaultbound` data, including the profile, rotating/migration backups and separate visual/social settings. Retain the isolated TEST exchange file if you want its demonstration history.
2. Import the repository-root `project.godot` using the standard GDScript **Godot 4.6.3 Android editor**, Compatibility renderer, landscape. Running in the editor does not require an APK export or signing key.
3. Start at Medium / 30 FPS and verify earned Depthmarks, inventory quantities/UIDs, loadouts, enhancements, talents, recruited companions, pets and Hall displays before testing new content. Never delete an existing profile to resolve a load error.
4. Record the exact stage/commit, device, Android/Godot versions, resolution, UI scale and quality settings. Do not include account secrets, private chat or device serial numbers in reports.

## 7B Sanctuary presentation

- Walk the entire ring road, all eight radial roads and both Forge/Tavern ramps. Recruit Guardian/Mystic and select a pet; confirm all three follow and that service approaches remain usable.
- Inspect the larger perimeter walls and distinct tower/giant-tree silhouettes from the plaza, district entrances and perimeter. Check for floating parts, overlapping trim, abruptly clipped crowns, excessive fog and unreadable dark masonry. Distant scenic bridges/landmarks are not promised as traversable paths.
- Sweep the third-person camera at low and high pitch near walls, towers, gate crests and terrace corners. Switch smoothly to isometric while moving. Watch for the lens entering opaque meshes, severe occlusion, flicker or camera pull-in that makes walking difficult.
- Approach the blue Rootbound and gold Hall gates. Confirm the destination label, large ENTER control, explicit review and return placement. Practice gates must remain clearly labeled practice. Do not expect purple/red routes before the Veilgarden/Frontier stages actually add them.
- Revisit all merchants, Forge, Tavern, Conservatory and the physical Ring Exchange terminal. Use the city map without remotely opening a service. TEST exchange and chat labels must remain honest about their offline status.
- Compare Low/Medium/High, reduced motion, reduced effects, ambient density zero and high-contrast prompts. Essential walls/portal obstructions must remain consistent across quality; reduced decoration must not hide enemies, loot or interactables. Observe daytime and the darker phase of the existing local daylight cycle.
- Enter/return from Rootbound, practice dungeon, Proving Grounds and Collection Hall in both camera views. Record a dungeon seed and verify that the visual pass has not altered its route, pickups or gameplay.

## Capture performance and visual evidence

Record at least ten minutes covering plaza/perimeter traversal, crowded district views, portals, combat and a representative dungeon. Compare cold start and warmed-up play; note frame-time spikes, thermal throttling, touch comfort and battery drain. Use the metrics display/profiler where available. Native mesh counts and cloud CPU timings cannot establish device FPS.

| Device / stage | Quality / target | Route / seed | Duration | Frame-time / thermal observations | Input / visual issues |
| --- | --- | --- | --- | --- | --- |
| Not yet tested | — | — | — | No physical measurements | Pending |

Attach actual screenshots or a short recording for visual issues. Label any desktop software-rendered capture accurately; it is not Android evidence. **30 FPS** and optional **60 FPS** remain device goals until verified.

Depth progression, new biomes/bosses/recruits, genetics, Veilgarden and Frontier require their own stage-specific tests when implemented. Their presence in the [plan](milestone-7-plan.md) does not make them available in 7B.
