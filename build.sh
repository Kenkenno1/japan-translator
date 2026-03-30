#!/bin/bash
# ============================================================
# japan-translator 混淆部署腳本
# 用法: bash build.sh
# 功能: 混淆 JS + 壓縮 CSS → push 到 GitHub → 還原本地原始碼
# ============================================================
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

SRC="index.html"
BACKUP="_index_src.html"
TEMP_JS="_temp.js"
OBF_JS="_temp_obf.js"

echo "📦 Step 1: 備份原始檔..."
cp "$SRC" "$BACKUP"

echo "🔧 Step 2: 提取 JS..."
sed -n '/<script>/,/<\/script>/p' "$SRC" | sed '1d;$d' > "$TEMP_JS"

echo "🔒 Step 3: 混淆 JS（深度模式）..."
npx javascript-obfuscator "$TEMP_JS" \
  --output "$OBF_JS" \
  --compact true \
  --control-flow-flattening true \
  --control-flow-flattening-threshold 0.75 \
  --dead-code-injection true \
  --dead-code-injection-threshold 0.4 \
  --identifier-names-generator hexadecimal \
  --rename-globals false \
  --self-defending true \
  --string-array true \
  --string-array-calls-transform true \
  --string-array-encoding base64 \
  --string-array-threshold 0.75 \
  --string-array-rotate true \
  --string-array-shuffle true \
  --split-strings true \
  --split-strings-chunk-length 10 \
  --transform-object-keys true \
  --unicode-escape-sequence false \
  --numbers-to-expressions true \
  --simplify true

echo "🎨 Step 4: 壓縮 CSS + 組裝混淆版 HTML..."
node -e "
const fs = require('fs');
let html = fs.readFileSync('$SRC', 'utf8');
const obfJS = fs.readFileSync('$OBF_JS', 'utf8');

// Replace JS
html = html.replace(
  /<script>[\s\S]*?<\/script>/,
  '<script>' + obfJS + '</script>'
);

// Minify CSS (collapse whitespace inside <style> tags)
html = html.replace(/<style>([\s\S]*?)<\/style>/g, (match, css) => {
  const min = css
    .replace(/\/\*[\s\S]*?\*\//g, '')   // remove comments
    .replace(/\s*\n\s*/g, '')            // remove newlines
    .replace(/\s*{\s*/g, '{')
    .replace(/\s*}\s*/g, '}')
    .replace(/\s*;\s*/g, ';')
    .replace(/\s*:\s*/g, ':')
    .replace(/\s*,\s*/g, ',');
  return '<style>' + min + '</style>';
});

// Remove HTML comments and extra blank lines
html = html.replace(/<!--[\s\S]*?-->/g, '');
html = html.replace(/\n{3,}/g, '\n');

fs.writeFileSync('$SRC', html);
console.log('  組裝完成: ' + (html.length / 1024).toFixed(1) + ' KB');
"

echo "🧹 Step 5: 清理暫存檔..."
rm -f "$TEMP_JS" "$OBF_JS"

echo "📤 Step 6: Commit & Push..."
git add "$SRC"
git commit -m "Deploy: obfuscated build

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push

echo "♻️  Step 7: 還原本地原始碼..."
cp "$BACKUP" "$SRC"
rm -f "$BACKUP"

echo ""
echo "✅ 完成！GitHub 上是混淆版，本地是原始碼。"
