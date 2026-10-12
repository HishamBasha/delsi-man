extends Node
## Game-feel module: footsteps synced to the run cycle, jump/land, slide and
## sprint swishes, speed lines, impact shake/flash, landing dust and pickup
## sparkle. Reads live game state each tick; gameplay code only calls
## setup(), tick() and pickup().

const STEP_SOUNDS := [
	preload("res://audio/sfx/footstep_concrete_000.ogg"),
	preload("res://audio/sfx/footstep_concrete_001.ogg"),
	preload("res://audio/sfx/footstep_concrete_002.ogg"),
	preload("res://audio/sfx/footstep_concrete_003.ogg"),
	preload("res://audio/sfx/footstep_concrete_004.ogg"),
]
const JUMP_SOUNDS := [
	preload("res://audio/sfx/cloth1.ogg"),
	preload("res://audio/sfx/cloth2.ogg"),
	preload("res://audio/sfx/cloth3.ogg"),
]
const LAND_SOUNDS := [
	preload("res://audio/sfx/impactSoft_medium_000.ogg"),
	preload("res://audio/sfx/impactSoft_medium_001.ogg"),
	preload("res://audio/sfx/impactSoft_heavy_000.ogg"),
	preload("res://audio/sfx/impactSoft_heavy_001.ogg"),
]
const SPRINT_SOUNDS := [
	preload("res://audio/sfx/clothBelt.ogg"),
	preload("res://audio/sfx/clothBelt2.ogg"),
]
const PICKUP_SOUNDS := [
	preload("res://audio/sfx/handleCoins.ogg"),
	preload("res://audio/sfx/handleCoins2.ogg"),
]
const HIT_SOUNDS := [
	preload("res://audio/sfx/impactPunch_medium_000.ogg"),
	preload("res://audio/sfx/impactPunch_medium_001.ogg"),
	preload("res://audio/sfx/impactPunch_medium_002.ogg"),
]
const DUST_TEXTURE = preload("res://assets/fx/kenney_particle_pack/PNG (Transparent)/smoke_04.png")
const STAR_TEXTURE = preload("res://assets/fx/kenney_particle_pack/PNG (Transparent)/star_05.png")
const LINE_TEXTURE = preload("res://assets/fx/kenney_particle_pack/PNG (Transparent)/trace_04.png")

var game
var hud: Control
var voices: Array[AudioStreamPlayer] = []
var voice_i := 0
var dust_emitters: Array[CPUParticles3D] = []
var dust_i := 0
var star_emitter: CPUParticles3D
var lines: Array[TextureRect] = []
var line_bases: Array[float] = []
var line_scrolls: Array[float] = []
var flash: ColorRect
var cycle := 0.0
var last_mark := 0.0
var airborne := false
var prev_height := 0.0
var prev_distance := 0.0
var prev_hits := 0
var prev_sprint := false
var prev_slide := false
var shake := 0.0
var flash_alpha := 0.0
var line_time := 0.0
var squash_t := 0.0

func setup(game_node: Node3D, hud_control: Control) -> void:
	game = game_node
	hud = hud_control
	for i in range(6):
		var voice = AudioStreamPlayer.new()
		game.add_child(voice)
		voices.append(voice)
	for i in range(2):
		var duster = make_particles(DUST_TEXTURE, false, Color(0.96, 0.92, 0.84, 0.95))
		game.add_child(duster)
		dust_emitters.append(duster)
	star_emitter = make_particles(STAR_TEXTURE, true, Color(1.0, 0.86, 0.38, 1.0))
	game.add_child(star_emitter)
	build_screen_fx()

func make_particles(tex: Texture2D, additive: bool, tint: Color) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 18
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.randomness = 0.4
	p.direction = Vector3(0, 1, 0)
	p.spread = 65.0
	p.gravity = Vector3(0, -3.5, 0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.scale_amount_min = 0.18
	p.scale_amount_max = 0.5
	var quad = QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = tex
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = material
	p.mesh = quad
	var ramp = Gradient.new()
	ramp.set_color(0, tint)
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	p.color_ramp = ramp
	return p

func build_screen_fx() -> void:
	for i in range(10):
		var streak = TextureRect.new()
		streak.texture = LINE_TEXTURE
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak.stretch_mode = TextureRect.STRETCH_SCALE
		var left_side = i < 5
		if left_side:
			streak.anchor_left = 0.0
			streak.anchor_right = 0.0
			streak.offset_left = 10.0 + float(i % 3) * 22.0
			streak.offset_right = streak.offset_left + 70.0
		else:
			streak.anchor_left = 1.0
			streak.anchor_right = 1.0
			streak.offset_left = -(10.0 + float(i % 3) * 22.0 + 70.0)
			streak.offset_right = -(10.0 + float(i % 3) * 22.0)
		streak.anchor_top = 0.0
		streak.anchor_bottom = 0.0
		streak.offset_top = 80.0 + float(i % 5) * 150.0
		streak.offset_bottom = streak.offset_top + 320.0
		streak.pivot_offset = Vector2(35, 160)
		streak.rotation = 0.18 if left_side else -0.18
		streak.modulate.a = 0.0
		hud.add_child(streak)
		lines.append(streak)
		line_bases.append(0.0)
		line_scrolls.append(0.0)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.visible = false
	hud.add_child(flash)

func play(sounds: Array, base_db: float, pmin: float, pmax: float) -> void:
	if game != null and game.audio != null and game.audio.volume_db <= -60.0:
		return
	var voice: AudioStreamPlayer = null
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = voices[voice_i]
		voice_i = (voice_i + 1) % voices.size()
	voice.stream = sounds.pick_random()
	voice.volume_db = base_db + randf_range(-1.5, 1.5)
	voice.pitch_scale = randf_range(pmin, pmax)
	voice.play()

func puff(pos: Vector3, big: bool) -> void:
	if dust_emitters.is_empty():
		return
	var duster = dust_emitters[dust_i]
	dust_i = (dust_i + 1) % dust_emitters.size()
	duster.global_position = pos
	if big:
		duster.scale_amount_min = 0.3
		duster.scale_amount_max = 0.75
		duster.initial_velocity_min = 1.6
		duster.initial_velocity_max = 3.2
	else:
		duster.scale_amount_min = 0.15
		duster.scale_amount_max = 0.45
		duster.initial_velocity_min = 1.0
		duster.initial_velocity_max = 2.2
	duster.restart()
	duster.emitting = true

func pickup(world_pos: Vector3) -> void:
	if star_emitter != null:
		star_emitter.global_position = world_pos
		star_emitter.restart()
		star_emitter.emitting = true
	play(PICKUP_SOUNDS, -14.0, 1.0, 1.25)

func tick(dt: float) -> void:
	if game == null or game.runner == null:
		return
	var runner = game.runner
	var running = game.state == "running"
	var sprinting = running and game.sprint_left > 0.0
	if absf(runner.distance - prev_distance) > 15.0:
		airborne = false
		last_mark = floor(cycle / PI)
	prev_distance = runner.distance
	var height = float(runner.height)
	if running:
		var grounded = height < 0.15 and runner.slide_left <= 0.0
		if grounded and not runner.holding():
			cycle += dt * (15.0 if sprinting else 12.0) * 1.5
			var mark = floor(cycle / PI)
			if mark > last_mark:
				if sprinting:
					play(STEP_SOUNDS, -18.0, 1.06, 1.2)
				else:
					play(STEP_SOUNDS, -20.0, 0.9, 1.06)
			last_mark = mark
		else:
			last_mark = floor(cycle / PI)
		if height > 0.25 and not airborne:
			airborne = true
			play(JUMP_SOUNDS, -16.0, 0.95, 1.1)
			puff(runner.position + Vector3(0, 0.1, 0), false)
		elif height <= 0.05 and airborne:
			airborne = false
			play(LAND_SOUNDS, -14.0, 0.95, 1.08)
			puff(runner.position + Vector3(0, 0.05, 0), true)
			squash_t = 0.18
		if sprinting and not prev_sprint:
			play(SPRINT_SOUNDS, -16.0, 0.95, 1.05)
			puff(runner.position + Vector3(0, 0.1, 0), true)
		prev_sprint = sprinting
		var sliding = runner.slide_left > 0.0
		if sliding and not prev_slide:
			play(JUMP_SOUNDS, -18.0, 0.8, 0.95)
		prev_slide = sliding
		var hits_now = int(game.hits)
		if hits_now > prev_hits:
			shake = 0.6
			flash_alpha = 0.2
			play(HIT_SOUNDS, -12.0, 0.92, 1.1)
			puff(runner.position + Vector3(0, 0.9, 0), false)
		prev_hits = hits_now
	prev_height = height
	update_hero_squash(dt)
	update_screen_fx(dt, sprinting)

func update_hero_squash(dt: float) -> void:
	if game.hero == null or not game.hero.has("root") or game.hero.root == null:
		return
	var root: Node3D = game.hero.root
	if squash_t > 0.0:
		squash_t = maxf(0.0, squash_t - dt)
		var t = 1.0 - squash_t / 0.18
		root.scale.y = lerpf(0.8, 1.0, t * t)
	elif airborne:
		root.scale.y = 1.12

func update_screen_fx(dt: float, sprinting: bool) -> void:
	if game.camera != null:
		# Widen the lens on a burst: the extra periphery is what sells the
		# speed boost more than the streaks alone.
		var fov_goal = 74.0 if sprinting else 68.0
		game.camera.fov = lerpf(game.camera.fov, fov_goal, minf(1.0, dt * 5.0))
		if shake > 0.0:
			shake = maxf(0.0, shake - dt * 2.4)
			game.camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.4
			game.camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.4
			if shake == 0.0:
				game.camera.h_offset = 0.0
				game.camera.v_offset = 0.0
	flash_alpha = maxf(0.0, flash_alpha - dt * 1.8)
	if flash != null:
		flash.visible = flash_alpha > 0.01
		if flash.visible:
			flash.modulate.a = flash_alpha
	line_time += dt
	var goal = 0.9 if sprinting else 0.0
	for i in range(lines.size()):
		line_bases[i] = move_toward(line_bases[i], goal, dt * 5.0)
		# The streaks rush past the lens instead of just fading in place.
		line_scrolls[i] = fmod(line_scrolls[i] + dt * (1400.0 if sprinting else 0.0) * (0.8 + 0.15 * float(i % 4)), 480.0)
		lines[i].modulate.a = line_bases[i] * (0.55 + 0.45 * sin(line_time * 30.0 + float(i) * 1.7))
		lines[i].position.y = 80.0 + float(i % 5) * 150.0 + line_scrolls[i] - 240.0
