extends SceneTree
## ×2 拡大でマップがはみ出す件の再現確認: 主要コントロールの
## グローバル矩形を数値で出し、スクリーンショットも撮る

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("od", "gra_root",
			"/home/hatch/workspace/.zipstage/mac")
	cfg.save("user://creators.cfg")
	for sz in [Vector2i(1600, 1000), Vector2i(1150, 820)]:
		root.size = sz
		var main = load("res://main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
		await process_frame
		main.call("_on_editor_selected", 2) # マップ
		await process_frame
		var map_ed = main.get("_editors")["map"]
		map_ed.set("_zoom_2x", true)
		map_ed.call("_apply_zoom")
		var canvas = map_ed.get("_canvas")
		canvas.offset = Vector2(190, 230)
		canvas.queue_redraw()
		await process_frame
		await create_timer(0.6).timeout
		var frame = canvas.get_parent().get_parent().get_parent()
		var inner = frame.get_parent()
		var right_col = inner.get_child(1)
		print("win ", sz, " canvas=", canvas.get_global_rect(),
				" vsb=", (map_ed.get("_vsb") as Control).get_global_rect(),
				" frame=", (frame as Control).get_global_rect(),
				" right=", (right_col as Control).get_global_rect())
		root.get_texture().get_image().save_png(
				"/home/hatch/workspace/probe-shots/zoom2x_%d.png" % sz.x)
		main.queue_free()
		await process_frame
	print("done")
	quit(0)
