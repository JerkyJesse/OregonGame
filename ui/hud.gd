extends CanvasLayer

const LOOK := preload("res://world/WorldLook.gd")
const BANNER_LOW := 0
const BANNER_NORMAL := 1
const BANNER_HIGH := 2


var ui_busy: bool = false
var gameplay_active: bool = false
var paused: bool = false
var _pause: PanelContainer
var _picker_slot: String = ""
var _picker_scale: String = "light"
var _picker_uids: Array[String] = []
var _banner_left: float = 0.0
var _banner_pri: int = 0
var _from_loadout: bool = false
var _workshop_scale: String = "light"
var _filter: String = "all"
var _bay_mech: Node
var _repair_uids: Array[String] = []

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
@onready var _loadout_box: VBoxContainer = $LoadoutPanel/Margin/VBox/SlotScroll/Slots

var _heat: ProgressBar
var _timer: Label
var _net: Label
var _sensors: Label
var _lungs: Label
var _lungs_bar: ProgressBar
var _sections: Label
var _deploy: PanelContainer
var _vendor: PanelContainer
var _bay: PanelContainer
var _repair: PanelContainer
var _filter_row: HBoxContainer
var _bay_hold: String = ""


func _ready() -> void:
	layer = 10
	visible = false
	gameplay_active = false
	ui_busy = false
	_extract_wrap.visible = false
	_banner.text = ""
	_build_extras()
	LOOK.attach_hud_chrome(self)
	LOOK.outline_label(_timer, Color(0.95, 0.7, 0.35))
	LOOK.outline_label(_net, Color(0.65, 0.75, 0.8))
	LOOK.outline_label(_sensors, Color(0.85, 0.9, 0.45))
	if _sections:
		LOOK.outline_label(_sections, Color(0.95, 0.62, 0.28))
	if _extract_bar:
		_extract_bar.add_theme_stylebox_override("background", LOOK.bar_bg())
		_extract_bar.add_theme_stylebox_override("fill", LOOK.bar_fill(Color(0.25, 0.85, 0.38)))
	_fit_menu(_loadout_panel)
	_fit_menu(_slot_panel)
	_ignore_hud_mouse()
	refresh_carry()
	set_health(RunState.health)
	set_process(false)


func freeze_for_title() -> void:
	gameplay_active = false
	ui_busy = false
	paused = false
	if _pause:
		_pause.queue_free()
		_pause = null
	visible = false
	set_process(false)
	close_all_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func enter_gameplay() -> void:
	gameplay_active = true
	visible = true
	set_process(true)


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
	_heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat.add_theme_stylebox_override("background", LOOK.bar_bg())
	_heat.add_theme_stylebox_override("fill", LOOK.bar_fill(Color(0.95, 0.42, 0.1)))
	add_child(_heat)
	_timer = Label.new()
	_timer.position = Vector2(24, 108)
	_timer.add_theme_font_size_override("font_size", 15)
	_timer.add_theme_color_override("font_color", Color(0.95, 0.7, 0.35))
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer)
	_net = Label.new()
	_net.position = Vector2(24, 132)
	_net.add_theme_font_size_override("font_size", 13)
	_net.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8))
	_net.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_net)
	_sensors = Label.new()
	_sensors.position = Vector2(24, 156)
	_sensors.add_theme_font_size_override("font_size", 13)
	_sensors.add_theme_color_override("font_color", Color(0.85, 0.9, 0.45))
	_sensors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sensors.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sensors.size = Vector2(900, 40)
	add_child(_sensors)
	_sections = Label.new()
	_sections.position = Vector2(24, 196)
	_sections.add_theme_font_size_override("font_size", 14)
	_sections.add_theme_color_override("font_color", Color(0.95, 0.62, 0.28))
	_sections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sections.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sections.size = Vector2(920, 28)
	_sections.visible = false
	add_child(_sections)
	_lungs = Label.new()
	_lungs.position = Vector2(280, 50)
	_lungs.add_theme_font_size_override("font_size", 18)
	_lungs.add_theme_color_override("font_color", Color(0.55, 0.9, 0.4))
	_lungs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lungs.visible = false
	add_child(_lungs)
	_lungs_bar = ProgressBar.new()
	_lungs_bar.max_value = 100
	_lungs_bar.show_percentage = false
	_lungs_bar.position = Vector2(280, 74)
	_lungs_bar.size = Vector2(160, 10)
	_lungs_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lungs_bar.visible = false
	add_child(_lungs_bar)
	_filter_row = HBoxContainer.new()
	var loadout_v: VBoxContainer = _loadout_panel.get_node("Margin/VBox")
	loadout_v.add_child(_filter_row)
	loadout_v.move_child(_filter_row, 2)
	for f in ["all", "chest", "weapon", "rare"]:
		var b := Button.new()
		b.text = f
		b.pressed.connect(_on_filter.bind(f))
		_filter_row.add_child(b)


func _process(delta: float) -> void:
	if not gameplay_active:
		return
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.modulate.a = clampf(_banner_left / 0.4, 0.0, 1.0) if _banner_left < 0.4 else 1.0
		if _banner_left <= 0.0:
			_banner.text = ""
			_banner_pri = BANNER_LOW
	if RunState.in_raid:
		RunState.raid_timer += delta
		_timer.text = "RAID  %02d:%02d" % [int(RunState.raid_timer) / 60, int(RunState.raid_timer) % 60]
		_timer.visible = true
	else:
		_timer.visible = false
	if _net:
		_net.text = "%s   %s   TIER %d   %d cr" % [NetSession.status_text(), WorldLore.faction_name(RunState.faction).to_upper(), RunState.hangar_tier, RunState.credits]
	_tick_bay_hold(delta)


func reset_for_scene() -> void:
	enter_gameplay()
	close_all_ui()
	set_prompt("")
	set_extract(-1.0)
	set_heat(-1.0)
	set_sensors("")
	set_sections("")
	_banner_pri = BANNER_LOW
	set_lungs(-1.0)
	refresh_carry()
	set_health(RunState.health)


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_objective(text: String) -> void:
	_objective.text = text


func set_health(value: float) -> void:
	_health.text = "HULL  %d" % int(round(value))
	_health.visible = true


func set_sensors(text: String) -> void:
	if _sensors:
		_sensors.text = text


func set_sections(text: String) -> void:
	if _sections == null:
		return
	_sections.text = text
	_sections.visible = text != ""


func set_lungs(value: float, ring: float = -1.0, dist: float = -1.0) -> void:
	if _lungs == null:
		return
	if value < 0.0 or not RunState.in_raid:
		_lungs.visible = false
		if _lungs_bar:
			_lungs_bar.visible = false
		return
	_lungs.visible = true
	var line := WorldLore.filter_label(value)
	if ring > 0.0:
		line += "   RING %.0f" % ring
		if dist > ring:
			line += "  BLOOM"
	_lungs.text = line
	var col := Color(0.55, 0.9, 0.4)
	if RunState.bloom_native():
		col = Color(0.62, 0.95, 0.38)
	elif value < 40.0:
		col = Color(0.95, 0.75, 0.25)
	if value < 18.0 and not RunState.bloom_native():
		col = Color(0.95, 0.3, 0.2)
	_lungs.add_theme_color_override("font_color", col)
	if _lungs_bar:
		_lungs_bar.visible = true
		_lungs_bar.value = clampf(value, 0.0, 100.0)


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
		_carry.text = "CARRY  " + ", ".join(names) + "   WT %.0f/%.0f   [Q] dump" % [RunState.carry_weight(), RunState.carry_limit()]


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


func show_banner(text: String, priority: int = BANNER_NORMAL) -> void:
	if text.strip_edges() == "":
		return
	if _banner_left > 0.55 and priority < _banner_pri:
		return
	_banner_pri = priority
	_banner.text = text
	_banner.modulate.a = 1.0
	if priority >= BANNER_HIGH:
		_banner_left = 4.4
	elif priority <= BANNER_LOW:
		_banner_left = 2.4
	else:
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


func open_machine_bay(mech: Node) -> void:
	_bay_mech = mech
	ui_busy = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.visible = false
	if _bay:
		_bay.queue_free()
	_bay = _panel("STRIP / BOLT  %s" % str(mech.get("scale_id")).to_upper())
	add_child(_bay)
	var box: VBoxContainer = _bay.get_node("M/Root/S/V")
	_add_label(box, "Look-free wreck workbench. Strip parts into carry, then bolt them onto another frame.")
	var pack: Variant = mech.get("equipped")
	var equipped: Dictionary = pack if pack is Dictionary else {}
	for slot in RunState.SLOTS:
		var part: Variant = equipped.get(slot, {})
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if part is Dictionary and not (part as Dictionary).is_empty():
			lab.text = "%s  %s  %.0f%%" % [slot.to_upper(), part.get("display_name", "?"), float(part.get("condition", 1.0)) * 100.0]
			var strip := Button.new()
			strip.text = "Strip"
			strip.pressed.connect(_bay_strip.bind(slot))
			row.add_child(lab)
			row.add_child(strip)
		else:
			lab.text = "%s  empty" % slot.to_upper()
			var bolt := Button.new()
			bolt.text = "Bolt from carry"
			bolt.pressed.connect(_bay_bolt.bind(slot))
			row.add_child(lab)
			row.add_child(bolt)
		box.add_child(row)
	if not bool(mech.get("core_taken")):
		var hack := Button.new()
		hack.text = WorldLore.bay_hack_label()
		hack.button_down.connect(_bay_hold_start.bind("hack"))
		hack.button_up.connect(_bay_hold_stop)
		box.add_child(hack)
	if str(mech.get("scale_id")) == "heavy":
		var pry := Button.new()
		pry.text = "Hold pry plate (alerts the heavy)"
		pry.button_down.connect(_bay_hold_start.bind("pry"))
		pry.button_up.connect(_bay_hold_stop)
		box.add_child(pry)
	var hw := Button.new()
	hw.text = "Hold hotwire"
	hw.button_down.connect(_bay_hold_start.bind("hotwire"))
	hw.button_up.connect(_bay_hold_stop)
	box.add_child(hw)
	if not bool(mech.get("disabled")) and bool(mech.get("alive")) and not bool(mech.get("boarded")):
		var board := Button.new()
		board.text = "Board cockpit"
		board.pressed.connect(_bay_board)
		box.add_child(board)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_all_ui)
	box.add_child(close)


func _bay_strip(slot: String) -> void:
	if _bay_mech == null or not is_instance_valid(_bay_mech):
		return
	var taken: Dictionary = _bay_mech.call("field_strip", slot)
	if taken.is_empty():
		return
	if RunState.add_carry(taken):
		refresh_carry()
		show_banner("Stripped %s — now it's yours." % taken.get("display_name", "part"))
		Fx.play("ui")
		open_machine_bay(_bay_mech)
	else:
		_bay_mech.call("field_install", taken)
		show_banner("Carry full.")


func _bay_bolt(slot: String) -> void:
	if _bay_mech == null or not is_instance_valid(_bay_mech):
		return
	var scale := str(_bay_mech.get("scale_id"))
	var bags: Array[Dictionary] = []
	bags.append_array(RunState.raid_carry)
	bags.append_array(RunState.secure_carry)
	var chosen: Dictionary = {}
	for part in bags:
		if str(part.get("slot", "")) == slot and RunState.scale_ok(part, scale):
			chosen = part
			break
	if chosen.is_empty():
		show_banner("No compatible part in carry for %s." % slot)
		return
	_remove_carry(str(chosen.get("uid", "")))
	if bool(_bay_mech.call("field_install", chosen)):
		refresh_carry()
		show_banner("Bolted %s onto the %s." % [chosen.get("display_name", "part"), scale])
		open_machine_bay(_bay_mech)
	else:
		RunState.add_carry(chosen)


func _remove_carry(uid: String) -> void:
	for i in RunState.raid_carry.size():
		if str(RunState.raid_carry[i].get("uid", "")) == uid:
			RunState.raid_carry.remove_at(i)
			return
	for i in RunState.secure_carry.size():
		if str(RunState.secure_carry[i].get("uid", "")) == uid:
			RunState.secure_carry.remove_at(i)
			return


func _bay_hold_start(kind: String) -> void:
	_bay_hold = kind


func _bay_hold_stop() -> void:
	_bay_hold = ""
	if _bay_mech and is_instance_valid(_bay_mech) and _bay_mech.has_method("reset_channels"):
		_bay_mech.call("reset_channels")


func _tick_bay_hold(delta: float) -> void:
	if _bay_hold == "" or _bay_mech == null or not is_instance_valid(_bay_mech):
		return
	var scav := _local_scav()
	if scav == null:
		return
	match _bay_hold:
		"hack":
			if _bay_mech.has_method("hold_hack_core"):
				if bool(_bay_mech.call("hold_hack_core", scav, delta)):
					_bay_hold = ""
					open_machine_bay(_bay_mech)
		"pry":
			if _bay_mech.has_method("hold_pry"):
				_bay_mech.call("hold_pry", scav, delta)
				refresh_carry()
		"hotwire":
			if _bay_mech.has_method("hold_hotwire"):
				_bay_mech.call("hold_hotwire", scav, delta)
				if bool(_bay_mech.get("boarded")):
					_bay_hold = ""
					close_all_ui()


func _bay_hack_start() -> void:
	if _bay_mech == null:
		return
	var scav := _local_scav()
	if scav and _bay_mech.has_method("hold_hack_core"):
		_bay_mech.call("hold_hack_core", scav, 0.35)
		open_machine_bay(_bay_mech)


func _bay_pry() -> void:
	if _bay_mech == null:
		return
	var scav := _local_scav()
	if scav and _bay_mech.has_method("hold_pry"):
		_bay_mech.call("hold_pry", scav, 0.4)
		refresh_carry()


func _bay_hotwire() -> void:
	if _bay_mech == null:
		return
	var scav := _local_scav()
	if scav and _bay_mech.has_method("hold_hotwire"):
		_bay_mech.call("hold_hotwire", scav, 0.5)
		if bool(_bay_mech.get("boarded")):
			close_all_ui()


func _bay_board() -> void:
	if _bay_mech == null:
		return
	var scav := _local_scav()
	if scav and _bay_mech.has_method("board_pilot"):
		close_all_ui()
		_bay_mech.call("board_pilot", scav)


func _local_scav() -> Node:
	for n in get_tree().get_nodes_in_group("scavenger"):
		if n is Scavenger and (n as Scavenger)._local() and not (n as Scavenger).boarded:
			return n
	return null


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


func toggle_pause() -> void:
	if RunState.walkthrough:
		return
	if not gameplay_active:
		return
	if paused:
		_close_pause()
		return
	if ui_busy:
		close_all_ui()
		return
	_open_pause()


func _open_pause() -> void:
	paused = true
	ui_busy = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pause:
		_pause.queue_free()
	_pause = _panel(WorldLore.pause_title())
	add_child(_pause)
	var box: VBoxContainer = _pause.get_node("M/Root/S/V")
	_add_label(box, WorldLore.pause_blurb())
	var actions: VBoxContainer = _pause.get_node("M/Root/A")
	var resume := Button.new()
	resume.text = "RESUME"
	resume.pressed.connect(toggle_pause)
	actions.add_child(resume)
	var quality := Button.new()
	quality.text = Settings.button_label()
	quality.pressed.connect(func() -> void:
		Settings.cycle()
		quality.text = Settings.button_label()
	)
	actions.add_child(quality)
	if RunState.in_raid:
		var abort := Button.new()
		abort.text = "ABORT TO NEW DODGE"
		abort.pressed.connect(_abort_raid)
		actions.add_child(abort)
	var title := Button.new()
	title.text = "TITLE"
	title.pressed.connect(_quit_title)
	actions.add_child(title)


func _close_pause() -> void:
	paused = false
	if _pause:
		_pause.queue_free()
		_pause = null
	ui_busy = false
	if gameplay_active and _in_gameplay_scene():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _abort_raid() -> void:
	_close_pause()
	RunState.fail_raid(WorldLore.abort_raid_banner())


func _quit_title() -> void:
	paused = false
	if _pause:
		_pause.queue_free()
		_pause = null
	ui_busy = false
	if RunState.in_raid:
		RunState.raid_carry.clear()
		RunState.in_raid = false
		RunState.save_state()
	freeze_for_title()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func close_all_ui() -> void:
	if paused:
		_close_pause()
		return
	ui_busy = false
	_from_loadout = false
	_picker_slot = ""
	_picker_uids.clear()
	_bay_mech = null
	_bay_hold = ""
	if _slot_panel:
		_slot_panel.visible = false
	if _loadout_panel:
		_loadout_panel.visible = false
	if _deploy:
		_deploy.queue_free()
		_deploy = null
	if _vendor:
		_vendor.queue_free()
		_vendor = null
	if _bay:
		_bay.queue_free()
		_bay = null
	if _repair:
		_repair.queue_free()
		_repair = null
	if _crosshair:
		_crosshair.visible = _in_gameplay_scene()
	if gameplay_active and _in_gameplay_scene() and not ui_busy:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _in_gameplay_scene() -> bool:
	if not is_inside_tree() or get_tree().current_scene == null:
		return false
	var path := get_tree().current_scene.scene_file_path
	return path.ends_with("hangar.tscn") or path.ends_with("raid.tscn") or path.ends_with("range.tscn") or path.ends_with("pipeline.tscn")


func _ignore_hud_mouse() -> void:
	for child in get_children():
		if child is Control and child != _slot_panel and child != _loadout_panel:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	repair.text = "Repair parts"
	repair.pressed.connect(open_repair)
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
		show_banner("New Dodge bay expanded to tier %d." % RunState.hangar_tier)
	else:
		show_banner("Need %d cr or already max." % (RunState.hangar_tier * 400))
	refresh_carry()


func open_repair() -> void:
	ui_busy = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.visible = false
	if _repair:
		_repair.queue_free()
	_repair = _panel("REFURBISH")
	add_child(_repair)
	var box: VBoxContainer = _repair.get_node("M/Root/S/V")
	_repair_uids.clear()
	_add_label(box, "Pick a damaged part. Cost scales with condition.")
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 220)
	box.add_child(list)
	for part in RunState.stash:
		if float(part.get("condition", 1.0)) < 0.99:
			_repair_uids.append(str(part.get("uid", "")))
			list.add_item("%s  %.0f%%  %s" % [part.get("display_name", "?"), float(part.get("condition", 1.0)) * 100.0, part.get("rarity", "")])
	for scale in RunState.SCALES:
		for slot in RunState.SLOTS:
			var eq := RunState.get_equipped(slot, scale)
			if not eq.is_empty() and float(eq.get("condition", 1.0)) < 0.99:
				_repair_uids.append(str(eq.get("uid", "")))
				list.add_item("%s/%s  %s  %.0f%%" % [scale, slot, eq.get("display_name", "?"), float(eq.get("condition", 1.0)) * 100.0])
	if _repair_uids.is_empty():
		list.add_item("(nothing damaged)")
		list.set_item_disabled(0, true)
	var go := Button.new()
	go.text = "Repair selected"
	go.pressed.connect(func() -> void:
		var sel := list.get_selected_items()
		if sel.is_empty() or sel[0] >= _repair_uids.size():
			return
		if RunState.repair_part(_repair_uids[sel[0]]):
			show_banner("Refurbished.")
		else:
			show_banner(RunState.last_message)
		refresh_carry()
		open_repair()
	)
	box.add_child(go)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_all_ui)
	box.add_child(close)


func _on_repair_open() -> void:
	open_repair()


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
	var box: VBoxContainer = _deploy.get_node("M/Root/S/V")
	var actions: VBoxContainer = _deploy.get_node("M/Root/A")
	var brief := Label.new()
	brief.name = "Briefing"
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD
	brief.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	box.add_child(brief)
	var net := Label.new()
	net.name = "NetHint"
	net.autowrap_mode = TextServer.AUTOWRAP_WORD
	net.add_theme_color_override("font_color", Color(0.65, 0.78, 0.82))
	box.add_child(net)
	_add_label(box, "Scale")
	box.add_child(_option(["scavenger", "light", "armor", "medium", "heavy", "vehicle"], RunState.deploy_scale, _on_scale_item))
	_add_label(box, "Raid mode")
	box.add_child(_option(["combat", "scav_wave", "late_drop"], RunState.raid_mode, _on_mode_item, true))
	_add_label(box, "Yard")
	box.add_child(_option(["ash_yard", "pipeline"], RunState.raid_map, _on_map_item, true))
	_add_label(box, "Faction")
	box.add_child(_option(RunState.FACTIONS, RunState.faction, _on_faction_item, true))
	_add_label(box, "Friend host address (same network)")
	var addr := LineEdit.new()
	addr.name = "JoinAddress"
	addr.text = ""
	addr.placeholder_text = "host address (hidden while typing)"
	addr.secret = true
	box.add_child(addr)
	var host := Button.new()
	host.text = "Host listen-server :%d" % NetSession.PORT
	host.pressed.connect(_host)
	box.add_child(host)
	var join := Button.new()
	join.text = "Join friend"
	join.pressed.connect(_join)
	box.add_child(join)
	var go := Button.new()
	go.text = "LAUNCH RAID"
	go.custom_minimum_size = Vector2(0, 40)
	go.pressed.connect(_launch)
	actions.add_child(go)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_all_ui)
	actions.add_child(close)
	_refresh_deploy_briefing()


func _option(ids, current: String, cb: Callable, lore: bool = false) -> OptionButton:
	var ob := OptionButton.new()
	var selected := 0
	for i in ids.size():
		var id := str(ids[i])
		var label := id.to_upper()
		if lore:
			if id in ["combat", "scav_wave", "late_drop"]:
				label = WorldLore.mode_title(id)
			elif id in ["ash_yard", "pipeline"]:
				label = WorldLore.map_title(id)
			else:
				label = WorldLore.faction_name(id)
		if id != "scavenger" and id in ["light", "armor", "medium", "heavy", "vehicle"] and not RunState.scale_unlocked(id):
			label += "  (locked)"
		ob.add_item(label, i)
		ob.set_item_metadata(i, id)
		if id != "scavenger" and id in ["light", "armor", "medium", "heavy", "vehicle"] and not RunState.scale_unlocked(id):
			ob.set_item_disabled(i, true)
		if id == current:
			selected = i
	ob.select(selected)
	ob.item_selected.connect(func(idx: int) -> void:
		cb.call(str(ob.get_item_metadata(idx)))
	)
	return ob


func _on_scale_item(s: String) -> void:
	_pick_scale(s)


func _on_mode_item(m: String) -> void:
	_pick_mode(m)


func _on_map_item(m: String) -> void:
	_pick_map(m)


func _on_faction_item(f: String) -> void:
	_pick_faction(f)


func _refresh_deploy_briefing() -> void:
	if _deploy == null or not is_instance_valid(_deploy):
		return
	var brief: Label = _deploy.get_node_or_null("M/Root/S/V/Briefing") as Label
	if brief:
		brief.text = WorldLore.deploy_briefing(RunState.raid_map, RunState.raid_mode, RunState.faction)
	var net: Label = _deploy.get_node_or_null("M/Root/S/V/NetHint") as Label
	if net:
		if NetSession.is_online() and NetSession.is_host():
			net.text = "Hosting on port %d. Friends enter your host address, then you press LAUNCH RAID." % NetSession.PORT
		elif NetSession.is_online():
			net.text = "Joined host. Wait for the host to launch — do not leave this hangar."
		else:
			net.text = "Offline solo, or host then share your host address off-screen. Same network. Port %d." % NetSession.PORT


func _pick_scale(s: String) -> void:
	if s != "scavenger" and not RunState.scale_unlocked(s):
		show_banner("Scale locked.")
		return
	RunState.deploy_scale = s
	show_banner("Deploy as %s" % s)
	_refresh_deploy_briefing()


func _pick_mode(m: String) -> void:
	RunState.raid_mode = m
	show_banner("Mode %s" % WorldLore.mode_title(m))
	_refresh_deploy_briefing()


func _pick_map(m: String) -> void:
	RunState.raid_map = m
	show_banner("Yard %s" % WorldLore.map_title(m))
	_refresh_deploy_briefing()


func _pick_faction(f: String) -> void:
	RunState.apply_faction(f)
	show_banner("Faction %s" % WorldLore.faction_name(f))
	if not RunState.in_raid:
		set_objective(WorldLore.hangar_objective(RunState.hangar_tier))
	_refresh_deploy_briefing()


func _host() -> void:
	if NetSession.host_game() == OK:
		show_banner("Hosting on port %d. Share your host address off-screen." % NetSession.PORT)
	else:
		show_banner(NetSession.last_error if NetSession.last_error != "" else "Host failed.")
	_refresh_deploy_briefing()


func _join() -> void:
	_join_async()


func _join_address_text() -> String:
	if _deploy and is_instance_valid(_deploy):
		var addr: LineEdit = _deploy.get_node_or_null("M/Root/S/V/JoinAddress") as LineEdit
		if addr:
			return addr.text.strip_edges()
	return ""


func _join_async() -> void:
	var err := await NetSession.join_and_wait(_join_address_text())
	if err == OK:
		show_banner("Joined. Wait for the host to press LAUNCH RAID.")
		if NetSession.is_online() and not NetSession.is_host():
			NetSession.request_raid.rpc_id(1)
	else:
		show_banner(NetSession.last_error if NetSession.last_error != "" else "Join failed.")
	_refresh_deploy_briefing()


func _launch() -> void:
	if NetSession.is_online() and not NetSession.is_host():
		show_banner("Wait for the host to launch.")
		NetSession.request_raid.rpc_id(1)
		return
	RunState.save_state()
	close_all_ui()
	var path := NetSession.scene_for_map(RunState.raid_map)
	if NetSession.is_online() and NetSession.is_host():
		NetSession.start_raid(path)
		return
	get_tree().change_scene_to_file(path)


func open_vendor() -> void:
	ui_busy = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.visible = false
	if _vendor:
		_vendor.queue_free()
	_vendor = _panel(WorldLore.vendor_title())
	add_child(_vendor)
	var box: VBoxContainer = _vendor.get_node("M/Root/S/V")
	_add_label(box, WorldLore.vendor_blurb())
	var offers := RunState.vendor_offers()
	for o in offers:
		var b := Button.new()
		b.text = "%s   %d cr" % [RunState.part_display_name(str(o[0])), int(o[1])]
		b.pressed.connect(_buy.bind(str(o[0]), int(o[1])))
		box.add_child(b)
	var paint := Button.new()
	paint.text = "Decal / paint cycle  15 cr"
	paint.pressed.connect(_buy_paint)
	box.add_child(paint)
	_add_label(box, "Tam buys junk. Not occupation guns. Not shards.")
	var sell_list := ItemList.new()
	sell_list.name = "SellList"
	sell_list.custom_minimum_size = Vector2(0, 140)
	box.add_child(sell_list)
	var sell_uids: Array[String] = []
	for part in RunState.stash:
		if bool(part.get("is_weapon", false)) or bool(part.get("is_payload", false)):
			continue
		sell_uids.append(str(part.get("uid", "")))
		var quote := maxi(int(float(part.get("value", 10)) * float(part.get("condition", 1.0)) * 0.4), 4)
		sell_list.add_item("%s  %.0f%%  Tam pays %d cr" % [part.get("display_name", "?"), float(part.get("condition", 1.0)) * 100.0, quote])
	if sell_uids.is_empty():
		sell_list.add_item("(nothing Tam will take)")
		sell_list.set_item_disabled(0, true)
	var sell := Button.new()
	sell.text = "Sell selected junk"
	sell.pressed.connect(func() -> void:
		var sel := sell_list.get_selected_items()
		if sel.is_empty() or sel[0] >= sell_uids.size():
			return
		var paid := RunState.vendor_sell(sell_uids[sel[0]])
		if paid >= 0:
			show_banner("Tam takes it. +%d cr." % paid)
			refresh_carry()
			open_vendor()
		else:
			show_banner(RunState.last_message if RunState.last_message != "" else "Tam won't take that.")
	)
	box.add_child(sell)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_all_ui)
	_vendor.get_node("M/Root/A").add_child(close)


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


func _fit_menu(p: Control) -> void:
	if p == null:
		return
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.anchor_left = 0.12
	p.anchor_top = 0.06
	p.anchor_right = 0.88
	p.anchor_bottom = 0.94
	p.offset_left = 0
	p.offset_top = 0
	p.offset_right = 0
	p.offset_bottom = 0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.clip_contents = true


func _panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = LOOK.ui_theme()
	p.add_theme_stylebox_override("panel", LOOK.panel_style())
	_fit_menu(p)
	var m := MarginContainer.new()
	m.name = "M"
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	p.add_child(m)
	var root := VBoxContainer.new()
	root.name = "Root"
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	m.add_child(root)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	root.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.name = "S"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.name = "V"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	var actions := VBoxContainer.new()
	actions.name = "A"
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	return p


func _add_label(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(l)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and ui_busy:
		close_all_ui()
		get_viewport().set_input_as_handled()
