extends SceneTree
## V2.0 テストワールド (~/workspace/.v2test_world) をコピーして開き、
## phi.jb / phi.pt / 条件・動作 80・92 を含む phi.swt が壊れずに
## 編集・保存できることの統合テスト。原本には触らない。

const SRC := "/home/hatch/workspace/.v2test_world"
const DST := "/tmp/pcs_v2test_copy"
const FILES: Array[String] = ["phi.td", "phi.jb", "phi.pt", "phi.swt",
		"phi_dm.cnf"]

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _read(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b


func _initialize() -> void:
	Cp932.ensure_loaded()
	if not FileAccess.file_exists(SRC.path_join("phi.jb")):
		print("test_stage23_v2world: skipped (no .v2test_world)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(DST)
	for name in FILES:
		var f := FileAccess.open(DST.path_join(name), FileAccess.WRITE)
		f.store_buffer(_read(SRC.path_join(name)))
		f.close()
	var orig_swt := _read(SRC.path_join("phi.swt"))
	var orig_jb := _read(SRC.path_join("phi.jb"))
	var orig_pt := _read(SRC.path_join("phi.pt"))
	var p := WorldProject.new()
	_check(p.open(DST), "world open")
	_check(p.has_jb and p.jb != null, "phi.jb を読んだ")
	_check(p.has_pt and p.pt != null, "phi.pt を読んだ")
	_check(p.swt != null, "phi.swt を読んだ")
	# phi.jb の実効値 (テストワールドは全職業に :N を書いている)
	var n_count := 0
	for jr in p.jb.records:
		if String(jr["kind"]) == "N":
			n_count += 1
	_check(n_count == 9, "jb: :N が9件読めた (%d)" % n_count)
	_check(p.jb.job_name(1) == "戦士", "jb: 職業名が読めた")
	# phi.swt: 80/92 を含むレコードが化けず往復する
	var neo := 0
	var exact := 0
	for i in p.swt.records.size():
		var rec: Dictionary = p.swt.records[i]
		if String(rec["kind"]) != "S":
			continue
		var f: Dictionary = rec["fields"]
		if int(f.get("cc", 0)) in [80, 91, 92] \
				or int(f.get("dd", 0)) in [34, 51, 52, 80, 81, 82, 92]:
			neo += 1
			if PhiSwt.build_line(rec) == p.swt.raw_lines.line_text(i):
				exact += 1
	_check(neo > 0, "swt: NEO 番号のレコードがある (%d)" % neo)
	_check(exact == neo, "swt: NEO レコード全件が往復一致 (%d/%d)"
			% [exact, neo])
	# 無編集保存では何も書かれない
	var saved := p.save_all()
	_check(saved.is_empty(), "無編集では保存されない: %s" % str(saved))
	_check(_read(DST.path_join("phi.swt")) == orig_swt, "swt バイト不変")
	# phi.jb の職業名を1件だけ編集して保存
	var ri := p.jb.find_record("N", 1)
	_check(ri >= 0, "jb: 職業1の :N がある")
	var rec := p.jb.records[ri]
	var before := String(rec["fields"]["name"])
	rec["fields"]["name"] = before + "X"
	p.jb.touch(rec)
	saved = p.save_all()
	_check(saved == ["phi.jb"], "保存は phi.jb だけ: %s" % str(saved))
	_check(FileAccess.file_exists(DST.path_join("phi.jb.bak")),
			"phi.jb.bak ができた")
	_check(_read(DST.path_join("phi.jb.bak")) == orig_jb,
			".bak は元の phi.jb")
	_check(_read(DST.path_join("phi.swt")) == orig_swt,
			"swt は触っていないので不変")
	_check(_read(DST.path_join("phi.pt")) == orig_pt, "pt バイト不変")
	# 保存後の phi.jb: 変わったのは対象行だけで、行数は同じ
	var new_lines := Cp932.decode(_read(DST.path_join("phi.jb"))).split("\n")
	var old_lines := Cp932.decode(orig_jb).split("\n")
	_check(new_lines.size() == old_lines.size(), "jb: 行数が同じ")
	var diffs := 0
	for i in old_lines.size():
		if new_lines[i] != old_lines[i]:
			diffs += 1
	_check(diffs == 1, "jb: 変わったのは1行だけ (%d)" % diffs)
	# 再度開いて実効値が反映される
	var p2 := WorldProject.new()
	_check(p2.open(DST), "再オープン")
	_check(p2.jb.job_name(1) == before + "X", "jb: 編集が反映された")
	print("test_stage23_v2world: %d checks, %d failures"
			% [_checks, _failures])
	quit(1 if _failures > 0 else 0)
