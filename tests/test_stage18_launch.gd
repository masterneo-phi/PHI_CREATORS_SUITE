extends SceneTree
## 第18段 (v0.5.0): 欠けファイルの新規作成とテスト起動
## (場所の指定ダイアログ＋サーバー/クライアントの起動コマンド)

var _failures := 0
var _checks := 0

const MainScript := preload("res://scripts/main.gd")


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("ok: ", label)
	else:
		_failures += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _make_world(dir: String) -> void:
	OS.execute("rm", ["-rf", dir])
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("phi.td"), FileAccess.WRITE)
	f.store_buffer(Cp932.encode(":N New World\n:T 0\n:O O 20099 A 001 001 MSGT\n.\n"))
	f.close()


func _find_button(node: Node, needle: String) -> Button:
	if node is Button and (node as Button).text.contains(needle):
		return node as Button
	for c in node.get_children():
		var found := _find_button(c, needle)
		if found != null:
			return found
	return null


func _run() -> void:
	Cp932.ensure_loaded()
	# --- WorldProject.create_file: 全種を空で作れること
	var dir_a := "/tmp/creators_stage18_a"
	_make_world(dir_a)
	var p := WorldProject.new()
	check(p.open(dir_a), "td のみの world が開ける")
	check(not p.has_ad and not p.has_ed and not p.has_swt, "最初は欠けている")
	for kind in ["swt", "ed", "od", "crt", "ex", "ad"]:
		check(p.create_file(kind), "create_file: " + kind)
		check(FileAccess.file_exists(dir_a.path_join("phi." + kind)),
				"ファイルが出来た: phi." + kind)
	check(p.has_ad and p.ad != null and p.ed != null and p.swt != null,
			"モデルが用意できた")
	check(not p.create_file("ad"), "既にあるファイルは作り直さない")
	check(not p.create_file("td"), "対象外の種類は作らない")
	var p2 := WorldProject.new()
	check(p2.open(dir_a), "作った world が再び開ける")
	check(p2.has_ad and p2.has_ed and p2.has_od and p2.has_crt
			and p2.has_ex and p2.has_swt, "作った全ファイルが読める")

	# --- 起動コマンドの形 (OS 別)
	var sc_win: Array = MainScript.server_command(
			"C:\\\\bin\\\\phi_dm.exe", "D:\\\\world", "Windows")
	check(String(sc_win[0]) == "cmd.exe"
			and String(sc_win[1][1]).begins_with("cd /d"),
			"Windows のサーバは cd してから起動")
	var sc_lin: Array = MainScript.server_command(
			"/opt/bin/phi_dm", "/tmp/w", "Linux")
	check(String(sc_lin[0]) == "/bin/sh"
			and String(sc_lin[1][3]) == "/tmp/w"
			and String(sc_lin[1][4]) == "/opt/bin/phi_dm",
			"Linux のサーバは sh で cd して exec")
	var cc_app: Array = MainScript.client_command("/Apps/NeoPHI.app", "macOS")
	check(String(cc_app[0]) == "/usr/bin/open", "Mac の .app は open で起動")
	var cc_exe: Array = MainScript.client_command("C:\\\\NeoPHI.exe", "Windows")
	check(String(cc_exe[0]) == "C:\\\\NeoPHI.exe", "通常はそのまま起動")
	# 実際に起動できること (/bin/true で代用)
	var sc: Array = MainScript.server_command("/bin/true", dir_a, OS.get_name())
	check(OS.create_process(String(sc[0]), sc[1]) > 0, "サーバコマンドが起動できる")
	var cc: Array = MainScript.client_command("/bin/true", OS.get_name())
	check(OS.create_process(String(cc[0]), cc[1]) > 0, "クライアントコマンドが起動できる")

	# --- Main 経由: エディタの新規作成ボタンと起動設定の保存・テスト起動
	var cfg_path := ProjectSettings.globalize_path("user://creators.cfg")
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)
	var dir_b := "/tmp/creators_stage18_b"
	_make_world(dir_b)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("open_world", dir_b)
	await process_frame
	main.call("_on_editor_selected", 8) # マスター権限 (phi.ad)
	await process_frame
	var editors: Dictionary = main.get("_editors")
	var ad_ed: Control = editors["ad"]
	var btn := _find_button(ad_ed, "新規作成")
	check(btn != null, "欠けエディタに新規作成ボタンがある")
	btn.pressed.emit()
	await process_frame
	await process_frame
	check(FileAccess.file_exists(dir_b.path_join("phi.ad")),
			"ボタンで phi.ad が作られた")
	check(ad_ed.get("_list") != null, "エディタが作り直されて一覧が出る")
	# 起動設定: 場所を保存して読み戻せること
	main.call("_show_launch_settings")
	await process_frame
	check((main.get("_launch_overlay") as Control).visible, "起動設定が出る")
	(main.get("_launch_client_edit") as LineEdit).text = "/bin/true"
	(main.get("_launch_server_edit") as LineEdit).text = "/bin/true"
	main.call("_save_launch_paths")
	check(String(main.call("_launch_path", "client")) == "/bin/true",
			"クライアントの場所が保存される")
	check(String(main.call("_launch_path", "server")) == "/bin/true",
			"サーバーの場所が保存される")
	(main.get("_launch_overlay") as Control).hide()
	# DM 起動とクライアント起動 (/bin/true で代用): 状態表示まで通ること
	main.call("_on_launch_server")
	await process_frame
	check((main.get("_status_label") as Label).text.contains("DM を起動しました"),
			"DM 起動が実行される")
	main.call("_on_launch_client")
	await process_frame
	check((main.get("_status_label") as Label).text.contains("クライアントを起動しました"),
			"クライアント起動が実行される")
	# 後片付け: cfg を消して他のスイートへ影響を残さない
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
