// ソースマップの sourcesContent から原ソースを復元する。
// 使い方: node extract-sourcemap.mjs <*.js.map> <出力ルート>
//
// 配布物はバンドル済みでコンポーネントの原ファイルを含まないが、ソースマップに
// 原ソースが埋め込まれている。開発時のディレクトリ構造で書き出すことで、
// コンポーネント名からファイルを引けるようにする。
import fs from 'node:fs';
import path from 'node:path';

const [mapFile, outRoot] = process.argv.slice(2);
if (!mapFile || !outRoot) {
  console.error('使い方: node extract-sourcemap.mjs <*.js.map> <出力ルート>');
  process.exit(2);
}

const map = JSON.parse(fs.readFileSync(mapFile, 'utf8'));
if (!map.sourcesContent || map.sourcesContent.length === 0) {
  console.error(`sourcesContent がありません: ${mapFile}`);
  process.exit(1);
}

// 依存ライブラリ由来のソースは _deps/ に分け、本体のソースと混ざらないようにする
function classify(src) {
  const parts = src.split(/[\\/]/).filter((p) => p && p !== '.' && p !== '..');
  const dep = parts.indexOf('node_modules');
  if (dep >= 0) return { area: '_deps', rel: parts.slice(dep + 1).join('/') };
  const vue = parts.indexOf('vue');
  if (vue >= 0 && parts.includes('src') && parts.includes('main')) {
    return { area: 'src/main/vue', rel: parts.slice(vue + 1).join('/') };
  }
  return { area: '_other', rel: parts.join('/') };
}

const stats = { own: 0, deps: 0, other: 0, skipped: 0 };
map.sources.forEach((src, i) => {
  const content = map.sourcesContent[i];
  const { area, rel } = classify(src);
  if (content == null || !rel) {
    stats.skipped++;
    return;
  }
  const dest = path.join(outRoot, area, rel);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, content);
  if (area === '_deps') stats.deps++;
  else if (area === '_other') stats.other++;
  else stats.own++;
});

// 走査対象0件は異常として扱う(空振りを成功にしない)
if (stats.own === 0) {
  console.error('本体のソースを1件も復元できませんでした');
  process.exit(1);
}
console.log(`復元: 本体 ${stats.own} / 依存 ${stats.deps} / その他 ${stats.other} / 除外 ${stats.skipped}`);
