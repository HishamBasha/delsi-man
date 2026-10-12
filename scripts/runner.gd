extends Node3D
## Pure runner simulation. Visuals/camera/world are independent consumers.
const ROAD_LIMIT := 5.8
const MAX_LATERAL_SPEED := 7.0
const STEERING_ACCEL := 40.0
const STEERING_DRAG := 20.0
const DODGE_IMPULSE := 4.0
## Reaction windows, each matched to the take that plays inside it (hero.gd
## plays every take at its own rate, so the swap back to the run lands on a
## finished move instead of a cut frame): 1.17s for the jog-off stumble,
## 1.33s for the knocked-backwards take at 2.5x, 1.15s for the hole fall at
## 1.5x, and the trimmed get-up at 1.6x.
const STUMBLE_LIGHT := 1.17
const STUMBLE_KNOCK := 1.33
const STUMBLE_HOLE := 1.15
const RECOVER_DOWN := 1.6
## A hit never stops the road: it only slows him down while he is staggered
## and steps the speed back up while he gets to his feet. Parking him on the
## spot (what the old held-in-place reaction did) is what read as a glitch.
const HURT_SPEED := 0.5
const RECOVER_SPEED := 0.75
## The sideways kick of a hit: a shove off the obstacle's line, not a guided
## dodge to a spot he is steered into. He keeps steering through it himself.
const KNOCK_LIGHT := 4.0
const KNOCK_DOWN := 6.0
## Kinds in DOWN_STUMBLE_KINDS hit the road and get back up; the rest stagger
## once and are straight back into the run.
const DOWN_STUMBLE_KINDS := [1, 4]
var x := 0.0
var lateral_speed := 0.0
var lateral_input := 0.0
var height := 0.0
var vertical_speed := 0.0
var slide_left := 0.0
var invulnerable := 0.0
var stumble_left := 0.0
var stumble_duration := STUMBLE_LIGHT
var recover_left := 0.0
var stumble_dir := 0.0
var stumble_kind := 0
var distance := 0.0
var running := false
var road_center := 0.0

static func is_down(kind: int) -> bool:
	return kind in DOWN_STUMBLE_KINDS

## How long the stumble take plays for this obstacle.
static func stumble_window(kind: int) -> float:
	if kind == 4:
		return STUMBLE_HOLE
	if kind == 1:
		return STUMBLE_KNOCK
	return STUMBLE_LIGHT

static func recover_duration(kind: int) -> float:
	return RECOVER_DOWN if is_down(kind) else 0.0

## True while a hit still has him: the stumble take first, then (for the kinds
## that put him on the road) the get-up.
func holding() -> bool:
	return stumble_left > 0.0 or recover_left > 0.0

func steer(direction: int) -> void:
	lateral_speed = clampf(lateral_speed + direction * DODGE_IMPULSE, -MAX_LATERAL_SPEED, MAX_LATERAL_SPEED)

func set_steering(value: float) -> void:
	lateral_input = clampf(value, -1.0, 1.0)

func jump() -> void:
	if height < 0.05:
		vertical_speed = 10.8
		slide_left = 0

func slide() -> void:
	# Ignore re-presses while a slide is already running: resetting the window
	# mid-take stretches it past the one-shot animation (which freezes on its
	# last frame) and lets a one-frame gap re-roll the slide/roll take.
	if height < 0.12 and slide_left <= 0.0:
		slide_left = 0.85

## Starts a hit reaction. `push` is the sideways kick in m/s, aimed off the
## obstacle; the stagger itself is the only thing that slows him down, and he
## is covered against a second hit until he is back on his feet.
func stumble(direction: float, obstacle_kind: int = 0, push: float = 0.0) -> void:
	if holding():
		return
	stumble_duration = stumble_window(obstacle_kind)
	stumble_left = stumble_duration
	stumble_dir = clampf(direction, -1.0, 1.0)
	stumble_kind = obstacle_kind
	recover_left = recover_duration(obstacle_kind)
	lateral_speed = clampf(push, -MAX_LATERAL_SPEED, MAX_LATERAL_SPEED)
	lateral_input = 0.0
	invulnerable = maxf(invulnerable, stumble_left + recover_left + 0.35)
	if obstacle_kind == 4:
		height = maxf(0.0, height - 0.35)

func advance(dt: float, speed: float) -> void:
	if not running:
		return
	for key in ["slide_left", "invulnerable"]:
		set(key, maxf(0, get(key) - dt))
	if stumble_left > 0.0:
		stumble_left = maxf(0.0, stumble_left - dt)
	elif recover_left > 0.0:
		recover_left = maxf(0.0, recover_left - dt)
	# The road keeps moving through a hit: slower while he staggers, part-way
	# back to pace while he picks himself up, so nothing ever freezes.
	var pace := 1.0
	if stumble_left > 0.0:
		pace = HURT_SPEED
	elif recover_left > 0.0:
		pace = RECOVER_SPEED
	distance += speed * pace * dt
	var gravity = 25.0
	vertical_speed -= gravity * dt
	height = maxf(0, height + vertical_speed * dt)
	if height <= 0.0001:
		height = 0.0
		vertical_speed = 0
	var handling = MAX_LATERAL_SPEED
	if slide_left > 0:
		handling *= 0.78
	var desired_speed = lateral_input * handling
	var response = STEERING_ACCEL if absf(lateral_input) > 0.05 else STEERING_DRAG
	lateral_speed = move_toward(lateral_speed, desired_speed, response * dt)
	var limit_left = road_center - ROAD_LIMIT
	var limit_right = road_center + ROAD_LIMIT
	x = clampf(x + lateral_speed * dt, limit_left, limit_right)
	if (x <= limit_left and lateral_speed < 0.0) or (x >= limit_right and lateral_speed > 0.0):
		lateral_speed = 0.0
	position = Vector3(x, height, -distance)

func reset(at: float) -> void:
	distance = at
	x = 0.0
	lateral_speed = 0.0
	lateral_input = 0.0
	height = 0
	vertical_speed = 0
	slide_left = 0
	invulnerable = 2
	stumble_left = 0.0
	recover_left = 0.0
	stumble_dir = 0.0
	stumble_kind = 0
	stumble_duration = STUMBLE_LIGHT
	position = Vector3(0, 0, -at)
