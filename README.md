# Notchy

MacBook çentiğini Dynamic Island benzeri canlı bir alana dönüştüren macOS uygulaması.

## Özellikler (v1)
- Ses ve parlaklık göstergesi (sistem HUD'u yerine)
- Şarj takma/çıkarma ve düşük pil (%20, %10) bildirimleri
- AirPods / Bluetooth kulaklık bağlanma bildirimi ve pil seviyeleri
- Çalan medya: şarkı bilgisi, oynat/duraklat/ileri/geri, iki parmakla kaydırma
- Hızlı kontroller: açık adada her zaman parlaklık ve ses düğmeleri, ekranı kilitleme
- Harici ekranlar: ada farenin olduğu ekrana geçer; çentiksiz ekranda boştayken gizlenir

## Gereksinimler
- macOS 14+; en iyi çentikli MacBook'ta çalışır, harici ve çentiksiz ekranlarda sanal çentik kullanılır
- Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), CMake (yalnızca adaptörü yeniden derlemek için)

## Geliştirme
    scripts/test.sh     # testler
    scripts/run.sh      # Debug derle ve çalıştır
    scripts/vendor-mediaremote-adapter.sh   # medya adaptörünü yeniden derle

Varsayılan derleme ad-hoc imzalıdır: macOS Erişilebilirlik iznini derlemenin parmak izine
bağlar, bu yüzden izin her yeniden derlemeden (testler dahil) sonra Sistem Ayarları › Gizlilik
ve Güvenlik › Erişilebilirlik'ten kaldırılıp tekrar verilmelidir. Bunu önlemek için depo köküne
git'e işlenmeyen bir `.signing-identity` dosyası koyun; `scripts/run.sh` ve `scripts/test.sh`
derlemeyi o kimlikle imzalar ve izin derlemeler arasında korunur (kimlikleri görmek için
`security find-identity -v -p codesigning`):

    echo 'Apple Development: Ad Soyad (XXXXXXXXXX)' > .signing-identity

## Performans (ölçülen)
Ölçüm: 23.09.2026, Apple M4 Pro MacBook Pro, macOS 26.6.2, Release derlemesi
(`build/DerivedData/Build/Products/Release/Notchy.app`). Uygulama açıldıktan 60 sn sonra
`top -l 13 -s 5 -stats pid,cpu` ile 5 sn arayla 13 örnek alındı, ilk örnek atıldı. Ölçüm
boyunca hiçbir medya çalmıyordu (adaptörün `get` çıktısı başta ve sonda kontrol edildi).

| Süreç   | CPU (12 örnek)        | Bellek (Activity Monitor) | RSS   |
|---------|-----------------------|--------------------------:|------:|
| Notchy  | %0.0–1.0 (ort. ≈%0.2) | 17 MB                     | 53 MB |
| Adaptör | %0.0 (hepsi)          | 9 MB                      | 26 MB |
| Toplam  |                       | 26 MB                     | 80 MB |

- **Bellek:** "Bellek" sütunu `footprint` aracının verdiği, Activity Monitor'de görünen
  değerdir ve 80 MB hedefinin çok altındadır. RSS (`ps -o rss`), paylaşılan sistem
  kütüphanelerinin (AppKit, SwiftUI, perl) sayfalarını her sürece ayrı ayrı saydığı için
  gerçek maliyetin üstündedir; toplamı hedefin tam sınırındadır.
- **CPU:** Boşta Notchy ilk üç örnekte %0.5–1.0, sonraki dokuz örnekte (45 sn) %0.0
  kullandı; adaptör hiç CPU kullanmadı.
- **Müzik çalarken:** Kapalı adada ekolayzır animasyonu sürekli çizilir. Daha önceki bir
  ölçümde (bir tarayıcı sekmesinde medya çalarken) Notchy %0–5, ortalama ≈%1.8 kullanmıştı;
  bu durum bu turda yeniden ölçülmedi.

`ps`'in `%CPU` sütunu süreç başlangıcından beri bir ortalama değildir; `ps(1)`'e göre son bir
dakikalık üstel ağırlıklı, kayan bir ortalamadır. Bu yüzden CPU için `top`'un ardışık
örnekleri kullanıldı.

## Lisanslar
Medya bilgisi için [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause) kullanılır; bkz. `Vendor/MediaRemoteAdapter/LICENSE`.
