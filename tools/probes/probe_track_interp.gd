extends SceneTree
const Hero = preload("res://scripts/hero.gd")
func _initialize() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var hero: Dictionary = Hero.create(host)
	var clip: Animation = hero.player.get_animation("delsi/walk")
	print("A: len=", clip.length, " tracks=", clip.get_track_count())
	var found := -1
	for i in range(clip.get_track_count()):
		if String(clip.track_get_path(i)).ends_with(":mixamorig_Hips") and clip.track_get_type(i) == Animation.TYPE_POSITION_3D:
			found = i
	print("B: pos track=", found)
	print("C: calling interpolate...")
	var v = clip.track_interpolate(found, 0.1)
	print("D: got ", typeof(v), " ", v)
	var lo := 1e9
	var hi := -1e9
	for s in range(9):
		var w = clip.track_interpolate(found, clip.length * float(s) / 9.0)
		if typeof(w) == TYPE_VECTOR3:
			lo = minf(lo, w.y)
			hi = maxf(hi, w.y)
	print("E: y_delta=", hi - lo)
	var rot := -1
	for i in range(clip.get_track_count()):
		if String(clip.track_get_path(i)).ends_with(":mixamorig_Hips") and clip.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rot = i
	var rv = clip.track_interpolate(rot, 0.475)
	print("F: rot typeof=", typeof(rv), " ", rv)
	if typeof(rv) == TYPE_QUATERNION:
		var heading := rad_to_deg(Basis(rv as Quaternion).get_euler(EULER_ORDER_YXZ).y)
		print("G: heading=", heading)
	quit(0)