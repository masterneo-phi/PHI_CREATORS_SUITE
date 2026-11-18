extends SceneTree
## About ダイアログ表示の確認用プローブ

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1280, 860)
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.call("_show_about")
	await create_timer(1.5).timeout
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_about.png")
		print("saved about shot")
	quit(0)
