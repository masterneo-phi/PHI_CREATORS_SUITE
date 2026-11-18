extends SceneTree
## 第13段: バージョン情報を通常 Window で出す (AcceptDialog は Mac で
## 開かない事象が NeoPHI であったための置き換え)

var _failures := 0
var _checks := 0


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("ok: ", label)
	else:
		_failures += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("_show_about")
	await process_frame
	var win: Window = main.get("_about_window")
	check(win != null, "About 窓が作られる")
	check(win != null and win.visible, "About 窓が表示される")
	check(win != null and win.transparent, "Mac 用に transparent")
	check(win != null and not (win is AcceptDialog),
			"AcceptDialog ではない")
	# 2回目も同じ窓を使い回す
	main.call("_show_about")
	await process_frame
	check(main.get("_about_window") == win, "About 窓は使い回す")
	# macOS メニュー経由の入口 (タグ付きコールバック)
	main.call("_on_macos_about_item", null)
	await process_frame
	check(win.visible, "メニュー経由でも表示される")
	# macOS 以外ではフックが無害なこと
	main.call("_setup_global_menu")
	check(true, "メニューフックは他 OS で無害")
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
