class_name BmpLoader
extends RefCounted
## BMP の読み込みと、透過を付けた画像への変換。
##
## Python 版 neophi/bmp.py の移植。対応するのは無圧縮(BI_RGB)の
## 1/4/8 ビット(パレット付き)と 24/32 ビットで、上下どちらの向きにも対応する。
## 透過の付け方は wphi の assets.rs と同じ。

## マスクの白の閾値。超えたら不透明。
const MASK_WHITE := 200
## キャラグラの透過色 (0, 128, 128)。
const TEAL_R := 0
const TEAL_G := 128
const TEAL_B := 128


static func _u16(data: PackedByteArray, off: int) -> int:
	return data[off] | (data[off + 1] << 8)


static func _u32(data: PackedByteArray, off: int) -> int:
	return data[off] | (data[off + 1] << 8) | (data[off + 2] << 16) | (data[off + 3] << 24)


static func _s32(data: PackedByteArray, off: int) -> int:
	var v := _u32(data, off)
	if v >= 0x80000000:
		return v - 0x100000000
	return v


## BMP のバイト列を RGB の画像にする。アルファはすべて不透明。読めなければ null。
static func decode_bmp(data: PackedByteArray) -> Image:
	if data.size() < 54 or data[0] != 0x42 or data[1] != 0x4D: # BM
		return null
	var offset := _u32(data, 10)
	var header_size := _u32(data, 14)
	if header_size < 40:
		return null
	var width := _s32(data, 18)
	var height := _s32(data, 22)
	var bpp := _u16(data, 28)
	var compression := _u32(data, 30)
	if compression != 0:
		return null
	if width <= 0 or height == 0:
		return null
	var top_down := height < 0
	height = absi(height)
	if not (bpp == 1 or bpp == 4 or bpp == 8 or bpp == 24 or bpp == 32):
		return null

	var palette: Array = []
	if bpp <= 8:
		var count := _u32(data, 46)
		if count == 0:
			count = 1 << bpp
		var pal_off := 14 + header_size
		for i in range(count):
			var j := pal_off + i * 4
			if j + 4 > data.size():
				return null
			palette.append([data[j + 2], data[j + 1], data[j]]) # R, G, B

	var stride := ((bpp * width + 31) / 32) * 4
	if offset + stride * height > data.size():
		return null
	var pixels := PackedByteArray()
	pixels.resize(width * height * 4)
	for row in range(height):
		# 下から上の BMP は、読む行を逆にする
		var src_row := row if top_down else height - 1 - row
		var base := offset + src_row * stride
		var di := row * width * 4
		if bpp == 24:
			for x in range(width):
				var j := base + x * 3
				pixels[di] = data[j + 2]
				pixels[di + 1] = data[j + 1]
				pixels[di + 2] = data[j]
				pixels[di + 3] = 255
				di += 4
		elif bpp == 32:
			for x in range(width):
				var j := base + x * 4
				pixels[di] = data[j + 2]
				pixels[di + 1] = data[j + 1]
				pixels[di + 2] = data[j]
				pixels[di + 3] = 255
				di += 4
		elif bpp == 8:
			for x in range(width):
				var c: Array = palette[data[base + x]]
				pixels[di] = c[0]
				pixels[di + 1] = c[1]
				pixels[di + 2] = c[2]
				pixels[di + 3] = 255
				di += 4
		elif bpp == 4:
			for x in range(width):
				var byte := data[base + x / 2]
				var idx := (byte >> 4) if x % 2 == 0 else (byte & 0x0F)
				var c: Array = palette[idx]
				pixels[di] = c[0]
				pixels[di + 1] = c[1]
				pixels[di + 2] = c[2]
				pixels[di + 3] = 255
				di += 4
		else: # 1bpp
			for x in range(width):
				var byte := data[base + x / 8]
				var idx := (byte >> (7 - x % 8)) & 1
				var c: Array = palette[idx]
				pixels[di] = c[0]
				pixels[di + 1] = c[1]
				pixels[di + 2] = c[2]
				pixels[di + 3] = 255
				di += 4
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)


## `key` の色を透明にする(キャラグラ)。
static func colorkey(img: Image, kr: int = TEAL_R, kg: int = TEAL_G, kb: int = TEAL_B) -> Image:
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		if data[i] == kr and data[i + 1] == kg and data[i + 2] == kb:
			data[i] = 0
			data[i + 1] = 0
			data[i + 2] = 0
			data[i + 3] = 0
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


static func _masked(data: PackedByteArray, rgb_i: int, mask_i: int, out: PackedByteArray, out_i: int) -> void:
	if data[mask_i] > MASK_WHITE and data[mask_i + 1] > MASK_WHITE and data[mask_i + 2] > MASK_WHITE:
		out[out_i] = data[rgb_i]
		out[out_i + 1] = data[rgb_i + 1]
		out[out_i + 2] = data[rgb_i + 2]
		out[out_i + 3] = 255
	else:
		out[out_i] = 0
		out[out_i + 1] = 0
		out[out_i + 2] = 0
		out[out_i + 3] = 0


## 左半分が画像、右半分がマスク(マップチップ)。
static func mask_h(img: Image) -> Image:
	var w := img.get_width() / 2
	var h := img.get_height()
	var data := img.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var src_w := img.get_width()
	for y in range(h):
		for x in range(w):
			_masked(data, (y * src_w + x) * 4, (y * src_w + x + w) * 4, out, (y * w + x) * 4)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## 上半分が画像、下半分がマスク(Items.bmp)。
static func mask_v(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height() / 2
	var data := img.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 4)
	for y in range(h):
		for x in range(w):
			_masked(data, (y * w + x) * 4, ((y + h) * w + x) * 4, out, (y * w + x) * 4)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
