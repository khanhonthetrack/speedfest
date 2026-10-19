#!/usr/bin/env python3
"""Read a TMNF .Challenge.Gbx: header (medals, name, author), LZO1X body, block list.

Our own implementation of the public GBX format (as documented by the community, e.g. GBX.NET).
Prototype for stadium/gbx/*.gd. Usage: python3 -I gbx_challenge.py FILE [FILE...] [--blocks]
"""
import struct
import sys

COLLECTIONS = {0: 'Desert', 1: 'Snow', 2: 'Rally', 3: 'Island', 4: 'Bay', 5: 'Coast',
               6: 'Stadium', 7: 'Valley', 8: 'Speed', 11: 'Alpine', 12: 'Rally',
               13: 'Island', 14: 'Bay', 25: 'Stadium256', 26: 'Stadium', 10003: 'Common'}
FACADE = 0xFACADE01
PIKS = 0x534B4950


def lzo1x_decompress(src: bytes, out_len: int) -> bytes:
    """LZO1X decompression (the format of lzo1x_1 / lzo1x_999), byte by byte."""
    dst = bytearray()
    ip = 0
    n = len(src)

    def copy_match(m_pos, length):
        for _ in range(length):
            dst.append(dst[m_pos])
            m_pos += 1

    state = 'start'
    t = 0
    while True:
        if state == 'start':
            if src[0] > 17:
                t = src[0] - 17
                ip = 1
                dst += src[ip:ip + t]
                ip += t
                state = 'match_next_lit' if t < 4 else 'first_literal_run'
                if t < 4:
                    # literals already copied; read the next instruction
                    t = src[ip]; ip += 1
                    state = 'match'
                continue
            state = 'loop'
            continue
        if state == 'loop':
            t = src[ip]; ip += 1
            if t >= 16:
                state = 'match'
                continue
            if t == 0:
                while src[ip] == 0:
                    t += 255; ip += 1
                t += 15 + src[ip]; ip += 1
            dst += src[ip:ip + t + 3]
            ip += t + 3
            state = 'first_literal_run'
            continue
        if state == 'first_literal_run':
            t = src[ip]; ip += 1
            if t >= 16:
                state = 'match'
                continue
            m_pos = len(dst) - (1 + 0x0800) - (t >> 2) - (src[ip] << 2); ip += 1
            copy_match(m_pos, 3)
            state = 'match_done'
            continue
        if state == 'match':
            if t >= 64:
                m_pos = len(dst) - 1 - ((t >> 2) & 7) - (src[ip] << 3); ip += 1
                copy_match(m_pos, (t >> 5) - 1 + 2)
            elif t >= 32:
                t &= 31
                if t == 0:
                    while src[ip] == 0:
                        t += 255; ip += 1
                    t += 31 + src[ip]; ip += 1
                m_pos = len(dst) - 1 - (src[ip] >> 2) - (src[ip + 1] << 6); ip += 2
                copy_match(m_pos, t + 2)
            elif t >= 16:
                m_pos = len(dst) - ((t & 8) << 11)
                t &= 7
                if t == 0:
                    while src[ip] == 0:
                        t += 255; ip += 1
                    t += 7 + src[ip]; ip += 1
                m_pos -= (src[ip] >> 2) + (src[ip + 1] << 6); ip += 2
                if m_pos == len(dst):
                    break   # end of stream
                m_pos -= 0x4000
                copy_match(m_pos, t + 2)
            else:
                m_pos = len(dst) - 1 - (t >> 2) - (src[ip] << 2); ip += 1
                copy_match(m_pos, 2)
            state = 'match_done'
            continue
        if state == 'match_done':
            t = src[ip - 2] & 3
            if t == 0:
                state = 'loop'
                continue
            dst += src[ip:ip + t]
            ip += t
            t = src[ip]; ip += 1
            state = 'match'
            continue
    if len(dst) != out_len:
        raise ValueError(f'lzo: got {len(dst)} bytes, expected {out_len}')
    return bytes(dst)


class Reader:
    def __init__(self, data: bytes, pos: int = 0):
        self.d = data
        self.p = pos
        self.ids = None      # lookback strings (None until the version is read)
        self.nodes = {}

    def u8(self):
        v = self.d[self.p]; self.p += 1; return v

    def u16(self):
        v = struct.unpack_from('<H', self.d, self.p)[0]; self.p += 2; return v

    def u32(self):
        v = struct.unpack_from('<I', self.d, self.p)[0]; self.p += 4; return v

    def i32(self):
        v = struct.unpack_from('<i', self.d, self.p)[0]; self.p += 4; return v

    def f32(self):
        v = struct.unpack_from('<f', self.d, self.p)[0]; self.p += 4; return v

    def peek_u32(self):
        return struct.unpack_from('<I', self.d, self.p)[0]

    def bytes(self, n):
        v = self.d[self.p:self.p + n]; self.p += n; return v

    def string(self):
        n = self.u32()
        return self.bytes(n).decode('utf-8', 'replace')

    def reset_ids(self):
        self.ids = None

    def lookback(self):
        if self.ids is None:
            ver = self.u32()
            if ver < 2:
                raise ValueError(f'lookback version {ver}')
            self.ids = []
        v = self.u32()
        if v == 0xFFFFFFFF:
            return ''
        if (v & 0xC0000000) and (v & 0x3FFFFFFF) == 0:
            s = self.string()
            self.ids.append(s)
            return s
        if v & 0xC0000000 == 0:
            return COLLECTIONS.get(v, f'#{v}')
        return self.ids[(v & 0x3FFFFFFF) - 1]

    def ident(self):
        return (self.lookback(), self.lookback(), self.lookback())


def read_header(r: Reader):
    if r.bytes(3) != b'GBX':
        raise ValueError('not a GBX file')
    ver = r.u16()
    if ver < 6:
        raise ValueError(f'GBX version {ver} not supported')
    fmt = r.bytes(4)  # 'B', ref table compr, body compr, 'R'
    cls = r.u32()
    user_size = r.u32()
    chunks = []
    if user_size:
        nchunks = r.u32()
        entries = [(r.u32(), r.u32()) for _ in range(nchunks)]
        for cid, size in entries:
            size &= 0x7FFFFFFF
            chunks.append((cid, r.bytes(size)))
    nnodes = r.u32()
    next_ext = r.u32()
    if next_ext:
        raise ValueError('external node references not supported')
    return {'version': ver, 'format': fmt, 'class': cls, 'header_chunks': chunks, 'nodes': nnodes}


def parse_header_chunks(chunks):
    info = {}
    for cid, data in chunks:
        r = Reader(data)
        if cid == 0x03043002:
            v = r.u8()
            info['desc_version'] = v
            if v < 3:
                info['uid'], info['collection'], info['author'] = r.ident()
                info['name'] = r.string()
            r.u32()
            if v >= 1:
                info['bronze'], info['silver'], info['gold'] = r.i32(), r.i32(), r.i32()
                info['author_time'] = r.i32()
                if v == 2:
                    r.u8()
                if v >= 4:
                    info['cost'] = r.u32()
                if v >= 5:
                    info['laps'] = bool(r.u32())
                if v == 6:
                    r.u32()
                if v >= 7:
                    info['mode'] = r.u32()
                if v >= 9:
                    info['author_score'] = r.u32()
                if v >= 10:
                    info['editor_mode'] = r.u32()
                if v >= 11:
                    r.u32()
                if v >= 13:
                    info['checkpoints'] = r.u32()
                    info['nb_laps'] = r.u32()
        elif cid == 0x03043003:
            v = r.u8()
            info['uid'], info['collection'], info['author'] = r.ident()
            info['name'] = r.string()
            info['kind'] = r.u8()
            if v >= 1:
                r.u32()
                r.string()
            if v >= 2:
                info['decoration'] = r.ident()
        elif cid == 0x03043008:
            r.u32(); r.u32()
            info['author_login'] = r.string()
            info['author_nick'] = r.string()
    return info


def read_body(r: Reader, hdr):
    comp = hdr['format'][2:3]
    if comp == b'C':
        usize = r.u32(); csize = r.u32()
        return lzo1x_decompress(r.bytes(csize), usize)
    return r.d[r.p:]


class Parser:
    """Walks the body chunks of a CGameCtnChallenge and its inline nodes."""

    def __init__(self, body: bytes):
        self.r = Reader(body)
        self.out = {'chunks': [], 'blocks': []}

    def node_ref(self):
        r = self.r
        idx = r.i32()
        if idx == -1:
            return None
        if idx in r.nodes:
            return r.nodes[idx]
        cls = r.u32()
        node = {'class': cls}
        r.nodes[idx] = node
        self.node_body(cls, node)
        return node

    def node_body(self, cls, node):
        r = self.r
        while True:
            cid = r.u32()
            if cid == FACADE:
                return
            self.out['chunks'].append(cid)
            if r.peek_u32() == PIKS:
                r.u32()
                size = r.u32()
                end = r.p + size
                if cid == 0x03043018:
                    node['lap_race'] = bool(r.u32())
                    node['nb_laps'] = r.u32()
                r.p = end
                continue
            self.chunk(cid, node)
            if cid == 0x0304301F:
                return   # everything we need is read; media clips follow

    def chunk(self, cid, node):
        r = self.r
        if cid == 0x0304300D:
            node['vehicle'] = r.ident()
        elif cid == 0x03043011:
            node['collectors'] = self.node_ref()
            node['params'] = self.node_ref()
            node['kind'] = r.u32()
        elif cid == 0x0301B000:
            n = r.u32()
            node['stock'] = [(r.ident(), r.u32()) for _ in range(n)]
        elif cid == 0x0305B000:
            node['p0'] = [r.u32() for _ in range(8)]
        elif cid == 0x0305B001:
            node['tips'] = [r.string() for _ in range(4)]
        elif cid == 0x0305B004:
            node['times'] = [r.i32() for _ in range(5)]
        elif cid == 0x0305B005:
            node['p5'] = [r.u32() for _ in range(3)]
        elif cid == 0x0305B006:
            n = r.u32()
            node['items'] = [r.u32() for _ in range(n)]
        elif cid == 0x0305B008:
            node['time_limit'] = r.i32()
            node['author_score'] = r.i32()
        elif cid == 0x0305B00D:
            node['validation_ghost'] = self.node_ref()
        elif cid == 0x0304301F:
            self.blocks(node)
        elif cid == 0x03043022:
            r.u32()
        elif cid == 0x03043024:
            self.fileref()
        elif cid == 0x03043025:
            node['origin'] = (r.f32(), r.f32()); node['target'] = (r.f32(), r.f32())
        elif cid == 0x03043026:
            node['clip_global'] = self.node_ref()
        elif cid == 0x03043028:
            self.chunk_3028(node)
        elif cid == 0x0304302A:
            r.u32()
        elif cid == 0x03043021:
            node['clip_intro'] = self.node_ref()
            node['clip_group_ingame'] = self.node_ref()
            node['clip_group_end'] = self.node_ref()
        elif cid == 0x03059000:
            node['text'] = r.string()
            r.string()
        elif cid == 0x03059001:
            node['text'] = r.string()
            node['pack'] = self.fileref()
        elif cid == 0x03059002:
            node['text'] = r.string()
            node['pack'] = self.fileref()
            node['parent_pack'] = self.fileref()
        elif cid == 0x03059003:
            r.u32()
            node['fg_pack'] = self.fileref()
        elif cid == 0x2E009000:
            v = r.u32()
            if v == 1:
                node['spawn'] = r.u32(); node['order'] = r.u32()
            elif v == 2:
                node['tag'] = r.string(); node['order'] = r.u32()
        else:
            raise ValueError(f'unknown non-skippable chunk {cid:08X} at {r.p}')

    def fileref(self):
        r = self.r
        v = r.u8()
        if v >= 3:
            r.bytes(32)
        path = r.string()
        if (len(path) and v >= 1) or v >= 3:
            r.string()
        return path

    def chunk_3028(self, node):
        r = self.r
        has_cam = r.u32()
        if has_cam:
            r.u8()
            r.bytes(4 * 9 + 4 * 3)   # mat3 + vec3
            r.bytes(4 * 3)           # fov, near, far
        node['comments'] = r.string()

    def blocks(self, node):
        r = self.r
        node['map'] = r.ident()
        node['map_name'] = r.string()
        node['decoration'] = r.ident()
        node['size'] = (r.u32(), r.u32(), r.u32())
        node['need_unlock'] = r.u32()
        ver = r.u32()
        node['blocks_version'] = ver
        n = r.u32()
        node['nb_blocks'] = n
        blocks = []
        while (r.p + 4 <= len(r.d)) and (r.peek_u32() & 0xC0000000):
            name = r.lookback()
            direction = r.u8()
            coord = (r.u8(), r.u8(), r.u8())
            flags = r.u16() if ver == 0 else r.u32()
            b = {'name': name, 'dir': direction, 'coord': coord, 'flags': flags}
            if flags != 0xFFFFFFFF:
                if flags & 0x8000:
                    b['author'] = r.lookback()
                    b['skin'] = self.node_ref()
                if flags & 0x100000:
                    b['waypoint'] = self.node_ref()
            blocks.append(b)
        self.out['blocks'] = blocks

    def generic_skin_or_waypoint(self, cls, node):
        pass


def load(path):
    data = open(path, 'rb').read()
    r = Reader(data)
    hdr = read_header(r)
    info = parse_header_chunks(hdr['header_chunks'])
    body = read_body(r, hdr)
    p = Parser(body)
    root = {'class': hdr['class']}
    p.node_body(hdr['class'], root)
    return hdr, info, root, p.out


if __name__ == '__main__':
    show_blocks = '--blocks' in sys.argv
    for f in [a for a in sys.argv[1:] if not a.startswith('--')]:
        try:
            hdr, info, root, out = load(f)
            params = root.get('params') or {}
            print(f"{f.split('/')[-1]}: {info.get('name')!r} by {info.get('author')} uid {info.get('uid')} "
                  f"medals {params.get('times')} hdr {info.get('bronze')},{info.get('silver')},{info.get('gold')},{info.get('author_time')} "
                  f"size {root.get('size')} blocks {len(out['blocks'])}/{root.get('nb_blocks')} v{root.get('blocks_version')} "
                  f"chunks {' '.join(f'{c:08X}' for c in out['chunks'])}")
            if show_blocks:
                for b in out['blocks']:
                    print('   ', b['name'], b['dir'], b['coord'], hex(b['flags']), 'waypoint' if b.get('waypoint') else '')
        except Exception as e:
            print(f"{f.split('/')[-1]}: ERROR {e}")
