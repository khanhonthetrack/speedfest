"""Deterministic decrypt of a re-keyed pak entry under a reader-buffering model; validated by zlib Adler-32.
usage: python3 pak_emulate.py PACKS PAK HASHNAME OUT"""
import sys, struct, zlib, re
import nadeopak

PARENT = {0x0501A000: 0x05002000, 0x0A029000: 0x0A02E000, 0x0A030000: 0x01001000}

def calls_in(out):
    """(position after which the Initialize happens, 4 bytes) in parse order."""
    calls = []
    b = out.find(b'\x00\x00\x03\x0a')
    if b >= 0: calls.append((b, struct.pack('<I', PARENT[0x0A030000])))
    for m in re.finditer(rb'(?s)(?=(.{4})(\x00\xa0\x01\x05|\x00\x90\x02\x0a))', out):
        idx = struct.unpack('<I', m.group(1))[0]
        cls = struct.unpack('<I', m.group(2))[0]
        p = m.start() + 8
        nxt = out[p:p + 4]
        if idx >= 0x10000: continue
        if len(nxt) == 4 and nxt[3] != (cls >> 24): continue
        calls.append((p, struct.pack('<I', PARENT[cls])))
    names = []
    for m in re.finditer(rb'\x00\xe0\x02\x0a', out):
        p = m.end()
        if p + 8 > len(out): break
        v = struct.unpack_from('<I', out, p)[0]
        if v == 3: p += 4; v = struct.unpack_from('<I', out, p)[0]
        p += 4
        if v == 0x40000000:
            n = struct.unpack_from('<I', out, p)[0]; p += 4
            if p + n > len(out): break
            name = out[p:p + n]; names.append(name); p += n
        elif v & 0x40000000 and (v & 0xFFFFFF) <= len(names):
            name = names[(v & 0xFFFFFF) - 1]
        else:
            continue
        end = out.find(b'\x01\xde\xca\xfa', p)
        if end < 0 or end + 8 > len(out): break
        calls.append((end + 8, name[:4]))
    calls.sort(key=lambda c: c[0])
    return calls

def run(d, key, hdr, f, model, nout=0, inblk=512):
    s, _ = nadeopak.file_stream(d, key, hdr, f)
    csize = f['csize']
    dobj = zlib.decompressobj()
    out = b''
    folded = 0
    consumed = 0
    while consumed < csize:
        # decide which calls happened before this refill
        calls = calls_in(out)
        if model == 'A':
            limit = len(out)
        else:  # output buffered in blocks of nout: parser has only reached the last full block start
            limit = (len(out) // nout) * nout if consumed else 0
        todo = [c for p, c in calls[folded:] if p <= limit]
        s.ivxor = 0
        for c in todo: s.initialize(c, 0, 4)
        folded += len(todo)
        n = min(inblk, csize - consumed)
        chunk = s.read(n); consumed += n
        try:
            out += dobj.decompress(chunk)
        except zlib.error as e:
            return None, f'zlib error near cipher {consumed}, out {len(out)}: {e}'
    try:
        out += dobj.flush()
    except zlib.error as e:
        return None, f'flush error {e}'
    if not dobj.eof or len(out) != f['usize']:
        return None, f'incomplete eof={dobj.eof} len={len(out)}'
    return out, f'OK folded {folded}'

def main():
    packs, pak, want, outp = sys.argv[1:5]
    d, key, hdr, folders, files = nadeopak.open_pak(packs, pak)
    f = next(f for f in files if f['name'].upper() == want.upper())
    # TmForever reads the zlib input in 256-byte blocks and inflates into a 1024-byte output buffer;
    # the parser's position at each refill is the start of the output block being filled.
    trials = [('B', 1024, 256)] + [('B', n, ib) for ib in (256, 512) for n in (512, 2048, 4096)]
    for model, n, ib in trials:
        out, msg = run(d, key, hdr, f, model, n, ib)
        print(model, n, ib, msg, flush=True)
        if out:
            open(outp, 'wb').write(out); return
main()
