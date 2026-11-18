extends SceneTree
## 確認用: td と od (elb_p02 選択) を 1600x1000 で撮る

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1600, 1000)
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("od", "gra_root",
			"/home/hatch/workspace/.zipstage/mac")
	cfg.save("user://creators.cfg")
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
	await process_frame
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check3_td.png")
	main.call("_on_editor_selected", 4) # オブジェクト
	await process_frame
	var od_ed = main.get("_editors")["od"]
	var project = main.get("_project")
	var idx := -1
	for i in project.od.records.size():
		var rec: Dictionary = project.od.records[i]
		if String(rec["kind"]) == "O" and \
				String(rec["fields"]["gname"]) == "elb_p02":
			idx = i
			break
	od_ed.call("_show", idx)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check3_od.png")
	print("saved check3, od idx=", idx)
	quit(0)
