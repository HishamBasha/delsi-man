@tool
class_name FinishMarker
extends Node3D
const Art = preload("res://scripts/art.gd")

@export var banner_text := "FINISH":
	set(value):
		banner_text = value
		_refresh()

var built := false

func _enter_tree() -> void:
	_write_meta()

func _ready() -> void:
	if built:
		return
	built = true
	_write_meta()
	_build()

func _refresh() -> void:
	_write_meta()
	if built and is_inside_tree():
		_rebuild()

func _write_meta() -> void:
	set_meta("kind", 11)

func _rebuild() -> void:
	for child in get_children():
		child.free()
	_build()

func _build() -> void:
	Art.box(self, Vector3(0, 0.06, 0), Vector3(13, 0.12, 1.4), Color("ffe38a"), true)
	for side in [-1, 1]:
		Art.box(self, Vector3(side * 6.2, 2.4, 0), Vector3(0.3, 4.8, 0.3), Color("2b3d55"))
	Art.box(self, Vector3(0, 4.7, 0), Vector3(13, 0.6, 0.45), Color("ffd45e"), true)
	Art.label(self, Vector3(0, 4.7, 0.3), banner_text, Color("3a2a12"), 64)
