# Tek satırlık medya görünümü — Tasarım Dokümanı

Tarih: 23.09.2026 · Dal: `feature/notchy-v1` · Ana tasarım: [2026-09-23-notchy-design.md](2026-09-23-notchy-design.md)

> **Revizyon (23.09.2026):** Sanatçı kaldırıldı. Şarkı adı sola yaslı, düğmeler sağda. Açık ada 392 pt genişliğe indi (`expandedSideWidth` 90, `expandedMinWidth` 380).

## 1. Amaç

Genişlemiş adadaki medya görünümü üç satırdan (şarkı adı, sanatçı, düğmeler) tek satıra iner. Ada da bu satıra göre kısalır.

## 2. Satır düzeni

Satır üç sütundan oluşur:

| Sütun | İçerik | Stil |
|-------|--------|------|
| Sol | Sanatçı | 11 pt regular, beyaz %50 opaklık, sola yaslı |
| Orta | Şarkı adı | 12 pt semibold, beyaz, ortalı |
| Sağ | Önceki · oynat/duraklat · sonraki | Simgeler 12 pt semibold (oynat/duraklat 15 pt), her düğme 28×28, aralık 2 pt, sağa yaslı |

- Sol ve sağ sütun eşit genişliktedir (100 pt). Sütunlar arasında 10 pt boşluk vardır. Böylece şarkı adı her zaman adanın, yani çentiğin, tam ortasında durur.
- 472 pt genişliğindeki adada satır 420 pt olur (iki yanda 26 pt iç boşluk). Orta sütun 200 pt kalır.
- Metinler tek satırdır. Sığmayan şarkı adı veya sanatçı adının sonu "…" ile kısalır.
- Sanatçı `nil` ya da boşsa sol sütun boş kalır, şarkı adı yine ortada durur.
- Medya yoksa satırın yerinde mevcut "Şu an çalan bir şey yok" yazısı ortada görünür.

## 3. Ada boyutu

- `NotchLayout.expandedExtraHeight` 104 pt'den 48 pt'ye iner. Genişlik formülü aynı kalır.
- Satır, çentiğin altındaki 48 pt'lik alanda dikey olarak ortalanır. Genişlemiş içerikteki 14 pt'lik alt boşluk kaldırılır.
- 200×32 pt çentik için örnek:
  - Ada 472×136'dan 472×80'e iner.
  - Panel 520×160'tan 520×104'e iner.

## 4. Ada açıkken ses ve parlaklık göstergesi

- `expandedHUD` artık adanın en altında gösterilmez.
- Çentik yüksekliğindeki üst şeritte `HUDPeekView` ile gösterilir: çentiğin solunda simge, sağında seviye çubuğu. Bu, ada kapalıyken çıkan göstergenin aynısıdır. Süre değişmez (`hudDuration`, 1,5 sn).
- Başka kullanımı olmayan `HUDInlineView` silinir.
- `NotchViewModel` durum makinesi değişmez.

## 5. Ana tasarımda değişen maddeler

- **§3:** "HUD değeri expanded görünümde küçük bir satır olarak güncellenir" maddesi değişir. Artık gösterge, bu belgenin §4'ündeki gibi üst şeritte görünür.
- **§4.4 expanded:** Şarkı adı, sanatçı ve düğmeler bu belgenin §2'sindeki tek satırlık düzenle gösterilir.

## 6. Değişecek dosyalar

- `Notchy/Modules/Media/MediaViews.swift`: `MediaExpandedView` tek satırlık düzene geçer.
- `Notchy/Notch/NotchView.swift`: `ExpandedContentView` üst şerit (gösterge) ve satırdan oluşur. `notchHeight` yerine `notchSize` alır.
- `Notchy/Notch/NotchLayout.swift`: `expandedExtraHeight = 48`.
- `Notchy/Modules/HUD/HUDViews.swift`: `HUDInlineView` silinir.
- `NotchyTests/NotchGeometryTests.swift`: genişlemiş ada ve panel için beklenen yeni boyutlar.
- `docs/superpowers/specs/2026-09-23-notchy-design.md`: §5'teki iki madde.

## 7. Test ve doğrulama

- `NotchGeometryTests` önce yeni boyutlarla güncellenir ve testin kırmızı olduğu görülür, ardından sabit değiştirilir.
- Projede SwiftUI görünüm testi altyapısı yok. Bunun yerine commit'lenmeyen geçici bir test, `ImageRenderer` ile şu durumları PNG'ye çizer. Bu resimler gözle kontrol edilir.
  - kısa şarkı adı
  - uzun şarkı adı ve uzun sanatçı adı
  - sanatçısız
  - medya yok
  - ada açıkken ses göstergesi
- Tam test paketi (`scripts/test.sh`) çalıştırılır.
- Elle kontrol (kullanıcı): uygulamada hover ile adayı açıp satırı, düğmeleri, iki parmakla kaydırmayı ve ses tuşunu dener.

## 8. Kapsam dışı

- Harici ekran desteği (ayrı bir tasarım konusu).
- Albüm kapağı.
- Kapalı durumdaki ekolayzır.
- Ada genişliğinin değişmesi.
