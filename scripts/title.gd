extends Control

const LOOK := preload("res://world/WorldLook.gd")


var _crawl_layer: Control
var _leaving := false
var _status: Label
var _ip: LineEdit
var _showcase: Node3D


func _enter_tree() -> void:
	Hud.freeze_for_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	Hud.freeze_for_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	call_deferred("_focus_menu")
	var args := OS.get_cmdline_user_args()
	if args.has("--host-raid"):
		call_deferred("_host")
	elif args.has("--join-raid"):
		call_deferred("_join")


func _build() -> void:
	_showcase = LOOK.mount_title_world(self)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.02, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	var title := Label.new()
	title.text = WorldLore.TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.98, 0.62, 0.18))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var sub := Label.new()
	sub.text = WorldLore.TAGLINE
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	_add_button(v, "NEW GAME", _new_game)
	_add_button(v, "CONTINUE" if RunState.has_save() else "ENTER NEW DODGE", _enter_hangar)
	_add_button(v, "QUICK DEPLOY  (Ash Yard 7, scavenger)", _quick)
	_add_button(v, "HOST RAID  :%d" % NetSession.PORT, _host)
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	v.add_child(ip_row)
	var ip_lab := Label.new()
	ip_lab.text = "Join IP"
	ip_row.add_child(ip_lab)
	_ip = LineEdit.new()
	_ip.text = NetSession.join_ip
	_ip.placeholder_text = "host LAN IP"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip)
	_add_button(v, "JOIN FRIEND", _join)
	_add_button(v, "QUIT", _quit)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.7, 0.82, 0.78))
	_status.text = "Host, then friends type your LAN IP and Join. This PC: %s" % NetSession.lan_ip_text()
	root.add_child(_status)
	var foot := Label.new()
	foot.text = WorldLore.controls_footer()
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(foot)


func _process(delta: float) -> void:
	if _showcase and is_instance_valid(_showcase):
		_showcase.rotate_y(delta * 0.16)


func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	box.add_child(b)


func _set_status(text: String) -> void:
	if _status:
		_status.text = text


func _focus_menu() -> void:
	Hud.freeze_for_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _crawl_layer != null:
		return
	for child in get_children():
		if child is MarginContainer:
			_grab_first_button(child)
			return


func _grab_first_button(n: Node) -> void:
	if n is Button:
		(n as Button).grab_focus()
		return
	for c in n.get_children():
		_grab_first_button(c)
		if get_viewport() and get_viewport().gui_get_focus_owner() is Button:
			return


func _new_game() -> void:
	_show_crawl()


func _show_crawl() -> void:
	if _crawl_layer != null:
		return
	_crawl_layer = Control.new()
	_crawl_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crawl_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_crawl_layer.gui_input.connect(_on_crawl_gui)
	add_child(_crawl_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawl_layer.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawl_layer.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(v)
	var head := Label.new()
	head.text = WorldLore.TITLE
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 28)
	head.add_theme_color_override("font_color", Color(0.95, 0.62, 0.22))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := Label.new()
	body.text = WorldLore.crawl_text()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(body)
	var hint := Label.new()
	hint.text = WorldLore.CRAWL_HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.62, 0.56, 0.48))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint)
	var go := Button.new()
	go.text = "CONTINUE"
	go.custom_minimum_size = Vector2(0, 40)
	go.pressed.connect(_finish_crawl)
	v.add_child(go)
	go.grab_focus()


func _on_crawl_gui(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_finish_crawl()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _crawl_layer == null:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		_finish_crawl()


func _finish_crawl() -> void:
	if _leaving:
		return
	_leaving = true
	RunState.new_game()
	get_tree().change_scene_to_file("res://scenes/hangar.tscn")


func _enter_hangar() -> void:
	get_tree().change_scene_to_file("res://scenes/hangar.tscn")


func _quick() -> void:
	RunState.deploy_scale = "scavenger"
	RunState.raid_map = "ash_yard"
	RunState.raid_mode = "combat"
	get_tree().change_scene_to_file("res://scenes/raid.tscn")


func _host() -> void:
	if NetSession.host_game() != OK:
		_set_status(NetSession.last_error)
		return
	RunState.deploy_scale = "scavenger"
	RunState.raid_map = "ash_yard"
	RunState.raid_mode = "combat"
	_set_status("Hosting %s:%d — launching Ash Yard." % [NetSession.lan_ip_text(), NetSession.PORT])
	print("HOST_READY ", NetSession.lan_ip_text(), ":", NetSession.PORT)
	NetSession.start_raid("res://scenes/raid.tscn")


func _join() -> void:
	_join_async()


func _join_async() -> void:
	var ip := "127.0.0.1"
	if _ip:
		ip = _ip.text.strip_edges()
	_set_status("Connecting to %s…" % ip)
	print("JOIN_START ", ip)
	var err := await NetSession.join_and_wait(ip)
	if not is_inside_tree():
		print("JOIN_ABORTED scene gone")
		return
	if err != OK:
		print("JOIN_FAIL ", NetSession.last_error)
		_set_status(NetSession.last_error if NetSession.last_error != "" else "Join failed.")
		return
	print("JOIN_OK id=", NetSession.local_id())
	RunState.deploy_scale = "scavenger"
	RunState.raid_mode = "late_drop"
	_set_status("Joined. Waiting for host to launch the raid…")
	if NetSession.is_online() and not NetSession.is_host():
		NetSession.request_raid.rpc_id(1)


func _quit() -> void:
	get_tree().quit()
