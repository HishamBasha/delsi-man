extends Node3D
const Runner = preload("res://scripts/runner.gd")
const Course = preload("res://scripts/course.gd")
const Art = preload("res://scripts/art.gd")
const Profile = preload("res://scripts/profile.gd")
var flavors: Array = []
var level: Dictionary
var profile: Dictionary
var runner: Node3D
var course: Node3D
var camera: Camera3D
var hero: Dictionary
var hud: Control
var menu: PanelContainer
var title: Label
var subtitle: Label
var stats: Label
var flavor_label: Label
var toast: Label
var progress: ProgressBar
var power: ProgressBar
var action_button: Button
var menu_title: Label
var menu_copy: Label
var lang_button: Button
var assist_button: Button
var pause_button: Button
var flavor_buttons: Array[Button] = []
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
var toast_left := 0.0
var lang := "en"
var assist := false
var audio: AudioStreamPlayer
var synth: AudioStreamGeneratorPlayback
var note_left := 0.0
var note_hz := 440.0
var oscillator := 0.0
var cart: Node3D
var chase_train: Node3D
var testing := false

func _exit_tree() -> void:
	if audio != null:
		audio.stop()
	synth = null

func _ready() -> void:
	testing = "--test" in OS.get_cmdline_user_args()
	flavors = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavors.json"))
	level = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_01.json"))
	profile = Profile.read()
	lang = profile.get("language","en")
	assist = profile.get("assist",false)
	setup_inputs()
	setup_world()
	setup_ui()
	show_menu(false)
	if testing:
		call_deferred("run_tests")

func setup_inputs() -> void:
	var map = {"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE,KEY_W,KEY_UP],"slide":[KEY_S,KEY_DOWN],"power":[KEY_E,KEY_SHIFT],"pause":[KEY_ESCAPE,KEY_P],"retry":[KEY_R]}
	for action in map:
		InputMap.add_action(action)
		for code in map[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
	var pads = {"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT,"jump":JOY_BUTTON_A,"slide":JOY_BUTTON_B,"power":JOY_BUTTON_X,"pause":JOY_BUTTON_START}
	for action in pads:
		var event = InputEventJoypadButton.new()
		event.button_index = pads[action]
		InputMap.action_add_event(action,event)

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
	env.environment = settings
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_color = Color("ffddaa")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	course = Course.new()
	add_child(course)
	course.build(flavors)
	runner = Runner.new()
	add_child(runner)
	hero = Art.hero(runner)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 68
	camera.far = 220
	camera.position = Vector3(0,5.5,10)
	camera.look_at(Vector3(0,1.5,-10))
	cart = Node3D.new()
	add_child(cart)
	Art.box(cart,Vector3(0,0.5,0),Vector3(1.8,0.45,2.5),Color("ffad45"))
	for x in [-0.9,0.9]:
		for z in [-0.8,0.8]:
			var wheel = Art.cylinder(cart,Vector3(x,0.3,z),0.3,0.2,Color("152b3f"))
			wheel.rotation.z = PI/2
	cart.visible = false
	chase_train = Node3D.new()
	add_child(chase_train)
	for i in range(3):
		Art.box(chase_train,Vector3(0,0.65,i*3),Vector3(2,0.5,2.7),Color("d6e8e8"))
		Art.box(chase_train,Vector3(0,1.5,i*3),Vector3(1.6,1.3,2.1),Color(flavors[i].color))
		Art.label(chase_train,Vector3(0,1.5,i*3-1.1),"DELSI",Color.WHITE,40)
	chase_train.visible = false
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

func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var n = Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	return n

func button(text: String, fn: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(80,45)
	b.pressed.connect(fn)
	return b

func setup_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var theme = Theme.new()
	theme.default_font_size = 17
	for style in ["normal","hover","pressed","focus"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color("183b50") if style == "normal" else Color("376983")
		box.corner_radius_top_left = 10
		box.corner_radius_top_right = 10
		box.corner_radius_bottom_left = 10
		box.corner_radius_bottom_right = 10
		box.content_margin_left = 16
		box.content_margin_right = 16
		theme.set_stylebox(style,"Button",box)
	hud.theme = theme
	var top = PanelContainer.new()
	top.position = Vector2(26,22)
	top.size = Vector2(420,142)
	hud.add_child(top)
	var margin = MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	top.add_child(margin)
	var column = VBoxContainer.new()
	margin.add_child(column)
	column.add_child(label("DELSI MAN   /   THE FIVE-FLAVOR RUN",14,Color("88d5e4")))
	title = label("01  /  THE MARKET DASH",24)
	column.add_child(title)
	subtitle = label("Run. Collect. Deliver.",15,Color("bdd2df"))
	column.add_child(subtitle)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	column.add_child(progress)
	stats = label("",19)
	stats.position = Vector2(26,183)
	hud.add_child(stats)
	var right = VBoxContainer.new()
	right.position = Vector2(954,26)
	right.size.x = 300
	hud.add_child(right)
	pause_button = button("Ⅱ  PAUSE",pause_run)
	right.add_child(pause_button)
	right.add_child(button("↺  CHECKPOINT  [R]",retry))
	flavor_label = label("",20)
	right.add_child(flavor_label)
	power = ProgressBar.new()
	power.custom_minimum_size.y = 8
	power.show_percentage = false
	right.add_child(power)
	toast = label("",27,Color("ffdd9d"))
	toast.position = Vector2(200,210)
	toast.size.x = 880
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(toast)
	var bottom = HBoxContainer.new()
	bottom.position = Vector2(26,610)
	bottom.add_theme_constant_override("separation",10)
	hud.add_child(bottom)
	bottom.add_child(button("←",func(): act("left")))
	bottom.add_child(button("→",func(): act("right")))
	bottom.add_child(button("JUMP  ␣",func(): act("jump")))
	bottom.add_child(button("SLIDE  S",func(): act("slide")))
	bottom.add_child(button("POWER  E",func(): act("power")))
	var flavor_row = HBoxContainer.new()
	flavor_row.position = Vector2(26,666)
	flavor_row.add_theme_constant_override("separation",6)
	hud.add_child(flavor_row)
	for i in range(5):
		var idx = i
		var b = button("%d · %s"%[i+1,flavors[i].name],func(): select_flavor(idx))
		b.add_theme_color_override("font_color",Color(flavors[i].color))
		flavor_row.add_child(b)
		flavor_buttons.append(b)
	menu = PanelContainer.new()
	menu.position = Vector2(345,180)
	menu.size = Vector2(590,375)
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.025,0.065,0.105,0.97)
	panel.content_margin_left = 30
	panel.content_margin_right = 30
	panel.content_margin_top = 26
	panel.content_margin_bottom = 26
	panel.corner_radius_top_left = 20
	panel.corner_radius_bottom_right = 20
	menu.add_theme_stylebox_override("panel",panel)
	hud.add_child(menu)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	menu.add_child(content)
	content.add_child(label("A YEMENI FLAVOR ADVENTURE",14,Color("6bd7d4")))
	menu_title = label("DELSI MAN",50)
	content.add_child(menu_title)
	menu_copy = label("",17,Color("c4d8e6"))
	content.add_child(menu_copy)
	action_button = button("START DELIVERY →",start_or_resume)
	content.add_child(action_button)
	var settings_row = HBoxContainer.new()
	content.add_child(settings_row)
	lang_button = button("العربية / EN",toggle_language)
	settings_row.add_child(lang_button)
	assist_button = button("ASSIST: OFF",toggle_assist)
	settings_row.add_child(assist_button)
	settings_row.add_child(button("SOUND",func(): audio.volume_db = -80 if audio.volume_db > -60 else -18))
	content.add_child(label("Original development build · Brand artwork pending approval",12,Color("8699aa")))
	refresh_language()

func tr_text(en: String, ar: String) -> String:
	return ar if lang == "ar" else en

func refresh_language() -> void:
	menu.layout_direction = Control.LAYOUT_DIRECTION_RTL if lang == "ar" else Control.LAYOUT_DIRECTION_LTR
	assist_button.text = tr_text("ASSIST: ","المساعدة: ") + (tr_text("ON","نعم") if assist else tr_text("OFF","لا"))
	pause_button.text = tr_text("Ⅱ  PAUSE","إيقاف مؤقت")
	for i in range(5):
		flavor_buttons[i].text = str(i+1)+" · "+ (flavors[i].arabic if lang == "ar" else flavors[i].name)
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

func show_menu(paused: bool) -> void:
	menu.show()
	menu_title.text = tr_text("DELIVERY PAUSED","التوصيل متوقف") if paused else "DELSI MAN"
	menu_copy.text = tr_text("Five flavors. One festival. Make the delivery.\nA/D or arrows · Space jump · S slide · E power\n1–5 select flavor · R checkpoint · Esc pause", "خمس نكهات ومهرجان واحد. أكمل التوصيل.\nالأسهم للحركة · Space للقفز · S للانزلاق · E للقوة\n١–٥ لاختيار النكهة · R لنقطة الحفظ")
	action_button.text = tr_text("RESUME →","متابعة ←") if paused else tr_text("START DELIVERY →","ابدأ التوصيل ←")
	if state == "finished":
		menu_title.text = tr_text("DELIVERED!","تم التوصيل!")
		var rank = "S" if hits < 4 else ("A" if hits < 10 else "B")
		menu_copy.text = tr_text("RANK %s  ·  %d POINTS\n%d bottles  ·  %d hits  ·  %.1fs\nYour best score is saved. Choose your next flavor."%[rank,score,bottles,hits,elapsed],"الرتبة %s · النقاط %d\nالزجاجات %d · الاصطدامات %d · الزمن %.1f"%[rank,score,bottles,hits,elapsed])
		action_button.text = tr_text("RUN AGAIN →","العب مجدداً ←")
	action_button.grab_focus()

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
		claimed.clear()
		runner.reset(0)
		course.restore(0,claimed)
	state = "running"
	runner.running = true
	menu.hide()
	message(tr_text("SPACE to jump · S to slide · E for flavor power","Space للقفز · S للانزلاق · E لقوة النكهة"),5)

func pause_run() -> void:
	if state == "running":
		state = "paused"
		runner.running = false
		show_menu(true)
	elif state == "paused":
		start_or_resume()

func retry() -> void:
	if state != "running":
		return
	runner.reset(checkpoint)
	cold = maxf(cold,60)
	combo = 0
	course.restore(checkpoint,claimed)
	message(tr_text("CHECKPOINT RESTORED","العودة إلى نقطة الحفظ"),2)

func select_flavor(index: int) -> void:
	runner.flavor = index
	runner.duration = float(flavors[index].duration)
	runner.power_left = 0
	if state == "running":
		message(str(flavors[index].hint),3)

func act(action: String) -> void:
	if state != "running":
		return
	match action:
		"left": runner.steer(-1)
		"right": runner.steer(1)
		"jump": runner.jump()
		"slide": runner.slide()
		"power":
			if runner.activate():
				beep(650,0.2)
				message(str(flavors[runner.flavor].ability).to_upper(),1.4)

func _unhandled_input(event: InputEvent) -> void:
	for action in ["left","right","jump","slide","power"]:
		if event.is_action_pressed(action):
			act(action)
	if event.is_action_pressed("pause"):
		pause_run()
	if event.is_action_pressed("retry"):
		retry()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			select_flavor(event.physical_keycode-KEY_1)

func beep(hz: float, seconds: float) -> void:
	note_hz = hz
	note_left = seconds

func message(text: String, seconds: float) -> void:
	toast.text = text
	toast_left = seconds

func _process(dt: float) -> void:
	if synth != null:
		for i in range(synth.get_frames_available()):
			var value = sin(oscillator) * minf(note_left*20,0.3) if note_left > 0 else 0.0
			synth.push_frame(Vector2(value,value))
			oscillator = fmod(oscillator+TAU*note_hz/22050.0,TAU)
			note_left = maxf(0,note_left-1.0/22050)
	if testing:
		return
	if state == "running":
		tick(minf(dt,0.05))
	update_visuals(dt)

func tick(dt: float) -> void:
	elapsed += dt
	var previous = runner.distance
	runner.advance(dt,float(level.speed)*(0.72 if assist else 1.0))
	cold = maxf(1,cold-dt*0.1)
	var next_section = mini(5,int(runner.distance/300))
	if next_section != section:
		section = next_section
		checkpoint = float(level.sections[section].start)
		select_flavor(int(level.sections[section].flavor))
		message(tr_text("CHECKPOINT · "+level.sections[section].title,"نقطة حفظ · "+level.sections[section].arabic),3)
	for item in course.objects:
		if item.done or item.at < previous-2 or item.at > runner.distance+1:
			continue
		var same_lane = absf(runner.position.x-item.lane*2.7) < 1.15
		var magnetic = runner.flavor == 3 and runner.power_left > 0
		if item.kind == 3:
			if (same_lane and runner.height < 2.6) or magnetic:
				item.done = true
				claimed[item.id] = true
				bottles += 1
				combo += 1
				score += 100 + mini(combo,20)*5
				cold = minf(100,cold+0.5)
				beep(700+combo*12,0.045)
		elif item.at <= runner.distance:
			item.done = true
			var safe = not same_lane or runner.invulnerable > 0 or assist
			safe = safe or (runner.power_left > 0 and runner.flavor == 4)
			safe = safe or (item.kind == 0 and (runner.height > 1.15 or (runner.power_left > 0 and runner.flavor == 0)))
			safe = safe or (item.kind == 1 and runner.slide_left > 0 and runner.height < 0.1)
			if not safe:
				hits += 1
				combo = 0
				cold -= 14
				runner.invulnerable = 1.2
				beep(120,0.12)
				message(tr_text("OOF! Keep the delivery cold.","انتبه! حافظ على برودة الطلب."),1)
				if cold <= 0:
					retry()
					break
	if runner.distance >= float(level.length):
		finish()

func finish() -> void:
	state = "finished"
	runner.running = false
	score += int(cold*20) + maxi(0,2000-int(elapsed*5))
	if not testing:
		Profile.record(profile,level.id,score,elapsed)
		if not Profile.write(profile):
			message("Save unavailable: this session's score remains visible.",10)
	show_menu(false)

func update_visuals(dt: float) -> void:
	phase += dt * (13 if state == "running" else 1)
	toast_left = maxf(0,toast_left-dt)
	toast.visible = toast_left > 0
	var color = Color(flavors[runner.flavor].color)
	flavor_label.text = (flavors[runner.flavor].arabic if lang == "ar" else flavors[runner.flavor].name)+("  • ACTIVE" if runner.power_left > 0 else "")
	flavor_label.modulate = color
	power.value = (1-runner.cooldown/8)*100
	progress.value = runner.distance/float(level.length)*100
	stats.text = tr_text("%06d   /   %d BOTTLES\nCOLD %d%%    COMBO ×%d"%[score,bottles,int(cold),combo],"%06d   /   %d زجاجة\nالبرودة %d%%    المتتالية ×%d"%[score,bottles,int(cold),combo])
	if section >= 0:
		title.text = "%02d / "%[section+1]+(level.sections[section].arabic if lang == "ar" else level.sections[section].title)
	subtitle.text = "%04dm / 1800m   ·   %02d:%02d"%[int(runner.distance),int(elapsed)/60,int(elapsed)%60]
	var riding = runner.distance > 750 and runner.distance < 870
	hero.root.position.y = 0.5 if riding else 0.0
	hero.root.scale.y = lerpf(hero.root.scale.y,0.47 if runner.slide_left > 0 else 1.0,minf(1,dt*15))
	hero.root.rotation.z = lerpf(hero.root.rotation.z,-(runner.lane*2.7-runner.position.x)*0.1,minf(1,dt*10))
	hero.root.visible = runner.invulnerable == 0 or fmod(runner.invulnerable,0.16)>0.06
	for i in range(hero.limbs.size()):
		hero.limbs[i].rotation.x = sin(phase+(PI if i%3 == 0 else 0))*0.65 if state == "running" and not riding else 0
	cart.visible = riding
	cart.position = runner.position
	var chase = runner.distance > 1500 and runner.distance < 1800
	chase_train.visible = chase
	chase_train.position = Vector3(sin(phase*0.08)*1.2,0,-runner.distance+11)
	var desired = runner.position + Vector3(runner.position.x*-0.65,8.0 if chase else 5.2,24 if chase else 10)
	camera.position = camera.position.lerp(desired,1-exp(-5*dt))
	camera.look_at(runner.position+Vector3(0,1.1,-4))
	camera.fov = lerpf(camera.fov,78.0 if runner.power_left > 0 else 68.0,minf(1,dt*3))
	course.update_visibility(runner.distance)

func run_tests() -> void:
	print("TEST: assets loaded; %d course entities"%course.objects.size())
	assert(flavors.size() == 5)
	runner.running = true
	runner.reset(0)
	runner.steer(-1)
	runner.steer(-1)
	assert(runner.lane == -1)
	runner.jump()
	runner.advance(0.1,14)
	assert(runner.height > 0 and runner.distance > 0)
	runner.flavor = 1
	runner.jump()
	assert(runner.jumps == 2)
	assert(runner.activate())
	assert(not runner.activate())
	runner.reset(0)
	runner.flavor = 0
	runner.activate()
	runner.advance(0.1,10)
	assert(is_equal_approx(runner.distance,1.5))
	runner.reset(0)
	runner.flavor = 2
	runner.activate()
	runner.advance(0.1,10)
	assert(runner.height > 1)
	start_or_resume()
	assist = false
	var hazard = course.objects[0]
	runner.reset(hazard.at-0.1)
	runner.lane = hazard.lane
	runner.position.x = hazard.lane*2.7
	runner.invulnerable = 0
	tick(0.02)
	assert(hits == 1)
	start_or_resume()
	runner.reset(hazard.at-0.1)
	runner.lane = hazard.lane
	runner.position.x = hazard.lane*2.7
	runner.invulnerable = 0
	runner.flavor = 4
	runner.activate()
	section = 0
	tick(0.02)
	assert(hits == 0)
	start_or_resume()
	var bottle_item = course.objects[1]
	runner.reset(bottle_item.at-0.1)
	runner.flavor = 3
	runner.activate()
	section = 0
	tick(0.02)
	assert(bottles >= 1 and claimed.has(bottle_item.id))
	var already_collected = bottles
	retry()
	assert(bottles == already_collected and bottle_item.done)
	var sample = {"version":1,"levels":{}}
	Profile.record(sample,"test",100,40)
	Profile.record(sample,"test",80,50)
	assert(sample.levels.test.score == 100 and sample.levels.test.time == 40)
	start_or_resume()
	assist = true
	for i in range(18000):
		if state != "running":
			break
		if i%240 == 0:
			act("power")
		tick(1.0/60)
	assert(state == "finished")
	assert(section == 5 and score > 0)
	update_visuals(0.016)
	print("PASS: lane bounds, jumps, five abilities, collision damage, checkpoint deduplication, records, all checkpoints, UI updates and full level completion")
	get_tree().quit(0)
