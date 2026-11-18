class_name UOptions
extends RefCounted
## phi.td :U 行のコード列をトークン単位で読み書きする。
## コードは空白区切りだが、R "…" だけは引用符の中に空白を含む
## ため、引用を尊重して分解する。未知のコードはそのまま保持する。

static func tokenize(codes: String) -> Array[String]:
	var out: Array[String] = []
	var i := 0
	var s := codes
	while i < s.length():
		while i < s.length() and s[i] == " ":
			i += 1
		if i >= s.length():
			break
		var start := i
		if s[i] == '"':
			i += 1
			while i < s.length() and s[i] != '"':
				i += 1
			if i < s.length():
				i += 1
		else:
			while i < s.length() and s[i] != " ":
				i += 1
		out.append(s.substr(start, i - start))
	return out


static func join(tokens: Array) -> String:
	return " ".join(tokens)


static func has(tokens: Array, code: String) -> bool:
	return tokens.has(code)


static func remove_code(tokens: Array, code: String) -> Array:
	var out: Array = []
	for t in tokens:
		if String(t) != code:
			out.append(t)
	return out


## pair/flag の設定: on なら code を入れ、off なら対コードと共に除く
static func set_flag(tokens: Array, on_code: String, off_code: String,
		on: bool) -> Array:
	var out := remove_code(tokens, on_code)
	if off_code != "":
		out = remove_code(out, off_code)
	if on:
		out.append(on_code)
	elif off_code != "":
		out.append(off_code)
	return out


## 数字つきコード (AE1 等) の読み取り。なければ -1
static func get_int(tokens: Array, prefix: String) -> int:
	for t in tokens:
		var s := String(t)
		if s.length() == prefix.length() + 1 and s.begins_with(prefix):
			var d := s.substr(prefix.length())
			if d >= "0" and d <= "9":
				return d.to_int()
	return -1


static func set_int(tokens: Array, prefix: String, value: int,
		default_value: int) -> Array:
	var out: Array = []
	for t in tokens:
		var s := String(t)
		if not (s.length() == prefix.length() + 1 and s.begins_with(prefix)):
			out.append(t)
	if value != default_value:
		out.append(prefix + str(value))
	return out


## 選択式: options の全コードを除いてから選ばれたコードを入れる
static func set_choice(tokens: Array, options: Dictionary, code: String) -> Array:
	var out: Array = tokens.duplicate()
	for v in options.values():
		if String(v) != "":
			out = remove_code(out, String(v))
	if code != "":
		out.append(code)
	return out


static func get_choice(tokens: Array, options: Dictionary,
		default_key: String) -> String:
	for k in options.keys():
		var code := String(options[k])
		if code != "" and tokens.has(code):
			return String(k)
	return default_key
