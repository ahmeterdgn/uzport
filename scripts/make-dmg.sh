#!/usr/bin/env bash
# build/UzPort.app'ten sürükle-bırak kurulumlu DMG üretir.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
APP="build/UzPort.app"
DMG="build/UzPort-$VERSION.dmg"
[ -d "$APP" ] || { echo "Önce ./scripts/build-app.sh çalıştırın"; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Kurulum - OKU.txt" <<'EOF'
UzPort kurulumu
================

1. UzPort simgesini yandaki "Applications" (Uygulamalar) klasörüne sürükleyin.
2. İlk açılışta macOS "geliştirici doğrulanamadı" uyarısı verebilir:
   Uygulamalar klasöründe UzPort'a sağ tıklayın → "Aç" → tekrar "Aç".
   (macOS 15 ve sonrası: Sistem Ayarları → Gizlilik ve Güvenlik → "Yine de Aç".)

   Alternatif olarak Terminal'de:
   xattr -dr com.apple.quarantine /Applications/UzPort.app

UzPort menü çubuğunda çalışır; Dock'ta simgesi görünmez.
EOF

rm -f "$DMG"
# Boş bir DMG bağlamak yerine doğrudan klasörden HFS+ kalıp üretip sıkıştır (disk bağlama gerektirmez).
RAW="$STAGE.raw.dmg"
hdiutil makehybrid -hfs -hfs-volume-name "UzPort $VERSION" -o "$RAW" "$STAGE" >/dev/null
hdiutil convert "$RAW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RAW"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "✓ $DMG"
