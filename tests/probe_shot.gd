extends SceneTree
## スクリーンショット用プローブ: 実世界を開いて世界設定を表示する

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1700, 1200)
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
	await create_timer(2.5).timeout
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_td.png")
		print("saved td shot")
	main.call("_on_editor_selected", 6)
	await create_timer(2.5).timeout
	img = root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_swt.png")
		print("saved swt shot")
	main.call("_on_editor_selected", 2)
	await create_timer(1.0).timeout
	var ed_editor = main.get("_editors")["ed"]
	ed_editor._list.select(0)
	ed_editor._on_enemy_selected(0)
	await create_timer(2.0).timeout
	img = root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_ed.png")
		print("saved ed shot")
	main.call("_on_editor_selected", 3)
	await create_timer(2.0).timeout
	img = root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_od.png")
		print("saved od shot")
	main.call("_on_editor_selected", 4)
	await create_timer(1.0).timeout
	var crt_editor = main.get("_editors")["crt"]
	crt_editor._list.select(0)
	crt_editor._show(0)
	await create_timer(2.0).timeout
	img = root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_crt.png")
		print("saved crt shot")
	main.call("_on_editor_selected", 5)
	await create_timer(1.5).timeout
	var map_editor = main.get("_editors")["map"]
	map_editor._canvas.offset = Vector2(88, 2)
	map_editor._canvas.cell_px = 24
	map_editor._canvas.queue_redraw()
	await create_timer(2.0).timeout
	img = root.get_texture().get_image()
	if img != null:
		img.save_png("/home/hatch/workspace/probe-shots/creators_map.png")
		print("saved map shot")
	quit(0)
