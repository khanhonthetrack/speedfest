class_name Lzo1x
extends RefCounted
## LZO1X decompression (the stream format of lzo1x_1 / lzo1x_999, used by GBX bodies).
## Our own implementation of the public algorithm; mirrors tools/research/tmnf/gbx_challenge.py.


## Decompresses `src` into exactly `out_len` bytes. Returns an empty array on malformed input.
static func decompress(input: PackedByteArray, out_len: int) -> PackedByteArray:
	var n := input.size()
	# a few zero bytes of padding so a truncated stream fails the checks below instead of reading
	# past the end
	var src := input.duplicate()
	src.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))
	var dst := PackedByteArray()
	dst.resize(out_len)
	var op := 0
	var ip := 0
	var t := 0
	var state := 0   # 0 loop, 1 first literal run, 2 match, 3 match done
	if n == 0 or out_len <= 0:
		return PackedByteArray()
	if src[0] > 17:
		t = src[0] - 17
		ip = 1
		if op + t > out_len or ip + t > n:
			return PackedByteArray()
		for k in t:
			dst[op + k] = src[ip + k]
		op += t
		ip += t
		if t < 4:
			t = src[ip]
			ip += 1
			state = 2
		else:
			state = 1
	while true:
		if ip >= n:
			return PackedByteArray()
		if state == 0:
			t = src[ip]
			ip += 1
			if t >= 16:
				state = 2
				continue
			if t == 0:
				while ip < n and src[ip] == 0:
					t += 255
					ip += 1
				t += 15 + src[ip]
				ip += 1
			var lit := t + 3
			if op + lit > out_len or ip + lit > n:
				return PackedByteArray()
			for k in lit:
				dst[op + k] = src[ip + k]
			op += lit
			ip += lit
			state = 1
		elif state == 1:
			t = src[ip]
			ip += 1
			if t >= 16:
				state = 2
				continue
			var m_pos := op - (1 + 0x0800) - (t >> 2) - (src[ip] << 2)
			ip += 1
			if m_pos < 0 or op + 3 > out_len:
				return PackedByteArray()
			for k in 3:
				dst[op] = dst[m_pos + k]
				op += 1
			state = 3
		elif state == 2:
			var m_pos := 0
			var length := 0
			if t >= 64:
				m_pos = op - 1 - ((t >> 2) & 7) - (src[ip] << 3)
				ip += 1
				length = (t >> 5) + 1
			elif t >= 32:
				t &= 31
				if t == 0:
					while ip < n and src[ip] == 0:
						t += 255
						ip += 1
					t += 31 + src[ip]
					ip += 1
				m_pos = op - 1 - (src[ip] >> 2) - (src[ip + 1] << 6)
				ip += 2
				length = t + 2
			elif t >= 16:
				m_pos = op - ((t & 8) << 11)
				t &= 7
				if t == 0:
					while ip < n and src[ip] == 0:
						t += 255
						ip += 1
					t += 7 + src[ip]
					ip += 1
				m_pos -= (src[ip] >> 2) + (src[ip + 1] << 6)
				ip += 2
				if m_pos == op:
					break   # end of stream
				m_pos -= 0x4000
				length = t + 2
			else:
				m_pos = op - 1 - (t >> 2) - (src[ip] << 2)
				ip += 1
				length = 2
			if m_pos < 0 or op + length > out_len:
				return PackedByteArray()
			for k in length:
				dst[op] = dst[m_pos + k]
				op += 1
			state = 3
		else:
			t = src[ip - 2] & 3
			if t == 0:
				state = 0
				continue
			if op + t > out_len or ip + t > n:
				return PackedByteArray()
			for k in t:
				dst[op + k] = src[ip + k]
			op += t
			ip += t
			t = src[ip]
			ip += 1
			state = 2
	if op != out_len:
		return PackedByteArray()
	return dst
