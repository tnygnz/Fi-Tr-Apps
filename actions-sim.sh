#!/usr/bin/env bash
# PUSH.md -> "Yontem 2: Tarayicidan yukleme" bolumundeki GitHub Actions is
# akisini YEREL olarak dogrular. Gercek GitHub'a hicbir sey gondermez: sahte
# uzak depo gecici bir klasorde kurulur ve cikista silinir.
#
#   bash actions-sim.sh          # PyYAML varsa onunla (YAML de dogrulanir)
#   SIM_NO_PYYAML=1 bash ...     # awk yedegi (PyYAML yoksa)
#
# Gereksinim: git, unzip; testler icin node. Cikis kodu 0 = tum kontroller gecti.
# IZLENMEYEN dosya: commit edilmemesi icin bu betigi `git add` yapma.
set -uo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
NOT="$SRC/PUSH.md"
ZIP=sanat-web-yukle.zip
WORK=$(mktemp -d "${TMPDIR:-/tmp}/actions-sim.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

GIT_ID=(git -c user.name=tnygnz -c user.email=tnygnz@users.noreply.github.com)
pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
step() { printf '\n%s\n' "$1"; }
need() { [ -f "$1" ] || { printf 'eksik dosya: %s\n' "$1" >&2; exit 2; }; }

# --------------------------------------------------------------------------
# 0) Girdiler: PUSH.md ve HEAD'den uretilen zip
# --------------------------------------------------------------------------
step "0) Girdiler"
need "$NOT"
git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'bu betik bir git deposunda calismali\n' >&2; exit 2; }
ok "PUSH.md: $(wc -l < "$NOT") satir, $(wc -c < "$NOT") bayt"

if git -C "$SRC" archive --format=zip -o "$WORK/$ZIP" HEAD 2>"$WORK/archive.err"; then
  ok "zip HEAD'den uretildi: $ZIP, $(wc -c < "$WORK/$ZIP") bayt"
else
  printf 'git archive basarisiz: %s\n' "$(cat "$WORK/archive.err")" >&2; exit 2
fi

# --------------------------------------------------------------------------
# 1) PUSH.md'den YAML'i ve isin run: adimlarini cikar
# --------------------------------------------------------------------------
step "1) PUSH.md'deki is akisi"
extract_py() {
  python3 - "$NOT" "$WORK/zip-ac.yml" "$WORK/steps.sh" <<'PY'
import sys
try:
    import yaml
except ImportError:
    sys.exit(3)
note, wfout, stepsout = sys.argv[1:4]
text = open(note, encoding="utf-8").read()
marker = "```yaml"
start = text.find(marker)
if start < 0:
    sys.exit(4)
start += len(marker)
if text[start:start + 1] == "\n":
    start += 1
end = text.find("```", start)
if end < 0:
    sys.exit(4)
body = text[start:end].rstrip("\n")
src = "\n".join(l[3:] if l.startswith("   ") else l for l in body.split("\n")) + "\n"
wf = yaml.safe_load(src)
if not isinstance(wf, dict) or "jobs" not in wf:
    sys.exit(5)
open(wfout, "w", encoding="utf-8").write(src)
steps = [s for j in wf["jobs"].values() for s in (j or {}).get("steps", []) if "run" in s]
if not steps:
    sys.exit(6)
out = ["set -euo pipefail", 'cd "$1"']
for s in steps:
    out.append('echo "--- %s"' % (s.get("name") or "adim").replace('"', ""))
    out.append(s["run"])
open(stepsout, "w").write("\n".join(out) + "\n")
print(len(steps))
PY
}

extract_awk() {
  awk '
    /^[[:space:]]*```yaml[[:space:]]*$/ { iny = 1; next }
    iny && /^[[:space:]]*```[[:space:]]*$/ { iny = 0; next }
    iny { l = $0; sub(/^[ ]{1,3}/, "", l); print l }
  ' "$NOT" > "$WORK/zip-ac.yml"
  awk '
    function ind(s,  i) { i = 0; while (substr(s, i + 1, 1) == " ") i++; return i }
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        l = line[i]
        if (l !~ /^[ ]*-?[ ]*run:[ ]*/) continue
        rest = l
        sub(/^[ ]*-?[ ]*run:[ ]*/, "", rest)
        if (rest == "|" || rest == ">" || rest ~ /^[|>][-+]?$/) {
          base = ind(l); i++
          while (i <= NR && (line[i] == "" || ind(line[i]) > base)) {
            s = line[i]; sub(/^[ ]+/, "", s); print s; i++
          }
          i--
        } else { print rest }
      }
    }
  ' "$WORK/zip-ac.yml" > "$WORK/raw-steps.txt"
  { printf 'set -euo pipefail\ncd "$1"\n'; cat "$WORK/raw-steps.txt"; } > "$WORK/steps.sh"
}

nsteps=""
if [ -z "${SIM_NO_PYYAML:-}" ] && command -v python3 >/dev/null 2>&1; then
  nsteps=$(extract_py); rc=$?
  case "$rc" in
    0) ok "YAML PyYAML ile ayristirildi, $nsteps run: adimi bulundu" ;;
    3) nsteps=""; ok "PyYAML yok, awk yedegine gecildi" ;;
    *) bad "PUSH.md icindeki YAML ayristirilamadi (kod $rc)"; nsteps="" ;;
  esac
fi
if [ -z "$nsteps" ]; then
  extract_awk
  got=$(grep -c '^echo "---' "$WORK/steps.sh" 2>/dev/null || true)
  ok "adimlar awk ile ayiklandi, $(wc -l < "$WORK/raw-steps.txt") satir komut"
else
  grep -qE "^[[:space:]]*'?on'?:" "$WORK/zip-ac.yml" && ok "tetikleyici: workflow_dispatch (elle)" \
    || bad "'on' anahtari bulunamadi"
  grep -q 'contents: write' "$WORK/zip-ac.yml" && ok "izin: contents: write" \
    || bad "contents: write izni yok"
fi
grep -qE "unzip .*$ZIP" "$WORK/steps.sh" && ok "zip adi is ile ayni: $ZIP" \
  || bad "is zip adini bulamiyor: $ZIP"
if grep -qP '\t' "$WORK/steps.sh"; then bad "adimlarda sekme karakteri (girinti bozulabilir)"
else ok "adimlarda sekme yok"; fi

# --------------------------------------------------------------------------
# 2) Uzak depo taklidi: tek commit, yalnizca README.md
# --------------------------------------------------------------------------
step "2) Uzak depo taklidi (tek commit: README.md)"
git init -q --bare -b main "$WORK/remote.git"
git init -q -b main "$WORK/seed"
printf '# suomi-kartat' > "$WORK/seed/README.md"
git -C "$WORK/seed" add README.md
"${GIT_ID[@]}" -C "$WORK/seed" commit -q -m "Initial commit"
git -C "$WORK/seed" remote add origin "$WORK/remote.git"
git -C "$WORK/seed" push -q -u origin main
[ "$(git -C "$WORK/remote.git" rev-list --count main)" = "1" ] \
  && ok "uzak main: 1 commit" || bad "uzak main 1 commit degil"

# --------------------------------------------------------------------------
# 3) Web arayuzu: zip yukleme + is akisi commit'i
# --------------------------------------------------------------------------
step "3) Web arayuzu commit'leri"
git clone -q "$WORK/remote.git" "$WORK/web" 2>/dev/null
cp "$WORK/$ZIP" "$WORK/web/$ZIP"
git -C "$WORK/web" add "$ZIP"
"${GIT_ID[@]}" -C "$WORK/web" commit -q -m "Add files via upload"
mkdir -p "$WORK/web/.github/workflows"
cp "$WORK/zip-ac.yml" "$WORK/web/.github/workflows/zip-ac.yml"
git -C "$WORK/web" add .github/workflows/zip-ac.yml
"${GIT_ID[@]}" -C "$WORK/web" commit -q -m "Create zip-ac.yml"
git -C "$WORK/web" push -q origin main
[ "$(git -C "$WORK/remote.git" rev-list --count main)" = "3" ] \
  && ok "uzak main: 3 commit (initial + zip + is akisi)" \
  || bad "uzak main beklenen 3 commit degil"

# --------------------------------------------------------------------------
# 4) actions/checkout@v4 taklidi + isin adimlarini calistir
# --------------------------------------------------------------------------
step "4) Is calistiriliyor (checkout + run adimlari)"
git clone -q "$WORK/remote.git" "$WORK/run" 2>/dev/null
[ "$(git -C "$WORK/run" rev-parse --abbrev-ref HEAD)" = "main" ] \
  && ok "checkout: main dali" || bad "checkout main dalinda degil"
[ -f "$WORK/run/$ZIP" ] && ok "is baslamadan zip depoda" || bad "zip depoda yok"

if bash "$WORK/steps.sh" "$WORK/run" > "$WORK/run.log" 2>&1; then
  ok "tum run: adimlari hatasiz bitti"
else
  bad "is adimlari hata verdi"
  sed -n '1,40p' "$WORK/run.log"
fi
sed -n 's/^\([0-9]* files\? changed.*\)$/\1/p' "$WORK/run.log" | sed 's/^/  -> /'

# --------------------------------------------------------------------------
# 5) Kontroller
# --------------------------------------------------------------------------
step "5) Kontroller"
R="$WORK/remote.git"
[ ! -e "$WORK/run/$ZIP" ] && ok "zip calisma agacindan silindi" || bad "zip hala calisma agacinda"
[ "$(git -C "$R" rev-list --count main)" = "4" ] && ok "uzak main: 4 commit (dogrusal)" \
  || bad "uzak main beklenen 4 commit degil"
[ "$(git -C "$R" ls-tree -r --name-only main | grep -c '\.zip$' || true)" = "0" ] \
  && ok "depoda zip dosyasi yok" || bad "depoda hala .zip var"
[ "$(git -C "$R" show main:README.md)" = "# suomi-kartat" ] \
  && ok "uzaktaki README.md korundu" || bad "README.md bozuldu"
[ "$(git -C "$R" ls-tree -r --name-only main -- sanat | wc -l)" = "13" ] \
  && ok "sanat/ altinda 13 dosya" || bad "sanat/ dosya sayisi beklenenden farkli"

if [ "$(git -C "$SRC" rev-parse HEAD:sanat)" = "$(git -C "$R" rev-parse main:sanat)" ]; then
  ok "sanat/ agac hash'i bu depoyla ayni"
else
  bad "sanat/ agac hash'i farkli"
fi
if [ "$(git -C "$SRC" rev-parse HEAD:.gitignore)" = "$(git -C "$R" rev-parse main:.gitignore)" ]; then
  ok "kok .gitignore bu depoyla ayni"
else
  bad "kok .gitignore farkli"
fi

mkdir -p "$WORK/gercek" "$WORK/cikan"
git -C "$SRC" archive HEAD | tar -x -C "$WORK/gercek"
git -C "$R" archive main -- sanat .gitignore | tar -x -C "$WORK/cikan"
diff -r "$WORK/gercek/sanat" "$WORK/cikan/sanat" >/dev/null 2>&1 \
  && ok "sanat/ birebir ayni (diff -r)" || bad "sanat/ icerigi farkli (diff -r)"
cmp -s "$WORK/gercek/.gitignore" "$WORK/cikan/.gitignore" \
  && ok "kok .gitignore birebir ayni (cmp)" || bad "kok .gitignore icerigi farkli (cmp)"

if command -v node >/dev/null 2>&1; then
  if ( cd "$WORK/cikan" && node sanat/tests/run.js > "$WORK/test.log" 2>&1 ) \
     && grep -q "0 basarisiz" "$WORK/test.log"; then
    ok "cikarilan uygulamanin testleri: $(grep -oE '[0-9]+ +gecti' "$WORK/test.log" | head -1)"
  else
    bad "cikarilan uygulamanin testleri gecmedi"
    sed -n '1,20p' "$WORK/test.log" 2>/dev/null
  fi
else
  ok "node yok, uygulama testleri atlandi"
fi

if git -C "$WORK/run" commit -m "bos" >/dev/null 2>&1; then
  bad "ikinci calistirma bos commit uretti (beklenen: nothing to commit)"
else
  ok "ikinci calistirma zararsiz biter (nothing to commit)"
fi

# --------------------------------------------------------------------------
step "SONUC"
printf '  %d gecti, %d basarisiz\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
