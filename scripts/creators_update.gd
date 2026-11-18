class_name CreatorsUpdate
extends RefCounted
## GitHub リリースによる更新チェック (NeoPHI 第40/102段の移植)。
## 配布は GitHub の masterneo-phi/PHI_CREATORS_SUITE リリースで行い、
## 起動時に最新のリリースを見て、新しければ窓で知らせる。
## 実際のダウンロードと差し替えは利用者がサイトで行う。

const REPO := "masterneo-phi/PHI_CREATORS_SUITE"
const API_URL := "https://api.github.com/repos/" + REPO + "/releases/latest"
const RELEASES_URL := "https://github.com/" + REPO + "/releases"


## バージョン文字列を数値の配列にする ("v1.2.3" -> [1, 2, 3])。
static func parse_version(v: String) -> Array:
	var s := v.strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1)
	var out: Array = []
	for part in s.split("."):
		var digits := ""
		for i in part.length():
			var c := part[i]
			if c >= "0" and c <= "9":
				digits += c
			else:
				break
		out.append(int(digits) if not digits.is_empty() else 0)
	return out


## latest が current より新しければ true。
static func is_newer(latest: String, current: String) -> bool:
	var a := parse_version(latest)
	var b := parse_version(current)
	var n := maxi(a.size(), b.size())
	for i in n:
		var av := int(a[i]) if i < a.size() else 0
		var bv := int(b[i]) if i < b.size() else 0
		if av != bv:
			return av > bv
	return false


## GitHub API (releases/latest) の応答 JSON から必要な項目を取り出す。
static func parse_latest(body_text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(body_text)
	if not (data is Dictionary):
		return {}
	var tag := str((data as Dictionary).get("tag_name", ""))
	if tag.is_empty():
		return {}
	return {
		"tag": tag,
		"name": str((data as Dictionary).get("name", "")),
		"url": str((data as Dictionary).get("html_url", "")),
	}


## 更新窓から開くページ。リリース個別の URL が無ければ一覧へ。
static func page_url(info: Dictionary) -> String:
	var url := str(info.get("url", ""))
	return url if not url.is_empty() else RELEASES_URL
