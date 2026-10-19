'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Rounds, TRACKS, TMNF_CAMPAIGN, ownTracks } = require('../lib/rounds');

test('the game\'s own tracks are the default, TMNF\'s campaign has 65', () => {
  assert.ok(TRACKS.length >= 6, `${TRACKS.length} own tracks`);
  assert.ok(TRACKS.every((t) => fs.existsSync(path.join(__dirname, '..', '..', 'tracks', `${t}.json`))), 'every listed track has its file');
  assert.ok(TRACKS.includes(new Rounds().begin(0).track));
  assert.strictEqual(TMNF_CAMPAIGN.length, 65);
  assert.strictEqual(TMNF_CAMPAIGN[0], 'A01');
  assert.strictEqual(TMNF_CAMPAIGN[64], 'E05');
});

test('the campaign: a list of ids, or series one after another', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sf-tracks-'));
  try {
    for (const f of ['A01', 'A02', 'B01', 'X99']) fs.writeFileSync(path.join(dir, `${f}.json`), '{}');
    fs.writeFileSync(path.join(dir, 'campaign.json'), JSON.stringify({ series: [{ name: 'White', tracks: ['A01', 'A02'] },
      { name: 'Green', tracks: ['B01'] }] }));
    assert.deepStrictEqual(ownTracks(dir), ['A01', 'A02', 'B01']);
    fs.writeFileSync(path.join(dir, 'campaign.json'), JSON.stringify(['B01', 'A01']));
    assert.deepStrictEqual(ownTracks(dir), ['B01', 'A01']);
    fs.writeFileSync(path.join(dir, 'A02.json'), JSON.stringify({ name: 'long', online: false }));
    assert.deepStrictEqual(ownTracks(dir), ['B01', 'A01']);
    fs.writeFileSync(path.join(dir, 'campaign.json'), JSON.stringify({ series: [{ name: 'White', tracks: ['A01', 'A02'] }] }));
    assert.deepStrictEqual(ownTracks(dir), ['A01'], 'a track off the online rotation');
    fs.unlinkSync(path.join(dir, 'campaign.json'));
    assert.deepStrictEqual(ownTracks(dir), ['A01', 'B01', 'X99']);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('own tracks cycle: every one before any repeats', () => {
  let r = 0;
  // a recently-played window as long as the list: every track once before any repeats
  const rounds = new Rounds({ roundMs: 1000, resultsMs: 100, recent: TRACKS.length, random: () => (r = (r + 0.61) % 1) });
  const seen = [rounds.begin(0).track];
  for (let i = 1; i < TRACKS.length; i++) {
    rounds.tick(i * 1100 - 100);
    rounds.tick(i * 1100);
    seen.push(rounds.track);
  }
  assert.deepStrictEqual(seen.slice().sort(), TRACKS.slice().sort());
});

test('rounds rotate: race, results, next random track not recently played', () => {
  let r = 0;
  const rounds = new Rounds({ roundMs: 1000, resultsMs: 100, tracks: TMNF_CAMPAIGN, random: () => (r = (r + 0.37) % 1) });
  const seen = [rounds.begin(0).track];
  let now = 0;
  for (let i = 0; i < 20; i++) {
    now += 1000;
    assert.strictEqual(rounds.tick(now), 'results');
    assert.strictEqual(rounds.state, 'results');
    now += 100;
    assert.strictEqual(rounds.tick(now), 'race');
    seen.push(rounds.track);
  }
  for (let i = 1; i < seen.length; i++) {
    const window = seen.slice(Math.max(0, i - 12), i);
    assert.ok(!window.includes(seen[i]), `${seen[i]} repeated within 12 rounds`);
  }
  assert.strictEqual(rounds.id, 21);
});

test('finishes: only this round and track, best time kept, ranking sorted', () => {
  const rounds = new Rounds({ roundMs: 300000, random: () => 0 });
  const info = rounds.begin(0);
  assert.ok(!rounds.finish(1, 'a', info.id, 'Z99', 30000), 'wrong track');
  assert.ok(!rounds.finish(1, 'a', info.id + 1, info.track, 30000), 'wrong round');
  assert.ok(!rounds.finish(1, 'a', info.id, info.track, 10), 'too short');
  assert.ok(rounds.finish(1, 'a', info.id, info.track, 30000));
  assert.ok(!rounds.finish(1, 'a', info.id, info.track, 31000), 'slower kept out');
  assert.ok(rounds.finish(2, 'b', info.id, info.track, 29000));
  assert.ok(rounds.finish(1, 'a', info.id, info.track, 28000));
  assert.deepStrictEqual(rounds.ranking().map((x) => [x.name, x.time]), [['a', 28000], ['b', 29000]]);
  rounds.tick(300000);
  assert.ok(!rounds.finish(2, 'b', info.id, info.track, 20000), 'not after the round');
});
