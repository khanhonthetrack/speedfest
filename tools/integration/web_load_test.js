// Loads a web build URL in headless Chromium (SwiftShader WebGL2), waits, screenshots, prints console.
// usage: NODE_PATH=$(npm root -g) node tools/integration/web_load_test.js <url> <out.png> [waitMs]
// usage: node load_test.js <url> <out.png> [waitMs]
const { chromium } = require('playwright');
(async () => {
  const [url, out, waitMs] = [process.argv[2], process.argv[3], parseInt(process.argv[4] || '15000')];
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  page.on('console', m => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', e => logs.push(`[pageerror] ${e.message}`));
  await page.goto(url);
  await page.waitForTimeout(waitMs);
  await page.screenshot({ path: out });
  const gl = await page.evaluate(() => { const c = document.createElement('canvas'); const g = c.getContext('webgl2'); return g ? g.getParameter(g.VERSION) + ' / ' + (g.getExtension('WEBGL_debug_renderer_info') ? g.getParameter(g.getExtension('WEBGL_debug_renderer_info').UNMASKED_RENDERER_WEBGL) : '?') : 'no webgl2'; });
  console.log('WEBGL', gl);
  console.log(logs.slice(0, 40).join('\n'));
  await browser.close();
})();
