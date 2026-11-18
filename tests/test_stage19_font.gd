extends SceneTree
## 第19段 (v0.5.1): フォントサイズを自由に変えられること
## テーマの既定サイズ・相対換算・ツールバーのスピン・cfg 保存・
## エディタ再構築による追随を確認する

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
	# --- テーマ: 引数で既定サイズが変わり、一覧の行高も追随する
	check(AppTheme.build().default_font_size == 27, "既定は 27")
	check(AppTheme.build(20).default_font_size == 20, "build(20) は 20")
	check(AppTheme.build(54).get_constant("item_height", "ItemList") == 92,
			"行高がサイズに比例する")
	# --- 相対換算: 基準 27 の相対指定が現在のテーマに比例する
	var host := Control.new()
	host.theme = AppTheme.build(36)
	root.add_child(host)
	var inner := Label.new()
	host.add_child(inner)
	await process_frame
	check(AppTheme.rel(inner, 27) == 36, "rel: 27 → そのまま基準")
	check(AppTheme.rel(inner, 20) == 27, "rel: 20 → 比例して 27")
	check(AppTheme.rel(inner, 30) == 40, "rel: 30 → 比例して 40")
	host.queue_free()

	# --- Main: スピンで変えるとテーマ・cfg・エディタに反映される
	var cfg_path := ProjectSettings.globalize_path("user://creators.cfg")
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)
	var dir := "/tmp/creators_stage19_world"
	OS.execute("rm", ["-rf", dir])
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("phi.td"), FileAccess.WRITE)
	f.store_buffer(Cp932.encode(":N New World\n:T 0\n:O O 20099 A 001 001 MSGT\n.\n"))
	f.close()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var spin: SpinBox = main.get("_font_spin")
	check(spin != null and int(spin.value) == 27, "スピンの初期値は 27")
	main.call("open_world", dir)
	await process_frame
	main.call("_on_editor_selected", 5) # エネミー
	await process_frame
	var before: Object = (main.get("_editors") as Dictionary)["ed"]
	spin.value = 32
	await process_frame
	await process_frame
	check(main.theme.default_font_size == 32, "テーマが 32 になる")
	check(int(main.call("_font_size_cfg")) == 32, "cfg に保存される")
	var after: Object = (main.get("_editors") as Dictionary)["ed"]
	check(after != null and after != before, "エディタが作り直される")
	check((main.get("_status_label") as Label).text.contains("32"),
			"状態表示に出る")
	spin.value = 18
	await process_frame
	check(main.theme.default_font_size == 18, "小さくもできる")
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
