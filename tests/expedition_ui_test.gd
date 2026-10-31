extends SceneTree
## Synthetic discovery-map, inventory and results routing checks.
## This validates Godot events and layout contracts, not physical Android input.
var failures := 0
var checks := 0
var actions: Array[StringName] = []
var equipped: Array[String] = []
var tonics := 0
func _initialize() -> void:
    run.call_deferred()
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(label)
func run() -> void:
    var hud = load("res://scenes/ui/hud.tscn").instantiate()
    root.add_child(hud)
    await process_frame
    var overlay = hud.expedition_overlay
    var input = root.get_node("InputHub")
    input.action_requested.connect(func(action: StringName): actions.append(action))
    hud.equipment_requested.connect(func(id: String): equipped.append(id))
    hud.consumable_requested.connect(func(): tonics += 1)
    hud.set_transition(0)
    hud.set_input_enabled(true)
    input.controls_enabled = true
    var dungeon = {"seed": 442, "floor": 1, "current_room": 0, "rooms": [{"id":0,"cell":Vector2i(0,0),"kind":"entrance","discovered":true,"neighbors":[1]},{"id":1,"cell":Vector2i(0,-1),"kind":"boss","discovered":true,"neighbors":[0,2]},{"id":2,"cell":Vector2i(1,-1),"kind":"secret","discovered":false,"hidden":true,"neighbors":[1]}],"awareness":{"value":36,"warning":"Roots are stirring"},"boss":{"visible":true,"name":"Rootwarden","health":200,"max_health":500,"phase":2},"extraction_unlocked":false,"active_enemies":2}
    hud.set_dungeon_snapshot(dungeon)
    check(overlay.visible_room_ids().size()==2, "Only discovered room ids shown")
    check(not overlay.minimap_room_positions().has(2), "Hidden secret stays absent")
    check(overlay.dungeon_snapshot.awareness==36.0, "Nested awareness adapts")
    check(overlay.dungeon_snapshot.boss_health==200 and overlay.dungeon_snapshot.boss_phase==2, "Boss health and phase adapt")
    check(overlay.dungeon_snapshot.current_room_id==0 and overlay.dungeon_snapshot.alive_enemies==2, "Room and performance data adapts")
    dungeon.rooms[2].discovered = true
    hud.set_dungeon_snapshot(dungeon)
    check(overlay.visible_room_ids().size()==3, "Secret appears after discovery")
    overlay.set_session_snapshot({"active":true,"unsecured_gold":27,"secured_gold":85,"bag":[{"id":"raw_sword","label":"Unsecured sword","quantity":1,"rarity":"rare","category":"equipment","weapon_style":"sword"}],"inventory":[{"id":"old_staff","label":"Old Staff","quantity":1,"rarity":"epic","category":"equipment","weapon_style":"staff"}]})
    check(overlay._pack_rect().size.y>=60 and overlay._tonic_rect().size.y>=60, "Pack targets remain thumb sized")
    check(not overlay._pack_rect().intersects(overlay._tonic_rect()), "Pack targets do not overlap")
    hud.toggle_inventory()
    check(overlay.mode==&"pack" and hud.surface.modal_blocked, "Pack opens and blocks combat surface")
    overlay.selected_item = "raw_sword"
    check(not overlay._can_equip_selected(), "Unsecured gear cannot be equipped")
    overlay._modal_press(overlay._tab_rect(&"bank").get_center())
    overlay._modal_press(overlay._item_rect(0).get_center())
    check(overlay._can_equip_selected(), "Secured gear may be selected")
    overlay._modal_press(overlay._equip_rect().get_center())
    check(equipped==["old_staff"], "Secured selection routes equip id")
    input.controls_enabled=false
    overlay._modal_press(overlay._modal_tonic_rect().get_center())
    check(tonics==1, "Modal healing routes even with gameplay input off")
    var event = InputEventScreenTouch.new()
    event.index=40
    event.pressed=true
    event.position=hud.surface._button_centers()[&"primary_attack"]
    var before=actions.size()
    hud.surface._input(event)
    check(actions.size()==before, "Combat touches do not leak through modal")
    event.position=overlay._continue_rect().get_center()
    overlay._input(event)
    check(overlay.mode==&"none" and not hud.surface.modal_blocked, "Continue works while gameplay is disabled")
    hud._on_results_ready({"outcome":"extracted","seed":442,"gold":27,"items":[],"kills":4,"elapsed_seconds":123,"boss_defeated":true,"secured_total":112})
    check(overlay.mode==&"none", "Results wait for travel")
    hud.present_pending_results()
    check(overlay.mode==&"results" and hud.pending_results.is_empty(), "Results present once after travel")
    for i in range(5): overlay.add_notice("Find %d" % i)
    check(overlay._notifications.size()==3, "Treasure notice queue is bounded")
    await process_frame
    await process_frame
    hud.close_results()
    hud.set_dungeon_snapshot({})
    check(not hud.surface.dungeon_active and overlay.visible_room_ids().is_empty(), "Hub restores schematic and clears dungeon state")
    print("EXPEDITION UI CHECKS: %d passed, %d failures" % [checks-failures,failures])
    hud.queue_free()
    await process_frame
    quit(0 if failures==0 else 1)
