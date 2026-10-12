extends SceneTree
## Screenshots of the running game into docs/shots/.
## Run windowed (NO --headless):  godot --path <proj> -s res://tools/shots/shot_game.gd
## Prints SHOT0..SHOT4 step markers so a failure point is always visible.

var game: Node3D = null
var frame := 0
var shots := 0
var here: Camera3D = null
# Condition-driven steer sequence: a hit slows the runner for its whole
# reaction (a 1.17s stagger, and a light hit has no second phase), and how
# many frames that costs depends on the frame rate (dt clamps at 0.05 when the
# window runs slow), so the right-press waits for the reaction instead of
# counting frames from the stumble at 76.
var steer_pressed := false
var steer_at := 0

func _initialize() -> void:
	print("SHOT0 display=%s user=%s" % [DisplayServer.get_name(), OS.get_user_data_dir()])
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	print("SHOT1 game added state=%s" % str(game.get("state")))

func _capture(tag: String) -> void:
	var tex := root.get_texture()
	if tex == null:
		print("SHOT-FAIL %s: no root texture" % tag)
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		print("SHOT-FAIL %s: empty image" % tag)
		return
	var path := "res://docs/shots/%s.png" % tag
	var err := img.save_png(path)
	shots += 1
	print("SHOT %s -> %s size=%s err=%d" % [tag, ProjectSettings.globalize_path(path), img.get_size(), err])

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		25:
			print("STEP start state=%s" % str(game.get("state")))
			game.start_or_resume()
		45:
			_capture("run")
		46:
			game.runner.slide()
		75:
			_capture("slide")
		76:
			game.runner.stumble(1.0, 0)
		100:
			_capture("stumble")
		101:
			here = Camera3D.new()
			here.fov = 45
			here.near = 0.05
			root.add_child(here)
			here.current = true
			here.global_position = game.runner.global_position + Vector3(1.4, 1.7, 2.4)
			here.look_at(game.runner.global_position + Vector3(0, 1.1, 0))
		130:
			_capture("closeup")
		_:
			if not steer_pressed:
				if frame >= 150 and game.runner.stumble_left <= 0.0 \
						and game.runner.recover_left <= 0.0 and str(game.get("state")) == "running":
					Input.action_press("right")
					game.runner.invulnerable = 99.0
					steer_pressed = true
					steer_at = frame
					print("STEER press at frame %d" % frame)
				elif frame > 420:
					print("STEER never pressed: state=%s stumble=%.2f recover=%.2f" % [
						str(game.get("state")), game.runner.stumble_left, game.runner.recover_left])
					print("DONE shots=%d" % shots)
					quit(1)
					return true
			else:
				var step := frame - steer_at
				if step == 14 and here != null:
					here.global_position = game.runner.global_position + Vector3(1.1, 1.6, 2.6)
					here.look_at(game.runner.global_position + Vector3(0, 1.1, 0))
				elif step == 19:
					game.runner.invulnerable = 0.0
				elif step == 22:
					game.hero.root.visible = true
					print("STEER right yaw=%.3f roll=%.3f x=%.2f lat=%.2f vis=%s hero=%s cam=%s cur=%s" % [
						game.hero.root.rotation.y, game.hero.root.rotation.z,
						game.runner.position.x, game.runner.lateral_speed,
						str(game.hero.root.visible), str(game.hero.root.global_position),
						str(here.global_position), str(here.current)])
					_capture("steer_right")
				elif step == 23:
					Input.action_release("right")
				elif step >= 26:
					print("DONE shots=%d" % shots)
					quit(0)
					return true
	return false
