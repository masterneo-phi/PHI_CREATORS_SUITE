extends SceneTree
## TD エディタの行ごとの最小幅を測るプローブ

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1600, 1000)
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
	await process_frame
	var td = main.get("_editors")["td"]
	var box: VBoxContainer = td.get("_box")
	print("box min: ", box.get_combined_minimum_size())
	for row in box.get_children():
		var row_c := row as Control
		if row_c == null:
			continue
		var mw := row_c.get_combined_minimum_size().x
		if mw > 900:
			var desc := ""
			for c in row.get_children():
				if c is Label:
					desc += "[L:%s] " % (c as Label).text.substr(0, 14)
				elif c is CheckBox:
					desc += "[C:%s] " % (c as CheckBox).text.substr(0, 14)
				elif c is HBoxContainer:
					for cc in c.get_children():
						if cc is CheckBox:
							desc += "[hC:%s] " % (cc as CheckBox).text.substr(0, 12)
						elif cc is SpinBox:
							desc += "[hS] "
						elif cc is LineEdit:
							desc += "[hE] "
				else:
					desc += "[%s] " % c.get_class()
			print("row min ", int(mw), ": ", desc)
	quit(0)
