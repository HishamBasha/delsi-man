@tool
class_name StairsObstacle
extends Node3D
const Art = preload("res://scripts/art.gd")

## One jump of a three-jump stair set, built from primitive boxes.
## kind 6 = the big stair flight (rising steps, each jump clears higher),
## kind 7 = the building stair (a porch block: small -> bigger -> third,
## all three at the same height). The course spawns three of these in a row
## with gaps wider than one hop, so every step needs its own timed jump.
@export_enum("Stairs", "Building Stair") var stair_type := 0:
	set(value):
		stair_type = value
		_refresh()
@export var radius := 1.2:
	set(value):
		radius = value
		_refresh()
## Top of the flight / block: the visual mass the hero sails over.
@export var height := 1.3:
	set(value):
		height = value
		_refresh()
## Which of the three steps this node is (0..2); drives the climb.
@export var step_index := 0:
	set(value):
		step_index = value
		_refresh()
## Runner height (metres) required to clear this step without a hit.
@export var clear_height := 1.15:
	set(value):
		clear_height = value
		_refresh()
@export var accent := Color("f0c16b"):
	set(value):
		accent = value
		_refresh()

var built := false

func configure(new_type: int, new_radius: float, new_height: float, new_clear: float, new_step: int) -> void:
	stair_type = new_type
	radius = new_radius
	height = new_height
	clear_height = new_clear
	step_index = new_step

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
	set_meta("kind", 6 + stair_type)
	set_meta("radius", radius)
	set_meta("clear", clear_height)
	set_meta("step", step_index)

func _rebuild() -> void:
	for child in get_children():
		child.free()
	_build()

func _build() -> void:
	if stair_type == 0:
		_build_flight()
	else:
		_build_block()

## A flight of four rising treads climbing away from the runner (-z), so the
## hop reads as running up the stairs. The label sits on the tallest riser,
## the one facing the approach.
func _build_flight() -> void:
	var tread_count := 4
	var depth := 0.62
	var span := radius * 2.0
	var rise := height / tread_count
	var stone := Color("b9ad96")
	var z_front := depth * tread_count * 0.5
	for i in range(tread_count):
		var h = rise * float(i + 1)
		var z = z_front - (float(i) + 0.5) * depth
		var tone = stone.lerp(Color("8e836f"), float(i) / float(tread_count))
		Art.box(self, Vector3(0, h * 0.5, z), Vector3(span, h, depth), tone)
		Art.box(self, Vector3(0, h + 0.03, z), Vector3(span + 0.06, 0.06, depth),
			accent if i == tread_count - 1 else tone.lightened(0.18), i == tread_count - 1)
	var top_riser_z = z_front - (float(tread_count - 1) + 0.5) * depth + depth * 0.5
	Art.label(self, Vector3(0, height - rise * 0.5, top_riser_z + 0.03), "STAIRS", Color("3c3a35"), 26)
	Art.box(self, Vector3(0, -0.01, 0), Vector3(span + 0.5, 0.14, depth * tread_count + 0.5), accent, false)

## A building's entrance step: one solid block with a two-step porch on the
## runner's side, so the jump reads as climbing in. The width grows with
## step_index (small -> bigger -> third) while the height stays the same.
func _build_block() -> void:
	var span := radius * 2.0
	var depth := 1.9
	var front := depth * 0.5
	var body := Color("cdc3ad").darkened(0.04 * float(step_index))
	Art.box(self, Vector3(0, height * 0.5, 0), Vector3(span, height, depth), body)
	# Porch treads on the approach side (+z): lower one further out.
	Art.box(self, Vector3(0, height * 0.28, front + 0.25), Vector3(span * 0.92, height * 0.56, 0.5), body.darkened(0.05))
	Art.box(self, Vector3(0, height * 0.14, front + 0.75), Vector3(span * 0.8, height * 0.28, 0.5), body.darkened(0.1))
	Art.box(self, Vector3(0, height + 0.05, 0), Vector3(span + 0.14, 0.1, depth + 0.14), accent, true)
	Art.box(self, Vector3(0, height * 0.62, front + 0.02), Vector3(span, 0.14, 0.05), accent.darkened(0.2))
	Art.label(self, Vector3(0, height * 0.82, front + 0.03), "STEPS", Color("3c3a35"), 26)
	Art.box(self, Vector3(0, -0.01, front * 0.5), Vector3(span + 0.4, 0.14, depth + 1.3), accent, false)
