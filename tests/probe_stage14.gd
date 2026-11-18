extends SceneTree
## 第14段の見た目確認: ×2 で右下端までスクロールしても枠外に描かないこと、
## Undo/Redo ボタン、更新のお知らせ窓

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
	main.call("_on_editor_selected", 2)
	await process_frame
	var map_ed = main.get("_editors")["map"]
	map_ed.set("_zoom_2x", true)
	map_ed.call("_apply_zoom")
	var canvas = map_ed.get("_canvas")
	canvas.offset = Vector2(190, 230)
	canvas.queue_redraw()
	await process_frame
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check6_map2x.png")
	# 1マス塗って Undo ボタンが有効になることも見る
	canvas.mode = "terrain"
	canvas.pen_code = 0x11
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(200, 240))
	canvas.call("_end_stroke")
	await process_frame
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check6_undo_btn.png")
	# 更新のお知らせ窓
	main.set("_update_info", {"tag": "v0.5.0", "name": "PHI CREATORS SUITE v0.5.0",
			"url": "https://github.com/masterneo-phi/PHI_CREATORS_SUITE/releases"})
	main.call("_show_update_dialog")
	await process_frame
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(
			"/home/hatch/workspace/probe-shots/check6_update.png")
	print("done")
	quit(0)
