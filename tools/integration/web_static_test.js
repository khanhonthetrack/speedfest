// Static web build test: serve the exported folder from a SUB-PATH with a plain static file server
// (no COOP/COEP headers, no game server), load it in headless Chromium, start a solo run with the
// AutoDriver (--auto_solo=<track> --autodrive) and wait for the finish. Saves screenshots.
// Checks: page boots without SharedArrayBuffer/cross-origin isolation, no 404s, no script errors,
// the race finishes.
//
// usage: NODE_PATH=$(npm root -g) node tools/integration/web_static_test.js <build_dir> <out_dir> [track=rails] [timeout_s=600] [shots_every_s=0]
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const [buildDir, outDir, trackArg, timeoutArg, everyArg] = process.argv.slice(2);
if (!buildDir || !outDir) {
  console.error('usage: web_static_test.js <build_dir> <out_dir> [track] [timeout_s] [shots_every_s]');
  process.exit(2);
}
const track = trackArg || 'rails';
const timeoutS = parseInt(timeoutArg || '600', 10);
const everyS = parseFloat(everyArg || '0');
const SUB = '/speedfest/';
fs.mkdirSync(outDir, { recursive: true });
const TYPES = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json', '.ico': 'image/x-icon' };
const notFound = [];
// Deliberately minimal: plain files, no special headers (like GitHub Pages / any static host).
const server = http.createServer((req, res) => {
  const u = decodeURIComponent(req.url.split('?')[0]);
  if (!u.startsWith(SUB)) { notFound.push(u); res.writeHead(404); res.end(); return; }
  let f = path.join(buildDir, u.slice(SUB.length) || 'index.html');
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { notFound.push(u); res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});

server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const url = `http://127.0.0.1:${port}${SUB}index.html?arg=${encodeURIComponent('--auto_solo=' + track)}&arg=--autodrive`;
  console.log('URL', url);
  const browser = await chromium.launch({
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl',
      '--autoplay-policy=no-user-gesture-required'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  let finishMs = -1;
  const t0 = Date.now();
  page.on('console', (m) => {
    const t = m.text();
    if (/AUTODRIVE|AUTOPILOT|SCRIPT ERROR|Parse Error|grind|finish/i.test(t)) console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s] ${t}`);
    const mm = t.match(/AUTODRIVE finish (\d+)/);
    if (mm) finishMs = parseInt(mm[1], 10);
    if (m.type() === 'error' || /SCRIPT ERROR|Parse Error/.test(t)) errors.push(t);
  });
  page.on('pageerror', (e) => errors.push('pageerror ' + e.message));
  await page.goto(url);
  const isolated = await page.evaluate(() => [window.crossOriginIsolated, typeof SharedArrayBuffer]);
  console.log('crossOriginIsolated', isolated[0], 'SharedArrayBuffer', isolated[1]);
  let shot = 0;
  let lastShot = Date.now();
  while (finishMs < 0 && (Date.now() - t0) / 1000 < timeoutS) {
    await page.waitForTimeout(1000);
    if (everyS > 0 && Date.now() - lastShot >= everyS * 1000) {
      lastShot = Date.now();
      await page.screenshot({ path: path.join(outDir, `web_${track}_${String(shot++).padStart(3, '0')}.png`) });
    }
  }
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(outDir, `web_${track}_end.png`) });
  await browser.close();
  server.close();
  const ok = finishMs > 0 && errors.length === 0 && notFound.length === 0;
  console.log(`finish_ms=${finishMs} errors=${errors.length} not_found=${JSON.stringify(notFound)}`);
  for (const e of errors.slice(0, 10)) console.log('  error:', e);
  console.log(ok ? 'WEB_STATIC_PASS' : 'WEB_STATIC_FAIL');
  process.exit(ok ? 0 : 1);
});
