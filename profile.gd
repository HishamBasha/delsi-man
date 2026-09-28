extends RefCounted
## Versioned, id-keyed progress. Missing fields survive additive content updates.
const PATH = "user://desli_profile.json"
static func read() -> Dictionary:
	# The previous project title selected a different Godot user-data directory.
	# Read it only as a fallback; subsequent writes use the renamed project folder.
	var source = PATH
	if not FileAccess.file_exists(source):
		source = OS.get_user_data_dir().get_base_dir().path_join("Desli Man/desli_profile.json")
	if FileAccess.file_exists(source):
		var data = JSON.parse_string(FileAccess.get_file_as_string(source))
		if data is Dictionary and data.get("version", 0) == 1:
			return data
	return {"version":1,"levels":{},"language":"en","assist":false}

static func write(data: Dictionary) -> bool:
	var f = FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(PATH + ".tmp", PATH) == OK

static func record(data: Dictionary, level_id: String, score: int, seconds: float) -> void:
	var old: Dictionary = data.levels.get(level_id, {})
	data.levels[level_id] = {"score":maxi(score, old.get("score",0)),"time":minf(seconds,old.get("time",1e9)),"completed":true}
