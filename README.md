<p align="center">
  <img src="docs/icon.png" width="128" alt="UzPort">
</p>

<h1 align="center">UzPort</h1>

<p align="center">
  <b>Hangi port kimde? Menü çubuğunda, tek bakışta.</b><br>
  Mac'inde çalışan tüm geliştirme sunucularını, veritabanlarını ve Docker konteynerlerini gösterir;<br>
  tek tıkla aç, kopyala, telefonda test et ya da portu boşalt.
</p>

<p align="center">
  <a href="../../releases/latest"><img src="https://img.shields.io/github/v/release/ahmeterdgn/uzport?label=indir&color=5B8CFF" alt="İndir"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-evrensel-9A6BFF" alt="Universal">
  <img src="https://img.shields.io/badge/lisans-MIT-34D399" alt="MIT">
  <img src="https://img.shields.io/badge/dil-TR%20%7C%20EN-FBBF24" alt="TR | EN">
</p>

<p align="center"><a href="#english">English ↓</a></p>

<p align="center">
  <img src="docs/screenshots/tr/panel.png" width="452" alt="UzPort paneli">
</p>

---

## Neden UzPort?

`Error: listen EADDRINUSE: address already in use :::3000`… Hangi terminal sekmesiydi? Hangi proje?
`lsof -i :3000` yaz, PID'yi bul, `kill -9`… UzPort bunu menü çubuğuna taşır.

- ▶️ **Projelerini panelden başlat.** `~/Desktop/devs`, `~/Projects`… klasörlerindeki projeler bulunur; ▶︎ ile `pnpm/yarn/bun/npm run dev`, `php artisan serve`, `manage.py runserver`, `rails server`, `docker compose up`. Kendi kabuğunda çalışır (nvm, Homebrew PATH'in geçerli). Durdur deyince npm'in açtığı tüm alt süreçler de kapanır.
- 📜 **Canlı loglar.** Her sunucunun çıktısı kendi penceresinde: renk kodları temizlenmiş, hata/uyarı renkli, arama, takip, kopyala; log'daki `Local: http://…` adresi tek tıkla açılır.
- 💥 **Çökeni yakala.** Sunucu çökerse satır kırmızıya döner; tek tıkla ya da otomatik yeniden başlat.
- ⌨️ **⌃⌥P** ile panel her yerden açılır.
- 📡 **Her şey tek panelde.** Vite, Next.js, Laravel, Django, Rails, Node, PHP… 40+ sunucu türü otomatik tanınır; proje adı `package.json`'dan ya da klasörden gelir.
- 🗂 **Akıllı gruplar.** *Projelerin*, *Veritabanları ve servisler* (PostgreSQL, Redis, MySQL, MongoDB, Ollama…), *Docker* (konteyner adı ve imajıyla), *Uygulamalar*. macOS sistem portları (AirPlay vb.) gizlidir.
- 🔎 **Port yaz, cevabı al.** Arama kutusuna `3000` yaz: doluysa kimin tuttuğunu görür, **tek tıkla boşaltırsın**; boşsa "boş" der.
- 🌐 **Sayfayı tanı.** Her sunucunun sayfa başlığı, favicon'u ve HTTP durumu (🟢 🟡 🔴), ne zamandır çalıştığı ve bellek kullanımı.
- 📱 **Telefonda test.** Ağ adresi için QR kod. Sunucu yalnızca `localhost`'u dinliyorsa uyarır (`--host` ipucuyla).
- ⚡ **Tek tık eylemler.** Tarayıcıda aç, adresi kopyala, Finder'da göster, VS Code / Cursor / Zed'de, Warp / iTerm / Terminal'de aç, PID'yi ya da komutu kopyala, süreci kapat (yanlışlıkla olmasın diye iki tık).
- 🔔 **Bildirim.** Yeni bir geliştirme sunucusu başlayınca haber verir; bildirime tıkla, açılsın.
- 🪶 **Hafif.** `lsof` çalıştırmaz; portları doğrudan macOS çekirdeğinden (`libproc`) okur. Yönetici izni istemez, Dock'ta yer kaplamaz.

<p align="center"><img src="docs/screenshots/tr/logs.png" width="820" alt="Canlı loglar"></p>

<table>
  <tr>
    <td><img src="docs/screenshots/tr/lookup.png" alt="Port arama"></td>
    <td align="center"><img src="docs/screenshots/tr/qr.png" width="240" alt="QR"></td>
  </tr>
  <tr>
    <td align="center"><sub>“3000 kimde?” — tek tıkla boşalt</sub></td>
    <td align="center"><sub>Telefonda aç</sub></td>
  </tr>
</table>

## Kurulum

1. [Son sürümden](../../releases/latest) `UzPort-x.y.z.dmg` dosyasını indir, **UzPort**'u **Applications**'a sürükle.
2. Uygulama Apple'a ücretli olarak imzalatılmadığı için ilk açılışta: Uygulamalar'da **sağ tık → Aç → Aç**
   (macOS 15+: *Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç*) ya da:
   ```sh
   xattr -dr com.apple.quarantine /Applications/UzPort.app
   ```
3. Menü çubuğundaki 📡 simgesine tıkla (ya da **⌃⌥P**). ⚙️ menüsünden **Girişte başlat**'ı açabilir, **Proje klasörleri** ekleyebilirsin.

## Nasıl çalışır?

- `proc_listpids` → her süreç için `PROC_PIDLISTFDS` → `PROC_PIDFDSOCKETINFO` ile **LISTEN** durumundaki TCP soketleri; 2 saniyede bir.
- Komut satırı (`KERN_PROCARGS2`) ve çalışma klasörü (`PROC_PIDVNODEPATHINFO`) ile sunucu türü ve proje kökü bulunur.
- Docker portları `docker ps` ile konteyner adlarına eşlenir (Docker Desktop, Colima, OrbStack).
- Sayfa başlığı ve favicon için sunucuya kısa bir `GET /` isteği atılır (yalnızca `localhost`).
- Yalnızca kendi kullanıcının süreçleri kapatılabilir; sistem süreçlerine dokunulmaz.
- Başlatılan sunucular `posix_spawn` ile **kendi süreç grubunda** çalışır; durdurma tüm gruba `SIGTERM` (gerekirse `SIGKILL`) gönderir. UzPort kapanınca başlattığı sunucular da kapanır.

## Kaynaktan derleme

```sh
git clone https://github.com/ahmeterdgn/uzport && cd uzport
swift test                     # 11 birim testi (gerçek soket açma/kapama dahil)
./scripts/build-app.sh         # build/UzPort.app (evrensel)
VERSION=1.0.0 ./scripts/make-dmg.sh
```

Gereksinim: Xcode 15+ / Swift 5.9+, macOS 13+.

Kardeş uygulama: [**UzDisc**](https://github.com/ahmeterdgn/uzdisc) — Mac'in açamadığı diskleri salt okunur aç, dosyalarını kurtar.

---

<a name="english"></a>

## English

<p align="center">
  <img src="docs/screenshots/en/panel.png" width="452" alt="UzPort panel">
</p>

**Who's on port 3000? UzPort answers from your menu bar.** It shows every dev server, database and Docker container
running on your Mac — open, copy, test on your phone, or free the port in one click.

- ▶️ **Launch your projects from the panel.** Projects in your dev folders are discovered; ▶︎ runs `pnpm/yarn/bun/npm run dev`, `php artisan serve`, `manage.py runserver`, `rails server` or `docker compose up` in your own shell (nvm & Homebrew PATH included). Stopping kills the whole process group — no orphaned node processes.
- 📜 **Live logs** in their own window: ANSI-stripped, colored errors/warnings, filter, follow, copy; the detected `Local:` URL is one click away.
- 💥 **Crash aware.** Crashed servers turn red; restart in one click or automatically.
- ⌨️ **⌃⌥P** opens the panel from anywhere.
- 📡 **Everything in one panel.** Vite, Next.js, Laravel, Django, Rails, Node, PHP… 40+ server types detected automatically, with the project name from `package.json` or the folder.
- 🗂 **Smart groups.** *Your projects*, *Databases & services*, *Docker* (with container name and image), *Apps*. macOS system ports are hidden.
- 🔎 **Type a port, get the answer.** Type `3000`: see who's using it and **free it in one click** — or confirm it's free.
- 🌐 **Know the page.** Page title, favicon, HTTP status, uptime and memory for every server.
- 📱 **Test on your phone.** QR code for the network URL, with a warning if the server only listens on `localhost`.
- ⚡ **One-click actions.** Open in browser, copy URL, reveal in Finder, open in VS Code / Cursor / Zed or Warp / iTerm / Terminal, stop the process (two clicks, to be safe).
- 🔔 **Notifications** when a new dev server starts.
- 🪶 **Lightweight.** No `lsof`, no admin password, no Dock icon — ports come straight from the kernel via `libproc`.

<p align="center"><img src="docs/screenshots/en/logs.png" width="820" alt="Live logs"></p>

<table>
  <tr>
    <td><img src="docs/screenshots/en/lookup.png" alt="Port lookup"></td>
    <td align="center"><img src="docs/screenshots/en/qr.png" width="240" alt="QR"></td>
  </tr>
</table>

### Install

Download `UzPort-x.y.z.dmg` from the [latest release](../../releases/latest), drag **UzPort** to **Applications**.
The app isn't notarized, so on first launch **right-click → Open → Open** (or `xattr -dr com.apple.quarantine /Applications/UzPort.app`).
The UI follows your system language (Turkish/English) and can be switched in ⚙️.

---

<p align="center">
  <a href="https://uzmoon.com"><img src="docs/uzmoon.png" width="28" alt="Uzmoon"></a><br>
  <sub><a href="https://uzmoon.com">uzmoon.com</a> tarafından yapılmıştır · Made by <a href="https://uzmoon.com">uzmoon.com</a></sub><br>
  <sub>MIT Lisansı</sub>
</p>
