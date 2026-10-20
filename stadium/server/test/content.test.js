'use strict';
// Community content: the GBX reader, track and car checks, TMX / ManiaPark links, and the admin
// API end to end (uploads, imports, rotations, cars, players downloading the files).
// TMX_DIR=<a folder of .Challenge.Gbx> (tools/compat/fetch_tmx.py) also checks real tracks.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');
const lzo = require('../lib/lzo');
const gbx = require('../lib/gbx');
const zip = require('../lib/zip');
const { Content, checkTrack, checkCar, tmxUrl, maniaparkUrl, loadCatalogue } = require('../lib/content');
const { Store } = require('../lib/store');
const { createServer, VERSION } = require('../server');

const START = { name: 'StadiumRoadMainStartLine', coord: [10, 1, 10] };
const FINISH = { name: 'StadiumRoadMainFinishLine', coord: [10, 1, 14] };
const track = (opts = {}) => gbx.writeChallenge({ blocks: [START, { name: 'StadiumRoadMain', coord: [10, 1, 11] }, FINISH], ...opts });

function solid() {
  // a GBX header of a CPlugSolid (the class the game reads car meshes from); the body isn't checked here
  const b = Buffer.alloc(40);
  b.write('GBX', 0, 'latin1');
  b.writeUInt16LE(6, 3);
  b.write('BUCR', 5, 'latin1');
  b.writeUInt32LE(0x09005000, 9);
  return b;
}

test('LZO literal streams and GBX tracks round-trip', () => {
  const data = Buffer.from('x'.repeat(1000) + 'hello');
  assert.deepStrictEqual(lzo.decompress(lzo.literals(data), data.length), data);
  assert.deepStrictEqual(lzo.decompress(lzo.literals(Buffer.from('abc')), 3), Buffer.from('abc'));
  assert.strictEqual(lzo.decompress(Buffer.from([0]), 10), null);
  for (const compress of [false, true]) {
    const c = gbx.readChallenge(track({ name: '$f00Red', author: 'bob', compress }));
    assert.strictEqual(c.error, '');
    assert.strictEqual(c.name, '$f00Red');
    assert.strictEqual(c.author, 'bob');
    assert.strictEqual(c.environment, 'Stadium');
    assert.strictEqual(c.times.author, 40000);
    assert.deepStrictEqual(c.blocks.map((b) => b.name), [START.name, 'StadiumRoadMain', FINISH.name]);
  }
  assert.match(gbx.readChallenge(Buffer.from('nope')).error, /GBX/);
  assert.match(gbx.readChallenge(track().subarray(0, 120)).error, /end of data|LZO|body/);
});

test('track checks: Stadium blocks, a start and a finish', () => {
  const cat = loadCatalogue();
  assert.ok(cat.size > 300, 'the block catalogue is found');
  const ok = checkTrack(track({ name: 'Mine' }), cat);
  assert.ifError(ok.error);
  assert.strictEqual(ok.track.name, 'Mine');
  assert.strictEqual(ok.track.blocks, 3);
  assert.match(checkTrack(track({ environment: 'Desert' }), cat).error, /Desert/);
  assert.match(checkTrack(gbx.writeChallenge({ blocks: [FINISH] }), cat).error, /no start/);
  assert.match(checkTrack(gbx.writeChallenge({ blocks: [START] }), cat).error, /no finish/);
  assert.match(checkTrack(gbx.writeChallenge({ blocks: [START, FINISH, { name: 'DesertRoad' }] }), cat).error, /aren't TMNF Stadium blocks/);
  const laps = checkTrack(gbx.writeChallenge({ blocks: [{ name: 'StadiumRoadMainStartFinishLine' }] }), cat);
  assert.ifError(laps.error);
  assert.strictEqual(laps.track.lap_race, true);
  assert.match(checkTrack(Buffer.from('GBX'), cat).error, /empty/);
});

test('car packs: checked and repacked with what the game uses', () => {
  const pack = zip.write([
    { name: 'MyCar/MainBody.Solid.Gbx', data: solid() },
    { name: 'MyCar/Diffuse.dds', data: Buffer.from('DDS fake texture') },
    { name: 'MyCar/Diffuse.psd', data: Buffer.alloc(5000, 7) },
    { name: 'MyCar/Engine/loop_4200Rpm_throttle_engine.wav', data: Buffer.from('RIFF') },
    { name: 'MyCar/readme.txt', data: Buffer.from('by someone') },
  ]);
  const r = checkCar(pack, 'My Car');
  assert.ifError(r.error);
  assert.deepStrictEqual(r.car.files, ['Diffuse.dds', 'Engine/loop_4200Rpm_throttle_engine.wav', 'MainBody.Solid.Gbx', 'readme.txt']);
  assert.ok(r.car.mesh && r.car.skin && r.car.sounds);
  const back = zip.list(r.data).entries;
  assert.strictEqual(zip.read(r.data, back.find((e) => e.name === 'Diffuse.dds')).toString(), 'DDS fake texture');
  const skin = checkCar(zip.write([{ name: 'Diffuse.dds', data: Buffer.from('x') }, { name: 'Icon.dds', data: Buffer.from('y') }]));
  assert.ifError(skin.error);
  assert.ok(skin.car.skin && !skin.car.mesh);
  assert.match(checkCar(zip.write([{ name: 'readme.txt', data: Buffer.from('x') }])).error, /no car/);
  assert.match(checkCar(Buffer.from('not a zip at all, sorry')).error, /not a car pack/);
  const notSolid = solid();
  notSolid.writeUInt32LE(0x03043000, 9);
  assert.match(checkCar(zip.write([{ name: 'MainBody.Solid.Gbx', data: notSolid }])).error, /CPlugSolid/);
});

test('TMX and ManiaPark links', () => {
  assert.strictEqual(tmxUrl('924307'), 'https://tmnf.exchange/trackgbx/924307');
  assert.strictEqual(tmxUrl('tmuf:7267999'), 'https://tmuf.exchange/trackgbx/7267999');
  assert.strictEqual(tmxUrl('https://tmnf.exchange/trackshow/924307'), 'https://tmnf.exchange/trackgbx/924307');
  assert.strictEqual(tmxUrl('https://tmuf.exchange/trackgbx/12'), 'https://tmuf.exchange/trackgbx/12');
  assert.strictEqual(tmxUrl('https://evil.example/trackshow/1'), '');
  assert.strictEqual(maniaparkUrl('https://maniapark.com/skin/sbCNfUzCnE6qop08HeXZ0g'), 'https://maniapark.com/skin/sbCNfUzCnE6qop08HeXZ0g/download');
  assert.strictEqual(maniaparkUrl('https://www.maniapark.com/model/Mobqi7WKEkijExu1VaYW8w/download'), 'https://maniapark.com/model/Mobqi7WKEkijExu1VaYW8w/download');
  assert.strictEqual(maniaparkUrl('https://maniapark.com.evil/skin/abcdefgh'), '');
});

test('content store: replace by uid, files by hash', () => {
  const c = new Content(new Store(''), '');
  const a = c.addTrack(track({ name: 'One' }));
  assert.ifError(a.error);
  assert.strictEqual(c.file(`${a.track.sha256}.Challenge.Gbx`).length, a.track.size);
  const b = c.addTrack(track({ name: 'One v2' }));
  assert.strictEqual(b.replaced, true);
  assert.strictEqual(Object.keys(c.tracks).length, 1);
  assert.strictEqual(c.file(`${a.track.sha256}.Challenge.Gbx`), null);
  assert.strictEqual(c.file('../master.json'), null);
  assert.ok(c.removeTrack(b.track.uid));
  assert.strictEqual(c.file(`${b.track.sha256}.Challenge.Gbx`), null);
});

function client(port, pathName = '/ws') {
  const ws = new WebSocket(`ws://127.0.0.1:${port}${pathName}`);
  const inbox = [];
  ws.on('message', (d) => inbox.push(JSON.parse(d.toString())));
  const next = (type, timeout = 3000, pred = () => true) => new Promise((resolve, reject) => {
    const t0 = Date.now();
    const look = () => {
      const i = inbox.findIndex((m) => m.t === type && pred(m));
      if (i >= 0) return resolve(inbox.splice(i, 1)[0]);
      if (Date.now() - t0 > timeout) return reject(new Error('timeout waiting for ' + type));
      setTimeout(look, 20);
    };
    look();
  });
  return { ws, next, open: new Promise((r) => ws.on('open', r)) };
}

test('admins upload tracks and cars, set the rotation; players download them', async () => {
  const carZip = zip.write([{ name: 'MainBody.Solid.Gbx', data: solid() }, { name: 'Diffuse.dds', data: Buffer.from('tex') }]);
  const remote = new Map([
    ['https://tmnf.exchange/trackgbx/4242', track({ uid: 'FromTmx0000000000000000000', name: 'From TMX' })],
    ['https://maniapark.com/model/Mobqi7WKEkijExu1VaYW8w/download', carZip],
  ]);
  const fetchMock = async (url) => {
    const body = remote.get(url);
    return { ok: !!body, status: body ? 200 : 404, headers: new Map([['content-disposition', 'attachment; filename=HighlandCar.zip']]),
      arrayBuffer: async () => body };
  };
  const srv = createServer({ adminPassword: 'let-me-in', fetch: fetchMock });
  await new Promise((r) => srv.listen(0, r));
  const port = srv.httpServer.address().port;
  const base = `http://127.0.0.1:${port}`;
  const call = (method, p, body, { raw = false, auth = 'Admin let-me-in' } = {}) => fetch(base + p, { method,
    headers: { ...(auth ? { authorization: auth } : {}), 'content-type': raw ? 'application/octet-stream' : 'application/json' },
    body: body === undefined ? undefined : raw ? body : JSON.stringify(body) }).then(async (r) => ({ code: r.status, body: await r.json() }));
  try {
    assert.strictEqual((await call('GET', '/api/admin', undefined, { auth: '' })).code, 401);
    assert.strictEqual((await call('GET', '/api/admin', undefined, { auth: 'Admin wrong' })).code, 401);
    let r = await call('GET', '/api/admin');
    assert.strictEqual(r.code, 200);
    assert.strictEqual(r.body.servers[0].id, 'main');
    // a file upload, onto the server's rotation
    const file = track({ uid: 'Uploaded000000000000000000', name: 'Uploaded' });
    r = await call('POST', '/api/admin/tracks?servers=main', file, { raw: true });
    assert.strictEqual(r.code, 200, JSON.stringify(r.body));
    assert.deepStrictEqual(r.body.servers, ['main']);
    const up = r.body.track;
    assert.ok(srv.games.get('main').mode.r.tracks.includes(up.uid));
    r = await call('POST', '/api/admin/tracks', gbx.writeChallenge({ blocks: [START] }), { raw: true });
    assert.strictEqual(r.code, 400);
    assert.match(r.body.error, /finish/);
    // imported from TMX
    r = await call('POST', '/api/admin/tracks?servers=all', { tmx: 'https://tmnf.exchange/trackshow/4242' });
    assert.strictEqual(r.code, 200, JSON.stringify(r.body));
    assert.strictEqual(r.body.track.source.site, 'tmnf.exchange');
    r = await call('POST', '/api/admin/tracks', { tmx: '99' });
    assert.strictEqual(r.code, 400);
    // the file, as players download it
    const dl = await fetch(base + up.url);
    assert.strictEqual(dl.status, 200);
    assert.match(String(dl.headers.get('cache-control')), /immutable/);
    assert.deepStrictEqual(Buffer.from(await dl.arrayBuffer()), file);
    // a car from ManiaPark, then everyone on it
    r = await call('POST', '/api/admin/cars?servers=main', { maniapark: 'https://maniapark.com/model/Mobqi7WKEkijExu1VaYW8w' });
    assert.strictEqual(r.code, 200, JSON.stringify(r.body));
    const car = r.body.car;
    assert.strictEqual(car.name, 'HighlandCar');
    assert.strictEqual(car.source.kind, 'model');
    // a player joins: the server's cars, then the uploaded track now
    const a = client(port);
    await a.open;
    a.ws.send(JSON.stringify({ t: 'hello', name: 'Ann', version: VERSION, car: car.id }));
    const w = await a.next('welcome');
    assert.deepStrictEqual(w.cars.map((c) => c.id), [car.id]);
    assert.strictEqual(w.players[0].car, car.id);
    r = await call('POST', '/api/admin/servers/main', { jump: up.uid });
    assert.strictEqual(r.code, 200, JSON.stringify(r.body));
    const rd = await a.next('round', 3000, (m) => m.round.track === up.uid);
    assert.strictEqual(rd.round.file.sha256, up.sha256);
    assert.strictEqual(rd.round.file.url, up.url);
    a.ws.send(JSON.stringify({ t: 'finish', round: rd.round.id, track: up.uid, time: 31234 }));
    const pl = await a.next('players', 3000, (m) => m.players.some((p) => p.best === 31234));
    assert.strictEqual(pl.players[0].best, 31234);
    // a car nobody uploaded is refused; the forced car wins
    a.ws.send(JSON.stringify({ t: 'car', id: 'nope' }));
    await a.next('players', 3000, (m) => m.players[0].car === '');
    r = await call('POST', '/api/admin/servers/main', { forced_car: car.id });
    assert.strictEqual(r.code, 200);
    await a.next('players', 3000, (m) => m.players[0].car === car.id);
    // rotations only take known tracks; deleting a track takes it out of the rotations
    r = await call('POST', '/api/admin/servers/main', { add_tracks: ['NoSuchTrack'] });
    assert.strictEqual(r.code, 400);
    r = await call('DELETE', `/api/admin/tracks/${up.uid}`);
    assert.strictEqual(r.code, 200);
    assert.ok(!srv.games.get('main').mode.r.tracks.includes(up.uid));
    assert.strictEqual((await fetch(base + up.url)).status, 404);
    r = await call('DELETE', `/api/admin/cars/${car.id}`);
    assert.strictEqual(r.code, 200);
    await a.next('cars', 3000, (m) => m.cars.length === 0);
    // the rotation and cars are kept for the next start
    assert.ok(srv.store.data.servers.main.tracks.includes('FromTmx0000000000000000000'));
    a.ws.close();
  } finally {
    await new Promise((r) => srv.close(r));
  }
});

test('admin accounts and servers without admins', async () => {
  const off = createServer({});
  await new Promise((r) => off.listen(0, r));
  try {
    const r = await fetch(`http://127.0.0.1:${off.httpServer.address().port}/api/admin`, { headers: { authorization: 'Admin x' } });
    assert.strictEqual(r.status, 403);
  } finally { await new Promise((r) => off.close(r)); }
  const srv = createServer({ admins: ['boss'] });
  await new Promise((r) => srv.listen(0, r));
  const base = `http://127.0.0.1:${srv.httpServer.address().port}`;
  const post = (p, body, token) => fetch(base + p, { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body) }).then(async (r) => ({ code: r.status, body: await r.json() }));
  try {
    const boss = (await post('/api/register', { login: 'boss', password: 'boss-password' })).body.token;
    const pleb = (await post('/api/register', { login: 'pleb', password: 'pleb-password' })).body.token;
    assert.strictEqual((await fetch(`${base}/api/admin`, { headers: { authorization: `Bearer ${boss}` } })).status, 200);
    assert.strictEqual((await fetch(`${base}/api/admin`, { headers: { authorization: `Bearer ${pleb}` } })).status, 403);
    assert.strictEqual((await fetch(`${base}/admin`)).status, 200);
  } finally { await new Promise((r) => srv.close(r)); }
});

test('real TrackMania Exchange tracks (TMX_DIR)', { skip: !process.env.TMX_DIR }, () => {
  const dir = process.env.TMX_DIR;
  const cat = loadCatalogue();
  const fails = [];
  let n = 0;
  const modded = [];
  for (const f of fs.readdirSync(dir).filter((x) => /\.gbx$/i.test(x))) {
    n += 1;
    const r = checkTrack(fs.readFileSync(path.join(dir, f)), cat);
    // modded tracks (TMUnlimiter, other environments' or custom blocks) are refused with the reason
    if (r.error && /TMUnlimiter|modded track/.test(r.error)) modded.push(`${f}: ${r.error}`);
    else if (r.error) fails.push(`${f}: ${r.error}`);
  }
  console.log(`TMX_DIR: ${n} tracks, ${fails.length} refused, ${modded.length} modded`);
  for (const m of modded) console.log(`  modded ${m}`);
  assert.deepStrictEqual(fails, []);
});

test('gbx: a string id of -2 (0xFFFFFFFE, some editors\' unassigned) reads as empty, as -1 does', () => {
  const ids = Buffer.alloc(16);
  ids.writeUInt32LE(3, 0);               // the lookback version
  ids.writeUInt32LE(0xFFFFFFFE, 4);
  ids.writeUInt32LE(0xFFFFFFFF, 8);
  ids.writeUInt32LE(0xFFFFFFFE, 12);
  const s = new gbx.Stream(ids);
  assert.deepStrictEqual([s.lookback(), s.lookback(), s.lookback()], ['', '', '']);
  assert.strictEqual(s.error || '', '');
});
