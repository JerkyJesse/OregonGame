extends Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Hud.reset_for_scene()
	Hud.set_objective("")
	Hud.set_prompt("")
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -320
	v.offset_top = -220
	v.offset_right = 320
	v.offset_bottom = 240
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := Label.new()
	title.text = "GET THE MECH OUTTA DODGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.62, 0.22))
	v.add_child(title)
	var sub := Label.new()
	sub.text = "First-person extraction. Strip the giants. Bolt their guns onto yours. Get out."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	v.add_child(sub)
	var hangar := Button.new()
	hangar.text = "ENTER HANGAR"
	hangar.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/hangar.tscn"))
	v.add_child(hangar)
	var deploy := Button.new()
	deploy.text = "QUICK DEPLOY  (Ash Yard 7, scavenger)"
	deploy.pressed.connect(_quick)
	v.add_child(deploy)
	var host := Button.new()
	host.text = "HOST RAID  :7777"
	host.pressed.connect(_host)
	v.add_child(host)
	var join := Button.new()
	join.text = "JOIN 127.0.0.1 AS SCAV WAVE"
	join.pressed.connect(_join)
	v.add_child(join)
	var quit := Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)
	var foot := Label.new()
	foot.text = "WASD move   mouse look   E interact   F board/dismount   G hotwire   LMB fire   CTRL crawl"
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)


func _quick() -> void:
	RunState.deploy_scale = "scavenger"
	RunState.raid_map = "ash_yard"
	RunState.raid_mode = "combat"
	get_tree().change_scene_to_file("res://scenes/raid.tscn")


func _host() -> void:
	NetSession.host_game()
	_quick()


func _join() -> void:
	NetSession.join_game("127.0.0.1")
	RunState.deploy_scale = "scavenger"
	RunState.raid_mode = "late_drop"
	get_tree().change_scene_to_file("res://scenes/raid.tscn")
