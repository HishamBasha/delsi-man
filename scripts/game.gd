extends Node3D
const Runner = preload("res://scripts/runner.gd")
const Course = preload("res://scripts/course.gd")
const Art = preload("res://scripts/art.gd")
const Profile = preload("res://scripts/profile.gd")
const City = preload("res://scripts/city.gd")
const Hero = preload("res://scripts/hero.gd")
const MainMenu = preload("res://scripts/main_menu.gd")
const Fx = preload("res://scripts/fx.gd")
const SKY_SHADER = preload("res://shaders/sky_grade.gdshader")
const GRADE_SHADER = preload("res://shaders/color_grade.gdshader")
var flavors: Array = []
var level: Dictionary
var profile: Dictionary
var runner: Node3D
var course: Node3D
var camera: Camera3D
var hero: Dictionary
var hud: Control
var menu: PanelContainer
var main_menu
var fx
var bottle_counter: Label
var timer_label: Label
var tries_root: HBoxContainer
var try_nodes: Array[Panel] = []
var tries_indicator: Panel
var path_panel: PanelContainer
var path_track: Control
var path_marker: ColorRect
var checkpoint_dots: Array[ColorRect] = []
var checkpoint_markers: Array[Node3D] = []
var bottle_pickups: Array[Dictionary] = []
var bottle_bump := 0.0
var action_button: Button
var menu_title: Label
var menu_copy: Label
var lang_button: Button
var assist_button: Button
var pause_button: Button
var score := 0
var bottles := 0
var hits := 0
var combo := 0
var cold := 100.0
var elapsed := 0.0
var checkpoint := 0.0
var section := -1
var state := "menu"
var claimed: Dictionary = {}
var phase := 0.0
var lang := "en"
var assist := false
var audio: AudioStreamPlayer
var synth: AudioStreamGeneratorPlayback
var note_left := 0.0
var note_hz := 440.0
var note_queue: Array = []
var lollipop_pops: Array[float] = []
var oscillator := 0.0
var cart: Node3D
var chase_train: Node3D
var testing := false
var touch_left := false
var touch_right := false
var tries_left := 3
var tries_charge := 0.0
var bottle_charge := 0
var barrel_left := 0.0
var barrel_node: Node3D
const BARREL_DURATION := 4.2
var cam_shake := 0.0
var sprint_left := 0.0
var sprint_cd := 0.0
var sprint_held := false
const SPRINT_TIME := 2.0
const SPRINT_COOLDOWN := 0.6
const SPRINT_BOOST := 1.4
const STEER_YAW := 0.38
const STEER_ROLL := 0.1

func _exit_tree() -> void:
	if audio != null:
		audio.stop()
	synth = null

func _ready() -> void:
	testing = "--test" in OS.get_cmdline_user_args()
	flavors = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavors.json"))
	level = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_01.json"))
	profile = Profile.read()
	lang = profile.get("language", "en")
	assist = profile.get("assist", false)
	setup_inputs()
	setup_world()
	setup_ui()
	show_menu(false)
	if testing:
		call_deferred("run_tests")

func setup_inputs() -> void:
	var map = {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_W, KEY_UP], "slide": [KEY_S, KEY_DOWN], "pause": [KEY_ESCAPE, KEY_P], "retry": [KEY_R], "sprint": [KEY_E]}
	for action in map:
		InputMap.add_action(action)
		for code in map[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	var pads = {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "jump": JOY_BUTTON_A, "slide": JOY_BUTTON_B, "pause": JOY_BUTTON_START, "sprint": JOY_BUTTON_Y}
	for action in pads:
		var event = InputEventJoypadButton.new()
		event.button_index = pads[action]
		InputMap.action_add_event(action, event)

func load_authored_course(scene_path: String) -> Node3D:
	if scene_path.is_empty():
		return null
	var level_scene = load(scene_path)
	if level_scene == null:
		push_warning("Level scene not found: " + scene_path)
		return null
	var candidate = level_scene.instantiate()
	add_child(candidate)
	if candidate.has_method("load_from_scene"):
		candidate.load_from_scene(candidate)
		if bool(candidate.get("use_in_game")) and not candidate.objects.is_empty():
			return candidate
	print("INFO: %s is not enabled for play or has no entities; using generated free-steering course." % scene_path)
	remove_child(candidate)
	candidate.queue_free()
	return null

## Background sky: every skybox in `assets/Skyboxes/` is a 4096x2048
## equirectangular panorama, so it drops straight into a PanoramaSkyMaterial.
## The level JSON can override the choice with "sky"; when the file cannot be
## loaded the flat colour background set above is kept.
const DEFAULT_SKY := "res://assets/Skyboxes/skybox-space-day.png"

func apply_sky(settings: Environment) -> void:
	var path := str(level.get("sky", DEFAULT_SKY))
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if texture == null:
		push_warning("sky panorama not found: " + path)
		return
	var sky := Sky.new()
	# The panorama goes through a sky shader instead of PanoramaSkyMaterial so
	# its violet cast can be pulled to daylight blue (shaders/sky_grade).
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("panorama", texture)
	sky.sky_material = material
	settings.sky = sky
	settings.background_mode = Environment.BG_SKY
	# Fog is full strength on background pixels, which would wash the panorama
	# back to grey, and its colour still belongs to the road: keep most of the
	# sky clear and pull the fog a little toward the horizon it now sits behind.
	# It leans blue to sit with the regraded sky instead of the old violet.
	settings.fog_sky_affect = 0.12
	settings.fog_light_color = Color("859eaa").lerp(Color("3f7fd0"), 0.35)

func setup_world() -> void:
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("708f9d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c3d8e6")
	settings.ambient_light_energy = 0.8
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.fog_enabled = true
	settings.fog_light_color = Color("859eaa")
	settings.fog_density = 0.004
	apply_sky(settings)
	env.environment = settings
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ffddaa")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var scene_path = str(level.get("scene", "res://scenes/levels/manual_sample_level.tscn"))
	course = load_authored_course(scene_path)
	if course == null:
		course = Course.new()
		add_child(course)
		course.build(flavors)
	for i in range(level.sections.size()):
		var sec = level.sections[i]
		var flavor_index = int(sec.get("flavor", i)) % maxi(1, flavors.size())
		var checkpoint = spawn_lollipop_checkpoint(course, float(sec.start), Color(flavors[flavor_index].color))
		checkpoint_markers.append(checkpoint)
		lollipop_pops.append(-1.0)
	runner = Runner.new()
	add_child(runner)
	hero = Hero.create(runner)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 68
	camera.far = 220
	camera.position = Vector3(0, 1.2, -6)
	camera.look_at(Vector3(0, 1.5, -2))
	chase_train = Node3D.new()
	add_child(chase_train)
	for i in range(3):
		Art.box(chase_train, Vector3(0, 0.65, i * 3), Vector3(2, 0.5, 2.7), Color("d6e8e8"))
		Art.box(chase_train, Vector3(0, 1.5, i * 3), Vector3(1.6, 1.3, 2.1), Color(flavors[i].color))
		Art.label(chase_train, Vector3(0, 1.5, i * 3 - 1.1), "DELSI", Color.WHITE, 40)
	chase_train.visible = false
	barrel_node = City.barrel(self, Vector3.ZERO, Color("b7653f"))
	barrel_node.visible = false
	audio = AudioStreamPlayer.new()
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = 0.1
	audio.stream = stream
	audio.volume_db = -18
	add_child(audio)
	if DisplayServer.get_name() != "headless":
		audio.play()
		synth = audio.get_stream_playback()
	setup_post_fx()

## Screen grade over the 3D view: bloom, exposure, contrast, colour
## temperature, saturation and a vignette (shaders/color_grade). It lives on
## canvas layer 1, the HUD on layer 2, so the world is graded and the interface
## is not. mouse_filter is ignored so gameplay input passes straight through.
func setup_post_fx() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material = ShaderMaterial.new()
	material.shader = GRADE_SHADER
	rect.material = material
	layer.add_child(rect)

func hud_box(bg_color: Color, edge: Color, radius: int = 12, border: int = 3) -> StyleBoxFlat:
	var panel = StyleBoxFlat.new()
	panel.bg_color = bg_color
	panel.border_color = edge
	panel.border_width_left = border
	panel.border_width_right = border
	panel.border_width_top = border
	panel.border_width_bottom = border
	panel.corner_radius_top_left = radius
	panel.corner_radius_top_right = radius
	panel.corner_radius_bottom_left = radius
	panel.corner_radius_bottom_right = radius
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	return panel

func outlined_label(text_value: String, size: int, color: Color, outline: Color, outline_size: int) -> Label:
	var n = label(text_value, size, color)
	n.add_theme_color_override("font_outline_color", outline)
	n.add_theme_constant_override("outline_size", outline_size)
	return n

func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var n = Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	return n

func bar_spacer() -> Control:
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return spacer

func button(text: String, fn: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(80, 45)
	b.pressed.connect(fn)
	return b

func steer_button(text: String, direction: int) -> Button:
	var action = "left" if direction < 0 else "right"
	var b = button(text, func(): act(action))
	b.button_down.connect(func(): set_touch_steer(direction, true))
	b.button_up.connect(func(): set_touch_steer(direction, false))
	return b

func set_touch_steer(direction: int, pressed: bool) -> void:
	if direction < 0:
		touch_left = pressed
	else:
		touch_right = pressed

func steering_axis() -> float:
	var axis = Input.get_axis("left", "right")
	if touch_left:
		axis -= 1.0
	if touch_right:
		axis += 1.0
	if barrel_left > 0.0:
		axis = -axis
	return clampf(axis, -1.0, 1.0)

func spawn_lollipop_checkpoint(parent: Node3D, at: float, color: Color) -> Node3D:
	var marker = Node3D.new()
	parent.add_child(marker)
	var cx = course.center_at(at) if course.has_method("center_at") else 0.0
	marker.position = Vector3(cx, 0, -at)
	marker.set_meta("kind", 10)
	marker.set_meta("radius", 1.4)
	Art.cylinder(marker, Vector3(0, 1.1, 0), 0.08, 2.2, Color("f2d18f"))
	var candy = Art.cylinder(marker, Vector3(0, 2.6, 0), 0.52, 0.52, color)
	candy.rotation.x = PI / 2
	var halo = Art.box(marker, Vector3(0, 2.88, 0), Vector3(1.2, 0.12, 1.2), color, true)
	halo.rotation.x = PI / 2
	Art.label(marker, Vector3(0, 3.3, 0), "•", Color.WHITE, 26)
	return marker

func setup_ui() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var theme = Theme.new()
	theme.default_font_size = 17
	theme.default_font = MainMenu.ui_font()
	for style in ["normal", "hover", "pressed", "focus"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color("183b50") if style == "normal" else Color("376983")
		box.corner_radius_top_left = 10
		box.corner_radius_top_right = 10
		box.corner_radius_bottom_left = 10
		box.corner_radius_bottom_right = 10
		box.content_margin_left = 16
		box.content_margin_right = 16
		theme.set_stylebox(style, "Button", box)
	hud.theme = theme
	# Single top bar: bottle counter → tries circle → timer → route path
	var top_bar = HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 10.0
	top_bar.offset_right = -10.0
	top_bar.offset_top = 18.0
	top_bar.offset_bottom = 110.0
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_bar.add_theme_constant_override("separation", 34)
	hud.add_child(top_bar)
	# 1) bottle counter
	var bottle_row = HBoxContainer.new()
	bottle_row.add_theme_constant_override("separation", 10)
	bottle_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(bottle_row)
	bottle_row.add_child(label("🍼", 34, Color.WHITE))
	bottle_counter = outlined_label("0", 34, Color("ffdd9d"), Color("04121f"), 6)
	bottle_counter.custom_minimum_size = Vector2(90, 46)
	bottle_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottle_row.add_child(bottle_counter)
	top_bar.add_child(bar_spacer())
	# 2) tries circle
	tries_root = HBoxContainer.new()
	tries_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tries_root.custom_minimum_size = Vector2(34, 34)
	tries_root.add_theme_constant_override("separation", 0)
	top_bar.add_child(tries_root)
	tries_indicator = Panel.new()
	var circle_box = StyleBoxFlat.new()
	circle_box.bg_color = Color("dfe9ff")
	circle_box.corner_radius_top_left = 999
	circle_box.corner_radius_top_right = 999
	circle_box.corner_radius_bottom_left = 999
	circle_box.corner_radius_bottom_right = 999
	tries_indicator.add_theme_stylebox_override("panel", circle_box)
	tries_indicator.custom_minimum_size = Vector2(22, 22)
	tries_indicator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tries_indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tries_indicator.visible = true
	tries_root.add_child(tries_indicator)
	try_nodes.append(tries_indicator)
	top_bar.add_child(bar_spacer())
	top_bar.add_child(bar_spacer())
	# 3) countdown timer
	timer_label = outlined_label("03:00", 34, Color("9fe8ff"), Color("04121f"), 6)
	timer_label.custom_minimum_size = Vector2(130, 46)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(timer_label)
	top_bar.add_child(bar_spacer())
	# 4) route path
	path_panel = PanelContainer.new()
	path_panel.custom_minimum_size = Vector2(292, 92)
	path_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	path_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	top_bar.add_child(path_panel)
	var path_margin = MarginContainer.new()
	path_margin.add_theme_constant_override("margin_left", 12)
	path_margin.add_theme_constant_override("margin_right", 12)
	path_margin.add_theme_constant_override("margin_top", 8)
	path_margin.add_theme_constant_override("margin_bottom", 8)
	path_panel.add_child(path_margin)
	var path_content = VBoxContainer.new()
	path_margin.add_child(path_content)
	var route_label = label("ROUTE", 12, Color("9fe8ff"))
	path_content.add_child(route_label)
	path_track = Control.new()
	path_track.custom_minimum_size = Vector2(240, 52)
	path_content.add_child(path_track)
	var path_line = ColorRect.new()
	path_line.color = Color("2d4d64")
	path_line.position = Vector2(18, 22)
	path_line.size = Vector2(200, 4)
	path_track.add_child(path_line)
	for i in range(level.sections.size()):
		var section = level.sections[i]
		var dot = ColorRect.new()
		var flavor_index = int(section.get("flavor", i)) % maxi(1, flavors.size())
		dot.color = Color(flavors[flavor_index].color)
		dot.size = Vector2(10, 10)
		dot.position = Vector2(18 + (float(section.start) / float(course.length)) * 200.0 - 5.0, 18)
		path_track.add_child(dot)
		checkpoint_dots.append(dot)
	path_marker = ColorRect.new()
	path_marker.color = Color("ffe38a")
	path_marker.size = Vector2(12, 12)
	path_marker.position = Vector2(18, 18)
	path_track.add_child(path_marker)
	menu = PanelContainer.new()
	menu.position = Vector2(345, 180)
	menu.size = Vector2(590, 375)
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.065, 0.105, 0.97)
	panel.content_margin_left = 30
	panel.content_margin_right = 30
	panel.content_margin_top = 26
	panel.content_margin_bottom = 26
	panel.corner_radius_top_left = 20
	panel.corner_radius_bottom_right = 20
	menu.add_theme_stylebox_override("panel", panel)
	hud.add_child(menu)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	menu.add_child(content)
	content.add_child(label("A YEMENI FLAVOR ADVENTURE", 14, Color("6bd7d4")))
	menu_title = label("DELSI MAN", 50)
	content.add_child(menu_title)
	menu_copy = label("", 17, Color("c4d8e6"))
	content.add_child(menu_copy)
	action_button = button("START DELIVERY →", start_or_resume)
	content.add_child(action_button)
	var settings_row = HBoxContainer.new()
	content.add_child(settings_row)
	lang_button = button("العربية / EN", toggle_language)
	settings_row.add_child(lang_button)
	assist_button = button("ASSIST: OFF", toggle_assist)
	settings_row.add_child(assist_button)
	settings_row.add_child(button("SOUND", toggle_sound))
	content.add_child(label("Original development build · Brand artwork pending approval", 12, Color("8699aa")))
	main_menu = MainMenu.new()
	hud.add_child(main_menu)
	main_menu.start_requested.connect(start_or_resume)
	main_menu.language_requested.connect(toggle_language)
	main_menu.assist_requested.connect(toggle_assist)
	main_menu.sound_requested.connect(toggle_sound)
	main_menu.beep.connect(beep)
	fx = Fx.new()
	add_child(fx)
	fx.setup(self, hud)
	refresh_language()

func tr_text(en: String, ar: String) -> String:
	return ar if lang == "ar" else en

func refresh_language() -> void:
	if menu != null:
		menu.layout_direction = Control.LAYOUT_DIRECTION_RTL if lang == "ar" else Control.LAYOUT_DIRECTION_LTR
	if assist_button != null:
		assist_button.text = tr_text("ASSIST: ", "المساعدة: ") + (tr_text("ON", "نعم") if assist else tr_text("OFF", "لا"))
	if pause_button != null:
		pause_button.text = tr_text("Ⅱ  PAUSE", "إيقاف مؤقت")
	if main_menu != null:
		main_menu.sync(lang, assist, audio == null or audio.volume_db > -60)
	if state != "running":
		show_menu(state == "paused")

func toggle_language() -> void:
	lang = "ar" if lang == "en" else "en"
	profile.language = lang
	if not testing:
		Profile.write(profile)
	refresh_language()

func toggle_assist() -> void:
	assist = not assist
	profile.assist = assist
	if not testing:
		Profile.write(profile)
	refresh_language()

func toggle_sound() -> void:
	audio.volume_db = -80 if audio.volume_db > -60 else -18
	refresh_language()

func show_menu(paused: bool) -> void:
	if state == "menu" and main_menu != null:
		menu.hide()
		main_menu.open()
		return
	if main_menu != null:
		main_menu.hide()
	menu.show()
	menu_title.text = tr_text("DELIVERY PAUSED", "التوصيل متوقف") if paused else "DELSI MAN"
	menu_copy.text = tr_text("Five flavors. One festival. Make the delivery.\nHold A/D or arrows to steer · Space jump · S slide · E sprint\nR checkpoint · Esc pause", "خمس نكهات ومهرجان واحد. أكمل التوصيل.\nالأسهم للحركة · Space للقفز · S للانزلاق · E للاندفاع\nR لنقطة الحفظ · Esc إيقاف مؤقت")
	action_button.text = tr_text("RESUME →", "متابعة ←") if paused else tr_text("START DELIVERY →", "ابدأ التوصيل ←")
	if state == "finished":
		menu_title.text = tr_text("DELIVERED!", "تم التوصيل!")
		var rank = "S" if hits < 4 else ("A" if hits < 10 else "B")
		menu_copy.text = tr_text("RANK %s  ·  %d POINTS\n%d bottles  ·  %d hits  ·  %.1fs\nYour best score is saved." % [rank, score, bottles, hits, elapsed], "الرتبة %s · النقاط %d\nالزجاجات %d · الاصطدامات %d · الزمن %.1f" % [rank, score, bottles, hits, elapsed])
		action_button.text = tr_text("RUN AGAIN →", "العب مجدداً ←")
	elif state == "dead":
		menu_title.text = tr_text("RUN ENDED", "انتهت الجولة")
		menu_copy.text = tr_text("%d points  ·  %d bottles  ·  %d hits", "%d نقطة · %d زجاجات · %d اصطدامات") % [score, bottles, hits]
		action_button.text = tr_text("RETRY →", "أعد المحاولة ←")
	action_button.grab_focus()

func reset_tries() -> void:
	tries_left = 3
	tries_charge = 0.0
	bottle_charge = 0

func start_or_resume() -> void:
	if state != "paused":
		score = 0
		bottles = 0
		hits = 0
		combo = 0
		cold = 100
		elapsed = 0
		checkpoint = 0
		section = -1
		reset_tries()
		claimed.clear()
		for i in range(lollipop_pops.size()):
			lollipop_pops[i] = -1.0
			if i < checkpoint_markers.size() and checkpoint_markers[i] != null:
				checkpoint_markers[i].visible = true
		respawn(0)
		course.restore(0, claimed)
	state = "running"
	runner.running = true
	menu.hide()
	if main_menu != null:
		main_menu.hide()

func pause_run() -> void:
	if state == "running":
		state = "paused"
		runner.running = false
		show_menu(true)
	elif state == "paused":
		start_or_resume()

func add_try() -> void:
	if tries_left >= 3:
		return
	tries_left += 1
	tries_charge = 0.0

func consume_try() -> void:
	if tries_left > 0:
		tries_left -= 1
	if tries_left <= 0:
		tries_left = 0
		if state == "running":
			die()

func respawn(at: float) -> void:
	runner.reset(at)
	var cx = course.center_at(at) if course.has_method("center_at") else 0.0
	runner.x = cx
	runner.position.x = cx
	barrel_left = 0.0
	sprint_left = 0.0
	sprint_cd = 0.0
	if barrel_node != null:
		barrel_node.visible = false

func retry() -> void:
	if state != "running":
		return
	reset_tries()
	respawn(checkpoint)
	cold = maxf(cold, 60)
	combo = 0
	course.restore(checkpoint, claimed)

## Out of tries or out of cold: play the death take and bring up the retry
## menu right away, no hold.
func die() -> void:
	if state != "running":
		return
	state = "dead"
	runner.running = false
	runner.invulnerable = 0.0
	sprint_left = 0.0
	barrel_left = 0.0
	if barrel_node != null:
		barrel_node.visible = false
	beep_seq([[392.0, 0.14], [311.0, 0.14], [233.0, 0.35]])
	show_menu(false)

func act(action: String) -> void:
	if state != "running":
		return
	# He still steers through a hit, but the reaction owns his body: a jump or
	# a slide would swap the take out mid-stagger.
	if runner.holding() and (action == "jump" or action == "slide"):
		return
	var reversed = barrel_left > 0.0
	match action:
		"left": runner.steer(1 if reversed else -1)
		"right": runner.steer(-1 if reversed else 1)
		"jump":
			_tag_jump_take()
			runner.jump()
		"slide": runner.slide()

## The hop over a hand-reach crate gets its own take (a vault clears a box you
## could plant a palm on); every other jump plays the standing jump take.
func _tag_jump_take() -> void:
	# A press the runner ignores (already airborne) must not leave a stale tag
	# for the next hop.
	if runner.height >= 0.05:
		hero["jump_pick"] = ""
		return
	var course_center = 0.0
	if course.has_method("center_at"):
		course_center = course.center_at(runner.distance)
	var runner_off = runner.position.x - course_center
	var tagged := false
	for item in course.objects:
		if item.done or int(item.kind) != 0:
			continue
		var ahead = float(item.at) - runner.distance
		if ahead < -1.0 or ahead > 10.0:
			continue
		var item_x = float(item.get("x", 0.0))
		var radius = float(item.get("radius", 1.05))
		if absf(runner_off - item_x) - radius < 1.6:
			tagged = true
			break
	hero["jump_pick"] = "jump2" if tagged else ""

func _unhandled_input(event: InputEvent) -> void:
	for action in ["left", "right", "jump", "slide"]:
		if event.is_action_pressed(action):
			if event is InputEventKey and event.echo:
				continue
			act(action)
	if event.is_action_pressed("pause"):
		pause_run()
	if event.is_action_pressed("retry"):
		retry()

func beep(hz: float, seconds: float) -> void:
	note_queue.clear()
	note_hz = hz
	note_left = seconds

func beep_seq(notes: Array) -> void:
	note_queue = notes.duplicate()
	if not note_queue.is_empty():
		var first = note_queue.pop_front()
		note_hz = float(first[0])
		note_left = float(first[1])

func spawn_bottle_pickup(world_pos: Vector3) -> void:
	if camera == null or hud == null:
		return
	if fx != null:
		fx.pickup(world_pos)
	var start = camera.unproject_position(world_pos)
	var pop = outlined_label("+1", 34, Color("ffdd9d"), Color("04121f"), 6)
	pop.position = start
	pop.modulate.a = 1.0
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(pop)
	var target = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 40)
	if bottle_counter != null and bottle_counter.size != Vector2.ZERO:
		target = bottle_counter.get_global_rect().get_center()
	bottle_pickups.append({
		"label": pop,
		"start": start,
		"target": target,
		"life": 0.0,
		"duration": 0.7,
	})

func _process(dt: float) -> void:
	if synth != null:
		if note_left <= 0.0 and not note_queue.is_empty():
			var nxt = note_queue.pop_front()
			note_hz = float(nxt[0])
			note_left = float(nxt[1])
		for i in range(synth.get_frames_available()):
			var value = sin(oscillator) * minf(note_left * 20, 0.3) if note_left > 0 else 0.0
			synth.push_frame(Vector2(value, value))
			oscillator = fmod(oscillator + TAU * note_hz / 22050.0, TAU)
			note_left = maxf(0, note_left - 1.0 / 22050)
	if testing:
		return
	if state == "running":
		tick(minf(dt, 0.05))
	update_visuals(dt)

func _barrel_event() -> void:
	if barrel_left > 0.0:
		return
	barrel_left = BARREL_DURATION
	beep(880, 0.16)

## Sprint on the press only: one tap of E starts a burst that runs for a fixed
## time, holding the key does nothing, and a lockout after the burst means the
## next press has to wait — so speed always comes back on its own.
func update_sprint(dt: float) -> void:
	var held := Input.is_action_pressed("sprint")
	var pressed := held and not sprint_held
	sprint_held = held
	if state != "running":
		sprint_left = 0.0
		sprint_cd = 0.0
		return
	if sprint_left > 0.0:
		sprint_left = maxf(0.0, sprint_left - dt)
		if sprint_left == 0.0:
			sprint_cd = SPRINT_COOLDOWN
	elif sprint_cd > 0.0:
		sprint_cd = maxf(0.0, sprint_cd - dt)
	elif pressed and runner.height <= 0.05:
		# Only on the road: a burst started mid-hop would spend half its window
		# in the air where the boost reads as nothing.
		sprint_left = SPRINT_TIME

func tick(dt: float) -> void:
	elapsed += dt
	var previous = runner.distance
	var course_center = 0.0
	if course.has_method("center_at"):
		course_center = course.center_at(runner.distance)
	runner.road_center = course_center
	runner.set_steering(steering_axis())
	update_sprint(dt)
	var run_speed = float(level.speed) + minf(3.5, runner.distance / 520.0)
	if combo >= 12:
		run_speed += 0.8
	if sprint_left > 0.0:
		run_speed *= SPRINT_BOOST
	runner.advance(dt, run_speed * (0.72 if assist else 1.0))
	if course.has_method("center_at"):
		course_center = course.center_at(runner.distance)
		runner.road_center = course_center
	var runner_off = runner.position.x - course_center
	if barrel_left > 0.0:
		barrel_left = maxf(0.0, barrel_left - dt)
		if barrel_left == 0.0:
			beep(560, 0.1)
	if course.has_method("update_dynamic"):
		course.update_dynamic(runner.distance)
	cold = maxf(1, cold - dt * 0.1)
	var next_section = mini(5, int(runner.distance / 300))
	if next_section != section:
		section = next_section
		checkpoint = float(level.sections[section].start)
		if tries_left < 3:
			add_try()
		if section < lollipop_pops.size() and lollipop_pops[section] < 0.0:
			lollipop_pops[section] = 0.0
			beep_seq([[660.0, 0.06], [880.0, 0.06], [1318.0, 0.16]])
		else:
			beep(520, 0.08)
	for item in course.objects:
		if item.done or item.at < previous - 2 or item.at > runner.distance + 1:
			continue
		if item.kind == 12:
			if item.at <= runner.distance:
				item.done = true
				_barrel_event()
			continue
		var item_x = float(item.get("x", 0.0))
		var radius = float(item.get("radius", 1.05))
		var gap = absf(runner_off - item_x) - radius
		var horizontal_overlap = gap < 0.0
		if item.kind == 3:
			if horizontal_overlap and item.at <= runner.distance and runner.height < 1.0:
				if item.node is Node3D:
					spawn_bottle_pickup(item.node.global_position)
					item.node.visible = false
				item.done = true
				claimed[item.id] = true
				bottles += 1
				bottle_charge += 1
				bottle_bump = 1.0
				if bottle_charge >= 20:
					bottle_charge = 0
					if tries_left < 3:
						add_try()
				combo += 1
				score += 100 + mini(combo, 30) * 7
				cold = minf(100, cold + 0.5)
		elif item.at <= runner.distance:
			item.done = true
			# Jump-clearable kinds: crate, hole and the two stair sets. The
			# stairs carry their own clearance height per step (taller step,
			# later jump), everything else clears at the standard hop height.
			var jumpable = item.kind in [0, 4, 6, 7]
			var jump_clear = jumpable and runner.height > float(item.get("clear", 1.15))
			var slide_clear = item.kind == 1 and runner.slide_left > 0 and runner.height < 0.1
			var safe = not horizontal_overlap or runner.invulnerable > 0 or assist or jump_clear or slide_clear
			if not safe:
				hits += 1
				combo = 0
				cold -= 14
				# Shove him off the obstacle's line instead of steering him
				# around it: the old auto-dodge slid him sideways over a frozen
				# road, which read as the game glitching. He keeps control.
				var push = signf(runner_off - item_x)
				if push == 0.0:
					push = -1.0 if (runner_off - course_center) <= 0.0 else 1.0
				var kick = Runner.KNOCK_DOWN if Runner.is_down(item.kind) else Runner.KNOCK_LIGHT
				runner.stumble(signf(item_x - runner_off), item.kind, push * kick)
				cam_shake = 1.0
				beep(120, 0.12)
				consume_try()
				if cold <= 0:
					die()
					break
			else:
				var close_dodge = not horizontal_overlap and gap < 0.45
				var timed_clear = horizontal_overlap and (jump_clear or slide_clear)
				if not assist and runner.invulnerable <= 0 and (close_dodge or timed_clear):
					combo += 1
					score += 45 + mini(combo, 25) * 4
					cold = minf(100, cold + 0.2)
					beep(520 + combo * 5, 0.035)
	if runner.distance >= float(course.length):
		finish()

func finish() -> void:
	state = "finished"
	runner.running = false
	score += int(cold * 20) + maxi(0, 2000 - int(elapsed * 5))
	if not testing:
		Profile.record(profile, level.id, score, elapsed)
		if not Profile.write(profile):
			push_warning("Save unavailable: this session's score remains visible.")
	show_menu(false)

func update_visuals(dt: float) -> void:
	var cadence = 1
	if state == "running":
		cadence = 15 if sprint_left > 0.0 else 12
	phase += dt * cadence
	if timer_label != null:
		var remaining = maxf(0.0, 180.0 - elapsed)
		timer_label.text = "%02d:%02d" % [int(remaining) / 60, int(remaining) % 60]
		timer_label.modulate = Color("ff8f8f") if remaining <= 15.0 and state == "running" else Color.WHITE
	if bottle_counter != null:
		bottle_counter.text = str(bottles)
		bottle_bump = maxf(0.0, bottle_bump - dt * 3.0)
		bottle_counter.pivot_offset = bottle_counter.size * 0.5
		bottle_counter.scale = Vector2.ONE * (1.0 + bottle_bump * 0.35)
	for i in range(try_nodes.size()):
		var node = try_nodes[i]
		var active = tries_left > 0
		node.visible = active
		var pulse = 1.0 + sin(phase * 7.0 + i * 1.2) * 0.12
		var size_factor = clampf(float(tries_left) / 3.0, 0.0, 1.0)
		var target_size = lerp(8.0, 22.0, size_factor)
		node.custom_minimum_size = Vector2(target_size, target_size)
		node.size = Vector2(target_size, target_size)
		node.scale = Vector2.ONE * lerp(node.scale.x, pulse, minf(1.0, dt * 8.0))
		var box = node.get_theme_stylebox("panel")
		if box != null:
			box.bg_color = Color("ffffff") if active else Color("4a5c74")
			box.border_width_left = 0
			box.border_width_right = 0
			box.border_width_top = 0
			box.border_width_bottom = 0
	for i in range(bottle_pickups.size() - 1, -1, -1):
		var fx = bottle_pickups[i]
		var label = fx["label"]
		fx["life"] += dt
		var t = clampf(fx["life"] / fx["duration"], 0.0, 1.0)
		var eased = 1.0 - pow(1.0 - t, 2.0)
		label.position = fx["start"].lerp(fx["target"], eased)
		label.modulate.a = 1.0 - t
		label.scale = Vector2.ONE * (1.0 + (1.0 - t) * 0.75)
		if t >= 1.0:
			label.queue_free()
			bottle_pickups.remove_at(i)
	if path_marker != null:
		var path_fraction = clampf(runner.distance / float(course.length), 0.0, 1.0)
		path_marker.position.x = 18.0 + path_fraction * 200.0 - path_marker.size.x * 0.5
		path_marker.position.y = 18.0
		for i in range(checkpoint_dots.size()):
			var section_point = level.sections[i]
			var dot_x = 18.0 + (float(section_point.start) / float(course.length)) * 200.0 - 5.0
			checkpoint_dots[i].position.x = dot_x
			checkpoint_dots[i].position.y = 18.0
	for idx in range(checkpoint_markers.size()):
		var marker = checkpoint_markers[idx]
		if marker == null:
			continue
		if idx < lollipop_pops.size() and lollipop_pops[idx] >= 0.0:
			var pop_t = lollipop_pops[idx]
			if pop_t < 1.0:
				pop_t = minf(1.0, pop_t + dt * 2.4)
				lollipop_pops[idx] = pop_t
				var rise = 1.0 - pow(1.0 - pop_t, 3.0)
				marker.visible = true
				marker.position.y = 0.15 + rise * 5.0
				marker.scale = Vector3.ONE * (1.3 - rise * 1.3)
				marker.rotation.y += dt * 6.0
			else:
				marker.visible = false
			continue
		var active = idx <= section
		var pulse = 1.0 + sin(phase * 2.8 + idx * 1.6) * 0.22
		var scale_goal = 1.18 if active else 1.0
		marker.scale = Vector3.ONE * lerp(marker.scale.x, scale_goal * pulse, minf(1.0, dt * 7.0))
		marker.rotation.y = lerp(marker.rotation.y, phase * 0.6 + idx * 0.9, minf(1.0, dt * 5.0))
		marker.position.y = sin(phase * 2.0 + idx * 2.1) * 0.12 + (0.15 if active else 0.0)
	hero.root.position.y = 0.0
	if hero.kind == "procedural":
		hero.root.scale.y = lerpf(hero.root.scale.y, 0.47 if runner.slide_left > 0 else 1.0, minf(1, dt * 15))
	var stumble_mix = 0.0
	if runner.stumble_left > 0.0:
		stumble_mix = 1.0 - runner.stumble_left / maxf(0.01, runner.stumble_duration)
	var lean = clampf(runner.position.x * 0.025, -0.12, 0.12)
	# A modest extra roll on top of the take: the stumble takes already throw
	# the body sideways, and stacking the old 0.9 rad on them read as the hero
	# toppling over rather than staggering.
	var stumble_tilt = runner.stumble_dir * (0.5 * sin(stumble_mix * PI))
	var hole_drop = 0.0
	var bob = sin(phase * 3.0) * 0.045 if state == "running" and not runner.holding() else 0.0
	if runner.stumble_kind == 4:
		hole_drop = 0.8 * stumble_mix
		hero.root.position.y = bob - hole_drop
		hero.root.rotation.x = lerpf(hero.root.rotation.x, 0.95 * stumble_mix * runner.stumble_dir + 1.0 * stumble_mix, minf(1, dt * 10))
	else:
		hero.root.position.y = bob
		hero.root.rotation.x = lerpf(hero.root.rotation.x, 0.55 * stumble_mix * runner.stumble_dir, minf(1, dt * 10))
	# Steer into the direction of travel: the hero looks the way he is going and
	# banks with it, both driven by lateral speed so the pose follows through
	# after the key is released instead of snapping back.
	var steer := 0.0
	if state == "running" and not runner.holding():
		steer = -clampf(runner.lateral_speed / Runner.MAX_LATERAL_SPEED, -1.0, 1.0)
	hero.root.rotation.z = lerpf(hero.root.rotation.z, - (lean + stumble_tilt) + steer * STEER_ROLL, minf(1, dt * 8))
	var wobble = sin(phase * 1.5) * 0.06 if state == "running" else 0.0
	hero.root.rotation.y = lerpf(hero.root.rotation.y, steer * STEER_YAW + wobble, minf(1, dt * 8))
	# Blink only through the grace after a hit: blinking through the reaction
	# itself cut the stumble take to pieces.
	hero.root.visible = runner.holding() or runner.invulnerable == 0 \
		or fmod(runner.invulnerable, 0.16) > 0.06
	if hero.kind == "procedural":
		var run_cycle = phase * 1.5
		var stride_offsets = [0.0, PI, PI, 0.0]
		for i in range(hero.limbs.size()):
			var swing = sin(run_cycle + stride_offsets[mini(i, 3)]) * 0.45 if state == "running" else 0.0
			hero.limbs[i].rotation.x = swing
			var lower = hero.limbs[i].get_node_or_null("lower")
			if lower != null:
				if i % 2 == 0:
					lower.rotation.x = -maxf(0.0, swing) * 1.1
				else:
					lower.rotation.x = maxf(0.0, -swing) * 1.2 + (0.12 if state == "running" else 0.0)
	else:
		Hero.animate(hero, state, float(cadence), runner, dt, sprint_left > 0.0, barrel_left > 0.0)
	var chase = runner.distance > float(course.length) - 300.0 and runner.distance < float(course.length)
	chase_train.visible = chase
	var cam_center = course.center_at(runner.distance) if course.has_method("center_at") else 0.0
	chase_train.position = Vector3(course.center_at(runner.distance - 11.0) if course.has_method("center_at") else 0.0, 0, -runner.distance + 11)
	if barrel_node != null:
		barrel_node.visible = barrel_left > 0.0
		if barrel_node.visible:
			barrel_node.position = Vector3(runner.position.x, 2.0 + sin(phase * 0.12) * 0.05, runner.position.z - 0.2)
			barrel_node.rotation = Vector3(0.3, 0.0, sin(phase * 0.05) * 0.4)
	var desired = Vector3(runner.position.x * 0.65 + cam_center * 0.35, 3.8, runner.position.z + (8 if chase else 5))
	# The chase follows through a hit: the runner keeps travelling while he
	# staggers, so holding the camera back would let him run out of frame.
	camera.position = camera.position.lerp(desired, 1 - exp(-4.2 * dt))
	camera.rotation_degrees.x = 0
	camera.rotation_degrees.y = 0
	camera.rotation_degrees.z = 0
	if cam_shake > 0.0:
		# Impact kick on top of the smoothed follow, so the blow on a hit reads
		# as an intentional strike instead of a hitch in the camera.
		cam_shake = maxf(0.0, cam_shake - dt * 3.0)
		var kick := cam_shake * cam_shake
		camera.position += Vector3(sin(phase * 2.0), cos(phase * 1.6), 0.0) * 0.18 * kick
		camera.rotation_degrees.z = sin(phase * 1.7) * 3.0 * kick
	course.update_visibility(runner.distance)
	if fx != null:
		fx.tick(dt)

## Test helper: parks the runner and the hero bookkeeping so the next animate()
## call picks its state from scratch instead of inheriting a stumble, a slide
## or a recovery left over from earlier ticks.
func _clear_hero_motion() -> void:
	runner.slide_left = 0.0
	runner.stumble_left = 0.0
	runner.stumble_dir = 0.0
	runner.stumble_kind = 0
	runner.height = 0.0
	runner.vertical_speed = 0.0
	hero["down"] = false
	hero["recover"] = ""
	hero["recover_left"] = 0.0
	hero["walk_left"] = 0.0
	hero["sprint_left"] = 0.0
	hero["sprint_prev"] = false

func run_tests() -> void:
	print("TEST: assets loaded; %d course entities"%course.objects.size())
	assert(flavors.size() == 5)
	var authored = load_authored_course("res://scenes/levels/manual_sample_level.tscn")
	assert(authored == null)
	var sample_root = load("res://scenes/levels/manual_sample_level.tscn").instantiate()
	add_child(sample_root)
	sample_root.load_from_scene(sample_root)
	assert(sample_root.objects.size() >= 5)
	assert(sample_root.finish_at == 1800.0)
	var sample_kinds: Dictionary = {}
	for item in sample_root.objects:
		sample_kinds[item.kind] = true
	assert(sample_kinds.has(0) and sample_kinds.has(3))
	sample_root.use_in_game = true
	assert(bool(sample_root.get("use_in_game")) and not sample_root.objects.is_empty())
	sample_root.update_visibility(50.0)
	sample_root.update_dynamic(50.0)
	assert(not sample_root.curved)
	assert(sample_root.center_at(100.0) == 0.0)
	remove_child(sample_root)
	sample_root.queue_free()
	assert(course.curved)
	assert(course.center_at(0.0) == 0.0)
	var total_bend = 0.0
	for b in course.bends:
		total_bend += float(b.delta)
	assert(absf(course.center_at(4000.0) - total_bend) < 0.01)
	assert(course.center_at(455.0) != 0.0 or course.center_at(700.0) != 0.0)
	runner.running = true
	runner.reset(0)
	runner.set_steering(-1)
	for i in range(45):
		runner.advance(1.0 / 60, 0)
	assert(runner.position.x < -2.0)
	for i in range(120):
		runner.advance(1.0 / 60, 0)
	assert(runner.position.x >= -5.81 and runner.position.x <= -5.7)
	runner.set_steering(1)
	for i in range(100):
		runner.advance(1.0 / 60, 0)
	assert(runner.position.x > -1.0)
	runner.reset(0)
	runner.jump()
	runner.advance(0.1, 14)
	assert(runner.height > 0 and runner.distance > 0)
	runner.reset(0)
	runner.slide()
	runner.advance(0.1, 10)
	assert(runner.slide_left > 0)
	start_or_resume()
	assist = false
	var hazard = null
	var bottle_item = null
	for item in course.objects:
		if hazard == null and item.kind in [0, 1, 2]:
			hazard = item
		if bottle_item == null and item.kind == 3:
			bottle_item = item
		if hazard != null and bottle_item != null:
			break
	assert(hazard != null and bottle_item != null)
	var slide_truck = null
	for item in course.objects:
		if item.kind == 1 and item.node is Node3D and item.node.has_meta("look") and int(item.node.get_meta("look")) == 4:
			slide_truck = item
			break
	assert(slide_truck != null)
	assert(hero.kind == "fbx" and hero.limbs.is_empty())
	assert(hero.player != null and hero.skeleton != null)
	assert(hero.skeleton.get_bone_count() == 33)
	assert(hero.player.current_animation == hero.clip)
	assert(hero.clip == "delsi/idle", "the hero must start on the idle take")
	var hips_bone: int = hero.skeleton.find_bone("mixamorig_Hips")
	assert(hips_bone >= 0)
	var hips_rest: Transform3D = hero.skeleton.get_bone_rest(hips_bone)
	for state in Hero.CLIPS:
		var clip_name: String = "delsi/" + str(state)
		assert(hero.player.has_animation(clip_name), "missing hero clip " + clip_name)
		var clip_length: float = hero.player.get_animation(clip_name).length
		assert(clip_length > 0.2, clip_name + " must be longer than a flash frame")
		hero.player.play(clip_name, 0.0)
		var low := Vector3(9, 9, 9)
		var high := Vector3(-9, -9, -9)
		for i in range(9):
			hero.player.seek(clip_length * float(i) / 9.0, true)
			# tracks only apply to the skeleton on a process frame; reading right
			# after seek would measure the previous pose (or the rest pose).
			await get_tree().process_frame
			var pose: Transform3D = hero.skeleton.get_bone_global_pose(hips_bone)
			low = low.min(pose.origin)
			high = high.max(pose.origin)
			var heading := rad_to_deg(Basis(pose.basis).get_euler(EULER_ORDER_YXZ).y)
			assert(absf(absf(heading) - 180.0) < 3.0,
				"%s must face the road axis, got %.1f" % [clip_name, heading])
		assert(high.x - low.x < 0.001, "fbx root motion must be pinned on x: " + state)
		assert(high.z - low.z < 0.001, "fbx root motion must be pinned on z: " + state)
		assert(absf(high.x - hips_rest.origin.x) < 0.01)
		assert(absf(high.z - hips_rest.origin.z) < 0.01)
		if state in ["run", "walk", "unbalanced", "stumble", "slide", "hurt", "knock", "getup"]:
			assert(high.y - low.y > 0.01, "the hip bob must survive root-motion removal: " + state)
		if state in ["jump", "jump2", "hole"]:
			assert(absf(high.y - hips_rest.origin.y) < 0.01,
				"the runner must carry the height for " + state)
	hero.player.seek(0.0, true)
	hero.player.play(hero.clip)
	# Hit reactions: a light hit staggers once and is straight back into the run,
	# a knocked hero plays the fall and picks himself up off the road.
	var light_seen: Array[String] = []
	runner.stumble(1.0, 0)
	for i in range(90):
		Hero.animate(hero, "running", 13.0, runner, 0.016)
		light_seen.append(str(hero.get("clip", "")))
		runner.stumble_left = maxf(0.0, runner.stumble_left - 0.016)
	assert(light_seen.has("delsi/stumble"), "a light hit must play the stumble take")
	assert(not light_seen.has("delsi/hurt"), "a light hit has no second phase: it staggers and runs")
	var down_seen: Array[String] = []
	runner.stumble(1.0, 1)
	for i in range(120):
		Hero.animate(hero, "running", 13.0, runner, 0.016)
		down_seen.append(str(hero.get("clip", "")))
		runner.stumble_left = maxf(0.0, runner.stumble_left - 0.016)
	assert(down_seen.has("delsi/knock"), "a knocked hero must play the knock take")
	assert(down_seen.has("delsi/getup"), "a knocked hero must get back up")
	runner.stumble_left = 0.0
	runner.recover_left = 0.0
	runner.stumble_dir = 0.0
	runner.stumble_kind = 0
	# The road never stops on a hit: he keeps travelling (at the stagger's
	# reduced pace) and gets shoved off the obstacle's line instead of being
	# steered around it over a frozen road.
	runner.running = true
	runner.reset(100.0)
	runner.stumble(-1.0, 0, Runner.KNOCK_LIGHT)
	var before_hit = runner.distance
	for i in range(60):
		runner.advance(1.0 / 60, 13.0)
	assert(runner.distance > before_hit + 3.0, "a stumble must slow the run, not freeze it")
	assert(runner.x > 0.1, "a hit must kick him sideways off the obstacle line")
	runner.stumble_left = 0.0
	runner.recover_left = 0.0
	runner.reset(0.0)
	hero["clip"] = "delsi/idle"
	hero["state"] = "idle"
	hero.player.play("delsi/idle", 0.0)
	hero.player.seek(0.0, true)
	var fallback_host := Node3D.new()
	add_child(fallback_host)
	var fallback: Dictionary = Art.hero(fallback_host)
	assert(fallback.limbs.size() == 4 and fallback.limbs[0].get_node_or_null("lower") != null)
	fallback_host.queue_free()
	runner.slide_left = 0.0
	runner.stumble_left = 0.0
	runner.recover_left = 0.0
	runner.height = 0.0
	runner.vertical_speed = 0.0
	var sprint_seen: Array[String] = []
	for i in range(45):
		Hero.animate(hero, "running", 13.0, runner, 0.016, true)
		sprint_seen.append(str(hero.get("clip", "")))
	assert(sprint_seen.has("delsi/sprint"), "the sprint burst must play the sprint take")
	course.update_visibility(hazard.at - 5.0)
	assert(absf(hazard.node.scale.x - 1.0) < 0.01 and hazard.node.rotation.y == 0.0)
	var bottle_y = bottle_item.node.position.y
	var bottle_rot = bottle_item.node.rotation.y
	course.update_visibility(bottle_item.at - 5.0)
	assert(is_equal_approx(bottle_item.node.position.y, bottle_y))
	assert(is_equal_approx(bottle_item.node.rotation.y, bottle_rot))
	runner.reset(hazard.at - 0.1)
	runner.x = course.center_at(hazard.at) + float(hazard.get("x", 0.0))
	runner.position.x = runner.x
	runner.invulnerable = 0
	tick(0.02)
	assert(hits == 1)
	start_or_resume()
	runner.reset(hazard.at - 0.1)
	runner.x = course.center_at(hazard.at) + float(hazard.get("x", 0.0))
	runner.position.x = runner.x
	runner.invulnerable = 1.5
	section = 0
	tick(0.02)
	assert(hits == 0)
	start_or_resume()
	runner.reset(bottle_item.at - 0.1)
	runner.x = course.center_at(bottle_item.at) + float(bottle_item.get("x", 0.0))
	runner.position.x = runner.x
	section = 0
	tick(0.02)
	assert(bottles >= 1 and claimed.has(bottle_item.id))
	var already_collected = bottles
	retry()
	assert(bottles == already_collected and bottle_item.done)
	# Three-jump stair sets: three steps each with their own clearance height,
	# the big flight climbing higher with every hop. A hop over the step
	# clears it; running in low takes the hit.
	var stair_items: Array = []
	var block_steps := 0
	for item in course.objects:
		if item.kind == 6:
			stair_items.append(item)
		elif item.kind == 7:
			block_steps += 1
	assert(stair_items.size() == 3, "a stair set must ask for three jumps")
	assert(block_steps == 3, "a building stair set must ask for three jumps")
	var first_clear = float(stair_items[0].get("clear", 0.0))
	var last_clear = float(stair_items[2].get("clear", 0.0))
	assert(first_clear >= 1.15 and last_clear > first_clear,
		"the stair must climb higher with each jump")
	start_or_resume()
	var mid_step = stair_items[1]
	runner.reset(mid_step.at - 0.01)
	runner.x = course.center_at(mid_step.at) + float(mid_step.get("x", 0.0))
	runner.position.x = runner.x
	runner.invulnerable = 0
	runner.height = float(mid_step.get("clear", 1.15)) + 0.4
	runner.vertical_speed = 4.0
	var hits_before = hits
	tick(0.05)
	assert(hits == hits_before and mid_step.done, "a hop over the stair must clear it")
	var low_step = stair_items[2]
	runner.reset(low_step.at - 0.01)
	runner.x = course.center_at(low_step.at) + float(low_step.get("x", 0.0))
	runner.position.x = runner.x
	runner.invulnerable = 0
	runner.height = 0.0
	runner.vertical_speed = 0.0
	tick(0.05)
	assert(hits == hits_before + 1 and low_step.done, "running into the stair must hurt")
	var trigger = null
	for item in course.objects:
		if item.kind == 12:
			trigger = item
			break
	assert(trigger != null)
	start_or_resume()
	runner.reset(trigger.at - 0.1)
	var respawn_center = course.center_at(trigger.at)
	runner.x = respawn_center
	runner.position.x = respawn_center
	runner.invulnerable = 0
	section = 0
	touch_left = true
	assert(steering_axis() < 0.0)
	tick(0.02)
	assert(barrel_left > 0.0)
	assert(steering_axis() > 0.0)
	# While the barrel rides, the gait is the tipsy walk of the new take; the
	# run returns the moment it is gone. The runner state is cleared first so
	# the pick cannot land on stumble/slide from earlier ticks.
	_clear_hero_motion()
	Hero.animate(hero, "running", 13.0, runner, 0.016, false, barrel_left > 0.0)
	assert(hero.state == "unbalanced", "the barrel must play the unbalanced walk")
	assert(hero.clip == "delsi/unbalanced")
	touch_left = false
	for i in range(300):
		tick(0.02)
	assert(barrel_left == 0.0)
	_clear_hero_motion()
	Hero.animate(hero, "running", 13.0, runner, 0.016, false, barrel_left > 0.0)
	assert(hero.state == "run", "the walk must end with the barrel")
	touch_right = false
	start_or_resume()
	runner.reset(100.0)
	runner.invulnerable = 2.0
	var before_run = runner.distance
	for i in range(30):
		tick(1.0 / 60)
	var normal_rate = (runner.distance - before_run) / 0.5
	runner.reset(100.0)
	runner.invulnerable = 2.0
	Input.action_press("sprint")
	before_run = runner.distance
	for i in range(30):
		tick(1.0 / 60)
	var sprint_rate = (runner.distance - before_run) / 0.5
	Input.action_release("sprint")
	assert(sprint_rate > normal_rate * 1.2)
	assert(lollipop_pops.size() == 6 and lollipop_pops[0] >= 0.0 and note_queue.size() > 0)
	# One press starts a timed burst, holding the key does nothing, and the
	# burst is followed by a lockout before E is accepted again.
	runner.invulnerable = 30.0
	assert(sprint_left > 0.0, "the press must start a timed sprint")
	for i in range(150):
		tick(1.0 / 60)
		if sprint_left == 0.0 and sprint_cd > 0.0:
			break
	assert(sprint_left == 0.0 and sprint_cd > 0.0, "the sprint must end and lock out")
	Input.action_press("sprint")
	tick(1.0 / 60)
	assert(sprint_left == 0.0, "E must be ignored while the lockout runs")
	Input.action_release("sprint")
	for i in range(90):
		tick(1.0 / 60)
	assert(sprint_cd == 0.0, "the lockout must expire")
	Input.action_press("sprint")
	tick(1.0 / 60)
	assert(sprint_left > 0.0, "E must start a new burst once the lockout is over")
	Input.action_release("sprint")
	var sample = {"version": 1, "levels": {}}
	Profile.record(sample, "test", 100, 40)
	Profile.record(sample, "test", 80, 50)
	assert(sample.levels.test.score == 100 and sample.levels.test.time == 40)
	start_or_resume()
	assist = true
	for i in range(18000):
		if state != "running":
			break
		tick(1.0 / 60)
	assert(state == "finished")
	assert(section == 5 and score > 0)
	assert(lollipop_pops.size() == 6 and lollipop_pops[0] >= 0.0 and lollipop_pops[5] >= 0.0)
	update_visuals(0.016)
	print("PASS: authored scene loading, curved centerline, barrel obstruction with reversed controls, smooth obstacle visibility, continuous steering, jumps, sliding, collision damage, invulnerability, bottle pickup and deduplication, records, all checkpoints, sprint, slide-under truck, three-jump stair sets, lollipop pickup animation, hero rig, UI updates and full level completion")
	get_tree().quit(0)
