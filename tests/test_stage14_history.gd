extends SceneTree
## 第14段: マップの Undo/Redo、×2 はみ出し対策 (clip)、更新チェック部品

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
	var base := "res://tests/fixtures/testworld"
	var dd := PhiDd.load_file(base + "/phi.dd", 8, 8)
	var fd := PhiFd.load_file(base + "/phi.fd", 8, 8)
	var od := PhiOd.load_file(base + "/phi.od")
	var canvas := MapCanvas.new()
	canvas.dd = dd
	canvas.fd = fd
	canvas.od = od
	root.add_child(canvas)
	_check(canvas.clip_contents, "canvas clips its drawing")

	# 地形ペン: 1ストロークで2マス塗る → Undo で両方戻る
	var before0 := dd.code_at(1, 1)
	var before1 := dd.code_at(2, 1)
	canvas.mode = "terrain"
	canvas.pen_code = 0x11
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(1, 1))
	canvas.call("_apply", Vector2i(2, 1))
	canvas.call("_end_stroke")
	_check(dd.code_at(1, 1) == 0x11 and dd.code_at(2, 1) == 0x11,
			"paint applied")
	_check(canvas.can_undo() and not canvas.can_redo(), "undo available")
	canvas.undo()
	_check(dd.code_at(1, 1) == before0 and dd.code_at(2, 1) == before1,
			"undo restores both cells")
	_check(canvas.can_redo(), "redo available")
	canvas.redo()
	_check(dd.code_at(1, 1) == 0x11, "redo re-applies")
	canvas.undo()

	# エリアペン
	var area_before := fd.code_at(1, 1)
	canvas.mode = "area"
	canvas.pen_area = 7
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(1, 1))
	canvas.call("_end_stroke")
	_check(fd.code_at(1, 1) == 7, "area painted")
	canvas.undo()
	_check(fd.code_at(1, 1) == area_before, "area undone")
	canvas.redo()
	_check(fd.code_at(1, 1) == 7, "area redone")
	canvas.undo()

	# 見た目 (:T): 追加 → Undo で消える → Redo で戻る
	canvas.mode = "surface"
	canvas.pen_code = 0x12
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(3, 3))
	canvas.call("_end_stroke")
	_check(canvas.call("_surface_pair_at", Vector2i(3, 3)) != "",
			"surface added")
	canvas.undo()
	_check(canvas.call("_surface_pair_at", Vector2i(3, 3)) == "",
			"surface removed by undo")
	canvas.redo()
	_check(canvas.call("_surface_pair_at", Vector2i(3, 3)) != "",
			"surface restored by redo")
	canvas.undo()

	# オブジェクト移動
	var oi := -1
	for i in od.records.size():
		if String(od.records[i]["kind"]) == "O":
			oi = i
			break
	_check(oi >= 0, "object exists")
	var of: Dictionary = od.records[oi]["fields"]
	of["x"] = 2
	of["y"] = 2
	od.touch(od.records[oi])
	var ox := 2
	var oy := 2
	canvas.mode = "object"
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(ox, oy))
	var tx := ox + 1 if ox + 1 < 8 else ox - 1
	canvas.call("_move_drag_obj", Vector2i(tx, oy))
	canvas.call("_end_stroke")
	_check(int(of["x"]) == tx, "object moved")
	canvas.undo()
	_check(int(of["x"]) == ox and int(of["y"]) == oy, "object move undone")
	canvas.redo()
	_check(int(of["x"]) == tx, "object move redone")

	# 変化のないストロークは履歴に積まれない
	var depth: int = (canvas.get("_undo_stack") as Array).size()
	canvas.mode = "terrain"
	canvas.pen_code = dd.code_at(0, 0)
	canvas.pen_roof = dd.roof_at(0, 0)
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(0, 0))
	canvas.call("_end_stroke")
	_check((canvas.get("_undo_stack") as Array).size() == depth,
			"no-change stroke not recorded")

	# 更新チェック部品 (NeoPHI 移植)
	_check(CreatorsUpdate.is_newer("v0.4.3", "0.4.2"), "newer patch")
	_check(CreatorsUpdate.is_newer("v0.5.0", "0.4.2"), "newer minor")
	_check(not CreatorsUpdate.is_newer("v0.4.2", "0.4.2"), "same not newer")
	_check(not CreatorsUpdate.is_newer("v0.4.1", "0.4.2"), "older not newer")
	var info := CreatorsUpdate.parse_latest(
			'{"tag_name":"v9.9.9","name":"Rel","html_url":"http://x"}')
	_check(String(info.get("tag", "")) == "v9.9.9"
			and String(info.get("url", "")) == "http://x", "parse latest")
	_check(CreatorsUpdate.parse_latest("not json").is_empty(),
			"parse failure is empty")
	_check(CreatorsUpdate.page_url({}) == CreatorsUpdate.RELEASES_URL,
			"page url fallback")

	print("stage14 checks: ", _checks, " failures: ", _failures)
	quit(1 if _failures > 0 else 0)
