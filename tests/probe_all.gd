extends SceneTree
## 全エディタを既定窓サイズ (1600x1000) で撮る確認用プローブ

const SHOTS: Array = [
	[0, "td"], [1, "announce"], [2, "map"], [3, "swt"], [4, "od"],
	[5, "ed"], [6, "crt"], [7, "ex"], [8, "ad"],
]


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
	for shot in SHOTS:
		main.call("_on_editor_selected", int(shot[0]))
		await create_timer(0.9).timeout
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png("/home/hatch/workspace/probe-shots/check_%s.png"
					% String(shot[1]))
	print("saved all-editor shots")
	quit(0)
