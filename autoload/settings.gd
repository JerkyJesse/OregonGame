extends Node

const LOOK := preload("res://world/WorldLook.gd")
const PATH := "user://settings.cfg"
const LEVELS: Array[String] = ["low", "medium", "high"]

var quality: String = "high"


func _ready() -> void:
	load_settings()
	apply()


func button_label() -> String:
	return "QUALITY  %s" % quality.to_upper()


func cycle() -> void:
	var i := LEVELS.find(quality)
	if i < 0:
		i = 2
	quality = LEVELS[(i + 1) % LEVELS.size()]
	save_settings()
	apply()


func is_low() -> bool:
	return quality == "low"


func is_high() -> bool:
	return quality == "high"


func dust_scale() -> float:
	match quality:
		"low":
			return 0.28
		"medium":
			return 0.55
		_:
			return 1.0


func grain_scale() -> float:
	match quality:
		"low":
			return 0.45
		"medium":
			return 0.75
		_:
			return 1.0


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var q := str(cfg.get_value("graphics", "quality", quality)).to_lower()
	if q in LEVELS:
		quality = q


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.save(PATH)


func apply() -> void:
	_apply_server()
	var tree := get_tree()
	if tree == null:
		return
	_apply_tree(tree.root)


func apply_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	match quality:
		"low":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_debanding = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.72
		"medium":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_debanding = true
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.88
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_debanding = true
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0


func _apply_server() -> void:
	match quality:
		"low":
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50, 300)
			RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 2, 50, 300)
			RenderingServer.environment_set_ssr_roughness_quality(RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED)
			RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
			RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_8)
		"medium":
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
			RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
			RenderingServer.environment_set_ssr_roughness_quality(RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW)
			RenderingServer.environment_set_volumetric_fog_volume_size(96, 96)
			RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_16)
		_:
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, false, 0.5, 2, 50, 300)
			RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH, true, 0.5, 2, 50, 300)
			RenderingServer.environment_set_ssr_roughness_quality(RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH)
			RenderingServer.environment_set_volumetric_fog_volume_size(160, 128)
			RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_32)


func _apply_tree(n: Node) -> void:
	if n is Viewport:
		apply_viewport(n as Viewport)
	if n is WorldEnvironment:
		var we := n as WorldEnvironment
		var kind := "yard"
		var host := we.get_parent()
		if host and host.has_meta("look_kind"):
			kind = str(host.get_meta("look_kind"))
		LOOK.retune_environment(we.environment, kind)
	if n is FogVolume:
		(n as FogVolume).visible = not is_low()
	if n is Camera3D:
		LOOK.tune_camera(n as Camera3D)
	if n is DirectionalLight3D:
		_style_sun(n as DirectionalLight3D)
	if n is MeshInstance3D:
		_haze_vis(n as MeshInstance3D)
	if n is CanvasLayer and n.name == "LookAtmo":
		_grade_grain(n as CanvasLayer)
	for c in n.get_children():
		_apply_tree(c)


func _style_sun(sun: DirectionalLight3D) -> void:
	match quality:
		"low":
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.shadow_blur = 1.0
		"medium":
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.shadow_blur = 1.25
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.shadow_blur = 1.55


func _haze_vis(mi: MeshInstance3D) -> void:
	var mat := mi.material_override
	if mat == null and mi.mesh:
		mat = mi.mesh.surface_get_material(0)
	if not (mat is ShaderMaterial):
		return
	var sh := (mat as ShaderMaterial).shader
	if sh and str(sh.resource_path).ends_with("haze_card.gdshader"):
		mi.visible = not is_low()


func _grade_grain(layer: CanvasLayer) -> void:
	var rect := layer.get_node_or_null("Grade") as ColorRect
	if rect == null or not (rect.material is ShaderMaterial):
		return
	var mat := rect.material as ShaderMaterial
	var base := 0.04
	if mat.has_meta("base_grain"):
		base = float(mat.get_meta("base_grain"))
	else:
		var g: Variant = mat.get_shader_parameter("grain")
		base = float(g) if g != null else 0.04
		mat.set_meta("base_grain", base)
	mat.set_shader_parameter("grain", base * grain_scale())
