extends SceneTree
## 第5段: UI 改善。
## - エディタの並び (マップはクリエイトの下、スイッチの上)
## - テーマのフォントサイズ (NeoPHI 並み)
## - クリエイトはブロック単位 (1ブロック = 1レシピ)
## - エリア選択でマップ上に強調表示される
## - 自動保存チェックで dirty な world が保存される

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
	if FileAccess.file_exists("user://creators.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://creators.cfg"))
	# --- 並び順 ---
	var MainScript: GDScript = load("res://scripts/main.gd")
	var scenes: Array = []
	for e in MainScript.EDITORS:
		scenes.append(String(e["scene"]))
	_check(scenes == ["td", "announce", "map", "swt", "od", "ed", "crt",
			"ex", "ad"], "editor order: " + str(scenes))
	# --- クリエイトのブロック化 (モデル) ---
	var crt := PhiCrt.load_file(
			"res://tests/fixtures/realworld/phi.crt")
	_check(crt != null, "realworld crt loads")
	var terms := 0
	for r in crt.records:
		if String(r["kind"]) == "term":
			terms += 1
	var blocks := crt.blocks()
	_check(blocks.size() == terms and terms >= 5,
			"blocks == recipes (%d)" % blocks.size())
	var expected_blocks := blocks.size()
	_check(crt.block_summary(blocks[0]).length() > 3, "block summary")
	# ブロック削除で records がその分だけ減る
	var before := crt.records.size()
	var b0 := blocks[0]
	var span := int(b0["end"]) - int(b0["start"]) + 1
	for i in range(int(b0["end"]), int(b0["start"]) - 1, -1):
		crt.remove_record(i)
	_check(crt.records.size() == before - span, "block removal shrinks")
	# --- 画面 ---
	var tmp := "/tmp/creators_test_world5"
	OS.execute("rm", ["-rf", tmp])
	OS.execute("cp", ["-r",
			"/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld", tmp])
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.theme != null and main.theme.default_font_size >= 27,
			"theme font size")
	_check(int(main.call("_editor_index", "map")) == 2, "map index")
	_check(int(main.call("_editor_index", "swt")) == 3, "swt index")
	main.open_world(tmp)
	await process_frame
	# クリエイトエディタ: 一覧 = レシピ数
	main.call("_on_editor_selected", 6)
	await process_frame
	var crt_ed = main.get("_editors")["crt"]
	_check(crt_ed._list.item_count == expected_blocks,
			"crt list is per-recipe (%d)" % crt_ed._list.item_count)
	crt_ed._list.select(0)
	crt_ed._show(0)
	await process_frame
	_check(crt_ed._detail.get_child_count() > 3, "crt detail shows block")
	# マップ: エリア選択で強調表示
	main.call("_on_editor_selected", 2)
	await process_frame
	var map_ed = main.get("_editors")["map"]
	_check(map_ed._canvas.cell_px >= 24, "map default zoom 24")
	_check(map_ed._hsb != null and map_ed._vsb != null, "scrollbars exist")
	map_ed._area_list.select(0)
	map_ed._on_area_selected(0)
	_check(map_ed._canvas.highlight_area >= 0, "area highlighted")
	map_ed._on_hsb(40.0)
	_check(absf(map_ed._canvas.offset.x - 40.0) < 0.01, "hsb moves view")
	# 自動保存: td を dirty にして tick を呼ぶ
	var td = main.get("_project").td
	var rec: Dictionary = td.find_record("N")
	rec["fields"]["name"] = "Auto Save Test"
	td.touch(rec)
	main._autosave_check.button_pressed = true
	main.call("_on_autosave_tick")
	var td2 := PhiTd.load_file(tmp.path_join("phi.td"))
	_check(String(td2.find_record("N")["fields"]["name"]) == "Auto Save Test",
			"autosave wrote phi.td")
	# About 窓 (第13段: Mac で出ない AcceptDialog をやめ通常 Window に。
	# transparent + 非 AcceptDialog であること)
	main.call("_show_about")
	await process_frame
	var about_win = main.get("_about_window")
	_check(about_win is Window and not (about_win is AcceptDialog)
			and (about_win as Window).transparent
			and (about_win as Window).visible,
			"about is a transparent plain window")
	if about_win != null:
		(about_win as Window).hide()
	print("stage5 checks: ", _checks, " failures: ", _failures)
	quit(1 if _failures > 0 else 0)