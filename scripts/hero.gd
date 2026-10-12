extends RefCounted
## Player character: applies the Mixamo FBX character and its clip set to the runner.
##
## Every source take is baked into an in-place state clip before it is played:
##   * horizontal root motion is pinned to the skeleton rest so the model stays on
##     the runner node, while the vertical hip bob is kept; takes whose own root
##     height would lift the body off the road (the jump and the hole fall) pin the
##     hip height instead and let the runner node carry the real height;
##   * the hips heading is pinned to the road axis, so every state faces the way
##     the game travels no matter which way the source take was authored;
##   * looping states wrap without a crossfade when the take already ends where it
##     starts (blending two equal poses is just a freeze), and state changes blend,
##     so poses do not snap;
## The state itself is derived from the runner: stumble/hole/knock from the
## obstacle kind, slide, air time, the sprint burst and the run-in walk, with
## every hit take sized to the reaction window it plays in (a light hit
## staggers once and is straight back to the run; the kinds that put him on
## the road get the get-up on top), and the barrel event swapping the gait for
## the tipsy walk. When the FBX cannot be loaded the procedural Art.hero rig is
## used instead.

const Art = preload("res://scripts/art.gd")
const Runner = preload("res://scripts/runner.gd")

const FBX_PATH := "res://assets/models/hero/Catwalk Walk Turn 180 Tight.fbx"
const CLIP_DIR := "res://assets/models/hero/"
const SOURCE_CLIP := "mixamo_com"
const LIBRARY := "delsi"
const CLIP_PREFIX := "delsi/"
const HIPS_BONE := "mixamorig_Hips"
const HEADING := PI
const FADE := 0.25
const FADE_KEYS := 8
const BLEND := 0.12
const IDLE_SPEED := 0.7
const SWING_RATIO := 1.5
const SLIDE_PITCH := -1.15
const WALK_IN := 0.5
const SPRINT_LEAD := 0.32

## state -> source take under CLIP_DIR plus how it is trimmed and played:
##   trim    seconds cut from the head of the take
##   end     where the take stops, cutting the tail (the get-up keeps the rise
##           and drops the standing-still tail, so the window stays short)
##   loop    crossfade the seam and loop the result
##   pin_y   pin the hip height as well (takes that fly or drop on their own)
##   rate    playback multiplier for one-shot takes
##   speed   "cadence" follows the step rate, "ground" the road speed (planted
##           feet on takes whose stride is too short for the cadence), "idle"
##           the menu pace
const CLIPS := {
	"idle": {"file": "Standing Idle.fbx", "loop": true, "speed": "idle"},
	"walk": {"file": "Walking.fbx", "loop": true, "speed": "cadence"},
	"run": {"file": "Running.fbx", "loop": true, "speed": "cadence"},
	"unbalanced": {"file": "Unbalanced _Walking.fbx", "loop": true, "speed": "ground"},
	"sprint": {"file": "Crouched To Sprinting.fbx", "rate": 1.0},
	"sprint_run": {"file": "Two Cycle Sprint.fbx", "loop": true, "speed": "ground"},
	"jump": {"file": "Jumping.fbx", "trim": 0.2, "rate": 1.13, "pin_y": true},
	"jump2": {"file": "Jumping_0.fbx", "trim": 0.1, "rate": 1.1, "pin_y": true},
	"fall": {"file": "Falling Idle.fbx", "loop": true},
	"slide": {"file": "Running Slide.fbx", "rate": 1.6},
	"roll": {"file": "Run To Rolling.fbx", "trim": 0.6, "rate": 1.3},
	"dead": {"file": "Zombie Stumbling.fbx", "rate": 1.1},
	# Hit takes: each length matches its window in runner.gd (1.17 / 1.33 / 1.15
	# / 1.6), so a reaction ends on a finished move instead of a cut frame.
	"stumble": {"file": "Jogging Stumble.fbx"},
	"knock": {"file": "Stumble Backwards.fbx", "rate": 2.5},
	"hole": {"file": "Falling Into Pool.fbx", "trim": 0.55, "rate": 1.5, "pin_y": true},
	# The old get-up trimmed the rise away (only the standing-still tail was
	# left), so he popped upright out of the knock; this take runs from the
	# road to his feet and the tail is cut so it fills the 1.6s window exactly.
	"getup": {"file": "Standing Up.fbx", "trim": 1.4, "end": 4.6, "rate": 2.0},
	"hurt": {"file": "Injured Stumble Idle.fbx"},
}

static func create(parent: Node3D) -> Dictionary:
	if ResourceLoader.exists(FBX_PATH):
		var hero := _from_fbx(parent)
		if not hero.is_empty():
			return hero
		push_warning("FBX hero could not be applied; using the procedural rig.")
	return procedural(parent)

static func procedural(parent: Node3D) -> Dictionary:
	var hero: Dictionary = Art.hero(parent)
	hero["kind"] = "procedural"
	hero["player"] = null
	hero["skeleton"] = null
	hero["clip"] = ""
	hero["states"] = {}
	hero["lengths"] = {}
	return hero

## Drives the state clip: the state comes from the runner, playback rate from the
## game cadence for the locomotion loops, and sliding dives the body instead of
## squashing the mesh.
static func animate(hero: Dictionary, state: String, cadence: float, runner: Node3D, dt: float, sprint := false, barrel := false) -> void:
	if str(hero.get("kind", "procedural")) != "fbx":
		return
	var player: AnimationPlayer = hero.player
	if player == null or not is_instance_valid(player):
		return
	var chosen := _state(hero, state, runner, dt, sprint, barrel)
	var clip := CLIP_PREFIX + chosen
	# Decide from the clip *we* asked for last frame, not from the player: a
	# one-shot that runs out clears current_animation, and replaying on that
	# would restart the take (visible when the frame rate drops and the game's
	# clamped clock runs the take out before the state ends).
	if str(hero.get("clip", "")) != clip:
		# A roll is a big pose change out of the run, so it gets a longer blend
		# than the routine locomotion swaps.
		player.play(clip, 0.22 if chosen == "roll" else BLEND)
		if chosen == "roll":
			# Pace the take to land exactly when the slide window ends: the raw
			# roll is longer than the window and a hard cut mid-move reads as a
			# glitch, not a slide.
			hero["roll_rate"] = float(hero.lengths[chosen]) / maxf(0.2, float(runner.slide_left))
	hero["clip"] = clip
	hero["state"] = chosen
	var cfg: Dictionary = CLIPS[chosen]
	var mode := str(cfg.get("speed", "rate"))
	if mode == "cadence":
		player.speed_scale = float(hero.lengths[chosen]) * cadence * SWING_RATIO / TAU
	elif mode == "ground":
		# Pace from the measured road speed, not the cadence: this take's stride
		# is far shorter than the run's, so cadence pacing would leave the feet
		# skating over the scrolling road. The measurement is kept every frame so
		# the first frame of the state already has a fresh delta.
		var tracked := float(hero.get("prev_dist", -1.0))
		hero["prev_dist"] = float(runner.distance)
		var road := 0.0
		if tracked >= 0.0 and dt > 0.0:
			road = (float(runner.distance) - tracked) / dt
		var speeds: Dictionary = hero.get("speeds", {})
		var authored := float(speeds.get(chosen, 0.0))
		if road > 1.0 and authored > 0.05:
			player.speed_scale = clampf(road / authored, 0.2, 40.0)
		else:
			# No road under the feet (menus, tests): fall back to the step rate.
			player.speed_scale = float(hero.lengths[chosen]) * cadence * SWING_RATIO / TAU
	elif mode == "idle":
		player.speed_scale = IDLE_SPEED
	else:
		player.speed_scale = float(hero.get("roll_rate", cfg.get("rate", 1.0))) if chosen == "roll" else float(cfg.get("rate", 1.0))
	var root: Node3D = hero.root
	# The pitch dive belongs to the classic slide only: forcing it on the roll
	# fights the take's own forward rotation and is what made the swap feel
	# rough. The roll animates the body itself, so leave the root alone.
	if runner.slide_left > 0.0 and str(hero.get("state", "")) == "slide":
		root.rotation.x = lerpf(root.rotation.x, SLIDE_PITCH, minf(1.0, dt * 14.0))
		root.position.y = lerpf(root.position.y, 0.0, minf(1.0, dt * 14.0))

## Maps the runner and the game state onto a baked clip.
static func _state(hero: Dictionary, game_state: String, runner: Node3D, dt: float, sprint := false, barrel := false) -> String:
	var previous := str(hero.get("prev_game_state", ""))
	if previous != "running" and game_state == "running":
		hero["walk_left"] = WALK_IN
	hero["prev_game_state"] = game_state
	if game_state == "dead":
		hero["walk_left"] = 0.0
		hero["sprint_left"] = 0.0
		return _pick(hero, "dead")
	if game_state != "running":
		hero["walk_left"] = 0.0
		hero["sprint_left"] = 0.0
		return _pick(hero, "idle")
	if runner.stumble_left > 0.0:
		var kind := int(runner.stumble_kind)
		return _pick(hero, "hole" if kind == 4 else ("knock" if kind == 1 else "stumble"))
	if runner.recover_left > 0.0:
		# The runner owns the recovery clock, and the take is sized to that
		# window, so he is upright again exactly when the road carries him at
		# full pace. Only the kinds that put him down recover this way: a light
		# hit has no second phase (an injured idle played over a running road
		# reads as a frozen pose), it staggers once and returns to the run.
		return _pick(hero, "getup" if Runner.is_down(int(runner.stumble_kind)) else "hurt")
	if runner.slide_left > 0.0:
		# Coin-flip the take when each slide starts so the move does not read
		# as the same clip every time; the pick is held for the whole slide.
		if not bool(hero.get("sliding_prev", false)):
			hero["slide_take"] = "roll" if randf() < 0.5 else "slide"
		hero["sliding_prev"] = true
		return _pick(hero, str(hero.get("slide_take", "slide")))
	hero["sliding_prev"] = false
	if runner.height > 0.02 or runner.vertical_speed > 0.0:
		# One take carries the whole hop: swapping to the falling idle at the
		# apex made a single jump read as two. The take is trimmed and paced so
		# its own apex and impact land on the runner's apex and touchdown; only
		# a genuinely long drop (never reached by a normal hop) uses the fall.
		if runner.vertical_speed < 0.0 and runner.height > 2.6:
			return _pick(hero, "fall")
		# One take carries the hop: the game tags a jump over a hand-reach
		# crate with "jump2" when the jump starts, every other hop plays the
		# standing jump take.
		if not bool(hero.get("jumping_prev", false)):
			hero["jump_take"] = str(hero.get("jump_pick", "")) if str(hero.get("jump_pick", "")) != "" else "jump"
			hero["jump_pick"] = ""
		hero["jumping_prev"] = true
		return _pick(hero, str(hero.get("jump_take", "jump")))
	hero["jumping_prev"] = false
	hero["jump_take"] = ""
	# The barrel event: controls are reversed while it rides on the head, and
	# the gait becomes the tipsy walk of the take. It outranks the locomotion
	# takes (the gag is the point) but not stumbling, sliding or air time. The
	# run-in walk is cancelled, not paused, so it cannot resurface afterwards.
	if barrel:
		hero["walk_left"] = 0.0
		return _pick(hero, "unbalanced")
	# The burst opens with the crouch-to-sprint take, then holds the two-cycle
	# sprint loop for as long as the game sprint window is open: this take does
	# not loop cleanly, and the window (not the key) decides when a burst is
	# active.
	var lead := float(hero.get("sprint_left", 0.0))
	if sprint and not bool(hero.get("sprint_prev", false)):
		lead = SPRINT_LEAD
	hero["sprint_prev"] = sprint
	if not sprint:
		lead = 0.0
	hero["sprint_left"] = maxf(0.0, lead - dt)
	if sprint:
		if float(hero.get("sprint_left", 0.0)) > 0.0:
			return _pick(hero, "sprint")
		return _pick(hero, "sprint_run")
	if float(hero.get("walk_left", 0.0)) > 0.0:
		hero["walk_left"] = float(hero.get("walk_left", 0.0)) - dt
		return _pick(hero, "walk")
	return _pick(hero, "run")

## Falls back when a take could not be baked, so the hero never plays a clip
## that is not in the library.
static func _pick(hero: Dictionary, wanted: String) -> String:
	var states: Dictionary = hero.get("states", {})
	if states.has(wanted):
		return wanted
	if states.has("run"):
		return "run"
	for state in states:
		return state
	return wanted

static func _from_fbx(parent: Node3D) -> Dictionary:
	var scene: PackedScene = load(FBX_PATH)
	if scene == null:
		return {}
	var instance: Node = scene.instantiate()
	var skeleton: Skeleton3D = null
	var player: AnimationPlayer = null
	var mesh: MeshInstance3D = null
	var drop: Array[Node] = []
	var stack: Array[Node] = [instance]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Camera3D or node is Light3D:
			drop.append(node)
			continue
		if node is Skeleton3D and skeleton == null:
			skeleton = node
		elif node is AnimationPlayer and player == null:
			player = node
		elif node is MeshInstance3D and mesh == null:
			mesh = node
		stack.append_array(node.get_children())
	for node in drop:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	if skeleton == null or player == null or skeleton.find_bone(HIPS_BONE) < 0:
		instance.free()
		return {}
	var library := AnimationLibrary.new()
	var lengths := {}
	var speeds := {}
	var states := {}
	var missing: Array[String] = []
	for state in CLIPS:
		var cfg: Dictionary = CLIPS[state]
		var source := _source(str(cfg.get("file", "")))
		var clip: Animation = null
		if source != null:
			clip = _bake(source, skeleton, cfg)
		if clip == null:
			missing.append(state)
			continue
		library.add_animation(StringName(str(state)), clip)
		lengths[state] = clip.length
		speeds[state] = _authored_speed(source, float(cfg.get("trim", 0.0)), float(cfg.get("end", source.length)))
		states[state] = true
	if not missing.is_empty():
		push_warning("hero clips not baked: %s" % str(missing))
	if states.is_empty():
		instance.free()
		return {}
	player.add_animation_library(LIBRARY, library)
	if mesh != null:
		# Bind-space vertices are centimetre scaled, so the renderer's bounds are
		# a few centimetres wide; give the mesh a box that matches the skinned body.
		mesh.set_custom_aabb(AABB(Vector3(-1.3, -0.3, -2.2), Vector3(2.6, 2.6, 4.4)))
	var root := Node3D.new()
	root.name = "Hero"
	parent.add_child(root)
	root.add_child(instance)
	var first := CLIP_PREFIX + _pick({"states": states}, "idle")
	player.play(first, 0.0)
	player.speed_scale = IDLE_SPEED
	return {
		"root": root,
		"limbs": [],
		"kind": "fbx",
		"player": player,
		"skeleton": skeleton,
		"clip": first,
		"state": "idle",
		"states": states,
		"lengths": lengths,
		"speeds": speeds,
		"walk_left": 0.0,
		"sprint_left": 0.0,
		"sprint_prev": false,
		"prev_game_state": "",
		"prev_dist": -1.0,
	}

## Road speed (m/s) a take was authored at: root travel across its span. The
## "ground" mode paces a clip from this, so its feet stay planted while the
## road scrolls underneath at a much higher speed than the take was made for.
static func _authored_speed(source: Animation, start: float, end: float) -> float:
	var span := maxf(0.05, end - start)
	for index in range(source.get_track_count()):
		if source.track_get_type(index) != Animation.TYPE_POSITION_3D:
			continue
		if not String(source.track_get_path(index)).ends_with(":" + HIPS_BONE):
			continue
		var a: Variant = _sample(source, index, start)
		var b: Variant = _sample(source, index, end)
		if a is Vector3 and b is Vector3:
			var dx := (b as Vector3).x - (a as Vector3).x
			var dz := (b as Vector3).z - (a as Vector3).z
			return Vector2(dx, dz).length() / span
	return 0.0

## Grabs the source take from one Mixamo FBX: the scene is only needed for the
## animation, the baked clip is retargeted onto the base skeleton.
static func _source(file: String) -> Animation:
	if file.is_empty():
		return null
	var path := CLIP_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	var found: Animation = null
	var stack: Array[Node] = [instance]
	while not stack.is_empty() and found == null:
		var node: Node = stack.pop_back()
		if node is AnimationPlayer and node.has_animation(SOURCE_CLIP):
			found = node.get_animation(SOURCE_CLIP)
			break
		stack.append_array(node.get_children())
	instance.free()
	return found

## Builds the in-place clip from the source take.
static func _bake(source: Animation, skeleton: Skeleton3D, cfg: Dictionary) -> Animation:
	var hips: int = skeleton.find_bone(HIPS_BONE)
	var rest: Transform3D = skeleton.get_bone_rest(hips)
	var pin_y := bool(cfg.get("pin_y", false))
	var looping := bool(cfg.get("loop", false))
	var start := clampf(float(cfg.get("trim", 0.0)), 0.0, maxf(0.0, source.length - 0.2))
	var end := clampf(float(cfg.get("end", source.length)), start + 0.2, source.length)
	var span := maxf(0.05, end - start)
	if source.get_track_count() == 0 or span <= 0.0:
		return null
	var out := Animation.new()
	out.step = 1.0 / 30.0
	out.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	# A take that already ends where it starts wraps cleanly on its own: adding a
	# crossfade there would only append a dead segment (the two poses being
	# blended are equal), which reads as a freeze once per loop.
	var seamless := looping and _seamless(source, start, end, rest, pin_y)
	out.length = span + (FADE if (looping and not seamless) else 0.0)
	for index in range(source.get_track_count()):
		if source.track_get_key_count(index) == 0:
			continue
		var path: NodePath = source.track_get_path(index)
		var kind: int = source.track_get_type(index)
		var track: int = out.add_track(kind)
		out.track_set_path(track, path)
		if kind == Animation.TYPE_VALUE:
			out.value_track_set_update_mode(track, source.value_track_get_update_mode(index))
		out.track_set_interpolation_type(track, source.track_get_interpolation_type(index))
		out.track_set_imported(track, source.track_is_imported(index))
		var pinned := String(path).ends_with(":" + HIPS_BONE)
		var at_start: Variant = _sample(source, index, start)
		var at_end: Variant = _sample(source, index, end)
		if at_start == null or at_end == null:
			out.remove_track(track)
			continue
		var first: Variant = _pin(at_start, kind, pinned, rest, pin_y)
		var last: Variant = _pin(at_end, kind, pinned, rest, pin_y)
		for key in range(source.track_get_key_count(index)):
			var when: float = source.track_get_key_time(index, key)
			if when <= start or when > end:
				continue
			var value: Variant = _pin(source.track_get_key_value(index, key), kind, pinned, rest, pin_y)
			out.track_insert_key(track, when - start, value, source.track_get_key_transition(index, key))
		out.track_insert_key(track, 0.0, first, 0.0)
		out.track_insert_key(track, span, last, 0.0)
		if looping and not seamless:
			for step in range(1, FADE_KEYS + 1):
				var blend := float(step) / float(FADE_KEYS)
				out.track_insert_key(track, span + FADE * blend, _blend(last, first, blend), 0.0)
	return out

## True when a take ends exactly where it starts, so the loop can wrap without
## a crossfade.
static func _seamless(source: Animation, start: float, end: float, rest: Transform3D, pin_y: bool) -> bool:
	for index in range(source.get_track_count()):
		if source.track_get_key_count(index) == 0:
			continue
		var kind: int = source.track_get_type(index)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
			continue
		var pinned := String(source.track_get_path(index)).ends_with(":" + HIPS_BONE)
		var at_start: Variant = _pin(_sample(source, index, start), kind, pinned, rest, pin_y)
		var at_end: Variant = _pin(_sample(source, index, end), kind, pinned, rest, pin_y)
		if at_start == null or at_end == null:
			continue
		var gap := 0.0
		if kind == Animation.TYPE_ROTATION_3D:
			gap = rad_to_deg((at_start as Quaternion).angle_to(at_end as Quaternion))
		else:
			gap = (at_start as Vector3).distance_to(at_end as Vector3)
		# A sub-degree wrap on a joint cannot be seen, but the crossfade that
		# would smooth it costs a 0.25s dead segment every loop (the take's own
		# motion frozen while two near-equal poses blend) -- the unbalanced walk
		# ends 0.676 degrees off its start on the right leg.
		if gap > (1.0 if kind == Animation.TYPE_ROTATION_3D else 0.002):
			push_warning("hero loop seam %.3f on %s" % [gap, str(source.track_get_path(index))])
			return false
	return true

static func _pin(value: Variant, kind: int, pinned: bool, rest: Transform3D, pin_y: bool) -> Variant:
	if not pinned:
		return value
	if kind == Animation.TYPE_POSITION_3D:
		var pos: Vector3 = value
		return Vector3(rest.origin.x, rest.origin.y if pin_y else pos.y, rest.origin.z)
	if kind == Animation.TYPE_ROTATION_3D:
		var quat: Quaternion = value
		var euler := Basis(quat).get_euler(EULER_ORDER_YXZ)
		euler.y = HEADING
		return Basis.from_euler(euler, EULER_ORDER_YXZ).get_rotation_quaternion()
	return value

## The heading a take is pinned to: the road axis, so the body faces the way the
## runner travels. Kept for probes that compare takes against each other.
static func _facing_yaw(source: Animation, time: float) -> float:
	for index in range(source.get_track_count()):
		if source.track_get_type(index) != Animation.TYPE_ROTATION_3D:
			continue
		if not String(source.track_get_path(index)).ends_with(":" + HIPS_BONE):
			continue
		var sample: Variant = _sample(source, index, time)
		if not (sample is Quaternion):
			continue
		var quat: Quaternion = sample
		return Basis(quat).get_euler(EULER_ORDER_YXZ).y
	return 0.0

## value_track_interpolate only reads TYPE_VALUE tracks, so the imported
## position/rotation tracks are sampled by hand: lerp for offsets, slerp for
## orientations, clamped outside the key range.
static func _sample(source: Animation, index: int, time: float) -> Variant:
	var kind: int = source.track_get_type(index)
	if kind == Animation.TYPE_VALUE:
		return source.value_track_interpolate(index, time)
	var count := source.track_get_key_count(index)
	if count == 0:
		return null
	if count == 1 or time <= source.track_get_key_time(index, 0):
		return source.track_get_key_value(index, 0)
	if time >= source.track_get_key_time(index, count - 1):
		return source.track_get_key_value(index, count - 1)
	var before := 0
	for key in range(count - 1):
		if source.track_get_key_time(index, key + 1) <= time:
			before = key + 1
		else:
			break
	var t0: float = source.track_get_key_time(index, before)
	var t1: float = source.track_get_key_time(index, before + 1)
	var alpha := 0.0 if t1 <= t0 else clampf((time - t0) / (t1 - t0), 0.0, 1.0)
	var from: Variant = source.track_get_key_value(index, before)
	var to: Variant = source.track_get_key_value(index, before + 1)
	if kind == Animation.TYPE_ROTATION_3D:
		var a: Quaternion = from
		var b: Quaternion = to
		return a.slerp(b, alpha)
	if kind == Animation.TYPE_POSITION_3D or kind == Animation.TYPE_SCALE_3D:
		return (from as Vector3).lerp(to as Vector3, alpha)
	return _blend(from, to, alpha)


static func _blend(from: Variant, to: Variant, weight: float) -> Variant:
	if from is Quaternion and to is Quaternion:
		var a: Quaternion = from
		var b: Quaternion = to
		if a.dot(b) < 0.0:
			b = -b
		return a.slerp(b, weight)
	if from is Vector3 and to is Vector3:
		return (from as Vector3).lerp(to as Vector3, weight)
	return to if weight >= 0.5 else from
