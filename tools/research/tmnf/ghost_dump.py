#!/usr/bin/env python3
"""A TMNF replay's (or challenge's validation) ghost as numbers: the run's input events and the car's
sampled states, to check our physics against TMNF's own runs (M10). Format knowledge from GBX.NET's
chunk descriptions (CGameCtnGhost 0x03092019/25 inputs, CGameGhost 0x0303F005/06 record data,
CSceneVehicleCar samples); our own code, no game data in the repo.

usage: python3 -I ghost_dump.py <X.Replay.Gbx> [--json=out.json] [--inputs=out.txt] [--samples]
  --inputs writes the inputs as a TMInterface-style script for race.tscn --inputs (times from the
  race's start, 0 = the countdown's end).
"""
import json
import math
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbx_challenge as g  # noqa: E402

# TMNF's surface ids (CPlugSurface material ids, as TmTuning.Surface)
SURFACES = {0: 'Concrete', 1: 'Pavement', 2: 'Grass', 3: 'Ice', 4: 'Metal', 5: 'Sand', 6: 'Dirt', 7: 'Turbo',
            8: 'DirtRoad', 9: 'Rubber', 10: 'SlidingRubber', 11: 'Test', 12: 'Rock', 13: 'Water', 14: 'Wood',
            15: 'Danger', 16: 'Asphalt', 17: 'WetDirtRoad', 18: 'WetAsphalt', 19: 'WetPavement', 20: 'WetGrass',
            21: 'Snow', 22: 'ResonantMetal', 23: 'GolfBall', 24: 'GolfWall', 25: 'GolfGround', 26: 'Turbo2',
            27: 'Bumper', 28: 'NotCollidable', 29: 'FreeWheeling', 30: 'TurboRoulette'}


class B:
    def __init__(self, d, p=0):
        self.d = d
        self.p = p

    def take(self, n):
        v = self.d[self.p:self.p + n]
        self.p += n
        return v

    def u8(self): return self.take(1)[0]
    def i8(self): return struct.unpack('<b', self.take(1))[0]
    def u16(self): return struct.unpack('<H', self.take(2))[0]
    def i16(self): return struct.unpack('<h', self.take(2))[0]
    def u32(self): return struct.unpack('<I', self.take(4))[0]
    def i32(self): return struct.unpack('<i', self.take(4))[0]
    def f32(self): return struct.unpack('<f', self.take(4))[0]


def unit4(b):
    """GBX.NET ReadVec3Unit4: heading and pitch as int16."""
    h = b.i16() / 32767.0 * math.pi
    p = b.i16() / 32767.0 * math.pi * 0.5
    return (math.cos(h) * math.cos(p), math.sin(h) * math.cos(p), math.sin(p))


def quat6(b):
    angle = b.u16() * math.pi / 65535.0
    ax = unit4(b)
    s = math.sin(angle)
    return (ax[0] * s, ax[1] * s, ax[2] * s, math.cos(angle))


def vec3_4(packed):
    """CSceneVehicleCar.ToVec3_4: log magnitude (int16 / 1000), heading and pitch as int8."""
    mag16 = struct.unpack('<h', struct.pack('<H', packed & 0xFFFF))[0]
    hb = struct.unpack('<b', bytes([(packed >> 16) & 0xFF]))[0]
    pb = struct.unpack('<b', bytes([(packed >> 24) & 0xFF]))[0]
    if mag16 == -32768:
        return (0.0, 0.0, 0.0)
    mag = math.exp(mag16 / 1000.0)
    h = hb / 127.0 * math.pi
    p = pb / 127.0 * math.pi * 0.5
    return (math.cos(h) * math.cos(p) * mag, math.sin(h) * math.cos(p) * mag, math.sin(p) * mag)


def sample(data, version):
    """One CSceneVehicleCar sample (versions 7-9: TMNF's)."""
    b = B(data)
    s = {'pos': (b.f32(), b.f32(), b.f32()), 'quat': quat6(b)}
    s['vel'] = vec3_4(b.u32())
    s['angvel'] = vec3_4(b.u32())
    if version < 7 or b.p >= len(data):
        return s
    s['speed_fwd_kmh'] = (b.u16() / 65535.0 * 11000 - 1000) * 3.6
    s['speed_side'] = b.u16() / 65535.0 * 2000 - 1000
    s['rpm'] = b.u16() / 65535.0 * 30000
    b.take(8)                                         # wheel rotations
    s['steer'] = b.u8() / 255.0 * 2 - 1
    s['gas'] = b.u8() / 255.0
    s['brake'] = b.u8() / 255.0
    b.u8()
    if version >= 8:
        b.u8()
    b.u8()
    b.u8()
    s['turbo'] = b.u8() / 255.0
    b.u8()
    wheels = []
    for _ in range(4):                                # FL, FR, RR, RL
        damp = b.u8() / 255.0 * 4 - 2
        mat = b.u8()
        wheels.append({'damp': damp, 'surface': mat})
    if version >= 8:
        b.u8()
        u26 = b.u8()
        u27 = b.u8()
        flags = [(u26 & 0x40, u26 & 0x80), (u27 & 0x01, u27 & 0x02), (u27 & 0x04, u27 & 0x08), (u27 & 0x10, u27 & 0x20)]
        for w, (sl, gr) in zip(wheels, flags):
            w['sliding'] = bool(sl)
            w['ground'] = bool(gr)
    s['wheels'] = wheels
    return s


def record_data(raw):
    """CGameGhost 0x0303F005/06: the zlib'd record data, new layout."""
    b = B(raw)
    out = {'class': '%08X' % b.u32()}
    if out['class'] == 'FFFFFFFF':
        return out
    out['fixed'] = b.u32() != 0
    b.i32()
    out['period_ms'] = b.i32()
    out['version'] = b.i32()
    n = b.u32()
    buf = b.take(n)
    num = b.i32()
    sizes = []
    size = -1
    if num > 0:
        b.i32()
        if num > 1:
            size = b.i32()
            if size == -1:
                sizes = [b.i32() for _ in range(num - 1)]
    times = []
    if not out['fixed']:
        k = b.u32()
        times = [b.i32() for _ in range(k)]
    sb = B(buf)
    samples = []
    t = 0
    for i in range(num):
        if i == num - 1:
            d = sb.take(len(buf) - sb.p)
        else:
            d = sb.take(size if size >= 0 else sizes[i])
        t = i * out['period_ms'] if not times else t + times[i]
        s = sample(d, out['version'])
        s['t'] = t
        s['bytes'] = len(d)
        samples.append(s)
    out['samples'] = samples
    return out


def steer_value(data):
    d = (data >> 16) & 0xFF
    v = data & 0xFFFF
    if d == 0xFF:
        return 65536 - v
    if d == 1:
        return -65536
    return -v * (d + 1)


def gas_value(data):
    # GBX.NET ToGasValue: the same packing as steer, 0..65536 when pressed
    return abs(steer_value(data))


def id_table(body, upto):
    """The body's lookback strings before `upto`, in order: every new id (0x40000000, a length, the
    text) found by scanning, the table later ids index into."""
    out = []
    key = struct.pack('<I', 0x40000000)
    i = body.find(key)
    while 0 <= i < upto:
        n = struct.unpack_from('<I', body, i + 4)[0] if i + 8 <= len(body) else 0
        txt = body[i + 8:i + 8 + n]
        if 0 < n < 64 and all(32 <= c < 127 for c in txt):
            out.append(txt.decode('latin1'))
            i = body.find(key, i + 8 + n)
        else:
            i = body.find(key, i + 1)
    return out


def ident(b, table):
    v = b.u32()
    if v == 0xFFFFFFFF:
        return ''
    if v & 0xC0000000 in (0x40000000, 0x80000000):
        if v & 0x3FFFFFFF == 0:
            n = b.u32()
            s = b.take(n).decode('latin1')
            table.append(s)
            return s
        k = (v & 0x3FFFFFFF) - 1
        return table[k] if k < len(table) else '?%d' % k
    return '#%d' % v


def inputs_at(body, at):
    """CGameCtnGhost 0x03092019 (or 0x03092025 v0) body at `at` (after the chunk id)."""
    b = B(body, at)
    dur = b.i32()
    if dur == 0:
        return dur, []
    b.i32()
    table = id_table(body, at)
    names = [ident(b, table) for _ in range(b.u32())]
    num = b.i32()
    b.i32()
    ev = []
    for _ in range(num):
        t = b.i32() - 100000
        k = b.u8()
        data = b.u32()
        name = names[k] if k < len(names) else '?%d' % k
        ev.append((t, name, data))
    return dur, ev


def find_all(data, cid):
    """Where chunk cid's data starts, each time it appears (past a skippable chunk's PIKS and size)."""
    key = struct.pack('<I', cid)
    out = []
    i = data.find(key)
    while i >= 0:
        at = i + 4
        if data[at:at + 4] == b'PIKS':
            at += 8
        out.append(at)
        i = data.find(key, i + 1)
    return out


def load(path):
    """Every ghost in the file, in order: [{record, duration_ms, inputs}] (a replay of a campaign
    track holds several: the author's run and others)."""
    data = open(path, 'rb').read()
    r = g.Reader(data)
    hdr = g.read_header(r)
    body = g.read_body(r, hdr)
    records = []
    for cid in (0x0303F005, 0x0303F006):
        for at in find_all(body, cid):
            try:
                b = B(body, at)
                if cid == 0x0303F006:
                    b.u32()                           # IsReplaying
                usize = b.i32()
                n = b.u32()
                raw = zlib.decompress(b.take(n))
                if len(raw) == usize:
                    records.append((at, record_data(raw)))
            except Exception:
                continue
    inputs = []
    for cid in (0x03092019, 0x03092025, 0x03092011):
        for at in find_all(body, cid):
            try:
                dur, ev = inputs_at(body, at + (4 if cid == 0x03092025 else 0))
                if ev:
                    inputs.append((at, dur, ev))
            except Exception:
                continue
    records.sort(key=lambda x: x[0])
    inputs.sort(key=lambda x: x[0])
    ghosts = []
    for k, (at, rec) in enumerate(records):
        gh = {'record': rec}
        if k < len(inputs):
            gh['duration_ms'] = inputs[k][1]
            gh['inputs'] = inputs[k][2]
        ghosts.append(gh)
    return hdr, ghosts


def script(ev):
    """TMInterface-style lines (race.tscn --inputs): press/release keys, analog steer and gas."""
    lines = []
    for t, name, data in sorted(ev, key=lambda e: e[0]):
        if t < 0 or name.startswith('_Fake'):
            continue
        s = '%.2f' % (t / 1000.0)
        on = data != 0
        if name == 'Accelerate':
            lines.append('%s %s up' % (s, 'press' if on else 'rel'))
        elif name == 'Brake':
            lines.append('%s %s down' % (s, 'press' if on else 'rel'))
        elif name == 'SteerLeft':
            lines.append('%s %s left' % (s, 'press' if on else 'rel'))
        elif name == 'SteerRight':
            lines.append('%s %s right' % (s, 'press' if on else 'rel'))
        elif name == 'Steer':
            lines.append('%s steer %d' % (s, steer_value(data)))
        elif name in ('Gas', 'AccelerateReal'):
            lines.append('%s gas %d' % (s, gas_value(data)))
        elif name == 'BrakeReal':
            lines.append('%s brake %d' % (s, gas_value(data)))
    return lines


def controls(ev, duration_ms):
    """The inputs held each 10 ms tick from the start: [gas 0..1, brake 0..1, steer -1..1 (+ right)]."""
    keys = {'Accelerate': False, 'Brake': False, 'SteerLeft': False, 'SteerRight': False}
    gas = brake = steer = None
    out = []
    ev = sorted(ev, key=lambda e: e[0])
    k = 0
    for tick in range(0, duration_ms // 10 + 1):
        t = tick * 10
        while k < len(ev) and ev[k][0] <= t:
            _, name, data = ev[k]
            if name in keys:
                keys[name] = data != 0
            elif name == 'Steer':
                steer = steer_value(data) / 65536.0
            elif name in ('Gas', 'AccelerateReal'):
                gas = gas_value(data) / 65536.0
            elif name == 'BrakeReal':
                brake = gas_value(data) / 65536.0
            k += 1
        g = 1.0 if keys['Accelerate'] else (gas or 0.0)
        b = 1.0 if keys['Brake'] else (brake or 0.0)
        st = (1.0 if keys['SteerRight'] else 0.0) - (1.0 if keys['SteerLeft'] else 0.0)
        if st == 0.0 and steer is not None:
            st = steer
        out.append([g, b, max(-1.0, min(1.0, st))])
    return out


def main():
    path = [a for a in sys.argv[1:] if not a.startswith('--')][0]
    hdr, ghosts = load(path)
    pick = 0
    for a in sys.argv[1:]:
        if a.startswith('--ghost='):
            pick = int(a[8:])
    for k, gh in enumerate(ghosts):
        rec = gh.get('record', {})
        print('  ghost %d: %d samples, %s ms, %d input events' % (k, len(rec.get('samples', [])),
                                                              gh.get('duration_ms'), len(gh.get('inputs', []))))
    ghost = ghosts[pick] if ghosts else {}
    rec = ghost.get('record', {})
    ss = rec.get('samples', [])
    ev = ghost.get('inputs', [])
    names = sorted({e[1] for e in ev})
    print('%s: record %s v%s period %s ms, %d samples (%s bytes each); %d input events %s, duration %s ms'
          % (os.path.basename(path), rec.get('class'), rec.get('version'), rec.get('period_ms'), len(ss),
             ss[0]['bytes'] if ss else '-', len(ev), names, ghost.get('duration_ms')))
    for a in sys.argv[1:]:
        if a.startswith('--json='):
            dur = ghost.get('duration_ms') or (rec['samples'][-1]['t'] if rec.get('samples') else 0)
            json.dump({'record': rec, 'inputs': ev, 'duration_ms': dur, 'controls': controls(ev, dur + 3000)}, open(a[7:], 'w'))
        if a.startswith('--inputs='):
            open(a[9:], 'w').write('# from %s (TMNF ghost inputs)\n' % os.path.basename(path) + '\n'.join(script(ev)) + '\n')
    if '--samples' in sys.argv:
        for s in ss[::10]:
            w = s.get('wheels', [])
            print('%6d pos %8.2f %8.2f %8.2f  v %7.2f km/h  steer %+.2f gas %.2f brake %.2f  %s' % (
                s['t'], *s['pos'], math.sqrt(sum(c * c for c in s['vel'])) * 3.6, s.get('steer', 0), s.get('gas', 0),
                s.get('brake', 0), ' '.join('%s%s%s' % (SURFACES.get(x['surface'], x['surface'])[:4],
                                                         '*' if x.get('sliding') else '', '' if x.get('ground', True) else '^')
                                             for x in w)))


if __name__ == '__main__':
    main()
