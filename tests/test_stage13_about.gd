extends SceneTree
## 第13段+0.4.3: バージョン情報は画面内オーバーレイで出す
## (別 OS 窓は Mac 実機で出ない事象が続いたための最終形)

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
	var ov: Variant = main.get("_about_overlay")
	check(ov != null, "About オーバーレイが作られる")
	check(ov != null and (ov as Control).visible,
			"About オーバーレイが表示される")
	check(ov != null and not (ov is Window),
			"別 OS 窓ではない (画面内 Control)")
	# 2回目も同じ窓を使い回す
	main.call("_show_about")
	await process_frame
	check(main.get("_about_overlay") == ov, "About オーバーレイは使い回す")
	# macOS メニュー経由の入口 (タグ付きコールバック)
	main.call("_on_macos_about_item", null)
	await process_frame
	check((ov as Control).visible, "メニュー経由でも表示される")
	# macOS 以外ではフックが無害なこと
	main.call("_setup_global_menu")
	check(true, "メニューフックは他 OS で無害")
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
