class_name WorldLook
extends RefCounted

const GRIT := preload("res://shaders/grit.gdshader")
const ATMO := preload("res://shaders/atmosphere.gdshader")
const ADD := preload("res://shaders/add_unshaded.gdshader")
const FLESH_SH := preload("res://shaders/pale_flesh.gdshader")
const SKY_SH := preload("res://shaders/sky_bloom.gdshader")
const HAZE_SH := preload("res://shaders/haze_card.gdshader")
const SPARK_SH := preload("res://shaders/soft_particle.gdshader")
const SMOKE_SH := preload("res://shaders/soft_smoke.gdshader")
const VISOR_SH := preload("res://shaders/visor.gdshader")
const TEX_RUST := preload("res://assets/tex/rust_grit.jpg")
const TEX_FLESH := preload("res://assets/tex/pale_flesh.jpg")
const TEX_CHOIR := preload("res://assets/tex/choir_vein.jpg")
const TEX_SPORE := preload("res://assets/tex/bloom_spore.jpg")

static var _bump: NoiseTexture2D

const KIND_HANGAR := "hangar"
const KIND_YARD := "yard"
const KIND_PIPE := "pipeline"
const KIND_RANGE := "range"
const KIND_TITLE := "title"

const PALE := Color(0.58, 0.9, 0.34)
const AMBER := Color(1.0, 0.62, 0.22)
const RUST := Color(0.46, 0.22, 0.09)
const STEEL := Color(0.28, 0.3, 0.33)
const SOOT := Color(0.12, 0.12, 0.13)


static func bump_tex() -> NoiseTexture2D:
	if _bump != null:
		return _bump
	var n := FastNoiseLite.new()
	n.seed = 17
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.042
	n.fractal_octaves = 4
	_bump = NoiseTexture2D.new()
	_bump.noise = n
	_bump.width = 512
	_bump.height = 512
	_bump.seamless = true
	_bump.as_normal_map = true
	_bump.bump_strength = 7.2
	return _bump


static func surface(color: Color, emit: float = 0.0, rust_amt: float = 0.32, metal: float = 0.22, wet: float = 0.0, panel: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRIT
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("stain", color.darkened(0.45))
	m.set_shader_parameter("rust", RUST)
	m.set_shader_parameter("roughness", 0.78 if emit <= 0.0 else 0.42)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("scale", 0.21)
	m.set_shader_parameter("rust_amount", rust_amt)
	m.set_shader_parameter("emission_energy", emit)
	m.set_shader_parameter("emission_color", color)
	m.set_shader_parameter("grit_tex", TEX_RUST)
	m.set_shader_parameter("tex_mix", 0.52)
	m.set_shader_parameter("wetness", wet)
	m.set_shader_parameter("bump", 1.45)
	m.set_shader_parameter("panel_size", panel)
	m.set_shader_parameter("displace", 0.0)
	return m


static func emit_surface(color: Color, energy: float = 1.4, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.28
	m.metallic = 0.22
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func paint_mat(color: Color, translucent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = TEX_RUST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 6.0
	m.uv1_scale = Vector3(0.32, 0.32, 0.32)
	m.metallic = 0.62
	m.metallic_specular = 0.72
	m.roughness = 0.38
	m.roughness_texture = TEX_RUST
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.normal_enabled = true
	m.normal_texture = bump_tex()
	m.normal_scale = 0.9
	m.ao_enabled = true
	m.ao_texture = TEX_RUST
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if translucent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.42
		m.emission_enabled = true
		m.emission = Color(0.18, 0.55, 0.7)
		m.emission_energy_multiplier = 0.9
	else:
		m.emission_enabled = true
		m.emission = color.darkened(0.4)
		m.emission_energy_multiplier = 0.05
	return m


static func flesh_mat(color: Color = PALE, energy: float = 1.2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLESH_SH
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("flesh_tex", TEX_FLESH)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("pulse", 1.25)
	return m


static func choir_plate(color: Color = Color(0.18, 0.2, 0.16)) -> StandardMaterial3D:
	var m := paint_mat(color)
	m.albedo_texture = TEX_CHOIR
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.3, 1.3, 1.3)
	m.emission_enabled = true
	m.emission = Color(0.32, 0.82, 0.28)
	m.emission_texture = TEX_CHOIR
	m.emission_energy_multiplier = 0.55
	return m


static func visor_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VISOR_SH
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("energy", 3.6)
	return m


static func additive(color: Color, energy: float = 1.8) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ADD
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	return m


static func particle_draw(size: Vector2, color: Color, add: bool = true) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var m := ShaderMaterial.new()
	m.shader = SPARK_SH if add else SMOKE_SH
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("softness", 1.8 if add else 2.4)
	q.material = m
	return q


static func make_env(kind: String, fog_override: Color = Color(0, 0, 0, 0), dens_override: float = -1.0) -> Environment:
	var e := Environment.new()
	match kind:
		KIND_HANGAR, KIND_RANGE:
			e.background_mode = Environment.BG_COLOR
			e.background_color = Color(0.035, 0.032, 0.028) if kind == KIND_HANGAR else Color(0.05, 0.046, 0.042)
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color = Color(0.62, 0.44, 0.28) if kind == KIND_HANGAR else Color(0.42, 0.38, 0.32)
			e.ambient_light_energy = 0.24 if kind == KIND_HANGAR else 0.3
			e.fog_enabled = true
			e.fog_light_color = Color(0.2, 0.14, 0.1) if kind == KIND_HANGAR else Color(0.18, 0.16, 0.14)
			e.fog_density = 0.014 if kind == KIND_HANGAR else 0.007
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = 0.018 if kind == KIND_HANGAR else 0.01
			e.volumetric_fog_albedo = Color(0.58, 0.4, 0.26)
			e.volumetric_fog_emission = Color(0.2, 0.08, 0.02)
			e.volumetric_fog_emission_energy = 0.42
			e.volumetric_fog_anisotropy = 0.45
			e.volumetric_fog_length = 32.0
			e.volumetric_fog_ambient_inject = 0.28
		KIND_PIPE:
			e.background_mode = Environment.BG_SKY
			e.sky = _bloom_sky(Color(0.1, 0.09, 0.07), Color(0.3, 0.26, 0.16), Color(0.07, 0.08, 0.06), Color(0.24, 0.22, 0.14), 0.85)
			e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			e.ambient_light_sky_contribution = 0.6
			e.ambient_light_energy = 0.52
			e.fog_enabled = true
			e.fog_light_color = Color(0.28, 0.24, 0.16)
			e.fog_density = 0.016
			e.fog_aerial_perspective = 0.62
			e.fog_sun_scatter = 0.22
			e.fog_height = 1.2
			e.fog_height_density = 0.07
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = 0.024
			e.volumetric_fog_albedo = Color(0.4, 0.36, 0.2)
			e.volumetric_fog_emission = Color(0.14, 0.22, 0.08)
			e.volumetric_fog_emission_energy = 0.55
			e.volumetric_fog_anisotropy = 0.28
			e.volumetric_fog_length = 78.0
			e.volumetric_fog_sky_affect = 0.8
		KIND_TITLE:
			e.background_mode = Environment.BG_SKY
			e.sky = _bloom_sky(Color(0.14, 0.07, 0.04), Color(0.52, 0.28, 0.1), Color(0.06, 0.04, 0.03), Color(0.3, 0.16, 0.07), 0.95)
			e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			e.ambient_light_energy = 0.68
			e.fog_enabled = true
			e.fog_light_color = Color(0.48, 0.3, 0.12)
			e.fog_density = 0.012
			e.fog_aerial_perspective = 0.55
			e.fog_sun_scatter = 0.4
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = 0.026
			e.volumetric_fog_albedo = Color(0.68, 0.42, 0.18)
			e.volumetric_fog_emission = Color(0.18, 0.28, 0.08)
			e.volumetric_fog_emission_energy = 0.5
			e.volumetric_fog_length = 90.0
			e.volumetric_fog_sky_affect = 0.9
		_:
			e.background_mode = Environment.BG_SKY
			e.sky = _bloom_sky(Color(0.16, 0.08, 0.04), Color(0.58, 0.36, 0.16), Color(0.08, 0.06, 0.04), Color(0.34, 0.2, 0.1), 1.05)
			e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			e.ambient_light_sky_contribution = 0.72
			e.ambient_light_energy = 0.58
			e.fog_enabled = true
			e.fog_light_color = Color(0.5, 0.34, 0.16)
			e.fog_density = 0.009
			e.fog_aerial_perspective = 0.7
			e.fog_sun_scatter = 0.38
			e.fog_height = 0.35
			e.fog_height_density = 0.05
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = 0.014
			e.volumetric_fog_albedo = Color(0.68, 0.46, 0.24)
			e.volumetric_fog_emission = Color(0.16, 0.22, 0.06)
			e.volumetric_fog_emission_energy = 0.38
			e.volumetric_fog_anisotropy = 0.38
			e.volumetric_fog_length = 110.0
			e.volumetric_fog_sky_affect = 0.9
			e.volumetric_fog_ambient_inject = 0.42
	if fog_override.a > 0.0:
		e.fog_light_color = fog_override
	if dens_override >= 0.0:
		e.fog_density = dens_override
	_finish_env(e, kind)
	return e


static func retune_environment(e: Environment, kind: String) -> void:
	if e == null:
		return
	_finish_env(e, kind)


static func _finish_env(e: Environment, kind: String) -> void:
	var q := Settings.quality if Engine.get_main_loop() else "high"
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.96 if kind != KIND_HANGAR and kind != KIND_RANGE else 1.02
	e.ssao_enabled = q != "low"
	e.ssao_radius = 1.55
	e.ssao_intensity = 1.28 if q == "high" else 1.05
	e.ssao_power = 1.45
	e.ssao_horizon = 0.05
	e.ssao_sharpness = 0.82
	e.ssao_light_affect = 0.45
	e.ssil_enabled = q == "high"
	e.ssil_radius = 2.1
	e.ssil_intensity = 0.92
	e.ssil_sharpness = 0.84
	e.ssr_enabled = q == "high" and kind != KIND_RANGE
	e.ssr_max_steps = 56 if q == "high" else 24
	e.ssr_fade_in = 0.12
	e.ssr_fade_out = 2.0
	e.ssr_depth_tolerance = 0.18
	e.sdfgi_enabled = q != "low"
	e.sdfgi_use_occlusion = q == "high"
	e.sdfgi_read_sky_light = kind != KIND_HANGAR and kind != KIND_RANGE
	e.sdfgi_bounce_feedback = 0.48
	e.sdfgi_cascades = 4 if q == "high" else 2
	e.sdfgi_min_cell_size = 0.3 if kind == KIND_HANGAR else 0.62
	e.sdfgi_energy = 1.12
	e.sdfgi_normal_bias = 1.12
	e.sdfgi_probe_bias = 1.05
	if e.background_mode == Environment.BG_SKY:
		e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.glow_enabled = true
	e.glow_normalized = true
	e.glow_intensity = 0.58 if q == "high" else (0.42 if q == "medium" else 0.28)
	e.glow_bloom = 0.26 if q == "high" else (0.16 if q == "medium" else 0.08)
	e.glow_hdr_threshold = 0.56
	e.glow_hdr_scale = 1.9
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if kind == KIND_HANGAR else Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(1, 0.32)
	e.set_glow_level(2, 0.88)
	e.set_glow_level(3, 1.05)
	e.set_glow_level(4, 0.78)
	e.set_glow_level(5, 0.42)
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.0
	e.adjustment_contrast = 1.12
	e.adjustment_saturation = 1.08
	e.volumetric_fog_enabled = q != "low"
	e.volumetric_fog_temporal_reprojection_enabled = q != "low"
	e.volumetric_fog_temporal_reprojection_amount = 0.93
	e.volumetric_fog_gi_inject = 0.7 if q == "high" else 0.35
	e.volumetric_fog_detail_spread = 2.0 if q == "high" else 1.2


static func _bloom_sky(top: Color, hor: Color, ground: Color, ghor: Color, pale_amt: float) -> Sky:
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SH
	mat.set_shader_parameter("sky_top", top)
	mat.set_shader_parameter("sky_horizon", hor)
	mat.set_shader_parameter("ground_bottom", ground)
	mat.set_shader_parameter("ground_horizon", ghor)
	mat.set_shader_parameter("pale_color", PALE)
	mat.set_shader_parameter("pale_amount", pale_amt)
	mat.set_shader_parameter("dust", 0.5)
	var s := Sky.new()
	s.sky_material = mat
	s.process_mode = Sky.PROCESS_MODE_REALTIME
	s.radiance_size = Sky.RADIANCE_SIZE_256 if Settings.is_high() else (Sky.RADIANCE_SIZE_128 if Settings.quality == "medium" else Sky.RADIANCE_SIZE_64)
	return s


static func apply(world: Node3D, kind: String) -> void:
	if world == null:
		return
	world.set_meta("look_kind", kind)
	if world.has_node("WorldEnvironment"):
		(world.get_node("WorldEnvironment") as WorldEnvironment).environment = make_env(kind)
	_style_lights(world, kind)
	_paint_shell(world, kind)
	_atmosphere(world, kind)
	if world.has_node("LookDressing"):
		world.get_node("LookDressing").free()
	var dress := Node3D.new()
	dress.name = "LookDressing"
	world.add_child(dress)
	match kind:
		KIND_HANGAR:
			_dress_hangar(dress, world)
		KIND_PIPE:
			_dress_pipeline(dress)
		KIND_RANGE:
			_dress_range(dress)
		_:
			_dress_yard(dress)
	dust(dress, _dust_box(kind), _dust_color(kind), _dust_count(kind))
	if kind == KIND_PIPE or kind == KIND_YARD:
		dust(dress, _dust_box(kind) * Vector3(0.7, 1.4, 0.7), Color(0.5, 0.92, 0.32, 0.12), 48)
	call_tune_cameras(world)
	Settings.apply()


static func _dust_box(kind: String) -> Vector3:
	match kind:
		KIND_HANGAR:
			return Vector3(18, 4, 14)
		KIND_RANGE:
			return Vector3(12, 3, 18)
		KIND_PIPE:
			return Vector3(36, 6, 24)
		_:
			return Vector3(48, 8, 38)


static func _dust_color(kind: String) -> Color:
	if kind == KIND_PIPE:
		return Color(0.55, 0.48, 0.28, 0.22)
	if kind == KIND_HANGAR:
		return Color(0.7, 0.5, 0.28, 0.16)
	return Color(0.72, 0.52, 0.28, 0.2)


static func _dust_count(kind: String) -> int:
	var n := 128
	if kind == KIND_RANGE:
		n = 56
	elif kind == KIND_HANGAR:
		n = 80
	return maxi(8, int(round(float(n) * Settings.dust_scale())))


static func _style_lights(world: Node3D, kind: String) -> void:
	if world.has_node("Sun"):
		var sun := world.get_node("Sun") as DirectionalLight3D
		sun.shadow_enabled = true
		sun.shadow_blur = 1.55
		sun.shadow_bias = 0.04
		sun.shadow_normal_bias = 1.15
		sun.light_angular_distance = 1.15
		sun.light_specular = 0.62
		sun.light_volumetric_fog_energy = 2.15
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_pancake_size = 6.0
		match kind:
			KIND_HANGAR:
				sun.light_color = Color(1.0, 0.72, 0.42)
				sun.light_energy = 1.05
				sun.directional_shadow_max_distance = 48.0
			KIND_PIPE:
				sun.light_color = Color(1.0, 0.58, 0.32)
				sun.light_energy = 1.25
				sun.directional_shadow_max_distance = 90.0
			KIND_RANGE:
				sun.light_color = Color(1.0, 0.82, 0.6)
				sun.light_energy = 0.95
				sun.directional_shadow_max_distance = 40.0
			_:
				sun.light_color = Color(1.0, 0.54, 0.26)
				sun.light_energy = 1.72
				sun.directional_shadow_max_distance = 150.0
	if world.has_node("BayLight"):
		var bay := world.get_node("BayLight") as OmniLight3D
		bay.light_color = Color(1.0, 0.58, 0.22)
		bay.light_energy = 5.2
		bay.omni_range = 20.0
		bay.light_volumetric_fog_energy = 2.1
		bay.shadow_enabled = true
		bay.shadow_blur = 1.6
		bay.light_specular = 0.7
	if world.has_node("FillLight"):
		var fill := world.get_node("FillLight") as OmniLight3D
		fill.light_color = Color(0.35, 0.55, 0.72)
		fill.light_energy = 1.8
		fill.omni_range = 18.0
	if world.has_node("Haze"):
		var haze := world.get_node("Haze") as OmniLight3D
		haze.light_color = Color(1.0, 0.48, 0.16)
		haze.light_energy = 4.5
		haze.omni_range = 48.0
		haze.light_volumetric_fog_energy = 1.4
		haze.position = Vector3(8, 16, -6)
	if kind == KIND_YARD or kind == KIND_PIPE:
		if world.get_node_or_null("PaleRim") == null:
			var rim := DirectionalLight3D.new()
			rim.name = "PaleRim"
			rim.light_color = Color(0.45, 0.85, 0.38)
			rim.light_energy = 0.48 if kind == KIND_YARD else 0.32
			rim.shadow_enabled = false
			rim.rotation_degrees = Vector3(-18, 155, 0)
			rim.light_specular = 0.2
			world.add_child(rim)


static func _paint_shell(world: Node3D, kind: String) -> void:
	var floor_col := Color(0.2, 0.19, 0.16)
	var wall_col := Color(0.16, 0.15, 0.14)
	var rust_amt := 0.38
	match kind:
		KIND_HANGAR:
			floor_col = Color(0.16, 0.16, 0.175)
			wall_col = Color(0.13, 0.135, 0.14)
			rust_amt = 0.22
		KIND_PIPE:
			floor_col = Color(0.18, 0.15, 0.11)
			wall_col = Color(0.14, 0.13, 0.11)
			rust_amt = 0.45
		KIND_RANGE:
			floor_col = Color(0.15, 0.15, 0.145)
			wall_col = Color(0.11, 0.11, 0.11)
			rust_amt = 0.12
		_:
			floor_col = Color(0.2, 0.16, 0.12)
			wall_col = Color(0.16, 0.14, 0.12)
	var floor_wet := 0.42 if kind == KIND_HANGAR else (0.12 if kind == KIND_RANGE else 0.32)
	var floor_panel := 3.6 if kind == KIND_HANGAR else (5.5 if kind == KIND_RANGE else 8.0)
	_set_csg_mat(world, "Floor", surface(floor_col, 0.0, rust_amt, 0.14, floor_wet, floor_panel))
	for n in ["WallN", "WallS", "WallW", "WallE", "WallBack", "WallFront", "WallLeft", "WallRight", "Back", "Ceiling", "Catwalk"]:
		_set_csg_mat(world, n, surface(wall_col, 0.0, rust_amt * 0.7, 0.2, 0.0, 6.5))
	_set_csg_mat(world, "Ruin", surface(Color(0.32, 0.2, 0.12), 0.0, 0.55, 0.08, 0.1, 4.0))
	_set_csg_mat(world, "Trim", emit_surface(AMBER, 1.35))
	_set_csg_mat(world, "Bay", surface(SOOT, 0.0, 0.15, 0.3, 0.0, 5.0))


static func _set_csg_mat(world: Node, name: String, mat: Material) -> void:
	var n := world.get_node_or_null(name)
	if n is CSGShape3D:
		(n as CSGShape3D).material = mat
	elif n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat


static func _atmosphere(world: Node, kind: String) -> void:
	var old := world.get_node_or_null("LookAtmo")
	if old:
		old.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "LookAtmo"
	layer.layer = 5
	layer.follow_viewport_enabled = false
	world.add_child(layer)
	var rect := ColorRect.new()
	rect.name = "Grade"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = ATMO
	match kind:
		KIND_HANGAR:
			mat.set_shader_parameter("tint", Color(1.04, 0.9, 0.76))
			mat.set_shader_parameter("vignette", 0.58)
			mat.set_shader_parameter("pale", 0.0)
			mat.set_shader_parameter("grain", 0.042)
		KIND_PIPE:
			mat.set_shader_parameter("tint", Color(0.94, 0.9, 0.76))
			mat.set_shader_parameter("vignette", 0.52)
			mat.set_shader_parameter("pale", 0.14)
			mat.set_shader_parameter("grain", 0.05)
		KIND_RANGE:
			mat.set_shader_parameter("tint", Color(1.0, 0.95, 0.88))
			mat.set_shader_parameter("vignette", 0.38)
			mat.set_shader_parameter("pale", 0.0)
			mat.set_shader_parameter("grain", 0.028)
		_:
			mat.set_shader_parameter("tint", Color(1.05, 0.88, 0.7))
			mat.set_shader_parameter("vignette", 0.5)
			mat.set_shader_parameter("pale", 0.1)
			mat.set_shader_parameter("grain", 0.044)
	mat.set_shader_parameter("pale_color", PALE)
	mat.set_shader_parameter("contrast", 1.12)
	mat.set_shader_parameter("saturation", 1.1)
	var grain: Variant = mat.get_shader_parameter("grain")
	var base_grain := float(grain) if grain != null else 0.04
	mat.set_meta("base_grain", base_grain)
	mat.set_shader_parameter("grain", base_grain * Settings.grain_scale())
	rect.material = mat
	layer.add_child(rect)
	world.set_meta("look_atmo_mat", mat)


static func set_pale(world: Node, amount: float) -> void:
	if world == null or not world.has_meta("look_atmo_mat"):
		return
	var mat: Variant = world.get_meta("look_atmo_mat")
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("pale", clampf(amount, 0.0, 1.0))


static func dust(parent: Node3D, extents: Vector3, color: Color, amount: int = 80) -> void:
	var p := GPUParticles3D.new()
	p.name = "AshMotes"
	p.amount = amount
	p.lifetime = 11.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(-extents, extents * 2.0)
	p.position = Vector3(0, extents.y * 0.45, 0)
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_shape_scale = extents
	pm.direction = Vector3(0.35, 0.08, 0.12)
	pm.spread = 28.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0, -0.04, 0)
	pm.damping_min = 0.05
	pm.damping_max = 0.18
	pm.scale_min = 0.6
	pm.scale_max = 1.8
	pm.color = color
	p.process_material = pm
	p.draw_pass_1 = particle_draw(Vector2(0.12, 0.12), color, true)
	parent.add_child(p)


static func smoke(parent: Node, pos: Vector3, color: Color = Color(0.18, 0.16, 0.14, 0.45)) -> void:
	var p := GPUParticles3D.new()
	p.name = "LookSmoke"
	p.amount = 18
	p.lifetime = 3.2
	p.preprocess = 1.5
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.35, 0)
	pm.scale_min = 0.8
	pm.scale_max = 2.4
	pm.color = color
	p.process_material = pm
	p.draw_pass_1 = particle_draw(Vector2(0.55, 0.55), color, false)
	parent.add_child(p)


static func sparkle(parent: Node3D, pos: Vector3, color: Color, radius: float = 0.8) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "LookSparkle"
	p.amount = 22
	p.lifetime = 1.6
	p.preprocess = 0.8
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.1
	pm.color = color
	p.process_material = pm
	p.draw_pass_1 = particle_draw(Vector2(0.08, 0.08), color, true)
	parent.add_child(p)
	return p


static func add_mesh(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emit: float = 0.0, rust_amt: float = 0.3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = emit_surface(color, emit) if emit > 0.0 else surface(color, 0.0, rust_amt)
	mi.mesh = box
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func add_sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 20
	sph.rings = 12
	sph.material = mat
	mi.mesh = sph
	mi.position = pos
	mi.scale = scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func add_cyl(parent: Node3D, pos: Vector3, height: float, radius: float, color: Color, rot := Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 16
	cyl.material = emit_surface(color, emit) if emit > 0.0 else surface(color, 0.0, 0.4, 0.4)
	mi.mesh = cyl
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func add_lamp(parent: Node3D, pos: Vector3, color: Color, energy: float = 3.2, range: float = 14.0) -> void:
	add_cyl(parent, pos, 0.18, 0.35, color.darkened(0.5))
	add_cyl(parent, pos + Vector3(0, -0.12, 0), 0.08, 0.28, color, Vector3.ZERO, 2.4)
	var spot := SpotLight3D.new()
	spot.position = pos + Vector3(0, -0.2, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = color
	spot.light_energy = energy
	spot.spot_range = range
	spot.spot_angle = 42.0
	spot.spot_attenuation = 0.65
	spot.shadow_enabled = energy >= 3.5
	spot.shadow_blur = 1.55
	spot.light_specular = 0.75
	spot.light_volumetric_fog_energy = 2.6
	parent.add_child(spot)
	_add_fog(parent, pos + Vector3(0, -2.4, 0), Vector3(5.2, 6.0, 5.2), color, color * Color(0.5, 0.4, 0.25), 0.1)


static func _haze_card(parent: Node3D, pos: Vector3, size: Vector2, color: Color, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	var m := ShaderMaterial.new()
	m.shader = HAZE_SH
	m.set_shader_parameter("color", color)
	q.material = m
	mi.mesh = q
	mi.position = pos
	mi.rotation_degrees.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _dress_yard(d: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	_ground_skin(d, Vector2(108, 88), Color(0.2, 0.16, 0.12), 0.34, 0.26)
	add_cyl(d, Vector3(-32, 6, -20), 12.0, 0.55, Color(0.22, 0.2, 0.17))
	add_cyl(d, Vector3(8, 9, 22), 18.0, 0.7, Color(0.2, 0.18, 0.15))
	add_cyl(d, Vector3(36, 5, -28), 10.0, 0.45, STEEL, Vector3(0, 0, 90), 0.0)
	add_cyl(d, Vector3(-18, 4.5, 30), 22.0, 0.4, Color(0.32, 0.22, 0.14), Vector3(0, 0, 90))
	add_mesh(d, Vector3(-40, 0.04, 0), Vector3(8, 0.05, 1.1), AMBER, 0.9, 0.0)
	add_mesh(d, Vector3(0, 0.04, 18), Vector3(1.0, 0.05, 10), Color(0.12, 0.12, 0.1))
	add_mesh(d, Vector3(22, 0.03, -12), Vector3(14, 0.04, 0.8), Color(0.16, 0.1, 0.06), 0.0, 0.6)
	for i in 22:
		var p := Vector3(rng.randf_range(-46, 46), 0.04, rng.randf_range(-38, 38))
		var s := Vector3(rng.randf_range(1.2, 3.8), 0.05, rng.randf_range(0.8, 2.4))
		add_mesh(d, p, s, Color(0.18 + rng.randf() * 0.08, 0.12, 0.08), 0.0, rng.randf_range(0.2, 0.7))
	for i in 7:
		var crate := Vector3(rng.randf_range(-30, 30), 0.55, rng.randf_range(-24, 24))
		add_mesh(d, crate, Vector3(1.1, 1.1, 1.1), Color(0.34, 0.28, 0.18), 0.0, 0.25)
	for i in 5:
		_add_puddle(d, Vector3(rng.randf_range(-28, 28), 0.025, rng.randf_range(-22, 22)), Vector2(rng.randf_range(2.4, 5.5), rng.randf_range(1.4, 3.2)))
	_haze_card(d, Vector3(0, 11, -43.4), Vector2(110, 26), Color(0.58, 0.32, 0.1, 0.22), 0)
	_haze_card(d, Vector3(0, 11, 43.4), Vector2(110, 26), Color(0.38, 0.26, 0.1, 0.18), 180)
	_haze_card(d, Vector3(-53, 11, 0), Vector2(90, 26), Color(0.32, 0.42, 0.16, 0.14), 90)
	_haze_card(d, Vector3(53, 11, 0), Vector2(90, 26), Color(0.55, 0.28, 0.08, 0.16), -90)
	_haze_card(d, Vector3(8, 16, -42), Vector2(70, 18), Color(0.45, 0.85, 0.28, 0.18), 0)
	occupation_walker(d, Vector3(28, 0, -38), 200.0, 1.15)
	occupation_walker(d, Vector3(-36, 0, -34), 155.0, 0.82)
	kneeling_frame(d, Vector3(-8, 0, -18), 28.0, 1.0)
	var omni := OmniLight3D.new()
	omni.position = Vector3(-26, 4.5, -8)
	omni.light_color = Color(1.0, 0.4, 0.12)
	omni.light_energy = 3.8
	omni.omni_range = 16.0
	omni.light_volumetric_fog_energy = 1.8
	omni.shadow_enabled = true
	d.add_child(omni)
	var pale := OmniLight3D.new()
	pale.position = Vector3(0, 12, -36)
	pale.light_color = PALE
	pale.light_energy = 3.4
	pale.omni_range = 28.0
	pale.light_volumetric_fog_energy = 2.4
	d.add_child(pale)
	_add_fog(d, Vector3(6, 14, -38), Vector3(70, 22, 18), Color(0.45, 0.7, 0.28), PALE, 0.07)
	_add_fog(d, Vector3(-26, 3.2, -8), Vector3(10, 6, 10), Color(0.7, 0.35, 0.12), Color(0.8, 0.3, 0.05), 0.08)
	smoke(d, Vector3(-32, 1.2, -20), Color(0.14, 0.12, 0.1, 0.5))
	smoke(d, Vector3(8, 1.4, 22), Color(0.16, 0.14, 0.12, 0.42))
	for i in 12:
		var gp := Vector3(rng.randf_range(-44, 44), 0.0, rng.randf_range(-36, 36))
		if gp.length() < 14.0:
			continue
		pale_growth(d, gp, 50 + i)


static func _dress_pipeline(d: Node3D) -> void:
	_ground_skin(d, Vector2(88, 62), Color(0.18, 0.15, 0.11), 0.5, 0.18)
	add_cyl(d, Vector3(0, 3.2, -6), 70.0, 0.7, Color(0.38, 0.22, 0.12), Vector3(0, 0, 90))
	add_cyl(d, Vector3(0, 5.4, 6), 64.0, 0.45, STEEL, Vector3(0, 0, 90), 0.15)
	add_cyl(d, Vector3(-20, 4, 0), 8.0, 2.0, RUST)
	add_cyl(d, Vector3(20, 4, 0), 8.0, 2.0, RUST)
	add_mesh(d, Vector3(0, 0.04, 0), Vector3(40, 0.05, 2.2), Color(0.12, 0.12, 0.1))
	add_lamp(d, Vector3(-12, 9.2, 0), Color(1.0, 0.55, 0.2), 4.0, 18.0)
	add_lamp(d, Vector3(12, 9.2, 0), Color(1.0, 0.55, 0.2), 4.0, 18.0)
	add_lamp(d, Vector3(0, 9.5, 12), PALE, 2.4, 16.0)
	_haze_card(d, Vector3(0, 9, -30), Vector2(78, 22), Color(0.28, 0.22, 0.12, 0.24), 0)
	_add_puddle(d, Vector3(2, 0.03, 10), Vector2(6.5, 3.2))
	_add_puddle(d, Vector3(-8, 0.03, -4), Vector2(4.0, 2.4))
	var leak := OmniLight3D.new()
	leak.position = Vector3(0, 6, 14)
	leak.light_color = PALE
	leak.light_energy = 4.2
	leak.omni_range = 18.0
	leak.light_volumetric_fog_energy = 2.6
	d.add_child(leak)
	_add_fog(d, Vector3(0, 4.5, 14), Vector3(10, 8, 8), Color(0.4, 0.75, 0.28), PALE, 0.16)
	pale_growth(d, Vector3(0, 0, 14.5), 9)
	pale_growth(d, Vector3(-16, 0, -8), 12)
	pale_growth(d, Vector3(18, 0, 8), 15)
	smoke(d, Vector3(0, 2.2, 14), Color(0.4, 0.7, 0.22, 0.35))


static func _dress_hangar(d: Node3D, world: Node3D) -> void:
	add_lamp(d, Vector3(-8, 9.4, -4), Color(1.0, 0.62, 0.28), 4.5, 16.0)
	add_lamp(d, Vector3(8, 9.4, -4), Color(1.0, 0.62, 0.28), 4.5, 16.0)
	add_lamp(d, Vector3(-8, 9.4, 6), Color(1.0, 0.55, 0.22), 3.6, 14.0)
	add_lamp(d, Vector3(8, 9.4, 6), Color(1.0, 0.55, 0.22), 3.6, 14.0)
	add_mesh(d, Vector3(0, 0.03, 0), Vector3(10, 0.04, 0.28), AMBER, 1.0, 0.0)
	add_mesh(d, Vector3(0, 0.03, 0), Vector3(0.28, 0.04, 8), AMBER, 1.0, 0.0)
	add_mesh(d, Vector3(-6, 0.03, 2), Vector3(3.2, 0.03, 3.2), Color(0.14, 0.14, 0.12))
	add_mesh(d, Vector3(8, 0.03, -4), Vector3(4.5, 0.03, 4.5), Color(0.14, 0.14, 0.12))
	add_cyl(d, Vector3(-18, 6, -8), 16.0, 0.18, Color(0.2, 0.2, 0.22), Vector3(0, 0, 90))
	add_cyl(d, Vector3(18, 6, 8), 14.0, 0.16, Color(0.22, 0.18, 0.14), Vector3(0, 0, 90))
	add_lamp(d, Vector3(12, 4.2, 12), Color(0.35, 0.95, 0.55), 3.0, 10.0)
	add_mesh(d, Vector3(14, 0.7, -12), Vector3(1.6, 1.4, 1.2), STEEL, 0.0, 0.2)
	_add_puddle(d, Vector3(0, 0.02, 4), Vector2(7.5, 3.5))
	_add_puddle(d, Vector3(-7, 0.02, -6), Vector2(4.2, 2.6))
	add_mesh(d, Vector3(-16, 8.6, 0), Vector3(8.0, 0.22, 0.35), Color(0.22, 0.2, 0.18), 0.0, 0.2)
	add_mesh(d, Vector3(16, 8.6, 0), Vector3(8.0, 0.22, 0.35), Color(0.22, 0.2, 0.18), 0.0, 0.2)
	add_mesh(d, Vector3(0, 9.4, -8), Vector3(28, 0.18, 0.4), Color(0.18, 0.17, 0.16), 0.0, 0.15)
	_add_fog(d, Vector3(0, 4.5, 0), Vector3(16, 8, 12), Color(0.7, 0.45, 0.22), Color(0.5, 0.22, 0.06), 0.05)
	smoke(d, Vector3(-14, 1.4, -10), Color(0.12, 0.11, 0.1, 0.35))
	var screen := world.get_node_or_null("DeployConsole/Screen") as MeshInstance3D
	if screen:
		screen.material_override = emit_surface(Color(0.25, 0.85, 0.95), 2.6)


static func _dress_range(d: Node3D) -> void:
	add_lamp(d, Vector3(-6, 7.2, -8), Color(1.0, 0.75, 0.45), 3.2, 16.0)
	add_lamp(d, Vector3(6, 7.2, -8), Color(1.0, 0.75, 0.45), 3.2, 16.0)
	add_mesh(d, Vector3(0, 0.03, -8), Vector3(0.4, 0.04, 28), Color(0.7, 0.2, 0.1), 0.6, 0.0)
	_add_puddle(d, Vector3(0, 0.02, -4), Vector2(5.5, 2.4))
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 6, -20)
	spot.rotation_degrees = Vector3(-35, 0, 0)
	spot.light_color = Color(1.0, 0.35, 0.12)
	spot.light_energy = 4.5
	spot.spot_range = 22.0
	spot.spot_angle = 28.0
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 2.2
	d.add_child(spot)


static func dress_hauler(host: Node3D) -> void:
	if host == null or host.get_node_or_null("LookHeadlights") != null:
		return
	var root := Node3D.new()
	root.name = "LookHeadlights"
	host.add_child(root)
	_box(root, Vector3(-0.7, 1.55, 3.75), Vector3(0.22, 0.16, 0.12), emit_surface(Color(1.0, 0.92, 0.7), 3.5))
	_box(root, Vector3(0.7, 1.55, 3.75), Vector3(0.22, 0.16, 0.12), emit_surface(Color(1.0, 0.92, 0.7), 3.5))
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 1.55, 3.9)
	spot.light_color = Color(1.0, 0.92, 0.75)
	spot.light_energy = 2.4
	spot.spot_range = 22.0
	spot.spot_angle = 32.0
	spot.light_volumetric_fog_energy = 1.4
	root.add_child(spot)


static func dress_human(host: Node3D, suit: Color, hide_fp: bool = false) -> void:
	if host == null or host.get_node_or_null("LookGear") != null:
		return
	var gear := Node3D.new()
	gear.name = "LookGear"
	host.add_child(gear)
	var layer := 2 if hide_fp else 1
	var helm := MeshInstance3D.new()
	var hmesh := BoxMesh.new()
	hmesh.size = Vector3(0.42, 0.28, 0.46)
	hmesh.material = paint_mat(suit.darkened(0.15))
	helm.mesh = hmesh
	helm.position = Vector3(0, 1.48, 0.02)
	helm.layers = layer
	gear.add_child(helm)
	var vis := MeshInstance3D.new()
	var vmesh := BoxMesh.new()
	vmesh.size = Vector3(0.34, 0.1, 0.08)
	vmesh.material = visor_mat(Color(0.2, 0.95, 0.75))
	vis.mesh = vmesh
	vis.position = Vector3(0, 1.48, 0.24)
	vis.layers = layer
	gear.add_child(vis)
	var pack := MeshInstance3D.new()
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.32, 0.38, 0.16)
	pmesh.material = paint_mat(suit.darkened(0.35))
	pack.mesh = pmesh
	pack.position = Vector3(0, 1.05, -0.22)
	pack.layers = layer
	gear.add_child(pack)
	var tank := MeshInstance3D.new()
	var tmesh := CylinderMesh.new()
	tmesh.top_radius = 0.07
	tmesh.bottom_radius = 0.07
	tmesh.height = 0.42
	tmesh.material = paint_mat(Color(0.22, 0.24, 0.26))
	tank.mesh = tmesh
	tank.position = Vector3(0.12, 1.08, -0.28)
	tank.rotation_degrees.x = 8
	tank.layers = layer
	gear.add_child(tank)
	if suit.g > 0.55 and suit.g > suit.r + 0.08:
		for i in 4:
			var veil := MeshInstance3D.new()
			var vc := CylinderMesh.new()
			vc.top_radius = 0.012
			vc.bottom_radius = 0.03
			vc.height = 0.55
			vc.material = flesh_mat(PALE, 1.6)
			veil.mesh = vc
			var ang := TAU * float(i) / 4.0
			veil.position = Vector3(cos(ang) * 0.18, 1.22, sin(ang) * 0.16 - 0.08)
			veil.rotation_degrees.x = 18.0
			veil.layers = layer
			gear.add_child(veil)


static func pale_growth(parent: Node3D, pos: Vector3, seed: int = 1) -> void:
	if parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	add_sphere(root, Vector3(0, 0.22, 0), 0.42, flesh_mat(Color(0.48, 0.78, 0.28), 0.7), Vector3(1.4, 0.45, 1.3))
	for i in 5:
		var ang := TAU * float(i) / 5.0 + rng.randf() * 0.4
		var h := rng.randf_range(0.7, 1.6)
		var cyl := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.03
		mesh.bottom_radius = 0.09
		mesh.height = h
		mesh.material = flesh_mat(PALE, 1.4)
		cyl.mesh = mesh
		cyl.position = Vector3(cos(ang) * 0.22, h * 0.5, sin(ang) * 0.22)
		cyl.rotation_degrees.z = rng.randf_range(-18, 18)
		cyl.rotation_degrees.x = rng.randf_range(-12, 12)
		root.add_child(cyl)
	sparkle(root, Vector3(0, 0.8, 0), Color(0.55, 1.0, 0.35, 0.65), 0.45)


static func dress_pale_host(host: Node3D) -> void:
	if host == null or host.get_node_or_null("LookAlien") != null:
		return
	var hide := host.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if hide:
		hide.visible = false
	var root := Node3D.new()
	root.name = "LookAlien"
	host.add_child(root)
	var flesh := flesh_mat(PALE, 1.45)
	# Cluster mass — not a biped. Filament colony wearing a stolen can silhouette.
	add_sphere(root, Vector3(0, 1.15, 0), 0.62, flesh, Vector3(0.95, 1.05, 0.88))
	add_sphere(root, Vector3(0.22, 1.55, 0.1), 0.34, flesh_mat(Color(0.68, 0.96, 0.38), 1.9), Vector3(1.1, 0.75, 0.95))
	add_sphere(root, Vector3(-0.28, 1.42, -0.12), 0.28, flesh, Vector3(0.8, 1.0, 0.85))
	var can := MeshInstance3D.new()
	var can_mesh := CylinderMesh.new()
	can_mesh.top_radius = 0.22
	can_mesh.bottom_radius = 0.26
	can_mesh.height = 0.55
	can_mesh.material = paint_mat(Color(0.22, 0.24, 0.2))
	can.mesh = can_mesh
	can.position = Vector3(0.05, 0.95, 0.18)
	can.rotation_degrees = Vector3(18, 0, -12)
	root.add_child(can)
	var slit := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.42, 0.05, 0.07)
	sm.material = emit_surface(Color(0.9, 1.0, 0.4), 5.0)
	slit.mesh = sm
	slit.position = Vector3(0.1, 1.62, 0.38)
	root.add_child(slit)
	# Tendril legs — uneven count, wrong for a person.
	for i in 5:
		var ang := TAU * float(i) / 5.0 + 0.15
		var reach := 0.34 + float(i % 2) * 0.12
		var hip := Vector3(cos(ang) * 0.3, 0.85, sin(ang) * 0.3)
		var thigh := MeshInstance3D.new()
		var tmesh := CylinderMesh.new()
		tmesh.top_radius = 0.045
		tmesh.bottom_radius = 0.1
		tmesh.height = 0.85 + float(i % 3) * 0.12
		tmesh.material = flesh
		thigh.mesh = tmesh
		thigh.position = hip + Vector3(cos(ang) * reach * 0.5, -0.38, sin(ang) * reach * 0.5)
		thigh.rotation_degrees.z = cos(ang) * 28.0
		thigh.rotation_degrees.x = sin(ang) * 26.0
		root.add_child(thigh)
		add_sphere(root, hip + Vector3(cos(ang) * reach, -0.85, sin(ang) * reach), 0.1, flesh)
	# Crown filaments
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var crown := MeshInstance3D.new()
		var cmesh := CylinderMesh.new()
		cmesh.top_radius = 0.01
		cmesh.bottom_radius = 0.04
		cmesh.height = 0.55 + float(i % 3) * 0.18
		cmesh.material = flesh_mat(Color(0.72, 1.0, 0.42), 2.2)
		crown.mesh = cmesh
		crown.position = Vector3(cos(ang) * 0.2, 2.05, sin(ang) * 0.18)
		crown.rotation_degrees.z = cos(ang) * 32.0
		crown.rotation_degrees.x = -sin(ang) * 30.0
		root.add_child(crown)
	for i in 5:
		var ang := TAU * float(i) / 5.0 + 0.55
		var hang := MeshInstance3D.new()
		var hmesh := CylinderMesh.new()
		hmesh.top_radius = 0.015
		hmesh.bottom_radius = 0.048
		hmesh.height = 0.95
		hmesh.material = flesh
		hang.mesh = hmesh
		hang.position = Vector3(cos(ang) * 0.38, 1.0, sin(ang) * 0.28)
		hang.rotation_degrees.x = 18.0
		root.add_child(hang)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.55, 0)
	light.light_color = PALE
	light.light_energy = 3.2
	light.omni_range = 8.0
	light.light_volumetric_fog_energy = 2.0
	root.add_child(light)
	sparkle(root, Vector3(0, 1.6, 0), Color(0.55, 1.0, 0.38, 0.8), 0.85)
	dust(root, Vector3(1.3, 1.5, 1.3), Color(0.55, 0.95, 0.32, 0.25), 22)
	var tag := Label3D.new()
	tag.text = "PALE HOST"
	tag.position = Vector3(0, 2.75, 0)
	tag.font_size = 32
	tag.modulate = PALE
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 6
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	root.add_child(tag)


static func dress_choir_husk(host: Node3D) -> void:
	if host == null or host.get_node_or_null("LookHusk") != null:
		return
	var hide := host.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if hide:
		hide.visible = false
	var root := Node3D.new()
	root.name = "LookHusk"
	host.add_child(root)
	var plate := choir_plate()
	var rust := paint_mat(Color(0.32, 0.16, 0.08))
	# Asymmetric wrecked scavenger frame — wrong proportions, dangling arm, exposed shard.
	_box(root, Vector3(0.02, 1.12, 0.0), Vector3(0.58, 0.72, 0.34), plate)
	_box(root, Vector3(-0.08, 0.78, -0.12), Vector3(0.42, 0.22, 0.28), rust)
	_box(root, Vector3(-0.48, 1.42, 0.02), Vector3(0.2, 0.95, 0.2), plate)
	_box(root, Vector3(-0.62, 0.95, 0.18), Vector3(0.14, 0.55, 0.14), rust)
	# Missing right shoulder — stump + hanging scavenged limb
	_box(root, Vector3(0.38, 1.28, 0.05), Vector3(0.28, 0.22, 0.28), rust)
	_box(root, Vector3(0.55, 0.72, 0.22), Vector3(0.16, 1.05, 0.16), plate)
	_box(root, Vector3(0.68, 0.22, 0.35), Vector3(0.14, 0.35, 0.35), paint_mat(Color(0.2, 0.22, 0.16)))
	# Uneven legs
	_box(root, Vector3(-0.16, 0.42, 0.02), Vector3(0.18, 0.78, 0.18), plate)
	_box(root, Vector3(0.2, 0.35, 0.06), Vector3(0.16, 0.62, 0.16), rust)
	add_sphere(root, Vector3(0.02, 1.68, 0.02), 0.22, flesh_mat(Color(0.38, 0.52, 0.28), 0.9), Vector3(1.05, 0.8, 0.95))
	var shard := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.28, 0.42, 0.2)
	prism.material = emit_surface(PALE, 4.2)
	shard.mesh = prism
	shard.position = Vector3(0.05, 1.15, 0.28)
	shard.rotation_degrees = Vector3(12, 18, -8)
	root.add_child(shard)
	var vis := MeshInstance3D.new()
	var vmesh := BoxMesh.new()
	vmesh.size = Vector3(0.32, 0.07, 0.06)
	vmesh.material = visor_mat(PALE)
	vis.mesh = vmesh
	vis.position = Vector3(0.02, 1.7, 0.22)
	root.add_child(vis)
	# Broken antenna / horn
	var horn := MeshInstance3D.new()
	var hmesh := CylinderMesh.new()
	hmesh.top_radius = 0.02
	hmesh.bottom_radius = 0.05
	hmesh.height = 0.55
	hmesh.material = emit_surface(Color(0.45, 1.0, 0.35), 2.4)
	horn.mesh = hmesh
	horn.position = Vector3(-0.12, 2.05, -0.05)
	horn.rotation_degrees = Vector3(25, 0, -35)
	root.add_child(horn)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.2, 0.25)
	light.light_color = PALE
	light.light_energy = 2.5
	light.omni_range = 5.5
	root.add_child(light)
	sparkle(root, Vector3(0.05, 1.2, 0.3), Color(0.55, 1.0, 0.4, 0.65), 0.4)
	var tag := Label3D.new()
	tag.text = "FERAL HUSK"
	tag.position = Vector3(0, 2.35, 0)
	tag.font_size = 30
	tag.modulate = Color(0.7, 0.95, 0.45)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 6
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	root.add_child(tag)


static func dress_dais(dais: Node3D) -> void:
	if dais == null or dais.get_node_or_null("LookDais") != null:
		return
	var root := Node3D.new()
	root.name = "LookDais"
	dais.add_child(root)
	add_cyl(root, Vector3(0, 0.08, 0), 0.12, 1.35, Color(0.16, 0.18, 0.16), Vector3.ZERO, 0.5)
	var crystal := MeshInstance3D.new()
	crystal.name = "ShardCrystal"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.42, 0.85, 0.42)
	prism.material = emit_surface(PALE, 3.4)
	crystal.mesh = prism
	crystal.position = Vector3(0, 1.35, 0)
	root.add_child(crystal)
	var light := OmniLight3D.new()
	light.name = "ShardLight"
	light.position = Vector3(0, 1.5, 0)
	light.light_color = PALE
	light.light_energy = 4.2
	light.omni_range = 10.0
	light.light_volumetric_fog_energy = 2.0
	root.add_child(light)
	sparkle(root, Vector3(0, 1.4, 0), Color(0.55, 1.0, 0.4, 0.8), 0.55)


static func dress_extract(zone: Node3D, color: Color) -> void:
	if zone == null:
		return
	if zone.has_node("Pad"):
		(zone.get_node("Pad") as MeshInstance3D).material_override = emit_surface(color, 1.8)
	if zone.has_node("Beacon"):
		var bmat := emit_surface(color, 2.8, 0.42)
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(zone.get_node("Beacon") as MeshInstance3D).material_override = bmat
	if zone.get_node_or_null("LookRing") == null:
		var p := GPUParticles3D.new()
		p.name = "LookRing"
		p.amount = 28
		p.lifetime = 2.2
		p.preprocess = 1.0
		p.position = Vector3(0, 0.4, 0)
		p.visibility_aabb = AABB(Vector3(-7, -1, -7), Vector3(14, 8, 14))
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_radius = 4.6
		pm.emission_ring_inner_radius = 4.2
		pm.emission_ring_height = 0.1
		pm.emission_ring_axis = Vector3(0, 1, 0)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 8.0
		pm.initial_velocity_min = 0.15
		pm.initial_velocity_max = 0.55
		pm.gravity = Vector3(0, 0.4, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.3
		pm.color = Color(color.r, color.g, color.b, 0.7)
		p.process_material = pm
		p.draw_pass_1 = particle_draw(Vector2(0.12, 0.18), color, true)
		zone.add_child(p)


static func tune_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	cam.far = 520.0
	cam.near = maxf(cam.near, 0.05)
	var attr := CameraAttributesPractical.new()
	attr.exposure_multiplier = 1.02
	attr.dof_blur_far_enabled = Settings.is_high()
	attr.dof_blur_far_distance = 95.0
	attr.dof_blur_far_transition = 55.0
	attr.dof_blur_amount = 0.07
	cam.attributes = attr


static func call_tune_cameras(world: Node) -> void:
	_tune_cams_recursive(world)


static func _tune_cams_recursive(n: Node) -> void:
	if n is Camera3D:
		tune_camera(n as Camera3D)
	for c in n.get_children():
		_tune_cams_recursive(c)


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.055, 0.05, 0.045, 0.94)
	s.border_color = Color(0.86, 0.46, 0.12, 1)
	s.set_border_width_all(2)
	s.set_corner_radius_all(2)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 10
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.border_blend = true
	return s


static func bar_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.07, 0.85)
	s.set_corner_radius_all(2)
	s.set_border_width_all(1)
	s.border_color = Color(0.25, 0.18, 0.1)
	return s


static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	return s


static func ui_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("panel", "PanelContainer", panel_style())
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.16, 0.1, 0.06, 1)
	btn.border_color = Color(0.85, 0.45, 0.12)
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(2)
	btn.content_margin_left = 10
	btn.content_margin_right = 10
	btn.content_margin_top = 6
	btn.content_margin_bottom = 6
	var btn_h := btn.duplicate() as StyleBoxFlat
	btn_h.bg_color = Color(0.32, 0.16, 0.06, 1)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_h)
	t.set_stylebox("pressed", "Button", btn_h)
	t.set_color("font_color", "Button", Color(0.95, 0.84, 0.62))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.7))
	t.set_color("font_color", "Label", Color(0.86, 0.8, 0.7))
	t.set_stylebox("background", "ProgressBar", bar_bg())
	t.set_stylebox("fill", "ProgressBar", bar_fill(Color(0.9, 0.45, 0.12)))
	return t


static func outline_label(lab: Label, color: Color) -> void:
	if lab == null:
		return
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.88))
	lab.add_theme_constant_override("outline_size", 5)


static func attach_hud_chrome(hud: Node) -> void:
	var cross := hud.get_node_or_null("Crosshair") as ColorRect
	if cross:
		cross.color = Color(0, 0, 0, 0)
		cross.offset_left = -22
		cross.offset_top = -22
		cross.offset_right = 22
		cross.offset_bottom = 22
		_tick(cross, Vector2(4, 21), Vector2(10, 2))
		_tick(cross, Vector2(30, 21), Vector2(10, 2))
		_tick(cross, Vector2(21, 4), Vector2(2, 10))
		_tick(cross, Vector2(21, 30), Vector2(2, 10))
		_tick(cross, Vector2(20.5, 20.5), Vector2(3, 3), Color(1.0, 0.82, 0.4, 0.95))
	for name in ["ObjectiveLabel", "HealthLabel", "CarryLabel", "PromptLabel", "BannerLabel"]:
		var lab := hud.get_node_or_null(name) as Label
		if lab:
			var col := lab.get_theme_color("font_color")
			outline_label(lab, col)
	var theme := ui_theme()
	for child in hud.get_children():
		if child is Control:
			(child as Control).theme = theme
	_helmet_frame(hud)


static func _tick(parent: Control, pos: Vector2, size: Vector2, color: Color = Color(0.95, 0.82, 0.45, 0.9)) -> void:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = color
	r.position = pos
	r.size = size
	parent.add_child(r)


static func _helmet_frame(hud: Node) -> void:
	if hud.get_node_or_null("HelmetFrame") != null:
		return
	var root := Control.new()
	root.name = "HelmetFrame"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	hud.move_child(root, 0)
	var col := Color(0.95, 0.72, 0.32, 0.35)
	_corner(root, Vector2(18, 14), 1, 1, col)
	_corner(root, Vector2(-18, 14), -1, 1, col)
	_corner(root, Vector2(18, -14), 1, -1, col)
	_corner(root, Vector2(-18, -14), -1, -1, col)


static func _corner(root: Control, inset: Vector2, sx: int, sy: int, color: Color) -> void:
	var a := ColorRect.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.color = color
	a.set_anchors_preset(Control.PRESET_TOP_LEFT if sy > 0 else Control.PRESET_BOTTOM_LEFT)
	if sx < 0:
		a.set_anchors_preset(Control.PRESET_TOP_RIGHT if sy > 0 else Control.PRESET_BOTTOM_RIGHT)
	a.offset_left = inset.x if sx > 0 else inset.x - 28
	a.offset_right = (inset.x + 28) if sx > 0 else inset.x
	a.offset_top = inset.y if sy > 0 else inset.y - 3
	a.offset_bottom = (inset.y + 3) if sy > 0 else inset.y
	if sy < 0:
		a.anchor_top = 1.0
		a.anchor_bottom = 1.0
	if sx < 0:
		a.anchor_left = 1.0
		a.anchor_right = 1.0
	root.add_child(a)
	var b := ColorRect.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.color = color
	b.anchor_left = a.anchor_left
	b.anchor_right = a.anchor_right
	b.anchor_top = a.anchor_top
	b.anchor_bottom = a.anchor_bottom
	if sx > 0:
		b.offset_left = inset.x
		b.offset_right = inset.x + 3
	else:
		b.offset_left = inset.x - 3
		b.offset_right = inset.x
	if sy > 0:
		b.offset_top = inset.y
		b.offset_bottom = inset.y + 22
	else:
		b.offset_top = inset.y - 22
		b.offset_bottom = inset.y
	root.add_child(b)


static func mount_title_world(host: Control) -> Node3D:
	var wrap := SubViewportContainer.new()
	wrap.name = "TitleWorld"
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.stretch = true
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(wrap)
	host.move_child(wrap, 0)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Settings.apply_viewport(vp)
	wrap.add_child(vp)
	var world := Node3D.new()
	world.name = "Stage"
	vp.add_child(world)
	world.set_meta("look_kind", KIND_TITLE)
	var we := WorldEnvironment.new()
	we.environment = make_env(KIND_TITLE)
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 38, 0)
	sun.light_color = Color(1.0, 0.52, 0.24)
	sun.light_energy = 1.85
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.1
	sun.light_volumetric_fog_energy = 2.4
	world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-6, 8, 8)
	fill.light_color = PALE
	fill.light_energy = 3.6
	fill.omni_range = 24.0
	fill.light_volumetric_fog_energy = 1.8
	world.add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(80, 0.4, 80)
	plane.material = surface(Color(0.16, 0.12, 0.09), 0.0, 0.55, 0.1, 0.28, 7.0)
	floor.mesh = plane
	floor.position.y = -0.2
	world.add_child(floor)
	_ground_skin(world, Vector2(78, 78), Color(0.16, 0.12, 0.09), 0.55, 0.22)
	dust(world, Vector3(20, 6, 16), Color(0.75, 0.5, 0.22, 0.25), 90)
	dust(world, Vector3(14, 8, 12), Color(0.5, 0.9, 0.3, 0.12), 40)
	_haze_card(world, Vector3(0, 10, -22), Vector2(80, 26), Color(0.7, 0.32, 0.08, 0.26), 0)
	_haze_card(world, Vector3(0, 12, -20), Vector2(50, 16), Color(0.45, 0.85, 0.28, 0.16), 0)
	occupation_walker(world, Vector3(18, 0, -16), 210.0, 0.55)
	_add_fog(world, Vector3(4, 8, -18), Vector3(40, 16, 14), Color(0.5, 0.35, 0.12), PALE, 0.08)
	_add_puddle(world, Vector3(2.5, 0.02, 3.0), Vector2(6.0, 3.4))
	var showcase := _showcase_mech(world)
	var cam := Camera3D.new()
	cam.position = Vector3(9.5, 5.6, 11.5)
	cam.fov = 42.0
	cam.current = true
	tune_camera(cam)
	world.add_child(cam)
	cam.look_at(Vector3(0, 3.8, 0))
	Settings.apply()
	return showcase


static func _showcase_mech(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ShowcaseMech"
	parent.add_child(root)
	var rust := paint_mat(Color(0.5, 0.26, 0.1))
	var dark := paint_mat(Color(0.14, 0.14, 0.16))
	_box(root, Vector3(0, 5.2, 0), Vector3(2.8, 3.2, 2.4), rust)
	_box(root, Vector3(0, 7.15, 0.35), Vector3(1.35, 1.05, 1.25), dark)
	_box(root, Vector3(0, 7.2, 1.02), Vector3(0.9, 0.28, 0.15), visor_mat(AMBER))
	_box(root, Vector3(-0.85, 1.8, 0), Vector3(0.7, 3.6, 0.85), dark)
	_box(root, Vector3(0.85, 1.8, 0), Vector3(0.7, 3.6, 0.85), dark)
	_box(root, Vector3(-1.9, 5.3, 0.15), Vector3(0.55, 2.5, 0.55), rust)
	_box(root, Vector3(1.9, 5.3, 0.15), Vector3(0.55, 2.5, 0.55), rust)
	_box(root, Vector3(2.25, 5.55, 0.2), Vector3(0.45, 0.8, 0.45), emit_surface(Color(1.0, 0.45, 0.1), 2.0))
	_box(root, Vector3(-1.05, 0.28, 0.35), Vector3(1.15, 0.22, 1.45), dark)
	_box(root, Vector3(1.05, 0.28, 0.35), Vector3(1.15, 0.22, 1.45), dark)
	_box(root, Vector3(-1.15, 6.15, 0.05), Vector3(1.05, 0.42, 1.35), rust)
	_box(root, Vector3(1.15, 6.15, 0.05), Vector3(1.05, 0.42, 1.35), rust)
	_box(root, Vector3(0, 5.35, -1.35), Vector3(1.4, 0.9, 0.55), dark)
	add_cyl(root, Vector3(-0.35, 4.6, -1.45), 1.1, 0.12, Color(0.18, 0.18, 0.2), Vector3.ZERO, 1.6)
	add_cyl(root, Vector3(0.35, 4.6, -1.45), 1.1, 0.12, Color(0.18, 0.18, 0.2), Vector3.ZERO, 1.6)
	add_cyl(root, Vector3(0.18, 7.85, -0.15), 0.7, 0.04, AMBER, Vector3(18, 0, -12), 1.4)
	var wreck := Node3D.new()
	wreck.position = Vector3(-7, 0, -4)
	wreck.rotation_degrees = Vector3(0, 35, 12)
	parent.add_child(wreck)
	_box(wreck, Vector3(0, 1.2, 0), Vector3(5.2, 2.0, 3.2), paint_mat(Color(0.1, 0.1, 0.1)))
	var alien := Node3D.new()
	alien.position = Vector3(6.8, 0, -2.4)
	alien.rotation_degrees.y = -40.0
	parent.add_child(alien)
	dress_pale_host(alien)
	pale_growth(parent, Vector3(4.5, 0, -8), 3)
	return root


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	parent.add_child(mi)


static func _add_fog(parent: Node3D, pos: Vector3, size: Vector3, albedo: Color, emission: Color, density: float) -> void:
	var fv := FogVolume.new()
	fv.size = size
	fv.position = pos
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = albedo
	fm.emission = emission
	fm.height_falloff = 0.45
	fm.edge_fade = 0.4
	fv.material = fm
	parent.add_child(fv)


static func _add_puddle(parent: Node3D, pos: Vector3, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.018, size.y)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.07)
	m.metallic = 0.88
	m.roughness = 0.07
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.4, 0.4, 0.4)
	m.albedo_texture = TEX_RUST
	box.material = m
	mi.mesh = box
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _ground_skin(parent: Node3D, size: Vector2, color: Color, rust_amt: float, wet: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "LookTerrain"
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 36
	plane.subdivide_depth = 28
	var mat := surface(color, 0.0, rust_amt, 0.08, wet, 8.0)
	mat.set_shader_parameter("displace", 0.2)
	plane.material = mat
	mi.mesh = plane
	mi.position.y = 0.03
	parent.add_child(mi)


static func occupation_walker(parent: Node3D, pos: Vector3, yaw: float, s: float = 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	parent.add_child(root)
	var rust := surface(Color(0.24, 0.16, 0.1), 0.0, 0.58, 0.22)
	var dark := surface(Color(0.1, 0.1, 0.11), 0.0, 0.28, 0.4)
	_box(root, Vector3(0, 14.2 * s, 0), Vector3(8.2 * s, 6.8 * s, 10.4 * s), rust)
	_box(root, Vector3(0, 18.8 * s, 2.4 * s), Vector3(4.6 * s, 3.4 * s, 5.0 * s), dark)
	_box(root, Vector3(0, 18.9 * s, 5.0 * s), Vector3(2.9 * s, 0.42 * s, 0.22 * s), emit_surface(PALE, 2.6))
	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if (i % 2) == 0 else 1.0
		var hip := Vector3(sx * 3.3 * s, 11.2 * s, sz * 3.7 * s)
		_box(root, hip + Vector3(sx * 1.5 * s, -4.6 * s, sz * 1.1 * s), Vector3(1.35 * s, 9.2 * s, 1.35 * s), dark)
		_box(root, hip + Vector3(sx * 2.3 * s, -9.3 * s, sz * 1.9 * s), Vector3(2.5 * s, 0.72 * s, 3.3 * s), rust)


static func kneeling_frame(parent: Node3D, pos: Vector3, yaw: float, s: float = 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	parent.add_child(root)
	var rust := surface(Color(0.42, 0.24, 0.1), 0.0, 0.4, 0.45)
	var dark := surface(Color(0.14, 0.14, 0.15), 0.0, 0.2, 0.5)
	_box(root, Vector3(0, 3.4 * s, 0.6 * s), Vector3(3.4 * s, 2.6 * s, 4.2 * s), rust)
	_box(root, Vector3(0, 5.2 * s, 1.4 * s), Vector3(1.7 * s, 1.2 * s, 1.8 * s), dark)
	_box(root, Vector3(0, 5.25 * s, 2.35 * s), Vector3(1.1 * s, 0.28 * s, 0.16 * s), visor_mat(AMBER))
	_box(root, Vector3(-1.05 * s, 1.1 * s, 1.6 * s), Vector3(0.85 * s, 2.2 * s, 1.4 * s), dark)
	_box(root, Vector3(1.05 * s, 1.1 * s, 1.6 * s), Vector3(0.85 * s, 2.2 * s, 1.4 * s), dark)
	_box(root, Vector3(-1.9 * s, 3.6 * s, 0.4 * s), Vector3(0.7 * s, 2.4 * s, 0.7 * s), rust)
	_box(root, Vector3(2.1 * s, 2.2 * s, 1.8 * s), Vector3(0.55 * s, 0.55 * s, 2.8 * s), rust)


static func dress_wreck(host: Node3D) -> void:
	if host == null:
		return
	for name in ["Hull", "Limb", "Limb2"]:
		var mi := host.get_node_or_null(name) as MeshInstance3D
		if mi:
			mi.material_override = surface(Color(0.14, 0.11, 0.09), 0.0, 0.72, 0.16, 0.08, 3.5)
	add_cyl(host, Vector3(0.8, 2.4, -0.4), 1.8, 0.05, Color(0.12, 0.12, 0.12), Vector3(18, 0, 22))
	add_cyl(host, Vector3(-0.6, 2.1, 0.5), 1.4, 0.04, Color(0.1, 0.1, 0.1), Vector3(-12, 0, -30))
	_add_fog(host, Vector3(0.2, 1.6, 0.3), Vector3(3.2, 2.4, 3.2), Color(0.2, 0.16, 0.12), Color(0.4, 0.16, 0.04), 0.08)


static func dress_machine(host: Node3D, scale_id: String, paint: Color) -> void:
	if host == null:
		return
	var old := host.get_node_or_null("LookGreeble")
	if old:
		old.free()
	var body := host.get_node_or_null("Body") as Node3D
	if body:
		var old_b := body.get_node_or_null("LookGreeble")
		if old_b:
			old_b.free()
	var root := Node3D.new()
	root.name = "LookGreeble"
	var upper := root
	if body:
		host.add_child(root)
		upper = Node3D.new()
		upper.name = "LookGreeble"
		body.add_child(upper)
	else:
		host.add_child(root)
		upper = root
	var h := float(host.get("cockpit_height")) if host.get("cockpit_height") != null else 7.4
	var s := clampf(h / 7.4, 0.35, 3.4)
	var plate := surface(paint.darkened(0.1), 0.0, 0.2, 0.58, 0.04, 1.8)
	var dark := surface(paint.darkened(0.42), 0.0, 0.14, 0.68, 0.0, 1.6)
	if scale_id == "vehicle":
		_box(root, Vector3(-1.55, 0.35, 2.4), Vector3(0.55, 0.7, 1.1), dark)
		_box(root, Vector3(1.55, 0.35, 2.4), Vector3(0.55, 0.7, 1.1), dark)
		_box(root, Vector3(-1.55, 0.35, -2.6), Vector3(0.55, 0.7, 1.1), dark)
		_box(root, Vector3(1.55, 0.35, -2.6), Vector3(0.55, 0.7, 1.1), dark)
		_box(root, Vector3(0, 1.15, 3.55), Vector3(2.4, 0.22, 0.28), plate)
		_box(root, Vector3(0, 2.55, 2.55), Vector3(1.6, 0.12, 0.9), dark)
		add_cyl(root, Vector3(0, 2.2, -3.6), 1.4, 0.35, Color(0.22, 0.2, 0.16), Vector3(90, 0, 0), 0.0)
		return
	_box(upper, Vector3(-1.55 * s, h * 0.08 if body else h * 0.74, 0.12 * s), Vector3(1.05 * s, 0.48 * s, 1.35 * s), plate)
	_box(upper, Vector3(1.55 * s, h * 0.08 if body else h * 0.74, 0.12 * s), Vector3(1.05 * s, 0.48 * s, 1.35 * s), plate)
	if not body:
		_box(upper, Vector3(0, h * 0.72, -1.15 * s), Vector3(1.55 * s, 1.05 * s, 0.55 * s), dark)
		add_cyl(upper, Vector3(-0.38 * s, h * 0.62, -1.35 * s), 0.85 * s, 0.11 * s, Color(0.16, 0.16, 0.18), Vector3.ZERO, 1.5)
		add_cyl(upper, Vector3(0.38 * s, h * 0.62, -1.35 * s), 0.85 * s, 0.11 * s, Color(0.16, 0.16, 0.18), Vector3.ZERO, 1.5)
		add_cyl(upper, Vector3(0.22 * s, h + 0.35 * s, -0.1 * s), 0.55 * s, 0.035 * s, AMBER, Vector3(16, 0, -14), 1.3)
		_box(root, Vector3(-0.95 * s, 0.22 * s, 0.35 * s), Vector3(1.15 * s, 0.22 * s, 1.45 * s), dark)
		_box(root, Vector3(0.95 * s, 0.22 * s, 0.35 * s), Vector3(1.15 * s, 0.22 * s, 1.45 * s), dark)
		add_cyl(root, Vector3(-0.85 * s, h * 0.28, 0.05 * s), 0.7 * s, 0.1 * s, paint.darkened(0.3), Vector3(0, 0, 8), 0.0)
		add_cyl(root, Vector3(0.85 * s, h * 0.28, 0.05 * s), 0.7 * s, 0.1 * s, paint.darkened(0.3), Vector3(0, 0, -8), 0.0)
		_box(upper, Vector3(0, h * 0.68, 1.15 * s), Vector3(1.7 * s, 0.12 * s, 0.18 * s), dark)
		_box(upper, Vector3(0, h * 0.62, 1.15 * s), Vector3(1.7 * s, 0.12 * s, 0.18 * s), dark)
	else:
		_box(upper, Vector3(0, 0.2 * s, -3.4 * s), Vector3(3.6 * s, 2.2 * s, 1.2 * s), dark)
		add_cyl(upper, Vector3(-1.1 * s, -1.2 * s, -3.6 * s), 2.4 * s, 0.28 * s, Color(0.16, 0.16, 0.18), Vector3.ZERO, 1.8)
		add_cyl(upper, Vector3(1.1 * s, -1.2 * s, -3.6 * s), 2.4 * s, 0.28 * s, Color(0.16, 0.16, 0.18), Vector3.ZERO, 1.8)
		_box(root, Vector3(-2.4 * s, 0.45 * s, 1.1 * s), Vector3(2.6 * s, 0.45 * s, 3.4 * s), dark)
		_box(root, Vector3(2.4 * s, 0.45 * s, 1.1 * s), Vector3(2.6 * s, 0.45 * s, 3.4 * s), dark)


static func impact(parent: Node, pos: Vector3, color: Color) -> void:
	if parent == null:
		return
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 4.2
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.9
	pm.color = Color(color.r, color.g, color.b, 0.9)
	p.process_material = pm
	p.draw_pass_1 = particle_draw(Vector2(0.07, 0.07), color, true)
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	parent.add_child(p)
	if p is Node3D:
		(p as Node3D).global_position = pos
	p.emitting = true
	if parent.get_tree():
		parent.get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.queue_free()
		)
