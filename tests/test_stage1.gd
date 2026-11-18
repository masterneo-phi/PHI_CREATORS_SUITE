extends SceneTree
## 第1段の統合テスト: WorldProject の読み込み→編集→保存と、
## メイン画面で3エディタが開けること。

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
	var tmp := "/tmp/creators_test_world"
	OS.execute("rm", ["-rf", tmp])
	OS.execute("cp", ["-r", "/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld", tmp])
	var p := WorldProject.new()
	_check(p.open(tmp), "project opens")
	_check(p.td.find_record("N")["fields"]["name"] == "Metro Planetarium",
			"world name read")
	_check(p.swt != null and p.swt.records.size() > 2900, "swt loaded")
	_check(not p.td_dirty(), "td clean at open")
	# 世界名を変更して保存
	var nrec := p.td.find_record("N")
	nrec["fields"]["name"] = "Renamed World"
	p.td.touch(nrec)
	_check(p.td_dirty(), "td dirty after edit")
	var before := FileAccess.get_file_as_bytes(tmp.path_join("phi.td"))
	var saved := p.save_all()
	_check(saved == ["phi.td"], "only phi.td saved: " + str(saved))
	_check(FileAccess.file_exists(tmp.path_join("phi.td.bak")), "bak created")
	var after := FileAccess.get_file_as_bytes(tmp.path_join("phi.td"))
	var td2 := PhiTd.parse(PhiRawLines.from_bytes(after))
	_check(td2.find_record("N")["fields"]["name"] == "Renamed World",
			"name persisted")
	# :N 以外の行がバイト不変であること
	var lines_before := PhiRawLines.from_bytes(before)
	var lines_after := PhiRawLines.from_bytes(after)
	_check(lines_before.line_count() == lines_after.line_count(),
			"line count stable")
	var same := true
	for i in lines_before.line_count():
		if lines_before.lines[i] == lines_after.lines[i]:
			continue
		if lines_before.line_text(i).begins_with(":N "):
			continue
		same = false
	_check(same, "only :N line changed")
	# 画面: 全エディタが開ける
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.open_world(tmp)
	await process_frame
	for idx in range(9):
		main.call("_on_editor_selected", idx)
		await process_frame
	_check(true, "editors switched without crash")
	# エネミー編集 → 保存で phi.ed だけが変わる
	_check(p.ed != null and p.ed.blocks().size() > 0, "ed loaded with blocks")
	var ed_before := FileAccess.get_file_as_bytes(tmp.path_join("phi.ed"))
	var hrec := p.ed.records[0]
	hrec["fields"]["mhp"] = "4321"
	p.ed.touch(hrec)
	var saved2 := p.save_all()
	_check(saved2 == ["phi.ed"], "only phi.ed saved: " + str(saved2))
	_check(FileAccess.get_file_as_bytes(tmp.path_join("phi.ed")) != ed_before,
			"phi.ed changed after edit")
	print("test_stage1: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
