extends SceneTree
## 第7段: スイッチ AI サポート。
## - 依頼文 (文脈) に世界名・書式・CC/DD 表・実例が入る
## - 検証: 正常な :S 行は通り、異常な行 (解釈不可・未定義コード・
##   範囲外座標・非 :S 行) は理由付きで弾かれる
## - 取り込んだ行が serialize に現れる

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
	var tmp := "/tmp/creators_test_world7"
	OS.execute("rm", ["-rf", tmp])
	OS.execute("cp", ["-r",
			"/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld", tmp])
	var p := WorldProject.new()
	_check(p.open(tmp), "world opens")
	# --- 依頼文 ---
	var ctx := SwtAi.build_context(p)
	_check(ctx.contains("Metro Planetarium"), "context has world name")
	_check(ctx.contains("条件 (CC)"), "context has CC table")
	_check(ctx.contains("動作 (DD)"), "context has DD table")
	_check(ctx.contains(":S 003 013 03"), "context has example")
	_check(ctx.contains("作りたい仕掛け"), "context has request slot")
	# --- 正常な行 (実在データから往復一致する :S を1つ) ---
	var good := ""
	for i in p.swt.records.size():
		var rec := p.swt.records[i]
		if String(rec["kind"]) == "S" \
				and PhiSwt.build_line(rec) == p.swt.raw_lines.line_text(i):
			good = p.swt.raw_lines.line_text(i)
			break
	_check(good != "", "found a round-trip :S line")
	var r1 := SwtAi.validate_lines(good, p.map_size)
	_check((r1["ok"] as Array).size() == 1 and (r1["errors"] as Array).is_empty(),
			"good line passes: " + str(r1["errors"]))
	# 日本語メッセージ付きの行
	var jp := ":S 010 010 06 00 0000 010 010 16 0 \"テストです\""
	var r2 := SwtAi.validate_lines(jp, p.map_size)
	_check((r2["ok"] as Array).size() == 1,
			"japanese line passes: " + str(r2["errors"]))
	# --- 異常な行 ---
	var r3 := SwtAi.validate_lines("hello world", p.map_size)
	_check((r3["ok"] as Array).is_empty() and not (r3["errors"] as Array).is_empty(),
			"non-:S rejected")
	var r4 := SwtAi.validate_lines(
			":S 001 001 99 0000 001 001 16 0 \"x\"", p.map_size)
	_check((r4["ok"] as Array).is_empty(), "undefined CC rejected")
	var r5 := SwtAi.validate_lines(
			":S 300 001 06 00 0000 300 001 13 1", p.map_size)
	_check((r5["ok"] as Array).is_empty(), "out-of-range coord rejected")
	var r6 := SwtAi.validate_lines(":S abc", p.map_size)
	_check((r6["ok"] as Array).is_empty(), "garbage :S rejected")
	# --- 取り込み → serialize ---
	var before := 0
	for rec in p.swt.records:
		if String(rec["kind"]) == "S":
			before += 1
	for rec in r1["ok"]:
		p.swt.add_record(rec)
	for rec in r2["ok"]:
		p.swt.add_record(rec)
	var bytes := p.swt.serialize()
	var p2 := PhiSwt.parse(PhiRawLines.from_bytes(bytes))
	var after := 0
	for rec in p2.records:
		if String(rec["kind"]) == "S":
			after += 1
	_check(after == before + 2, "imported lines serialized (%d -> %d)"
			% [before, after])
	print("stage7 checks: ", _checks, " failures: ", _failures)
	quit(1 if _failures > 0 else 0)
