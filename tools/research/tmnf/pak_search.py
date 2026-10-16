"""Backtracking decrypt of a re-keyed TMF pak entry. At each 256-byte input refill, try fold counts
nearest the buffer model's guess first (TmForever's reader position is not always the model's:
large reads bypass its output buffer); zlib errors prune, Adler-32 confirms the result.
usage: pak_search.py classmap.json PACKS PAK HASHNAME OUT"""
import sys, os, struct, zlib, copy, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pak_generic as pg
import nadeopak

def main():
    packs, pak, want, outp = sys.argv[2:6]
    d, key, hdr, folders, files = nadeopak.open_pak(packs, pak)
    f = next(f for f in files if f['name'].upper() == want.upper())
    s, enc = nadeopak.file_stream(d, key, hdr, f)
    total = f['csize']; NOUT, INB, MAXC = 1024, 256, 8
    out = bytearray(); sc = None
    dobj = zlib.decompressobj()
    # first block: no folds possible
    out += dobj.decompress(s.read(INB)); consumed = INB
    class NoScan:   # until the header (user data can be large) is decompressed: no node reads yet
        nodes = {}; done = 0; extra = {}; xdone = 0; xpend = None
        def scan(self, b): return []
    sc = NoScan()
    def header_scanner():
        nonlocal sc
        if isinstance(sc, NoScan) and len(out) >= 21:
            uds = struct.unpack_from('<I', out, 13)[0]
            if len(out) >= 25 + uds:
                sc = pg.Scanner(struct.unpack_from('<I', out, 17 + uds)[0], struct.unpack_from('<I', out, 9)[0], 25 + uds)
    folded = 0
    stack = []   # frames: (cands, i, snapshot)
    def snap():
        return (copy.copy(s.__dict__), dobj.copy(), len(out), folded, consumed)
    def restore(sn):
        nonlocal dobj, folded, consumed
        s.__dict__.update(copy.copy(sn[0])); dobj = sn[1].copy(); del out[sn[2]:]
        folded, consumed = sn[3], sn[4]
        L = sn[2]
        sc.nodes = {p: c for p, c in sc.nodes.items() if p <= L - 260}
        sc.done = max(0, L - 256)
        sc.extra = {p: c for p, c in sc.extra.items() if p <= L - 260}
        sc.xdone = max(0, L - 256); sc.xpend = None
    t0 = time.time(); best = 0; steps = 0; deepest = [0]
    while consumed < total:
        header_scanner()
        calls = sc.scan(bytes(out))
        pend = [c for c in calls[folded:]]
        avail = [c for c in pend if c[0] <= len(out)]
        limit = (len(out) // NOUT) * NOUT
        j0 = sum(1 for c in avail if c[0] <= limit)
        cands = sorted(range(len(avail) + 1), key=lambda j: (abs(j - j0), j))[:MAXC]
        frame = [cands, 0, snap()]
        stack.append(frame)
        ok = False
        while stack:
            fr = stack[-1]
            if fr[1] >= len(fr[0]):
                stack.pop()
                if not stack: break
                restore(stack[-1][2]); stack[-1][1] += 1
                continue
            restore(fr[2])
            j = fr[0][fr[1]]
            calls = sc.scan(bytes(out)); avail = [c for c in calls[folded:] if c[0] <= len(out)]
            s.ivxor = 0
            for p, c in avail[:j]: s.initialize(c, 0, 4)
            n = min(INB, total - consumed)
            try:
                more = dobj.decompress(s.read(n))
            except zlib.error as e:
                if os.environ.get('PAK_DEBUG'): print('  try', consumed, j, e)
                fr[1] += 1; continue
            if os.environ.get('PAK_DEBUG') and j != fr[0][0]:
                print('  decision at cipher', consumed, 'out', len(out), 'folds', j, 'model', fr[0][0], 'avail', [(p, c.hex()) for p, c in avail])
            out += more; consumed += n; folded += j
            ok = True; break
        steps += 1
        if not ok:
            print('FAILED at', consumed, 'out', len(out)); sys.exit(1)
        if consumed > deepest[0]:
            deepest[0] = consumed
            if consumed % 16384 == 0: open(outp + '.partial', 'wb').write(out)
        if consumed > best + 65536:
            best = consumed; print(f'{consumed}/{total} out {len(out)} depth {len(stack)} {time.time()-t0:.0f}s', flush=True)
    try:
        out += dobj.flush()
    except zlib.error as e:
        print('flush error', e); sys.exit(1)
    print('eof', dobj.eof, 'len', len(out), 'usize', f['usize'])
    open(outp, 'wb').write(out)
main()
