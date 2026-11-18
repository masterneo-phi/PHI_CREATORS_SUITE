extends SceneTree
## 第4段a: 既存 world の読み込みと座標のマップ指定。
## - 実サーバの world フォルダ (タブ区切り phi_dm.cnf、phi.crt/ex/ad
##   無し) を開ける。cnf からの寸法読みは phi.dd が無くても効く。
## - エネミーの出現位置とスイッチの設置位置を、マップをクリック
##   して指定できる (キャンセルも)。

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	if FileAccess.file_exists("user://creators.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://creators.cfg"))
	# --- 既存 world (実サーバのフォルダ) を開く ---
	var srv := "/tmp/creators_test_serverworld"
	OS.execute("rm", ["-rf", srv])
	OS.execute("cp", ["-r", "/home/hatch/workspace/phi-server/world", srv])
	var p := WorldProject.new()
	_check(p.open(srv), "server world opens")
	_check(p.map_size == Vector2i(8, 8), "map size from tab cnf: " + str(p.map_size))
	_check(p.crt == null and p.ex == null and p.ad == null,
			"missing files stay null")
	_check(p.ed != null and p.swt != null and p.dd != null, "present files load")
	OS.execute("rm", [srv.path_join("phi.dd")])
	var p2 := WorldProject.new()
	_check(p2.open(srv), "server world opens without dd")
	_check(p2.map_size == Vector2i(8, 8), "cnf size without dd: " + str(p2.map_size))
	# --- 画面: 全エディタが開ける (不足ファイル込み) ---
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.open_world(srv)
	await process_frame
	for idx in range(9):
		main.call("_on_editor_selected", idx)
		await process_frame
	_check(true, "editors switched on partial world")
	# --- エネミーの出現位置をマップで指定 ---
	var tmp := "/tmp/creators_test_world4"
	OS.execute("rm", ["-rf", tmp])
	OS.execute("cp", ["-r",
			"/home/hatch/workspace/phi-creators-godot/tests/fixtures/testworld", tmp])
	main.open_world(tmp)
	await process_frame
	main.call("_on_editor_selected", 3) # エネミー
	await process_frame
	var editors: Dictionary = main.get("_editors")
	var ed_editor: Control = editors["ed"]
	ed_editor.call("_on_enemy_selected", 0)
	await process_frame
	var pick_btn := _find_button(ed_editor, "出現位置をマップで指定")
	_check(pick_btn != null, "ed pick button exists")
	pick_btn.pressed.emit()
	await process_frame
	var map_editor: Control = editors["map"]
	var canvas: MapCanvas = map_editor.get("_canvas")
	_check(canvas.pick_mode, "canvas in pick mode")
	_check(canvas.spawn_points.size() > 0, "spawn marks present")
	canvas.coord_picked.emit(3, 4)
	await process_frame
	var proj: WorldProject = main.get("_project")
	var hf: Dictionary = proj.ed.records[int(proj.ed.blocks()[0]["header"])]["fields"]
	_check(String(hf["ix"]) == "003" and String(hf["iy"]) == "004",
			"spawn set from map: %s,%s" % [String(hf["ix"]), String(hf["iy"])])
	_check(not canvas.pick_mode, "pick mode off after pick")
	_check((main.get("_host") as Container).get_children().has(ed_editor),
			"returned to ed editor after pick")
	# キャンセルでは変わらない
	ed_editor.call("_on_enemy_selected", 0)
	await process_frame
	pick_btn = _find_button(ed_editor, "出現位置をマップで指定")
	pick_btn.pressed.emit()
	await process_frame
	canvas.pick_cancelled.emit()
	await process_frame
	_check(String(hf["ix"]) == "003" and String(hf["iy"]) == "004",
			"cancel keeps values")
	# --- スイッチの設置位置をマップで指定 (実世界データ) ---
	var rw := "/tmp/creators_test_world4b"
	OS.execute("rm", ["-rf", rw])
	OS.execute("cp", ["-r",
			"/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld", rw])
	main.open_world(rw)
	await process_frame
	main.call("_on_editor_selected", 2) # スイッチ
	await process_frame
	var swt_editor: Control = editors["swt"]
	var proj2: WorldProject = main.get("_project")
	var row := -1
	var rec_idx := -1
	var indices: Array = swt_editor.get("_indices")
	for r in indices.size():
		if String(proj2.swt.records[int(indices[r])]["kind"]) == "S":
			row = r
			rec_idx = int(indices[r])
			break
	_check(row >= 0, "found an S record")
	swt_editor.call("_on_selected", row)
	await process_frame
	var swt_btn := _find_button(swt_editor, "設置位置をマップで指定")
	_check(swt_btn != null, "swt pick button exists")
	swt_btn.pressed.emit()
	await process_frame
	canvas = (editors["map"] as Control).get("_canvas")
	_check(canvas.switch_points.size() > 2000, "switch marks present: "
			+ str(canvas.switch_points.size()))
	canvas.coord_picked.emit(10, 11)
	await process_frame
	var sf: Dictionary = proj2.swt.records[rec_idx]["fields"]
	_check(int(sf["sx"]) == 10 and int(sf["sy"]) == 11,
			"switch pos set from map: %s,%s" % [str(sf["sx"]), str(sf["sy"])])
	print("test_stage4_pick: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
