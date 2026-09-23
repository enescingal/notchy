# Notchy

MacBook çentiğini Dynamic Island benzeri canlı bir alana dönüştüren macOS uygulaması.

## Özellikler (v1)
- Ses ve parlaklık göstergesi (sistem HUD'u yerine)
- Şarj takma/çıkarma ve düşük pil (%20, %10) bildirimleri
- AirPods / Bluetooth kulaklık bağlanma bildirimi ve pil seviyeleri
- Çalan medya: şarkı bilgisi, oynat/duraklat/ileri/geri, iki parmakla kaydırma

## Gereksinimler
- Çentikli ekranlı MacBook, macOS 14+
- Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), CMake (yalnızca adaptörü yeniden derlemek için)

## Geliştirme
    scripts/test.sh     # testler
    scripts/run.sh      # Debug derle ve çalıştır
    scripts/vendor-mediaremote-adapter.sh   # medya adaptörünü yeniden derle

Ad-hoc imzalı derlemelerde Erişilebilirlik izni her yeniden derlemeden sonra
Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik'ten kaldırılıp tekrar verilmelidir.

## Performans (ölçülen)
Ölçüm tarihi: 23.09.2026. Makine: Apple M4 Pro MacBook Pro, macOS 26.6.2. Release
derlemesi (`build/DerivedData/Build/Products/Release/Notchy.app`) çalıştırılıp çentikten
uzakta, imleç hareketsiz bırakılarak ölçüldü. Ölçüm anında medya çalmıyordu
(`mediaremote-adapter.pl ... get --no-artwork` çıktısı `"playing":false` döndürdü, yani
ekolayzer animasyonu bu ölçüm sırasında tetiklenmedi); adaptör alt süreci
(`mediaremote-adapter.pl stream ...`) `pgrep -f mediaremote-adapter.pl` ile bulundu.

`ps -o pid,rss,%cpu -p <Notchy> -p <adapter>` ile iki örnek alındı (60 sn boşta, sonra
~30 sn sonra tekrar):

| Örnek                | Notchy RSS | Notchy %CPU | Adapter RSS | Adapter %CPU | Toplam RSS |
|-----------------------|-----------:|------------:|------------:|-------------:|-----------:|
| 60 sn boşta            | 42.5 MB    | 2.9 %       | 22.7 MB     | 0.0 %        | 65.2 MB    |
| ~30 sn sonra (2. örnek) | 40.4 MB    | 5.0 %       | 22.0 MB     | 0.0 %        | 62.4 MB    |

Toplam RSS her iki örnekte de hedeflenen <80 MB sınırının altında (≈62–65 MB).

`ps`'in `%CPU` sütunu süreç başlangıcından (açılış maliyeti dahil) itibaren üstel
ağırlıklı bir ortalama olduğundan tek başına anlık boşta kullanımı yansıtmaz; bu yüzden
aynı pencerede `top -l 3 -s 1 -pid <Notchy> -pid <adapter>` ile 1 sn arayla 3 ardışık
örnek de alındı ve her üç örnekte de her iki süreç için de %0.0 CPU görüldü — bu da
hedeflenen "boşta ≈%0 CPU" davranışını doğruluyor. Medya çalarken ekolayzer animasyonu
sırasındaki CPU kullanımı bu otomatik ölçümde doğrulanamadı (bkz. Step 4/manuel kontrol
listesi); insan gözetiminde aktif oynatma ile ayrıca gözlemlenmelidir.

## Lisanslar
Medya bilgisi için [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause) kullanılır; bkz. `Vendor/MediaRemoteAdapter/LICENSE`.
