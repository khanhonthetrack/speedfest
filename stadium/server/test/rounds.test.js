'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { Rounds, CAMPAIGN } = require('../lib/rounds');

test('campaign has 65 tracks', () => {
  assert.strictEqual(CAMPAIGN.length, 65);
  assert.strictEqual(CAMPAIGN[0], 'A01');
  assert.strictEqual(CAMPAIGN[64], 'E05');
});

test('rounds rotate: race, results, next random track not recently played', () => {
  let r = 0;
  const rounds = new Rounds({ roundMs: 1000, resultsMs: 100, random: () => (r = (r + 0.37) % 1) });
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
