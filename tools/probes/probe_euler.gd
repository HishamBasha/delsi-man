extends SceneTree
## Checks how Godot composes EULER_ORDER_YXZ so the heading pin in the hero
## bake keeps each pose's pitch in the character's own frame.

func _initialize() -> void:
	var x := 0.3
	var y := 1.0
	var z := 0.0
	var actual := Basis.from_euler(Vector3(x, y, z), EULER_ORDER_YXZ) * Vector3(0, 0, -1)
	var outermost := Basis(Vector3.UP, y) * Basis(Vector3.RIGHT, x) * Basis(Vector3.FORWARD, z)
	var innermost := Basis(Vector3.FORWARD, z) * Basis(Vector3.RIGHT, x) * Basis(Vector3.UP, y)
	print("actual       = %s" % str(actual))
	print("y outermost  = %s" % str(outermost * Vector3(0, 0, -1)))
	print("y innermost  = %s" % str(innermost * Vector3(0, 0, -1)))
	quit(0)
