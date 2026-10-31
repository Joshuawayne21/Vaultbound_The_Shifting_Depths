extends "res://tests/test_harness.gd"
## Accessible tier text and honest inspect metadata using the actual catalog.
## This validates presentation contracts, not physical color-vision/device tests.

func _initialize() -> void:
	suite_name = "VAULTBOUND RARITY UI"
	_run.call_deferred()

func _run() -> void:
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var panel: Control = hud.expedition_overlay.rpg_panel
	var loot: Control = hud.expedition_overlay.loot_panel
	var samples := {}
	for id: String in VaultLootTable.ITEM_IDS:
		var definition := VaultLootTable.item_for(id)
		if definition != null and definition.category != "gold" and not samples.has(definition.rarity):
			samples[definition.rarity] = definition.describe(2)
	check(samples.size() == 7, "The starter catalog supplies real items for all seven rarity tiers")
	var marks: Array[String] = []
	for index in range(7):
		var rarity: String = ["common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic"][index]
		if not samples.has(rarity): continue
		var item: Dictionary = samples[rarity]
		var marker: String = ["I", "II", "III", "IV", "V", "VI", "VII"][index]
		var caption := marker + " · " + rarity.replace("_", " ").to_upper()
		check(panel.item_rarity_mark(item) == marker and not marks.has(marker), "Inventory grid uses a unique readable tier mark for " + rarity)
		marks.append(panel.item_rarity_mark(item))
		check(panel.item_rarity_caption(item) == caption, "Inventory inspect identifies " + rarity + " by both numeral and name")
		check(loot.row_caption(item) == caption + " · ×2", "Search rows retain the readable rarity label and remaining quantity for " + rarity)
	var ancient: Array[Color] = VaultUITheme.rarity_accents("ancient_relic")
	check(ancient.size() == 2 and ancient[0] == Color("5be7d6") and ancient[1] == VaultUITheme.GOLD, "Ancient Relic frames specify distinct turquoise and gold borders")
	check(VaultUITheme.rarity_accents("common").size() == 1, "Common items retain a restrained single rarity border")
	check(loot.row_caption({"id": "__depthmarks", "quantity": 17, "rarity": "currency"}) == "17 DM", "Depthmarks remain currency rather than a fabricated equipment rarity")
	var staff := VaultLootTable.item_for("runic_staff").describe()
	var note := VaultUITheme.item_inspection_note(staff)
	check(note.contains("Shared family model (prototype)") and note.contains("From "), "A real staff's inspect metadata labels shared artwork and valid acquisition sources")
	var future := {"uid": "presentation-only", "category": "equipment", "slot": "main_weapon", "obtainable": false, "combat_supported": false, "model_art_status": "missing", "icon_art_status": "catalog_placeholder", "acquisition_sources": ["monster:unfinished_boss"]}
	note = VaultUITheme.item_inspection_note(future)
	check(note.contains("Not currently obtainable") and note.contains("Combat unavailable") and note.contains("Model unavailable") and note.contains("Placeholder icon") and not note.contains("From "), "Unavailable catalog metadata never claims implemented combat, finished artwork or an active loot source")
	panel.section = &"inventory"
	check(panel._selected_actions(future).is_empty(), "An unsupported catalog-only weapon is not offered equip actions")
	staff["uid"] = "presentation-owned-staff"
	check(panel._selected_actions(staff).size() == 2, "A real supported starter staff retains both loadout assignment actions")
	for scale_percent in [100, 110, 120]:
		panel.apply_visual_settings({"ui_scale_percent": scale_percent})
		loot.apply_visual_settings({"ui_scale_percent": scale_percent})
		panel.size = Vector2(1280, 720)
		loot.size = Vector2(1280, 720)
		check(panel.action_rect(0, 2).size.y >= 48 and loot.take_rect().size.y >= 48 and not panel.action_rect(0, 2).intersects(panel.action_rect(1, 2)), "Rarity text additions preserve existing touch geometry at %d%%" % scale_percent)
	hud.queue_free()
	await process_frame
	finish()
