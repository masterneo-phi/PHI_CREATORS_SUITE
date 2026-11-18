extends SceneTree
## 修正確認用: td / swt (項目選択状態) / ed (項目選択状態) を 1600x1000 で撮る

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
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check2_td.png")
	main.call("_on_editor_selected", 3) # スイッチ
	await process_frame
	var swt_ed = main.get("_editors")["swt"]
	var list: ItemList = swt_ed.get("_list")
	list.select(2)
	list.item_selected.emit(2)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check2_swt.png")
	main.call("_on_editor_selected", 5) # エネミー
	await process_frame
	var ed_ed = main.get("_editors")["ed"]
	var elist: ItemList = ed_ed.get("_list")
	elist.select(0)
	elist.item_selected.emit(0)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check2_ed.png")
	print("saved check2 shots")
	quit(0)
