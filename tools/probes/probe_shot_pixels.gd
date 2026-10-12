extends SceneTree
## Pixel statistics for docs/shots/course_*.png (mean/std/bucket counts) so a
## blank or flat render is caught without eyeballing the PNGs.

func _initialize() -> void:
	var dir := DirAccess.open("res://docs/shots")
	if dir == null:
		print("PROBE FAIL no docs/shots")
		quit(1)
		return
	var names := dir.get_files()
	names.sort()
	var fails := 0
	for f in names:
		if not (f.begins_with("course_") or f.begins_with("steer_")) or not f.ends_with(".png"):
			continue
		var img := Image.load_from_file("res://docs/shots/" + f)
		if img == null or img.is_empty():
			print("PIXEL %s LOADFAIL" % f)
			fails += 1
			continue
		var w := img.get_width()
		var h := img.get_height()
		var sum := 0.0
		var sum2 := 0.0
		var n := 0
		var buckets := {}
		var y := 0
		while y < h:
			var x := 0
			while x < w:
				var c := img.get_pixel(x, y)
				var l := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				sum += l
				sum2 += l * l
				n += 1
				var key := "%d%d%d" % [int(c.r * 7.99), int(c.g * 7.99), int(c.b * 7.99)]
				buckets[key] = int(buckets.get(key, 0)) + 1
				x += 6
			y += 6
		var mean := sum / n
		var std := sqrt(maxf(0.0, sum2 / n - mean * mean))
		var ok := std > 0.03 and buckets.size() > 24
		if not ok:
			fails += 1
		print("PIXEL %s %dx%d mean=%.1f std=%.1f buckets=%d %s" % [
			f, w, h, mean, std, buckets.size(), "ok" if ok else "FLAT"])
	print("PROBE DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
