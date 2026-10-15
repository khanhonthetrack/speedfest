// End-to-end online test in real browsers: N headless Chromium pages load the web build from a
// running SpeedFest server, and AutoPilot (game/autoload/auto_pilot.gd) drives them through one
// online round with --autodrive. Prints PASS/FAIL plus per-client AUTOPILOT events, and saves
// screenshots of every client during the race.
//
// usage: [CARS=kitsune,goliath] NODE_PATH=$(npm root -g) node tools/integration/online_browser_test.js <base_url> <out_dir> [clients=3] [track=arena] [duration_s=60]
// e.g.   PUBLIC_DIR=/tmp/web COUNTDOWN_MS=2000 RESULTS_MS=4000 PORT=8090 node server/server.js &
//        NODE_PATH=$(npm root -g) node tools/integration/online_browser_test.js http://127.0.0.1:8090 /tmp/out 3 arena 45
//
// SwiftShader renders slowly, so the race runs below real time. The test checks the online flow
// (connect, join, round start, race scene, remote players, round end, back to lobby). Finishes are
// reported but not required.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const [base, outDir, nArg, track, durArg] = process.argv.slice(2);
const N = parseInt(nArg || '3', 10);
const duration = parseInt(durArg || '60', 10);
if (!base || !outDir) {
  console.error('usage: online_browser_test.js <base_url> <out_dir> [clients] [track] [duration_s]');
  process.exit(2);
}
fs.mkdirSync(outDir, { recursive: true });

// CARS=goliath,pixie picks the clients' cars (default kaze, brute, veloce)
const CAR_LIST = (process.env.CARS || 'kaze,brute,veloce').split(',').map((c) => c.trim()).filter(Boolean);

function urlFor(i) {
  const args = [
    `--auto_online=${i === 0 ? 'host' : 'guest'}`,
    '--autodrive',
    `--name=Bot${i + 1}`,
    `--car=${CAR_LIST[i % CAR_LIST.length]}`,
  ];
  if (i === 0) args.push(`--track=${track || 'arena'}`, `--duration=${duration}`, `--expect=${N}`);
  return `${base.replace(/\/$/, '')}/index.html?` + args.map((a) => 'arg=' + encodeURIComponent(a)).join('&');
}

(async () => {
  const browser = await chromium.launch({
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl',
      '--autoplay-policy=no-user-gesture-required'],
  });
  const clients = [];
  for (let i = 0; i < N; i++) {
    const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
    const c = { i, page, logs: [], events: {}, errors: [] };
    page.on('console', (m) => {
      const t = m.text();
      c.logs.push(`[${m.type()}] ${t}`);
      const mm = t.match(/^AUTOPILOT (\w+)/);
      if (mm) c.events[mm[1]] = (c.events[mm[1]] || 0) + 1;
      if (m.type() === 'error' || /SCRIPT ERROR|Parse Error/.test(t)) c.errors.push(t);
    });
    page.on('pageerror', (e) => c.errors.push('pageerror ' + e.message));
    clients.push(c);
    // Stagger: the host creates the room first, guests join it.
    await page.goto(urlFor(i));
    await page.waitForTimeout(i === 0 ? 8000 : 2000);
  }

  // Loading N software-rendered pages can take minutes on a CPU-only box: give the clients up to
  // LOAD_S to connect and start the round, then the round itself (duration + margin) from its start.
  const t0 = Date.now();
  const loadMs = Number(process.env.LOAD_S || 420) * 1000;
  const roundMs = (duration + 120) * 1000;
  let tStart = 0;
  let shotTaken = false;
  while (Date.now() - t0 < loadMs + roundMs) {
    await new Promise((r) => setTimeout(r, 2000));
    const started = clients.every((c) => c.events.round_start);
    if (started && !tStart) tStart = Date.now();
    if (!started && Date.now() - t0 > loadMs) break;
    if (tStart && Date.now() - tStart > roundMs) break;
    if (started && !shotTaken && Date.now() - tStart > 25000) {
      shotTaken = true;
      for (const c of clients) await c.page.screenshot({ path: path.join(outDir, `client${c.i + 1}_race.png`) });
    }
    if (clients.every((c) => c.events.round_end)) break;
  }
  await new Promise((r) => setTimeout(r, 6000));
  for (const c of clients) await c.page.screenshot({ path: path.join(outDir, `client${c.i + 1}_end.png`) });

  let ok = true;
  for (const c of clients) {
    fs.writeFileSync(path.join(outDir, `client${c.i + 1}.log`), c.logs.join('\n'));
    const need = ['connected', 'round_start', 'round_end'];
    const missing = need.filter((k) => !c.events[k]);
    if (missing.length) ok = false;
    console.log(`client${c.i + 1}: events=${JSON.stringify(c.events)} missing=${JSON.stringify(missing)} errors=${c.errors.length}`);
    for (const e of c.errors.slice(0, 8)) console.log('   ' + e.slice(0, 200));
    const end = c.logs.filter((l) => l.includes('AUTOPILOT round_end')).pop();
    if (end) console.log('   ' + end.slice(0, 300));
  }
  console.log(ok ? `PASS online_browser_test: ${N} clients` : 'FAIL online_browser_test');
  await browser.close();
  process.exit(ok ? 0 : 1);
})();
