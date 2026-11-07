#!/usr/bin/env bash
# tek.sh — Tek komut: test → sürüm damgası → üç depo → doğrulama.
#
#   ./tek.sh "sanat: kısa değişiklik özeti"
#   KURU=1 ./tek.sh "..."      # hiçbir şey yazmaz, planı gösterir
#   DOGRULA=1 ./tek.sh "..."   # yayından sonra canlı baytları da bekler
#
# Yapı: Fi-Tr-Apps (bu depo) tek kaynak. suomi-kartat (canlı site) ve
# Opin-Suomen ondan türeyen aynalar; aynalar aynı ağacı tek commit olarak alır.
#
#   1) testler            node sanat/tests/run.js — kırıksa hiçbir yere yazılmaz
#   2) sürüm damgası      index.html içindeki ?v=, app.js+styles.css+data.js
#                         içeriğinden türetilir: aynı içerik → aynı damga,
#                         yani komutu iki kez koşmak yeni commit üretmez
#   3) kaynak depo        yerel commit + git push origin main
#   4) aynalar            yayinla.sh REPO=<ayna> (Git Data API, tek commit)
#   5) doğrulama          üç depoda blob sha'ları yerelle aynı mı
#
# Neden damga: GitHub Pages varlıkları `cache-control: max-age=600` ile sunuluyor
# ve URL'de sürüm yok; yeni HTML eski app.js ile eşleşince "Paketler" sekmesi boş
# görünüyordu. Damga varlık URL'sini içeriğe bağlar, karışma olamaz.
#
# Kimlik: GH_TOKEN ortamdan ya da `gh auth token` ile alınır; ekrana basılmaz.
set -uo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 2
cd "$SRC" || exit 2

DAL=${DAL:-sanat}
EK=${EK:-.github/workflows/zip-ac.yml}
KAYNAK=${KAYNAK:-tnygnz/Fi-Tr-Apps}
AYNALAR=${AYNALAR:-"tnygnz/suomi-kartat tnygnz/Opin-Suomen"}
BRANCH=${BRANCH:-main}
SAYFA=${SAYFA:-https://tnygnz.github.io/suomi-kartat/sanat/}
KURU=${KURU:-0}
DOGRULA=${DOGRULA:-0}
MSG=${1:-${MSG:-"sanat: yayın"}}

say() { printf '%s\n' "$*"; }
adim() { printf '\n▸ %s\n' "$*"; }
die() { printf '\nDURDU: %s\n' "$*" >&2; exit 1; }

for a in git node python3 curl; do
  command -v "$a" >/dev/null 2>&1 || die "$a bulunamadı" 2
done
[ -d "$DAL" ] || die "$DAL dizini yok" 2
[ -f kontrol.py ] || die "kontrol.py yok" 2

# --- 1) test kapısı -------------------------------------------------------
adim "1/5 testler ($DAL/tests/run.js)"
if node "$DAL/tests/run.js" >/tmp/tek-test.log 2>&1; then
  grep -E "SONUC:|Tüm test" /tmp/tek-test.log | tail -6
else
  tail -30 /tmp/tek-test.log
  die "testler kırık; hiçbir depoya yazılmadı"
fi

# --- 2) sürüm damgası -----------------------------------------------------
adim "2/5 sürüm damgası"
SURUM=$(cat "$DAL/app.js" "$DAL/styles.css" "$DAL/data.js" | sha256sum | cut -c1-10)
python3 - "$DAL/index.html" "$SURUM" <<'PY' || die "damga yazılamadı"
import re, sys
yol, damga = sys.argv[1], sys.argv[2]
s = open(yol, encoding="utf-8").read()
for ad in ("styles.css", "data.js", "app.js"):
    desen = r'((?:href|src)="%s)(\?v=[^"]*)?(")' % re.escape(ad)
    s = re.sub(desen, lambda m: m.group(1) + "?v=" + damga + m.group(3), s)
open(yol, "w", encoding="utf-8").write(s)
PY
say "  içerik damgası: ?v=$SURUM"
say "  bağlantılar: $(grep -o '?v=[a-z0-9]*' "$DAL/index.html" | sort -u | tr '\n' ' ')"

# --- 3) kaynak depo -------------------------------------------------------
adim "3/5 kaynak depo ($KAYNAK)"
git add -A -- "$DAL" "$EK" tek.sh yayinla.sh kontrol.py .github/workflows/kontrol.yml README.md
if git diff --cached --quiet; then
  say "  commit gerektiren değişiklik yok"
else
  say "  değişen: $(git diff --cached --name-only -- "$DAL" "$EK" tek.sh yayinla.sh kontrol.py .github/workflows/kontrol.yml README.md | tr '\n' ' ')"
  if [ "$KURU" = 1 ]; then
    git reset -q --
    say "  (kuru) commit ve push atlandı"
  else
    git -c user.name="Freebuff" -c user.email="cloud@freebuff.local" \
        commit -q -m "$(printf '%s\n\n🤖 Generated with Codebuff\nCo-Authored-By: Codebuff <noreply@codebuff.com>' "$MSG")" \
      || die "commit atılamadı"
    say "  commit: $(git log --oneline -1)"
  fi
fi

if [ "$KURU" != 1 ]; then
  if git push -q origin "HEAD:$BRANCH"; then
    say "  push: origin/$BRANCH güncel ($(git rev-parse --short HEAD))"
  else
    die "kaynak push reddedildi — uzak ilerlemiş olabilir: git fetch origin && git status"
  fi
fi

# --- 4) aynalar -----------------------------------------------------------
adim "4/5 aynalar"
if [ "$KURU" != 1 ] && [ -z "${GH_TOKEN:-}" ]; then
  GH_TOKEN=$(gh auth token 2>/dev/null || true)
  export GH_TOKEN
fi
[ "$KURU" = 1 ] || [ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN yok: 'gh auth login' ya da GH_TOKEN ortam değişkeni"

for r in $AYNALAR; do
  log="/tmp/tek-$(printf '%s' "$r" | tr '/' '-').log"
  say "  → $r"
  if REPO="$r" EK="$EK" TEST_YOK=1 KURU="$KURU" DOGRULA=0 BRANCH="$BRANCH" \
      ./yayinla.sh "$MSG" >"$log" 2>&1; then
    sed -n 's/^/     /p' "$log" | grep -E "degisti|Yayinlanacak|SONUC|Tamam|ok " | tail -6
  else
    sed -n 's/^/     /p' "$log" | tail -20
    die "ayna yayını başarısız: $r (günlük: $log)"
  fi
done

# --- 5) doğrulama ---------------------------------------------------------
adim "5/5 doğrulama (kontrol.py — CI ile aynı betik)"
if [ "$KURU" = 1 ]; then
  say "  (kuru) damga ve uzak karşılaştırma atlandı"
else
  [ -n "${GH_TOKEN:-}" ] || { GH_TOKEN=$(gh auth token 2>/dev/null || true); export GH_TOKEN; }
  [ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN yok: 'gh auth login' ya da GH_TOKEN ortam değişkeni"
  TOKEN="$GH_TOKEN" KAYNAK="$KAYNAK" AYNALAR="$AYNALAR" BRANCH="$BRANCH" DAL="$DAL" EK="$EK" \
    python3 kontrol.py || die "damga ya da depo eşitliği bozuk (yukarıdaki satırlar)"
fi

# --- canlı kontrol (isteğe bağlı) -----------------------------------------
if [ "$DOGRULA" = 1 ] && [ "$KURU" != 1 ]; then
  adim "canlı kontrol: $SAYFA"
  for f in "$DAL/app.js" "$DAL/index.html"; do
    goreli=${f#"$DAL"/}
    tamam=0
    for _ in $(seq 1 18); do
      if curl -sS -m 20 "$SAYFA$goreli?cb=$(date +%s)" -o /tmp/tek-canli 2>/dev/null \
        && cmp -s /tmp/tek-canli "$f"; then tamam=1; break; fi
      sleep 10
    done
    if [ "$tamam" = 1 ]; then say "  ok    canlı = yerel: $goreli"
    else say "  BEKLE Pages henüz eski: $goreli (birkaç dakika sonra DOGRULA=1 ile tekrar)"; fi
  done
fi

say ""
say "Tamam: $KAYNAK + $(printf '%s' "$AYNALAR" | wc -w) ayna · damga ?v=$SURUM · commit $(git rev-parse --short HEAD)"
say "Site : $SAYFA"
