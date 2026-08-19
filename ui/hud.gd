extends CanvasLayer

var ui_busy: bool = false
var _picker_slot: String = ""
var _picker_scale: String = "light"
var _picker_uids: Array[String] = []
var _banner_left: float = 0.0
var _from_loadout: bool = false
var _workshop_scale: String = "light"
var _filter: String = "all"

@onready var _prompt: Label = $PromptLabel
@onready var _objective: Label = $ObjectiveLabel
@onready var _health: Label = $HealthLabel
@onready var _carry: Label = $CarryLabel
@onready var _banner: Label = $BannerLabel
@onready var _extract_wrap: PanelContainer = $ExtractWrap
@onready var _extract_bar: ProgressBar = $ExtractWrap/Margin/ExtractBar
@onready var _crosshair: ColorRect = $Crosshair
@onready var _slot_panel: PanelContainer = $SlotPanel
@onready var _slot_title: Label = $SlotPanel/Margin/VBox/Title
@onready var _item_list: ItemList = $SlotPanel/Margin/VBox/ItemList
@onready var _equipped_label: Label = $SlotPanel/Margin/VBox/EquippedLabel
@onready var _loadout_panel: PanelContainer = $LoadoutPanel
@onready var _loadout_box: VBoxContainer = $LoadoutPanel/Margin/VBox/Slots

var _heat: ProgressBar
var _timer: Label
var _net: Label
var _deploy: PanelContainer
var _vendor: PanelContainer
var _filter_row: HBoxContainer


func _ready() -> void:
	layer = 10
	close_all_ui()
	_extract_wrap.visible = false
	_banner.text = ""
	_build_extras()
	refresh_carry()
	set_health(RunState.health)


func _build_extras() -> void:
	_heat = ProgressBar.new()
	_heat.max_value = 100
	_heat.show_percentage = false
	_heat.visible = false
	_heat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_heat.offset_left = 24
	_heat.offset_top = -48
	_heat.offset_right = 220
	_heat.offset_bottom = -32
	_heat.anchor_top = 1.0
	_heat.anchor_bottom = 1.0
	add_child(_heat)
	_timer = Label.new()
	_timer.position = Vector2(24, 108)
	_timer.add_theme_font_size_override("font_size", 15)
	_timer.add_theme_color_override("font_color", Color(0.95, 0.7, 0.35))
	add_child(_timer)
	_net = Label.new()
	_net.position = Vector2(24, 132)
	_net.add_theme_font_size_override("font_size", 13)
	_net.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8))
	add_child(_net)
	_filter_row = HBoxContainer.new()
	_loadout_box.get_parent().add_child(_filter_row)
	_loadout_box.get_parent().move_child(_filter_row, 2)
	for f in ["all", "chest", "weapon", "rare"]:
		var b := Button.new()
		b.text = f
		b.pressed.connect(_on_filter.bind(f))
		_filter_row.add_child(b)


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.modulate.a = clampf(_banner_left / 0.4, 0.0, 1.0) if _banner_left < 0.4 else 1.0
		if _banner_left <= 0.0:
			_banner.text = ""
	if RunState.in_raid:
		RunState.raid_timer += delta
		_timer.text = "RAID  %02d:%02d" % [int(RunState.raid_timer) / 60, int(RunState.raid_timer) % 60]
		_timer.visible = true
	else:
		_timer.visible = false
	if _net:
		_net.text = "%s   %s   TIER %d   %d cr" % [NetSession.status_text(), RunState.faction.to_upper(), RunState.hangar_tier, RunState.credits]


func reset_for_scene() -> void:
	close_all_ui()
	set_prompt("")
	set_extract(-1.0)
	set_heat(-1.0)
	refresh_carry()
	set_health(RunState.health)


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_objective(text: String) -> void:
	_objective.text = text


func set_health(value: float) -> void:
	_health.text = "HULL  %d" % int(round(value))
	_health.visible = true


func set_heat(ratio: float) -> void:
	if _heat == null:
		return
	if ratio < 0.0:
		_heat.visible = false
		return
	_heat.visible = true
	_heat.value = clampf(ratio, 0.0, 1.0) * 100.0


func refresh_carry() -> void:
	if not RunState.in_raid:
		_carry.text = _stash_summary()
		return
	var names: PackedStringArray = PackedStringArray()
	for part in RunState.raid_carry:
		names.append(str(part.get("display_name", "?")))
	for part in RunState.secure_carry:
		names.append("*%s" % part.get("display_name", "?"))
	if names.is_empty():
		_carry.text = "CARRY  empty  (lost on death)  WT %.0f/%.0f" % [RunState.carry_weight(), RunState.carry_limit()]
	else:
		_carry.text = "CARRY  " + ", ".join(names) + "   WT %.0f/%.0f" % [RunState.carry_weight(), RunState.carry_limit()]


func _stash_summary() -> String:
	return "STASH  %d    %d cr    SKILL %.0f%%    WT %.0f/%.0f" % [
		RunState.stash.size(), RunState.credits, RunState.repair_skill * 100.0,
		RunState.stash_weight(), RunState.stash_limit(),
	]


func set_extract(progress: float) -> void:
	if progress < 0.0:
		_extract_wrap.visible = false
		return
	_extract_wrap.visible = true
	_extract_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner_left = 3.6


func open_loadout_editor() -> void:
	open_workshop("light")


func open_workshop(scale: String) -> void:
	_workshop_scale = scale
	ui_busy = true
	_from_loadout = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_loadout_panel.visible = true
	_slot_panel.visible = false
	_crosshair.visible = false
	_rebuild_loadout_buttons()


func open_slot_picker(slot: String, scale: String = "") -> void:
	_from_loadout = _loadout_panel.visible
	_picker_slot = slot
	_picker_scale = scale if scale != "" else _workshop_scale
	ui_busy = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_loadout_panel.visible = false
	_slot_panel.visible = true
	_crosshair.visible = false
	_slot_title.text = "%s  /  %s" % [_picker_scale.to_upper(), slot.to_upper().replace("_", " ")]
	_refresh_picker()


func close_slot_picker() -> void:
	_slot_panel.visible = false
	_picker_slot = ""
	_picker_uids.clear()
	if _from_loadout:
		_from_loadout = false
		open_workshop(_picker_scale)
		return
	close_all_ui()


func close_all_ui() -> void:
	ui_busy = false
	_from_loadout = false
	_picker_slot = ""
	_picker_uids.clear()
	if _slot_panel:
		_slot_panel.visible = false
	if _loadout_panel:
		_loadout_panel.visible = false
	if _deploy:
		_deploy.visible = false
	if _vendor:
		_vendor.visible = false
	if _crosshair:
		_crosshair.visible = true
	if is_inside_tree() and get_tree().current_scene != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rebuild_loadout_buttons() -> void:
	while _loadout_box.get_child_count() > 0:
		var child := _loadout_box.get_child(0)
		_loadout_box.remove_child(child)
		child.free()
	var hint := Label.new()
	hint.text = "Frame %s   paint %d   [filters above]" % [_workshop_scale, RunState.paint_index]
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_loadout_box.add_child(hint)
	for slot in RunState.SLOTS:
		var part := RunState.get_equipped(slot, _workshop_scale)
		if _filter == "chest" and slot != "chest":
			continue
		if _filter == "weapon" and (part.is_empty() or not bool(part.get("is_weapon", false))):
			if slot not in ["chest", "arm_l", "arm_r", "legs"]:
				continue
		var btn := Button.new()
		var equipped := "empty" if part.is_empty() else "%s  %.0f%%" % [part.get("display_name", "?"), float(part.get("condition", 1.0)) * 100.0]
		btn.text = "%s     %s" % [slot.to_upper().replace("_", " "), equipped]
		btn.pressed.connect(_on_loadout_slot.bind(slot))
		_loadout_box.add_child(btn)
	var row := HBoxContainer.new()
	var paint := Button.new()
	paint.text = "Cycle paint"
	paint.pressed.connect(_on_paint)
	var repair := Button.new()
	repair.text = "Repair selected / stash"
	repair.pressed.connect(_on_repair_open)
	var up := Button.new()
	up.text = "Upgrade hangar (%d cr)" % (RunState.hangar_tier * 400)
	up.pressed.connect(_on_upgrade)
	row.add_child(paint)
	row.add_child(repair)
	row.add_child(up)
	_loadout_box.add_child(row)


func _on_filter(f: String) -> void:
	_filter = f
	_rebuild_loadout_buttons()


func _on_paint() -> void:
	RunState.paint_next()
	Fx.play("ui")
	_rebuild_loadout_buttons()


func _on_upgrade() -> void:
	if RunState.try_upgrade_hangar():
		show_banner("Hangar expanded to tier %d." % RunState.hangar_tier)
	else:
		show_banner("Need %d cr or already max." % (RunState.hangar_tier * 400))
	refresh_carry()


func _on_repair_open() -> void:
	if RunState.stash.is_empty():
		show_banner("Nothing to refurbish.")
		return
	var part: Dictionary = RunState.stash[0]
	if RunState.repair_part(str(part.get("uid", ""))):
		show_banner("Refurbished %s." % part.get("display_name", "part"))
	else:
		show_banner(RunState.last_message)
	refresh_carry()
	_rebuild_loadout_buttons()


func _on_loadout_slot(slot: String) -> void:
	open_slot_picker(slot, _workshop_scale)


func _refresh_picker() -> void:
	_item_list.clear()
	_picker_uids.clear()
	var equipped := RunState.get_equipped(_picker_slot, _picker_scale)
	if equipped.is_empty():
		_equipped_label.text = "Installed: none"
	else:
		_equipped_label.text = "Installed: %s  %.0f%%  %s  %.1f wt" % [
			equipped.get("display_name", "?"),
			float(equipped.get("condition", 1.0)) * 100.0,
			str(equipped.get("rarity", "")),
			float(equipped.get("weight", 0.0)),
		]
	for part in RunState.stash_for_slot(_picker_slot, _picker_scale):
		if _filter == "rare" and str(part.get("rarity", "common")) in ["common"]:
			continue
		_picker_uids.append(str(part.get("uid", "")))
		_item_list.add_item("%s   %.0f%%   %s   %.1fwt" % [
			part.get("display_name", "?"),
			float(part.get("condition", 1.0)) * 100.0,
			part.get("rarity", ""),
			float(part.get("weight", 0.0)),
		])
	if _picker_uids.is_empty():
		_item_list.add_item("(no matching parts)")
		_item_list.set_item_disabled(0, true)


func _on_equip_pressed() -> void:
	if _picker_slot == "":
		return
	var selected := _item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _picker_uids.size():
		return
	RunState.equip_uid(_picker_uids[idx], _picker_slot, _picker_scale)
	refresh_carry()
	_refresh_picker()


func _on_unequip_pressed() -> void:
	if _picker_slot == "":
		return
	RunState.unequip(_picker_slot, _picker_scale)
	refresh_carry()
	_refresh_picker()


func _on_close_pressed() -> void:
	close_slot_picker()


func _on_loadout_close_pressed() -> void:
	close_all_ui()


func open_deploy() -> void:
	ui_busy = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.visible = false
	if _deploy:
		_deploy.queue_free()
	_deploy = _panel("DEPLOY")
	add_child(_deploy)
	var box: VBoxContainer = _deploy.get_node("M/V")
	_add_label(box, "Scale")
	for s in ["scavenger", "light", "armor", "medium", "heavy", "vehicle"]:
		var b := Button.new()
		var lock: bool = (not RunState.scale_unlocked(s)) and (s != "scavenger")
		b.text = s.to_upper() + ("  (locked)" if lock else "")
		b.disabled = lock
		b.pressed.connect(_pick_scale.bind(s))
		box.add_child(b)
	_add_label(box, "Raid mode")
	for m in ["combat", "scav_wave", "late_drop"]:
		var b := Button.new()
		b.text = m.replace("_", " ").capitalize()
		b.pressed.connect(_pick_mode.bind(m))
		box.add_child(b)
	_add_label(box, "Map / faction")
	for m in ["ash_yard", "pipeline"]:
		var b := Button.new()
		b.text = m.replace("_", " ").capitalize()
		b.pressed.connect(_pick_map.bind(m))
		box.add_child(b)
	for f in RunState.FACTIONS:
		var b := Button.new()
		b.text = "Faction: " + f
		b.pressed.connect(_pick_faction.bind(f))
		box.add_child(b)
	var host := Button.new()
	host.text = "Host listen-server :7777"
	host.pressed.connect(_host)
	box.add_child(host)
	var join := Button.new()
	join.text = "Join 127.0.0.1"
	join.pressed.connect(_join)
	box.add_child(join)
	var go := Button.new()
	go.text = "LAUNCH RAID"
	go.pressed.connect(_launch)
	box.add_child(go)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_all_ui)
	box.add_child(close)


func _pick_scale(s: String) -> void:
	RunState.deploy_scale = s
	show_banner("Deploy as %s" % s)


func _pick_mode(m: String) -> void:
	RunState.raid_mode = m
	show_banner("Mode %s" % m)


func _pick_map(m: String) -> void:
	RunState.raid_map = m
	show_banner("Map %s" % m)


func _pick_faction(f: String) -> void:
	RunState.faction = f
	show_banner("Faction %s" % f)
	RunState.save_state()


func _host() -> void:
	if NetSession.host_game() == OK:
		show_banner("Hosting.")
	else:
		show_banner("Host failed.")


func _join() -> void:
	if NetSession.join_game("127.0.0.1") == OK:
		show_banner("Joining…")
		await get_tree().create_timer(0.4).timeout
		_launch()
	else:
		show_banner("Join failed.")


func _launch() -> void:
	RunState.save_state()
	close_all_ui()
	var path := "res://scenes/raid.tscn"
	if RunState.raid_map == "pipeline":
		path = "res://scenes/pipeline.tscn"
	get_tree().change_scene_to_file(path)


func open_vendor() -> void:
	ui_busy = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.visible = false
	if _vendor:
		_vendor.queue_free()
	_vendor = _panel("VENDOR")
	add_child(_vendor)
	var box: VBoxContainer = _vendor.get_node("M/V")
	_add_label(box, "Cosmetics and junk only. No pay-to-win guns.")
	var offers := [
		["armor_plate", 25],
		["myomer_strand", 30],
		["cooler_pack", 35],
		["sensor_suite", 70],
	]
	for o in offers:
		var b := Button.new()
		b.text = "%s   %d cr" % [RunState.part_display_name(str(o[0])), int(o[1])]
		b.pressed.connect(_buy.bind(str(o[0]), int(o[1])))
		box.add_child(b)
	var paint := Button.new()
	paint.text = "Decal / paint cycle  15 cr"
	paint.pressed.connect(_buy_paint)
	box.add_child(paint)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_all_ui)
	box.add_child(close)


func _buy(id: String, cost: int) -> void:
	if RunState.vendor_buy(id, cost):
		show_banner("Bought %s." % RunState.part_display_name(id))
	else:
		show_banner("Can't buy.")
	refresh_carry()


func _buy_paint() -> void:
	if RunState.credits >= 15:
		RunState.credits -= 15
		RunState.paint_next()
		show_banner("Paint applied across scales.")
	refresh_carry()


func _panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -260
	p.offset_top = -280
	p.offset_right = 260
	p.offset_bottom = 280
	var m := MarginContainer.new()
	m.name = "M"
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.name = "V"
	m.add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return p


func _add_label(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	box.add_child(l)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and ui_busy:
		close_all_ui()
		get_viewport().set_input_as_handled()
