extends SceneTree
## 第10段: オブジェクトのグラ表示 (全体+向きフレーム) とグラ名プルダウン

var _failures := 0
var _checks := 0


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("ok: ", label)
	else:
		_failures += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var gra_dir := ProjectSettings.globalize_path("res://tests/fixtures/gra")
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("od", "gra_root", gra_dir)
	cfg.save("user://creators.cfg")
	var project := WorldProject.new()
	check(project.open("res://tests/fixtures/realworld"), "world を開ける")
	var ed_script: GDScript = load("res://scripts/od_editor.gd")
	var editor = ed_script.new()
	root.add_child(editor)
	editor.setup(project)
	await process_frame
	var names: Array = editor.get("_gra_names")
	check(names.has("elb_p02"), "グラ一覧に elb_p02 が入る")
	var paths: Dictionary = editor.get("_gra_paths")
	check(paths.has("elb_p02"), "グラパスが引ける")
	var idx := -1
	for i in project.od.records.size():
		var rec: Dictionary = project.od.records[i]
		if String(rec["kind"]) == "O" and \
				String(rec["fields"]["gname"]) == "elb_p02":
			idx = i
			break
	check(idx >= 0, "elb_p02 のオブジェクトがある")
	editor.call("_show", idx)
	await process_frame
	var sheet: TextureRect = editor.get("_sheet_rect")
	check(sheet != null and sheet.texture != null, "全体グラが表示される")
	var frame: TextureRect = editor.get("_frame_rect")
	check(frame != null and frame.texture != null, "向きフレームが表示される")
	var f: Dictionary = project.od.records[idx]["fields"]
	var before: Texture2D = frame.texture
	f["dir"] = (int(f["dir"]) + 1) % 4
	editor.call("_update_preview", f)
	await process_frame
	check(frame.texture != null and frame.texture != before,
			"向きを変えるとフレームが変わる")
	f["gname"] = "no_such_gra"
	editor.call("_update_preview", f)
	check(sheet.texture == null, "無いグラはプレビューが空になる")
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
