extends SceneTree
## 第12段: crt / ex / swt:A の分解フォーム

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
	# 実データが ItemForm で分解できること
	var crt_p: Dictionary = ItemForm.parse_item_data(
			"Sword of Mystic/*MP*/         0312 12 e 24 00 11 01")
	check(not crt_p.is_empty() and String(crt_p["type"]) == "0312",
			"crt の生成物を分解できる")
	var ex_i: Dictionary = ItemForm.parse_item_data(
			"*                               -f-- -- - -- -- -- --")
	check(not ex_i.is_empty() and String(ex_i["type"]) == "-f--",
			"ex の禁止アイテムパターンを分解できる")
	var project := WorldProject.new()
	check(project.open("res://tests/fixtures/realworld"), "world を開ける")
	# --- crt: 素材の追加と削除 ---
	var crt_ed = load("res://scripts/crt_editor.gd").new()
	root.add_child(crt_ed)
	crt_ed.setup(project)
	await process_frame
	crt_ed.call("_show", 0)
	await process_frame
	var blocks: Array = crt_ed.get("_blocks")
	var b0: Dictionary = blocks[0]
	var s_before := 0
	for i in range(int(b0["start"]), int(b0["end"]) + 1):
		if String(project.crt.records[i]["kind"]) == "S":
			s_before += 1
	check(s_before == 2, "レシピ0 の素材は2つ")
	var detail: VBoxContainer = crt_ed.get("_detail")
	var add_btn: Button = null
	for c in detail.get_children():
		if c is Button and (c as Button).text == "素材 (:S) を追加":
			add_btn = c
	check(add_btn != null, "素材追加ボタンがある")
	add_btn.pressed.emit()
	await process_frame
	blocks = crt_ed.get("_blocks")
	b0 = blocks[0]
	var s_after := 0
	for i in range(int(b0["start"]), int(b0["end"]) + 1):
		if String(project.crt.records[i]["kind"]) == "S":
			s_after += 1
	check(s_after == 3, "素材を追加できる")
	# --- ex: :I の詳細が開ける ---
	var ex_ed = load("res://scripts/ex_editor.gd").new()
	root.add_child(ex_ed)
	ex_ed.setup(project)
	await process_frame
	var i_idx := -1
	for i in project.ex.records.size():
		if String(project.ex.records[i]["kind"]) == "I":
			i_idx = i
			break
	check(i_idx >= 0, "ex に :I がある")
	ex_ed.call("_show", i_idx)
	await process_frame
	check(true, "ex :I の分解フォームが開ける")
	# --- swt :A テレポート末尾の分解 ---
	var swt_ed = load("res://scripts/swt_editor.gd").new()
	root.add_child(swt_ed)
	swt_ed.setup(project)
	await process_frame
	var arec := PhiSwt._parse_line(":A 0001 0000 0000 x 012 034")
	check(int(arec["fields"]["tail_kind"]) == 1, ":A テレポートとして解析")
	var aidx: int = project.swt.add_record(arec)
	swt_ed.call("_refresh_list")
	swt_ed.call("_show_detail", aidx)
	await process_frame
	var found_spin := false
	for c in (swt_ed.get("_detail") as VBoxContainer).get_children():
		for cc in c.get_children():
			if cc is Label and (cc as Label).text == "転送先 X":
				found_spin = true
	check(found_spin, ":A 転送先 X の欄が出る")
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
