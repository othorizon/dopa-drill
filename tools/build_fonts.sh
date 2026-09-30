#!/usr/bin/env bash
# Rebuild the subset WOFF2 fonts used by the game from the Google Fonts (OFL) sources.
# Dela Gothic One and Zen Maru Gothic keep only digits, Latin and math symbols;
# every Chinese character and CJK punctuation comes from Noto Sans SC Bold/Black.
# Requires: curl, uv. Usage: bash tools/build_fonts.sh
set -euo pipefail
GAME="$(cd "$(dirname "$0")/../app" && pwd)"
WORK="$(mktemp -d)"
BASE=https://raw.githubusercontent.com/google/fonts/main/ofl
curl -sSfo "$WORK/dela.ttf" "$BASE/delagothicone/DelaGothicOne-Regular.ttf"
curl -sSfo "$WORK/zen-bold.ttf" "$BASE/zenmarugothic/ZenMaruGothic-Bold.ttf"
curl -sSfo "$WORK/zen-black.ttf" "$BASE/zenmarugothic/ZenMaruGothic-Black.ttf"
curl -sSfo "$WORK/noto-sc.ttf" "$BASE/notosanssc/NotoSansSC%5Bwght%5D.ttf"
python3 - "$GAME" "$WORK" <<'PY'
import sys, pathlib
game, work = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
chars = {chr(c) for c in range(0x20, 0x7f)}
for f in [*game.glob('*.html'), *game.glob('*.css'), *game.glob('js/*.js')]:
    chars |= set(f.read_text(encoding='utf-8'))
chars |= set('０１２３４５６７８９＋−×÷＝，。、：；！？“”‘’（）《》～…—·')
chars = {c for c in chars if ord(c) >= 0x20}
# Full-width math operators stay with the Latin fonts so problems look as before.
MATH = set('＋＝')
CJK_PUNCT = set('“”‘’…—·')
latin = {c for c in chars if (ord(c) < 0x2E80 and c not in CJK_PUNCT) or c in MATH}
(work / 'chars.txt').write_text(''.join(sorted(chars)), encoding='utf-8')
(work / 'latin.txt').write_text(''.join(sorted(latin)), encoding='utf-8')
PY
# Noto Sans SC is a variable font: pin the two weights the game uses.
for w in 700 900; do
  uv run --no-project --with fonttools fonttools varLib.instancer "$WORK/noto-sc.ttf" "wght=$w" -o "$WORK/noto-sc-$w.ttf" -q
done
for spec in "dela latin dela-gothic-one" "zen-bold latin zen-maru-gothic-bold" "zen-black latin zen-maru-gothic-black" \
           "noto-sc-700 chars noto-sans-sc-bold" "noto-sc-900 chars noto-sans-sc-black"; do
  set -- $spec
  uv run --no-project --with fonttools --with brotli pyftsubset "$WORK/$1.ttf" --text-file="$WORK/$2.txt" --flavor=woff2 --layout-features='*' --output-file="$GAME/fonts/$3.woff2"
done
rm -rf "$WORK"
echo "fonts rebuilt in $GAME/fonts"
