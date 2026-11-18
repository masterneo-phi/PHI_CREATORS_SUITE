extends SceneTree
## AI サポートダイアログの確認用プローブ

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1900, 1300)
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
	await process_frame
	main.call("_on_editor_selected", 3) # スイッチ
	await process_frame
	var swt_editor = main.get("_editors")["swt"]
	swt_editor._show_ai_ask()
	await create_timer(1.5).timeout
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_ai_ask.png")
		print("saved ai ask shot")
	quit(0)
