// ブラウザ版の 画面めぐり（godot/tests/web_text.gd）を Chromium で 動かし、出た 行を ファイルに 書く。
// tools/web_text_check.sh が 呼ぶ。  node tools/web_text_browser.js <URL> <出力ファイル> [待つ 秒（既定 1800）]
// 出力：コンソールの「WEBTEXT …」の 行 そのまま ＋ エラー（「CONSOLE ERROR …」「PAGE ERROR …」）。
// 画面は 1280×720・倍率 1（テストと 同じ 大きさ）。ソフトウェア描画（swiftshader）なので おそい。
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }
const fs = require('fs');

(async () => {
  const [url, outFile, limitArg] = process.argv.slice(2);
  if (!url || !outFile) { console.error('使い方: node web_text_browser.js <URL> <出力>'); process.exit(2); }
  const limit = Number(limitArg || 1800) * 1000;
  const out = fs.createWriteStream(outFile);
  const browser = await pw.chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  let done = false;
  let lines = 0;
  page.on('console', (m) => {
    const t = m.text();
    if (t.startsWith('WEBTEXT ')) {
      out.write(t + '\n');
      lines++;
      if (t.startsWith('WEBTEXT {"end"')) done = true;
    } else if (m.type() === 'error' || /SCRIPT ERROR|^ERROR/.test(t)) {
      out.write('CONSOLE ERROR ' + t.replace(/\n/g, ' ') + '\n');
    }
  });
  page.on('pageerror', (e) => out.write('PAGE ERROR ' + String(e).replace(/\n/g, ' ') + '\n'));
  const t0 = Date.now();
  await page.goto(url);
  let last = -1;
  while (!done && Date.now() - t0 < limit) {
    await page.waitForTimeout(2000);
    if (lines !== last && (Date.now() - t0) > 60000 && lines % 200 < 20) process.stderr.write(`  ブラウザ: ${lines} 行（${Math.round((Date.now() - t0) / 1000)} 秒）\n`);
    last = lines;
  }
  if (!done) out.write('TIMEOUT ' + Math.round((Date.now() - t0) / 1000) + '\n');
  await new Promise((r) => out.end(r));
  await browser.close();
  process.exit(done ? 0 : 1);
})();
