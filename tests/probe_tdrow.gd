extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _dump(c: Control, depth: int) -> void:
	var t := ""
	if c is Label: t = " text=" + (c as Label).text.substr(0, 10)
	if c is CheckBox: t = " text=" + (c as CheckBox).text.substr(0, 10)
	print("  ".repeat(depth), c.get_class(), " min=", int(c.get_combined_minimum_size().x), t)
	for ch in c.get_children():
		if ch is Control:
			_dump(ch, depth + 1)

func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1600, 1000)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
	await process_frame
	var box: VBoxContainer = main.get("_editors")["td"].get("_box")
	for row in box.get_children():
		var rc := row as Control
		if rc != null and rc.get_combined_minimum_size().x > 1250:
			_dump(rc, 0)
	quit(0)
