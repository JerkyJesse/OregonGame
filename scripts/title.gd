extends Control

var _crawl_layer: Control
var _leaving := false


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


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(640, 0)
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(v)
	var title := Label.new()
	title.text = WorldLore.TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.62, 0.22))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var sub := Label.new()
	sub.text = WorldLore.TAGLINE
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)
	_add_button(v, "NEW GAME", _new_game)
	_add_button(v, "ENTER HANGAR", _enter_hangar)
	_add_button(v, "QUICK DEPLOY  (Ash Yard 7, scavenger)", _quick)
	_add_button(v, "HOST RAID  :7777", _host)
	_add_button(v, "JOIN 127.0.0.1 AS SCAV WAVE", _join)
	_add_button(v, "QUIT", _quit)
	var foot := Label.new()
	foot.text = "Click a button or use arrows + Enter.  In-game: WASD  mouse look  E interact  F board  G hold hotwire  LMB fire"
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)


func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	box.add_child(b)


func _focus_menu() -> void:
	Hud.freeze_for_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _crawl_layer != null:
		return
	for child in get_children():
		if child is CenterContainer:
			for box in child.get_children():
				if box is VBoxContainer:
					for b in box.get_children():
						if b is Button:
							(b as Button).grab_focus()
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
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawl_layer.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(720, 0)
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(v)
	var head := Label.new()
	head.text = WorldLore.TITLE
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 28)
	head.add_theme_color_override("font_color", Color(0.95, 0.62, 0.22))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var body := Label.new()
	body.text = WorldLore.crawl_text()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)
	var hint := Label.new()
	hint.text = WorldLore.CRAWL_HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.62, 0.56, 0.48))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hint)
	var go := Button.new()
	go.text = "CONTINUE"
	go.custom_minimum_size = Vector2(0, 36)
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
		return
	_quick()


func _join() -> void:
	_join_async()


func _join_async() -> void:
	var err := await NetSession.join_and_wait("127.0.0.1")
	if err != OK:
		return
	RunState.deploy_scale = "scavenger"
	RunState.raid_mode = "late_drop"
	get_tree().change_scene_to_file("res://scenes/raid.tscn")


func _quit() -> void:
	get_tree().quit()
