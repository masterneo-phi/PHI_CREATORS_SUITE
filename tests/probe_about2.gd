extends SceneTree
## 確認用: バージョン情報 (通常 Window 版) を 1600x1000 で撮る

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1600, 1000)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
	await process_frame
	main.call("_show_about")
	await create_timer(0.9).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check5_about.png")
	print("saved check5_about")
	quit(0)
