extends Node3D
## Pure runner simulation. Visuals/camera/world are independent consumers.
var lane := 0
var height := 0.0
var vertical_speed := 0.0
var slide_left := 0.0
var jumps := 0
var power_left := 0.0
var cooldown := 0.0
var invulnerable := 0.0
var flavor := 0
var distance := 0.0
var running := false
var duration := 4.0

func steer(direction: int) -> void:
	lane = clampi(lane + direction, -1, 1)

func jump() -> void:
	if height < 0.03 or (flavor == 1 and jumps < 2):
		vertical_speed = 9.5
		jumps += 1
		slide_left = 0

func slide() -> void:
	if height < 0.1:
		slide_left = 0.9

func activate() -> bool:
	if cooldown > 0:
		return false
	power_left = duration
	cooldown = 8
	if flavor == 1 or flavor == 2:
		vertical_speed = 13.0
		jumps = 1
	return true

func advance(dt: float, speed: float) -> void:
	if not running:
		return
	for key in ["slide_left","power_left","cooldown","invulnerable"]:
		set(key, maxf(0, get(key) - dt))
	distance += speed * dt * (1.5 if power_left > 0 and flavor == 0 else 1.0)
	vertical_speed -= (11.0 if power_left > 0 and flavor == 2 else 26.0) * dt
	height = maxf(0,height + vertical_speed * dt)
	if height == 0:
		vertical_speed = 0
		jumps = 0
	position = Vector3(lerpf(position.x,lane * 2.7,1-exp(-18*dt)),height,-distance)

func reset(at: float) -> void:
	distance = at
	lane = 0
	height = 0
	vertical_speed = 0
	power_left = 0
	cooldown = 0
	slide_left = 0
	invulnerable = 2
	position = Vector3(0,0,-at)
