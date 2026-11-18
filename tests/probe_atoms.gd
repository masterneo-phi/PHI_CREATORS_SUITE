extends SceneTree
## 解析用: Metro の :S の引用アトムの形を CC/DD 別に集める

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var swt := PhiSwt.load_file(
			"/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld/phi.swt")
	var seen := {}
	for rec in swt.records:
		if String(rec["kind"]) != "S":
			continue
		var f: Dictionary = rec["fields"]
		for side in ["cond", "act"]:
			var code := int(f["cc"]) if side == "cond" else int(f["dd"])
			var atoms: Array = f[side]
			for a in atoms:
				var s := String(a)
				if s.begins_with("\""):
					var key := "%s%02d" % ["C" if side == "cond" else "D", code]
					var lst: Array = seen.get(key, [])
					if lst.size() < 3:
						lst.append(s.substr(0, 60))
						seen[key] = lst
	var keys := seen.keys()
	keys.sort()
	for k in keys:
		print(k, " -> ", seen[k])
	quit(0)
