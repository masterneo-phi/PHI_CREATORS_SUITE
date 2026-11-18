extends SceneTree
## マップ拡大 ×2 の確認用プローブ

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
	main.call("_on_editor_selected", 2) # マップ
	await process_frame
	var map_ed = main.get("_editors")["map"]
	map_ed.set("_zoom_2x", true)
	map_ed.call("_apply_zoom")
	await create_timer(1.5).timeout
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_map2x.png")
		print("saved map2x shot")
	quit(0)
