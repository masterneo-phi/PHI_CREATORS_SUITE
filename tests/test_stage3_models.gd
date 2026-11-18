extends SceneTree
## 第3段モデル (dd/fd): 無編集往復のバイト一致、
## 1マス編集→その行だけ変化、cnf からの寸法読みを検証する。

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _initialize() -> void:
	Cp932.ensure_loaded()
	for world in ["realworld", "testworld"]:
		var base: String = "res://tests/fixtures/" + String(world)
		var p := WorldProject.new()
		_check(p.open("/home/hatch/workspace/phi-creators-godot/tests/fixtures/" + world),
				world + " opens")
		_check(p.map_size.x > 0, world + " map size read: " + str(p.map_size))
		_check(p.dd != null and p.fd != null, world + " dd/fd loaded")
		if p.dd == null:
			continue
		var dd_orig := FileAccess.get_file_as_bytes(base.path_join("phi.dd"))
		_check(p.dd.serialize() == dd_orig, world + " dd untouched round trip")
		var fd_orig := FileAccess.get_file_as_bytes(base.path_join("phi.fd"))
		_check(p.fd.serialize() == fd_orig, world + " fd untouched round trip")
		# 1マス編集: (1,1) を木にする → その行だけ変わる
		p.dd.set_cell(1, 1, 0xDC, false)
		var after := p.dd.serialize()
		_check(after != dd_orig, world + " dd changes after edit")
		var lo := PhiRawLines.from_bytes(dd_orig)
		var la := PhiRawLines.from_bytes(after)
		var diff_rows := 0
		for i in mini(lo.line_count(), la.line_count()):
			if lo.lines[i] != la.lines[i]:
				diff_rows += 1
				_check(i == 1, world + " only row 1 differs (got row %d)" % i)
		_check(diff_rows == 1, world + " exactly one row differs")
		_check(la.line_text(1).substr(2, 2) == "TT", world + " cell written as TT")
		# エリア編集
		p.fd.set_cell(1, 1, 0x07)
		_check(p.fd.serialize() != fd_orig, world + " fd changes after edit")
		_check(PhiFd.parse(p.fd.serialize(), p.map_size.x, p.map_size.y)
				.code_at(1, 1) == 7, world + " fd cell reparses to 07")
	# 新規作成
	var p2 := WorldProject.new()
	p2.create_map(16)
	_check(p2.dd.serialize().size() == 16 * 33 + 0, "new dd size")
	_check(p2.dd.code_at(0, 0) == 0xEC and p2.dd.roof_at(0, 0),
			"new dd border is roofed metal wall")
	_check(p2.dd.code_at(5, 5) == 0, "new dd interior is space")
	_check(p2.fd.used_codes() == [0], "new fd has area 00 only")
	print("test_stage3_models: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
