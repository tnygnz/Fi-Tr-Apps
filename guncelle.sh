#!/usr/bin/env bash
# sanat/app.js ve sanat/styles.css'i GitHub API ile uzak main'e isler.
#
# Neden API: yerel gecmis ile uzak gecmis iliskisiz (ortak ata yok), bu yuzden
# duz `git push` "non-fast-forward" ile reddedilir. API'de dosya bazli commit
# ayni sonucu verir ve uzak gecmisi bozmaz.
#
# Kimlik: token yalnizca GH_TOKEN ortam degiskeninden okunur; ekrana basilmaz,
# komut satirina yazilmaz (curl --config gecici dosyasi, chmod 600).
#
#   GH_TOKEN=... bash guncelle.sh     # gercek guncelleme
#   KURU=1 bash guncelle.sh           # token gerekmez: yalnizca plan
set -uo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=${REPO:-tnygnz/suomi-kartat}
BRANCH=${BRANCH:-main}
MSG=${MSG:-"Masaüstünde sekme çubuğu hizalandı, hero'daki emoji onay ikonuna döndü"}
FILES=(sanat/app.js sanat/styles.css)
KURU=${KURU:-0}
API="https://api.github.com/repos/$REPO/contents"

say() { printf '%s\n' "$*"; }
die() { printf '\nDURDU: %s\n' "$*" >&2; exit "${2:-1}"; }

for f in "${FILES[@]}"; do [ -f "$SRC/$f" ] || die "eksik dosya: $f" 2; done
command -v curl >/dev/null 2>&1 || die "curl yok" 2
command -v python3 >/dev/null 2>&1 || die "python3 yok" 2

if [ "$KURU" = "1" ] && [ -z "${GH_TOKEN:-}" ]; then
  say "KURU plan (aga cikilmadi):"
  for f in "${FILES[@]}"; do
    say "  PUT $API/$f  (branch=$BRANCH, sha=<uzak sha>, $(wc -c < "$SRC/$f") bayt)"
  done
  say "  commit mesaji: $MSG"
  exit 0
fi

[ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN tanimli degil.
Yapilacaklar:
  1) GitHub -> Settings -> Developer settings -> Personal access tokens
     - Fine-grained: yalnizca $REPO, izin 'Contents: Read and write'
     - ya da Classic: 'repo' kapsami
  2) Bu projede Settings -> Secrets -> GH_TOKEN olarak ekle (sohbete YAPISTIRMA)
  3) Yeni oturumda:  bash guncelle.sh" 3

CFG=$(mktemp) || die "gecici dosya acilamadi" 2
chmod 600 "$CFG"
printf 'header = "Authorization: Bearer %s"\nheader = "Accept: application/vnd.github+json"\nheader = "X-GitHub-Api-Version: 2022-11-28"\n' "$GH_TOKEN" > "$CFG"
trap 'rm -f "$CFG"' EXIT

get_sha() {
  curl -sS -m 30 --config "$CFG" "$API/$1?ref=$BRANCH" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print(d.get("sha", "") if isinstance(d, dict) else "")'
}

say "Depo: $REPO (dal: $BRANCH)"
fail=0
for f in "${FILES[@]}"; do
  sha=$(get_sha "$f")
  if [ -z "$sha" ]; then say "  FAIL $f: uzak sha alinamadi (token yetkisi / depo adi)"; fail=$((fail + 1)); continue; fi
  say "  $f uzak sha: ${sha:0:12}"
  govde=$(python3 - "$f" "$SRC/$f" "$sha" "$MSG" "$BRANCH" <<'PY'
import base64, json, sys
path, local, sha, msg, branch = sys.argv[1:6]
print(json.dumps({"message": msg,
                  "content": base64.b64encode(open(local, "rb").read()).decode(),
                  "sha": sha, "branch": branch}))
PY
) || { say "  FAIL $f: govde kurulamadi"; fail=$((fail + 1)); continue; }
  if [ "$KURU" = "1" ]; then say "  (kuru) PUT atlandi"; continue; fi
  out=$(curl -sS -m 60 --config "$CFG" -X PUT -H "Content-Type: application/json" --data "$govde" "$API/$f")
  newsha=$(printf '%s' "$out" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print((d.get("commit") or {}).get("sha", ""))')
  if [ -n "$newsha" ]; then say "  ok  $f -> commit ${newsha:0:12}"
  else say "  FAIL $f: $(printf '%s' "$out" | head -c 300)"; fail=$((fail + 1)); fi
done

say ""
if [ "$fail" -eq 0 ]; then say "SONUC: ${#FILES[@]} dosya guncellendi"; else say "SONUC: $fail dosya basarisiz"; fi
[ "$fail" -eq 0 ] || exit 1
