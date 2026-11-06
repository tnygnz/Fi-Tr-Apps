# Push notu

Bu depo GitHub'da **`tnygnz/suomi-kartat`** altında yayınlanır.

## Durum (5 Kasım 2026)

| Yer | Dal | Commit | İçerik |
|---|---|---|---|
| Yerel | `main` (çalışma dalının aynası) | `89f66c5` | **11 commit**, `sanat/` uygulaması |
| Uzak | `main` | `8eec4d5` | **1 commit** — GitHub'ın oluşturduğu "Initial commit", yalnızca `README.md` |

`git merge-base HEAD origin/main` **boş** çıkar: iki geçmişin **ortak atası yok**.
Bu yüzden push normal yolla geçmez, force gerekir.

## Force neden gerekiyor — adım adım

1. **Uzağı getir.** `git fetch origin` uzak dalı `origin/main` olarak yerele yazar.
   Karşılaştırmanın tamamı bu ref üzerinden yapılır, çalışma ağacına dokunmaz.
2. **Ata kontrolü.** `git merge-base HEAD origin/main` boş döner. Git'in "hızlı
   ileri sarma" (fast-forward) izni, uzak ucun yerelin **atası** olmasına bağlıdır;
   burada öyle bir bağ yok.
3. **Normal push reddedilir.** `git push -u origin main` şu satırla döner:
   `! [rejected] main -> main (non-fast-forward)` ya da `(fetch first)`.
   Sunucu, kendi `8eec4d5`'ini kaybetmeden yerelin 11 commit'ini üstüne ekleyemez.
4. **Merge da çözüm değil.** `git pull --allow-unrelated-histories` iki geçmişi
   birleştirir ama uzakta korunacak içerik yok: `8eec4d5` sadece GitHub'ın ilk
   commit'i (`README.md`). Birleştirme commit'i geçmişi gereksiz yere dallandırır,
   `sanat/` ilk commit'te zaten tam olarak var.
5. **Bilinçli üzerine yazma.** `--force-with-lease`, uzak dalın son `fetch`'ten beri
   **değişmediğini** kontrol eder; arada başka biri push ettiyse komut reddedilir ve
   onun commit'i ezilmez. Bu yüzden çıplak `--force` yerine bu kullanılır.
6. **Sonuç.** Uzak `main`, `89f66c5`'i gösterir. `8eec4d5` uzaktan düşer; yerelde
   `origin/main` ref'i ve commit nesnesi durmaya devam eder (`git show 8eec4d5`).

## Komutlar (depo kökünde, sırayla)

1. `git status --porcelain` — çıktı **boş** olmalı.
2. `git fetch origin`
3. `git log --oneline origin/main..main` — **11 satır** görünmeli (yayınlanacak commit'ler).
4. `git push -u origin main` — reddedilmesi beklenir; hata metnini görüp geçilebilir.
5. `git push --force-with-lease origin main`
   Beklenen çıktı: `+ 8eec4d5...89f66c5 main -> main (forced update)`.
6. `git ls-remote --heads origin` — `refs/heads/main` yanında **`89f66c5`** görünmeli.
7. GitHub → **Settings → Pages** → *Deploy from a branch* → `main` / `/ (root)`.
   Adres: `https://tnygnz.github.io/suomi-kartat/sanat/index.html`

`main` yerel dalı çalışma dalıyla aynı commit'i gösterir; ikisi de `89f66c5`.
İstersen çalışma dalını yeniden adlandırabilirsin: `git branch -m main` (dal zaten
`main`'e işaret ettiği için bu yalnızca adı değiştirir).

## Yöntem 1: Termux ile gerçek terminal (yalnızca Android)

Bilgisayar gerekmez: depo, yedek bundle'dan telefonun içinde klonlanır ve push
oradan yapılır. iPhone'da Termux yok; orada iSH gibi bir kabuk gerekir ve paket
adları değişir.

1. **Termux'u F-Droid'den kur.** Play Store sürümü terk edilmiş, `pkg` depoları
   eski kalıyor. Adres: `https://f-droid.org/packages/com.termux/`. APK'yı
   telefona indirip "bilinmeyen kaynaklara izin ver" ile aç.
2. **Paketleri güncelle.**
   `pkg update -y && pkg upgrade -y`
3. **Araçları kur.**
   `pkg install -y git unzip gh`
4. **Depolamaya erişim ver.** `termux-setup-storage` → izin penceresinde
   **İzin ver**. Bundan sonra İndirilenler klasörü `~/storage/downloads` olur.
5. **Paketi telefona indir.** `sanat-teslim.zip` dosyasını İndirilenler'e kaydet.
6. **Aç.**
   `cd ~/storage/downloads && unzip -o sanat-teslim.zip -d sanat-push`
7. **Bundle'dan klonla.**
   `cd sanat-push && git clone sanat-backup-2026-11-05.bundle sanat`
   Klon doğrudan `main` dalında ve `89f66c5` üzerinde açılır.
8. **Uzağı ekle ve getir.**
   `cd sanat`
   `git remote add origin https://github.com/tnygnz/suomi-kartat.git`
   `git fetch origin`
   `fetch` şart: `--force-with-lease`, `origin/main` ile karşılaştırarak karar
   verir; bu ref olmadan "stale info" hatası alınır.
9. **Giriş yap.** İki yoldan biri yeter:
   a. `gh auth login` → *GitHub.com* → *HTTPS* → *Login with a web browser* →
      ekrandaki 8 haneli kodu tarayıcıda gir → yetkilendir.
   b. `git config credential.helper store` → push sırasında kullanıcı adı
      `tnygnz`, parola yerine **kişisel erişim anahtarı** (classic, `repo`
      kapsamı). Anahtar `~/.git-credentials` içinde düz metin kalır; iş bitince:
      `git config --unset credential.helper && rm -f ~/.git-credentials`
10. **Push.**
    `git push --force-with-lease -u origin main`
    Beklenen çıktı: `+ 8eec4d5...89f66c5 main -> main (forced update)`.
11. **Doğrula.**
    `git ls-remote --heads origin`
    `refs/heads/main` yanında `89f66c5` görünmeli.
12. **Pages'i aç.** GitHub → **Settings → Pages** → *Deploy from a branch* →
    `main` / `/ (root)`. Birkaç dakika sonra:
    `https://tnygnz.github.io/suomi-kartat/sanat/index.html`
13. **Temizlik.** `rm -rf ~/storage/downloads/sanat-push` (klonun telefonundaki
    kopyası; depo GitHub'da). Token sakladıysan 9b'deki iki komutu çalıştır.

Termux ipuçları: komutu yapıştırmak için ekrana uzun bas → **Paste**; `gh`
kurulamazsa 9b yolunu kullan. `pkg` komutları ilk açılışta biraz sürer.

## Yöntem 2: Tarayıcıdan yükleme (GitHub web arayüzü)

Tarayıcı dışında araç yok: git, token, bundle ve force push gerekmez. GitHub'ın
**Add file → Upload files** ekranı doğrudan `main` dalına, mevcut `8eec4d5`
commit'inin **üstüne** normal bir commit ekler. Geçmiş doğrusal kalır; uzaktaki
`README.md` (`# suomi-kartat`) **silinmez** — force'un aksine orada kalır.

**Zip açma sorunu.** GitHub'ın web arayüzü yüklenen zip'i **açmaz**: `sanat-`
`web-yukle.zip`i olduğu gibi yüklersen depoda tek bir `.zip` dosyası durur ve Pages
onu indirmeye sunar, uygulama açılmaz. Klasör yapısı (`sanat/`, `sanat/fonts/`,
`sanat/tests/`) korunmak zorunda. Çözüm: zip'i bir kez **GitHub Actions**'ta
açtırmak — telefonda ne terminal ne de zip ayıklama gerekir, tek seferlik küçük bir
YAML yapıştırması yeter.

İndirilecek dosya: **`sanat-web-yukle.zip`** (uygulamanın 17 dosyası). Bu not
(`PUSH.md`) yalnızca `sanat-teslim.zip` içinde, ayrı indirilir; ikisi karışmaz.

1. **Zip'i yükle.** Telefonda `https://github.com/tnygnz/suomi-kartat` → **Add file
   → Upload files** → `sanat-web-yukle.zip`i seç → **Commit changes**. Dosya depo
   köküne düşer. Adı **tam böyle kalsın**, 4. adımdaki iş bu adı arıyor.
2. **İş akışını oluştur.** **Add file → Create new file** → dosya adı alanına
   `.github/workflows/zip-ac.yml` yaz (eğik çizgiler klasörleri kendiliğinden
   oluşturur) → içeriğe şunu yapıştır:

   ```yaml
   name: zip-ac
   'on': workflow_dispatch
   permissions:
     contents: write
   jobs:
     ac:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - name: Zip'i aç (varsa)
           id: unzip
           run: |
             set -euo pipefail
             out="${GITHUB_OUTPUT:-/dev/null}"
             if [ ! -f sanat-web-yukle.zip ]; then
               echo "Zip yok; yapılacak iş kalmadı (idempotent çıkış)."
               echo "done=false" >> "$out"
               exit 0
             fi
             unzip -o sanat-web-yukle.zip
             rm -f sanat-web-yukle.zip
             echo "done=true" >> "$out"
         - name: Commit ve push
           if: steps.unzip.outputs.done == 'true'
           run: |
             set -euo pipefail
             git config user.name "github-actions[bot]"
             git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
             git add -A
             if git diff --cached --quiet; then
               echo "Değişiklik yok; commit gerekmiyor (idempotent çıkış)."
               exit 0
             fi
             git commit -m "sanat: zip'ten çıkar"
             git push
   ```

   İş **idempotent**: zip yoksa ya da commit edilecek değişiklik yoksa hata
   vermeden başarıyla biter; rozet yeşil kalır. Bozuk zip gerçek bir hata olduğu
   için kırmızı görünür.

3. **Kaydet.** Sayfanın altındaki **Commit changes** → açılan kutuda yine **Commit
   changes**. Dosya `main`e işlenir.
4. **Çalıştır.** **Actions** sekmesi → soldaki **zip-ac** → sağda **Run workflow**
   → yeşil **Run workflow** düğmesi.
5. **Bekle.** İş yaklaşık bir dakika sürer; listede yeşil ✓ görününce **Code**
   sekmesine dön.
6. **Kontrol et.** Kökte `sanat/` klasörü; içinde `index.html`, `app.js`,
   `styles.css`, `data.js`, `fonts/`, `tests/`. `sanat-web-yukle.zip` artık
   görünmemeli (iş onu siler ve tek commit'te yok sayar).
7. **Pages'i aç.** **Settings → Pages** → *Deploy from a branch* → `main` /
   `/ (root)` → **Save**. Birkaç dakika sonra:
   `https://tnygnz.github.io/suomi-kartat/sanat/index.html`
8. **Temizlik (isteğe bağlı).** `.github/workflows/zip-ac.yml` dosyasını sil (Code →
   dosya → çöp kutusu simgesi → commit). İş yalnızca zip açmak içindi.

Notlar:

- İş şunu yapar: zip'i açar, zip dosyasını siler, sonucu `main`e commit eder. Zip'in
  içindeki yollar korunur, bu yüzden `sanat/fonts/fraunces.woff2` gibi ikili
  dosyalar da doğru yere düşer.
- Komut satırı yok: commit'i GitHub senin hesabınla atar, `git config` gerekmez.
- İşi ikinci kez çalıştırırsan "nothing to commit" ile kırmızı bitebilir; zararsız,
  çünkü yapılacak bir şey kalmamıştır.
- Public depoda Actions ücretsizdir. Private depoda dakika kotasından düşer.
- `patches/` ve `PUSH.md` bu yöntemde depoya girmez; site için gerekli değiller.
  Yedek bundle (`sanat-backup-2026-11-05.bundle`) `sanat-teslim.zip` içinde sende
  kalır.
- Masaüstü tarayıcıda klasör sürükle-bırak çalışıyorsa Actions'a hiç gerek yok:
  `sanat-web-yukle.zip`i bir kez açıp **Upload files** ekranına `sanat/` klasörünü
  bırakmak yeterli. Mobil tarayıcının dosya seçicisi klasör yapısını korumaz, o
  yüzden telefonda yukarıdaki yol kullanılır.
- Force push'a göre farkı: `8eec4d5` ve `README.md` korunur, ama yeni commit'in
  ebeveyni `8eec4d5` olur; yereldeki 11 commit'in mesajları depoda görünmez (tek
  commit olarak iner). İçerik aynıdır: `sanat/` tam olarak `89f66c5`'teki hâliyle.

## Kimlik doğrulama

1. **HTTPS + kişisel erişim anahtarı** — GitHub → Settings → Developer settings →
   Tokens (classic), `repo` kapsamı. Push'ta kullanıcı adı `tnygnz`, parola yerine
   token. Kalıcı için `git config credential.helper store` (token düz metin
   saklanır; paylaşılan makinede kullanma).
2. **`gh` CLI** — `gh auth login` → `https://github.com` → tarayıcıyla giriş,
   ardından aynı push komutu.
3. **SSH** — `git remote set-url origin git@github.com:tnygnz/suomi-kartat.git`,
   anahtar GitHub'da tanımlı olmalı; parolalı anahtar için `ssh-agent`.

Bu çalışma alanında üçü de yok (`gh auth status`: *not logged into any GitHub
hosts*, `credential.helper` tanımsız), bu yüzden push buradan yapılamaz.

## Uzak depoya erişim yoksa

Yedek bundle'dan klonlayıp kendi kimliğinle gönder:

```bash
git clone sanat-backup-2026-11-05.bundle sanat
cd sanat
git remote add origin https://github.com/tnygnz/suomi-kartat.git
git push --force-with-lease -u origin main
```

Bundle'dan gelen klon doğrudan `main` dalında ve `89f66c5` üzerinde açılır; force
gerekçesi aynıdır (uzak `8eec4d5` ile ortak ata yok).

Alternatif: `patches/` altındaki dosyalar sırayla `git am patches/*.patch` ile
uygulanır (0001–0008).

## Force push'un sileceği tek şey

Uzaktaki `README.md` (GitHub'ın "Initial commit"inde oluşturduğu dosya). Yerel
ağaçta kök `README.md` yok; uygulamanın belgesi `sanat/README.md`. Bu dosyayı
korumak istersen force'tan önce içeriğini kopyalayıp köke ekleyebilirsin:

```bash
git show origin/main:README.md > README.md
git add README.md && git commit -m "Uzak depodaki README'yi koru"
```

Bu durumda yeni HEAD değişir; push komutundaki commit hash'i değil dal adı (`main`)
kullanıldığı için komutlar aynı kalır.

## Push edilmemesi gerekenler

`cert/` (TLS özel anahtarı), `*.bundle` ve `patches/` kök `.gitignore` ile izleme
dışında; `sanat/sanat-server.log` ve `.pid` de `sanat/.gitignore` kapsamında. Push
öncesi `git status --porcelain` çıktısı boş olmalı. Yükleme paketleri
(`sanat-web-yukle.zip`, `sanat-teslim.zip`) ve `tasarim/` ekran görüntüleri de
izlenmiyor — site kökünde yalnızca uygulama dosyaları yayınlanır.

## İlk push'tan sonra

GitHub'da varsayılan dalın `main` olduğunu bir kez kontrol et; Pages derlemesi
birkaç dakika sürebilir, Actions sekmesinde "pages build and deployment" işini izle.
