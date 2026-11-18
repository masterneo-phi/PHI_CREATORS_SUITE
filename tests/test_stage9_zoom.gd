extends SceneTree
## 第9段: マップ拡大 ×2 スイッチ + macOS メニュー接続の安全確認。
## - ×2 を入れると cell_px が倍になり、外すと戻る
## - _setup_global_menu は macOS 以外では何もしない (落ちない)

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var cfg_path := ProjectSettings.globalize_path("user://creators.cfg")
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.call("_setup_global_menu") # Linux では早期 return のはず
	_check(true, "global menu setup safe off-macOS")
	main.open_world(ProjectSettings.globalize_path(
			"res://tests/fixtures/realworld"))
	await process_frame
	main.call("_on_editor_selected", 2) # マップ
	await process_frame
	var map_ed = main.get("_editors")["map"]
	var canvas = map_ed.get("_canvas")
	_check(int(canvas.get("cell_px")) == 24, "default zoom 24: %d"
			% int(canvas.get("cell_px")))
	map_ed.set("_zoom_2x", true)
	map_ed.call("_apply_zoom")
	_check(int(canvas.get("cell_px")) == 48, "2x zoom 48: %d"
			% int(canvas.get("cell_px")))
	map_ed.set("_zoom_base", 48)
	map_ed.call("_apply_zoom")
	_check(int(canvas.get("cell_px")) == 96, "2x zoom 96: %d"
			% int(canvas.get("cell_px")))
	map_ed.set("_zoom_2x", false)
	map_ed.call("_apply_zoom")
	_check(int(canvas.get("cell_px")) == 48, "back to 48")
	print("stage9 checks: ", _checks, " failures: ", _failures)
	quit(1 if _failures > 0 else 0)
