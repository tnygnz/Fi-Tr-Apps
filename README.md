# suomi-kartat

Kişisel Fince ↔ Türkçe çalışma uygulaması. Statik, bağımlılıksız; verisi yalnızca
tarayıcının `localStorage` alanında. Uygulama `sanat/` dizininde, ayrıntılar
[`sanat/README.md`](sanat/README.md) içinde.

Canlı: <https://tnygnz.github.io/suomi-kartat/sanat/>

## Yayınlama

Depo kökünde tek komut — test, sürüm damgası, üç depo ve doğrulama:

```bash
./tek.sh "sanat: kısa değişiklik özeti"
```

`tek.sh` sırayla: (1) `node sanat/tests/run.js` — kırıksa hiçbir yere yazmaz;
(2) `index.html` içindeki `?v=` damgasını `app.js`+`styles.css`+`data.js`
içeriğinden türetir (aynı içerik → aynı damga, tekrar koşmak yeni commit
üretmez); (3) yerel commit + `git push origin main`; (4) `suomi-kartat` ve
`Opin-Suomen` deposuna aynı ağacı (uygulama + `zip-ac.yml`) tek commit olarak
yazar; (5) üç deponun blob sha'larını yerelle karşılaştırır.

| Komut | Ne yapar |
|---|---|
| `./tek.sh "mesaj"` | üç depoyu yayımlar |
| `KURU=1 ./tek.sh "mesaj"` | yazmadan planı gösterir |
| `DOGRULA=1 ./tek.sh "mesaj"` | yayından sonra canlı baytları da bekler |

Sürüm damgası neden gerekli: GitHub Pages varlıkları
`cache-control: max-age=600` ile sunuluyor ve URL'de sürüm yoktu; yeni HTML eski
`app.js` ile eşleşince "Paketler" sekmesi boş görünebiliyordu. Damga varlık
URL'sini içeriğe bağlar, eski/yeni karışması olamaz.

### Tek depo: `yayinla.sh`

`tek.sh` aynaları bu betikle yayımlar; tek depoya elle yayın için de kullanılır.
Betik sırayla:

1. `node sanat/tests/run.js` — testler kırıksa yayın yapılmaz (`TEST_YOK=1` ile atlanır).
2. Uzak `main` ile `sanat/` arasındaki farkı çıkarır (yeni dosyalar ve silmeler dahil).
3. Farkı **tek commit** olarak `main`'e yazar; GitHub Pages 1–3 dakikada yayımlar.
4. Uzak blob'ların yerelle aynı olduğunu doğrular; `DOGRULA=1` verilirse canlı
   dosyaların baytlarını da bekler.

Kimlik: `GH_TOKEN` — fine-grained PAT, yalnız bu depo, izin **Contents: Read and write**
(ya da Classic `repo`). Token yalnızca ortam değişkeninden okunur; ekrana, komut
satırına ya da depoya yazılmaz. Token yoksa betik yapılacakları yazıp **3** ile çıkar.

| Komut | Ne yapar |
|---|---|
| `KURU=1 ./yayinla.sh` | token gerekmez; yalnızca planı gösterir |
| `./yayinla.sh "mesaj"` | tek commit olarak yayımlar |
| `DOGRULA=1 ./yayinla.sh "mesaj"` | yayımdan sonra canlı baytları da doğrular |
| `TEST_YOK=1 ./yayinla.sh "mesaj"` | test kapısını atlar |
| `SILME_ONAY=1 ./yayinla.sh "mesaj"` | yerelde olmayan uzak dosyaları da siler |

`git push` neden kullanılmıyor: bu depoda yerel geçmiş ile uzak geçmiş ilgisiz
(ortak ata yok), düz `git push` "non-fast-forward" ile reddedilir. Betik GitHub
Git Data API'siyle uzak ağacın üzerine tek commit üretir ve uzak geçmişi yeniden
yazmaz.
