extends SceneTree
## Frame-driven: verify the baked clips actually animate the skeleton over
## real process frames (seek+immediate read is unreliable).

const Hero = preload("res://scripts/hero.gd")

var hero: Dictionary = {}
var hips := 0
var frame := 0
var states := ["idle", "walk", "run", "stumble", "slide", "hurt", "sprint", "jump", "hole"]
var sidx := 0
var tidx := 0
var lo := 1e9
var hi := -1e9
var lox := 1e9
var hix := -1e9

func _initialize() -> void:
	var host := Node3D.new()
	root.add_child(host)
	hero = Hero.create(host)
	if str(hero.get("kind", "")) != "fbx":
		print("DIAG not fbx: " + str(hero.get("kind")))
		quit(1)
		return
	hips = hero.skeleton.find_bone(Hero.HIPS_BONE)
	print("DIAG fbx ok hips=%d states=%s" % [hips, str(states)])

func _measure() -> void:
	var p: Transform3D = hero.skeleton.get_bone_global_pose(hips)
	lo = minf(lo, p.origin.y)
	hi = maxf(hi, p.origin.y)
	lox = minf(lox, p.origin.x)
	hix = maxf(hix, p.origin.x)

func _process(_d: float) -> bool:
	frame += 1
	if sidx >= states.size():
		print("PROBE DONE")
		quit(0)
		return false
	var st: String = states[sidx]
	var cname := "delsi/" + st
	var clip: Animation = hero.player.get_animation(cname)
	if tidx == 0:
		lo = 1e9
		hi = -1e9
		lox = 1e9
		hix = -1e9
		hero.player.play(cname, 0.0)
		hero.player.seek(0.0, true)
		_measure()
		tidx = 1
		return false
	hero.player.seek(clip.length * float(tidx) / 9.0, true)
	_measure()
	tidx += 1
	if tidx >= 9:
		print("STATE %-8s y_delta=%.4f x_delta=%.4f pos_end=%.3f cur=%s" % [
			st, hi - lo, hix - lox, hero.player.current_animation_position,
			hero.player.current_animation])
		sidx += 1
		tidx = 0
	return false
