# Notchy

MacBook çentiğini Dynamic Island benzeri canlı bir alana dönüştüren macOS uygulaması.

## Özellikler (v1)
- Ses ve parlaklık göstergesi (sistem HUD'u yerine)
- Şarj takma/çıkarma ve düşük pil (%20, %10) bildirimleri
- AirPods / Bluetooth kulaklık bağlanma bildirimi ve pil seviyeleri
- Çalan medya: şarkı bilgisi, oynat/duraklat/ileri/geri, iki parmakla kaydırma
- Harici ekranlar: ada farenin olduğu ekrana geçer; çentiksiz ekranda boştayken gizlenir

## Gereksinimler
- macOS 14+; en iyi çentikli MacBook'ta çalışır, harici ve çentiksiz ekranlarda sanal çentik kullanılır
- Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), CMake (yalnızca adaptörü yeniden derlemek için)

## Geliştirme
    scripts/test.sh     # testler
    scripts/run.sh      # Debug derle ve çalıştır
    scripts/vendor-mediaremote-adapter.sh   # medya adaptörünü yeniden derle

Ad-hoc imzalı derlemelerde Erişilebilirlik izni her yeniden derlemeden sonra
Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik'ten kaldırılıp tekrar verilmelidir.

## Performans (ölçülen)
Ölçüm tarihi: 23.09.2026 (final inceleme düzeltmesi — önceki tablo kendisiyle çelişiyordu
ve `ps`'in `%CPU` sütununu yanlış açıklıyordu, bkz. altta). Makine: Apple M4 Pro
MacBook Pro, macOS 26.6.2. Release derlemesi
(`build/DerivedData/Build/Products/Release/Notchy.app`), `onboarding.completed` `true`
ayarlanıp açıldı, çentikten uzakta imleç hareketsiz bırakılarak 60 sn beklendikten sonra
ölçüldü. Ölçüm penceresinde bir sekmede medya gerçekten çalıyordu
(`mediaremote-adapter.pl ... get --no-artwork` çıktısı `"playing":true` döndürdü); yani
bu sayılar "medya yok" saf boşta durumunu değil, "çentik kapalı, imleç uzakta ama medya
akışı arka planda işleniyor" durumunu yansıtıyor. Adaptör alt süreci
(`mediaremote-adapter.pl stream ...`) `pgrep -f mediaremote-adapter.pl` ile bulundu.

`top -l 13 -s 5 -stats pid,command,cpu,rsize -pid <Notchy> -pid <adapter>` ile 5 sn
arayla 13 örnek alındı; ilk örnek (ısınma payı bırakmak için) atıldı, kalan 12 örnek:

| Süreç   | RSS (12 örnekte sabit) | %CPU aralığı | %CPU ortalama |
|---------|------------------------:|--------------:|---------------:|
| Notchy  | 16 MB                   | 0.0 – 5.0 %    | ≈1.8 %          |
| Adapter | ≈9.1 MB                 | 0.0 % (hepsi)  | 0.0 %           |

Toplam RSS ≈ 25 MB, hedeflenen <80 MB sınırının belirgin şekilde altında.

Notchy'nin %CPU'su bu turda belirgin şekilde sıfır değil (12 örnekte 0.0–5.0 % arası,
ortalama ≈%1.8): bunu dürüstçe böyle bildiriyoruz. Muhtemel açıklaması, ölçüm penceresinde
medyanın gerçekten çalıyor olması — adaptör sürekli now-playing güncellemesi akıtıyor ve
`MediaModule` panel görünür olmasa bile bunu işliyor — ve ölçüm anında makinenin başka
işlerle de meşgul olması (`Load Avg` ≈4.5–5.9 aynı pencerede). Bu turda bunun ötesinde
yeni bir performans soruşturması açılmadı; "boşta ≈%0 CPU" iddiası bu ölçümle
doğrulanamadı, sayı olduğu gibi raporlanıyor.

`ps`'in `%CPU` sütunu, önceki sürümün iddia ettiğinin aksine süreç başlangıcından beri
bir ortalama DEĞİLDİR: `ps(1)` man sayfasına göre önceki gerçek zamanın en fazla bir
dakikası üzerinden üstel ağırlıklı, kayan (decaying) bir ortalamadır. Bu yüzden art arda
alınan iki `ps` örneği arasında görülen fark, sürecin gerçekten hızlanmakta olduğu
anlamına gelmez; yukarıdaki ölçüm bu yüzden `ps` yerine `top`'un ardışık örneklerine
dayanıyor. Medya çalarken ekolayzer animasyonu sırasındaki CPU kullanımı panel görünürken
ayrıca insan gözetiminde gözlemlenmelidir (bkz. manuel kontrol listesi).

## Lisanslar
Medya bilgisi için [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause) kullanılır; bkz. `Vendor/MediaRemoteAdapter/LICENSE`.
