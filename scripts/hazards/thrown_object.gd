@tool
class_name ThrownObject
extends Node3D
const Art = preload("res://scripts/art.gd")
const City = preload("res://scripts/city.gd")

@export var radius := 0.85:
	set(value):
		radius = value
		_refresh()
@export var accent := Color("ef8064"):
	set(value):
		accent = value
		_refresh()
@export_enum("Crate", "Pedestrian", "Handcart", "Motorbike", "Car", "Truck", "Barrel") var style := 0:
	set(value):
		style = value
		_refresh()
@export var spin := 0.0:
	set(value):
		spin = value
		_refresh()

var built := false

func configure(new_radius: float, new_accent: Color, new_style: int = -1, new_spin: float = 0.0) -> void:
	radius = new_radius
	accent = new_accent
	if new_style >= 0:
		style = new_style
	spin = new_spin

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
	set_meta("kind", 5)
	set_meta("radius", radius)
	set_meta("style", style)
	set_meta("spin", spin)

func _rebuild() -> void:
	for child in get_children():
		child.free()
	_build()

func _build() -> void:
	var body = Node3D.new()
	add_child(body)
	body.scale = Vector3.ONE * maxf(0.55, radius / 0.85)
	match style:
		1:
			City.pedestrian(body, Vector3.ZERO, accent, 0)
		2:
			City.vehicle(body, Vector3.ZERO, accent, 3)
		3:
			City.vehicle(body, Vector3.ZERO, accent, 2)
		4:
			City.vehicle(body, Vector3.ZERO, accent, 0)
		5:
			City.vehicle(body, Vector3.ZERO, accent, 1)
		6:
			City.barrel(body, Vector3.ZERO, accent)
		_:
			Art.box(body, Vector3(0, 0.52, 0), Vector3(1.65, 1.25, 1.65), accent, true)
			Art.box(body, Vector3(0, 0.53, 0.86), Vector3(1.2, 0.78, 0.08), Color("ffe2b8"), true)
			Art.box(body, Vector3(0, 1.2, 0), Vector3(1.9, 0.12, 1.9), Color("fff1ba"), true)
			Art.label(body, Vector3(0, 0.6, 0.93), "!", Color("43181a"), 42)
