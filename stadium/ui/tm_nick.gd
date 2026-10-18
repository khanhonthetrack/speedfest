class_name TmNick
extends RefCounted
## Nicknames with TMNF's $-codes: $RGB a colour (three hex digits), $o bold, $i italic, $w wide,
## $n narrow, $m normal width, $s shadow, $t capitals, $g the default colour, $z everything back
## to default, $< and $> save and restore the style, $l[url]text$l and $h[...]...$h links (the
## text stays, the link goes), $$ a dollar sign. Unknown codes are dropped.
## to_bbcode() renders a nickname for a RichTextLabel (wide and narrow as letter spacing, shadow
## as an outline), strip() gives the plain text.

const MAX_LENGTH := 75   ## TMNF's limit, codes included


## The runs of a nickname: [{text, colour (Color, or null: the default), bold, italic, wide,
## narrow, shadow, upper}], adjacent text in the same style merged.
static func runs(nick: String) -> Array:
	var out: Array = []
	var st := _plain()
	var saved: Array = []
	var i := 0
	var n := nick.length()
	while i < n:
		var c := nick[i]
		if c != "$":
			_put(out, st, c)
			i += 1
			continue
		if i + 1 >= n:
			break
		var k := nick[i + 1].to_lower()
		i += 2
		if k == "$":
			_put(out, st, "$")
		elif _is_hex(k):
			# a colour: three hex digits (TMNF fills a short one with zeros)
			var hex := k
			while hex.length() < 3 and i < n and _is_hex(nick[i].to_lower()):
				hex += nick[i].to_lower()
				i += 1
			hex = hex.rpad(3, "0")
			st["colour"] = Color(hex.substr(0, 1).hex_to_int() / 15.0, hex.substr(1, 1).hex_to_int() / 15.0, hex.substr(2, 1).hex_to_int() / 15.0)
		elif k == "o":
			st["bold"] = true
		elif k == "i":
			st["italic"] = true
		elif k == "w":
			st["wide"] = true
			st["narrow"] = false
		elif k == "n":
			st["narrow"] = true
			st["wide"] = false
		elif k == "m":
			st["wide"] = false
			st["narrow"] = false
		elif k == "s":
			st["shadow"] = true
		elif k == "t":
			st["upper"] = true
		elif k == "g":
			st["colour"] = null
		elif k == "z":
			st = _plain()
		elif k == "<":
			saved.push_back(st.duplicate())
		elif k == ">":
			if not saved.is_empty():
				st = saved.pop_back()
		elif k == "l" or k == "h":
			# a link: $l[url]text$l or $ltext$l (the text is the url); keep the text
			if i < n and nick[i] == "[":
				var close := nick.find("]", i)
				i = close + 1 if close >= 0 else n
	return out


static func _plain() -> Dictionary:
	return {"colour": null, "bold": false, "italic": false, "wide": false, "narrow": false, "shadow": false, "upper": false}


static func _is_hex(c: String) -> bool:
	return c.length() == 1 and "0123456789abcdef".contains(c)


static func _put(out: Array, st: Dictionary, text: String) -> void:
	if st["upper"]:
		text = text.to_upper()
	if not out.is_empty():
		var last: Dictionary = out[out.size() - 1]
		var same := true
		for key: String in st:
			if key != "upper" and last[key] != st[key]:
				same = false
		if same:
			last["text"] += text
			return
	var r := st.duplicate()
	r["text"] = text
	out.append(r)


## The nickname without its codes.
static func strip(nick: String) -> String:
	var s := ""
	for r: Dictionary in runs(nick):
		s += String(r["text"])
	return s


## The nickname as BBCode for a RichTextLabel. default_colour colours the runs without a colour of
## their own.
static func to_bbcode(nick: String, default_colour := Color.WHITE) -> String:
	var s := ""
	for r: Dictionary in runs(nick):
		var text := String(r["text"]).replace("[", "[lb]")
		var col: Color = r["colour"] if r["colour"] != null else default_colour
		var open := "[color=#%s]" % col.to_html(false)
		var close := "[/color]"
		if r["bold"]:
			open += "[b]"
			close = "[/b]" + close
		if r["italic"]:
			open += "[i]"
			close = "[/i]" + close
		if r["wide"] or r["narrow"]:
			open += "[font gl=%d]" % (4 if r["wide"] else -2)
			close = "[/font]" + close
		if r["shadow"]:
			open += "[outline_size=6][outline_color=#000000c0]"
			close = "[/outline_color][/outline_size]" + close
		s += open + text + close
	return s
