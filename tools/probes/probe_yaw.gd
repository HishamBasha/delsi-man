extends SceneTree
## Prints var_to_str (tscn-compatible) Transform3D strings for placement yaws.

func _initialize() -> void:
	var yaws := {
		"yaw_pi": PI,
		"yaw_half_pi": PI / 2.0,
		"yaw_neg_half_pi": -PI / 2.0,
		"yaw_quarter": PI / 4.0,
	}
	for key in yaws:
		var t := Transform3D(Basis(Vector3.UP, yaws[key]), Vector3.ZERO)
		var s := var_to_str(t)
		var back := str_to_var(s) as Transform3D
		var ok := back.is_equal_approx(t)
		print("%s :: %s :: roundtrip=%s" % [key, s, str(ok)])
	print("YAW DONE")
	quit(0)
