#!/usr/bin/env python3
"""Sürüm damgası ve üç depo eşitliği denetimi — CI ve yerel için tek uygulama.

1) Damga: sanat/index.html içindeki her ?v= değeri, app.js + styles.css + data.js
   içeriğinden türetilen 10 karakterlik sha256 ile aynı olmalı. Damga eskiyse
   tarayıcı yeni HTML ile eski app.js'i eşleştirebilir ("Paketler" boş görünür).
2) Eşitlik: kontrol dosyalarının git blob sha'sı, kaynak depoda ve aynalarda
   (dal ucu) yerel ağaçtakiyle birebir aynı olmalı.

Kullanım:
    TOKEN=... python3 kontrol.py              # yerel: GH_TOKEN=$(gh auth token)
    TOKEN=... python3 kontrol.py --kati       # okunamayan depo da hata sayılır

Ortam değişkenleri:
    KAYNAK   tnygnz/Fi-Tr-Apps
    AYNALAR  "tnygnz/suomi-kartat tnygnz/Opin-Suomen"
    BRANCH   main
    DAL      sanat
    EK       .github/workflows/zip-ac.yml

Çıkış: 0 damga doğru ve okunabilen tüm depolar aynı · 1 damga ya da eşitlik bozuk.
Özel depoya erişemeyen jeton (ör. CI'da yalnız GITHUB_TOKEN) o depoyu "okunamadı"
olarak işaretler; --kati verilmedikçe hata sayılmaz.
"""

import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

DAL = os.environ.get("DAL", "sanat")
EK = os.environ.get("EK", ".github/workflows/zip-ac.yml")
KONTROL = [
    "%s/app.js" % DAL,
    "%s/styles.css" % DAL,
    "%s/data.js" % DAL,
    "%s/index.html" % DAL,
    "%s/imports/index.json" % DAL,
    EK,
]
KAYNAK = os.environ.get("KAYNAK", "tnygnz/Fi-Tr-Apps")
AYNALAR = os.environ.get("AYNALAR", "tnygnz/suomi-kartat tnygnz/Opin-Suomen").split()
BRANCH = os.environ.get("BRANCH", "main")
TOKEN = (
    os.environ.get("TOKEN")
    or os.environ.get("GH_TOKEN")
    or os.environ.get("GITHUB_TOKEN")
    or ""
)
KATI = "--kati" in sys.argv or "--katı" in sys.argv
OZET = os.environ.get("GITHUB_STEP_SUMMARY", "")


def say(satir=""):
    print(satir, flush=True)


def blob_sha(veri):
    return hashlib.sha1(b"blob %d\0" % len(veri) + veri).hexdigest()


def uzak_sha(repo, yol):
    """(sha, hata) — hata 404 ise depo/jeton erişimi yok demektir."""
    url = "https://api.github.com/repos/%s/contents/%s?ref=%s" % (
        repo,
        urllib.parse.quote(yol),
        urllib.parse.quote(BRANCH),
    )
    istek = urllib.request.Request(
        url,
        headers={
            "Authorization": "Bearer " + TOKEN,
            "Accept": "application/vnd.github+json",
            "User-Agent": "kontrol.py",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(istek, timeout=30) as yanit:
            return json.load(yanit).get("sha", ""), None
    except urllib.error.HTTPError as h:
        return "", h.code
    except Exception as e:  # ağ hatası: depo farkı değil, erişim sorunu
        return "", str(e)


def damga_denetle():
    say("▸ damga")
    parcalar = []
    for ad in ("app.js", "styles.css", "data.js"):
        yol = os.path.join(DAL, ad)
        try:
            parcalar.append(open(yol, "rb").read())
        except OSError as e:
            say("  FAIL  okunamadı: %s (%s)" % (yol, e))
            return None, False
    beklenen = hashlib.sha256(b"".join(parcalar)).hexdigest()[:10]

    try:
        html = open(os.path.join(DAL, "index.html"), encoding="utf-8").read()
    except OSError as e:
        say("  FAIL  okunamadı: %s/index.html (%s)" % (DAL, e))
        return beklenen, False

    bulunan = sorted(set(re.findall(r"\?v=([A-Za-z0-9_-]+)", html)))
    if len(bulunan) == 1 and bulunan[0] == beklenen:
        say("  ok    ?v=%s (içerikle aynı)" % beklenen)
        return beklenen, True
    if not bulunan:
        say("  FAIL  index.html içinde ?v= damgası yok (beklenen ?v=%s)" % beklenen)
    else:
        say(
            "  FAIL  damga eski: index.html ?v=%s · içerik ?v=%s"
            % ("," .join(bulunan), beklenen)
        )
        say("        düzeltmek için: ./tek.sh \"mesaj\"")
    return beklenen, False


def esitlik_denetle(damga, tablo):
    say("")
    say("▸ depo eşitliği (dal: %s)" % BRANCH)
    yerel = {}
    for yol in KONTROL:
        try:
            yerel[yol] = blob_sha(open(yol, "rb").read())
        except OSError:
            yerel[yol] = None

    fark = 0
    okunamayan = 0
    for repo in [KAYNAK] + AYNALAR:
        uyan, eksik, kod = 0, [], None
        for yol in KONTROL:
            if yerel[yol] is None:
                eksik.append("%s (yerelde yok)" % yol)
                continue
            uzak, hata = uzak_sha(repo, yol)
            if hata is not None:
                kod = hata
                break
            if uzak == yerel[yol]:
                uyan += 1
            else:
                eksik.append("%s (uzak %s / yerel %s)" % (yol, (uzak or "-")[:10], yerel[yol][:10]))

        if kod is not None:
            okunamayan += 1
            say("  ????  %s — okunamadı (HTTP %s): özel depo için KONTROL_TOKEN gerekli" % (repo, kod))
            tablo.append((repo, "okunamadı (HTTP %s)" % kod))
        elif uyan == len(KONTROL):
            say("  ok    %s — %d/%d dosya birebir aynı" % (repo, uyan, len(KONTROL)))
            tablo.append((repo, "%d/%d aynı" % (uyan, len(KONTROL))))
        else:
            fark += 1
            say("  FAIL  %s — %d/%d aynı" % (repo, uyan, len(KONTROL)))
            for e in eksik:
                say("          fark: %s" % e)
            tablo.append((repo, "FARKLI (%d/%d)" % (uyan, len(KONTROL))))

    say("")
    if fark:
        say("SONUC: %d depoda fark var · düzeltmek için: ./tek.sh \"mesaj\"" % fark)
    elif okunamayan:
        say(
            "SONUC: okunabilen depolar aynı (%d depo okunamadı — KONTROL_TOKEN eklenirse kapsanır)"
            % okunamayan
        )
    else:
        depolar = [KAYNAK] + AYNALAR
        say("SONUC: damga ?v=%s · %d/%d depo birebir aynı" % (damga, len(depolar), len(depolar)))

    if OZET:
        with open(OZET, "a", encoding="utf-8") as f:
            f.write("## kontrol\n\n")
            f.write("| depo | durum |\n|---|---|\n")
            for repo, durum in tablo:
                f.write("| `%s` | %s |\n" % (repo, durum))
            f.write("\nDamga: `?v=%s`\n" % (damga or "?"))
    return fark, okunamayan


def main():
    if not TOKEN:
        say("DURDU: TOKEN/GH_TOKEN/GITHUB_TOKEN yok — ör. TOKEN=$(gh auth token)")
        return 2

    damga, damga_ok = damga_denetle()
    tablo = []
    fark, okunamayan = esitlik_denetle(damga, tablo)

    if not damga_ok:
        return 1
    if fark:
        return 1
    if okunamayan and KATI:
        say("--kati: okunamayan %d depo hata sayıldı" % okunamayan)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
