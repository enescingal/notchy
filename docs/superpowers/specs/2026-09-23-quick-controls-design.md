# Hızlı kontroller — Tasarım Dokümanı

Tarih: 23.09.2026 · Dal: `feature/notchy-v1` · Ana tasarım: [2026-09-23-notchy-design.md](2026-09-23-notchy-design.md)

> **Revizyon (23.09.2026):** Gruplar arası boşluk 28 pt'ye çıktı. Açık ada 392 pt genişliğinde; çentik yanındaki gösterge bu alana göre daraltılıyor (`NotchLayout.expandedSideSpace`).

> **Revizyon 2 (24.09.2026):** Satır ikiye ayrıldı: solda parlaklık ve ses, sağda zamanlayıcı ve kilit. Düğmeler arasında yüzde değerleri bir süre denendi, kullanıcı istemediği için kaldırıldı.

## 1. Amaç

Açık adada, müzik çalsın ya da çalmasın, her zaman bir kontrol satırı görünür. Satırda şu düğmeler vardır: parlaklığı azalt/artır, sesi azalt/artır ve ekranı hemen kilitle.

## 2. Görünüm

- Kontrol satırı çentik şeridinin hemen altındaki ilk satırdır. Yeri müziğe göre değişmez.
- Satırda üç gruba ayrılmış beş düğme vardır ve satır ortalanır:
  - parlaklık: `sun.min.fill`, `sun.max.fill`
  - ses: `speaker.wave.1.fill`, `speaker.wave.3.fill`
  - kilit: `lock.fill`
- Stil:
  - simgeler 13 pt semibold ve beyaz
  - her düğme 28×28
  - grup içinde 2 pt, gruplar arasında 16 pt boşluk
- Medya varsa, yani `viewModel.media != nil` ise (çalıyor ya da duraklatılmış), mevcut tek satırlık medya görünümü kontrol satırının altına gelir. İki satır arasında 8 pt boşluk vardır.
- Medya yoksa yalnızca kontrol satırı görünür. "Şu an çalan bir şey yok" yazısı kaldırılır.
- Kullanılamayan bir düğme %30 opaklıkta çizilir ve tıklanamaz. Yeri değişmez.

## 3. Ada boyutu

- Çentiğin altındaki alan medya yokken 48 pt'dir (bugünkü değer). Medya varken buna `expandedRowHeight` = 36 pt eklenir ve alan 84 pt olur. Satırlar bu alanda dikey olarak ortalanır.
- `NotchLayout.islandSize(for:isMediaPlaying:hasMedia:notch:)` açık durumdaki yüksekliği `hasMedia`'ya göre belirler. Panel, adanın en uzun hâline göre boyutlanır.
- Örnek, 200×32 pt çentik için:
  - medya yokken açık ada 472×80
  - medya varken açık ada 472×116
  - panel 520×140
- Medya gelip gidince ada mevcut yay animasyonuyla uzar ya da kısalır.

## 4. Davranış

- **Parlaklık − / +:** Yerleşik ekranın parlaklığını tuşlarla aynı adımla (1/16) değiştirir (`BrightnessController`). Ada hangi ekranda olursa olsun değişen, yerleşik ekrandır.
- **Ses − / +:** Varsayılan çıkış aygıtının sesini 1/16 adımla değiştirir (`VolumeController`). Ses kapalıysa, tuşlarda olduğu gibi açar.
- **Gösterge:** Her basıştan sonra yeni seviye `present(.hud(...))` ile gösterilir. Ada açıkken bu gösterge çentiğin yanındaki şeritte çıkar.
- **Kilit:** `SACLockScreenImmediate()` çağrılır ve ekran hemen kilitlenir. Fonksiyon, gizli `login.framework` kütüphanesinden çalışma anında `dlopen` ile yüklenir.
- **Kullanılabilirlik:** Ada her açıldığında ve her basıştan sonra yeniden hesaplanır.
  - Parlaklık: `BrightnessController` yüklenebildiyse ve yerleşik ekran açıksa (`isUsable`) kullanılabilir.
  - Ses: `canSetVolume` doğruysa kullanılabilir.
  - Kilit: fonksiyon bulunduysa kullanılabilir.
- **Bağımsızlık:** Kontroller modül ayarlarından ve Erişilebilirlik izninden bağımsızdır. `AppCoordinator` onları her zaman başlatır ve bunun için ayrı bir ses denetleyicisi çalıştırır.

## 5. Yapı

- `Notchy/Modules/Controls/QuickControls.swift`:
  - `QuickControl` enum'u
  - `VolumeStepping`, `BrightnessStepping` ve `ScreenLocking` protokolleri
  - işleyiciyi ve kullanılabilirliği görünüm modeline bağlayan `QuickControls` sınıfı
- `Notchy/Modules/Controls/ScreenLocker.swift`: `SACLockScreenImmediate` yükleyicisi.
- `Notchy/Modules/Controls/QuickControlsView.swift`: kontrol satırının görünümü.
- `NotchViewModel`: `controlHandler`, `perform(_:)` ve `availableControls` eklenir.
- `NotchLayout`, `NotchView` ve `NotchPanelController`: ada boyu hesabına `hasMedia` eklenir.
- `ExpandedContentView`: kontrol satırını ve altında medya satırını gösterir.
- `AppCoordinator`: `QuickControls`'u oluşturur. `Log`'a `controls` kategorisi eklenir.
- Belgeler:
  - ana tasarım: açık görünüm maddeleri
  - README: özellikler listesi

## 6. Test ve doğrulama

- `QuickControlsTests` birim testleri sahte ses, parlaklık ve kilit nesneleriyle şunları kontrol eder:
  - her düğme doğru adımı atar ve göstergeyi açar
  - kullanılamayan bir düğme hiçbir şey yapmaz
  - kullanılabilir düğmeler kümesi doğrudur
  - ada açılınca kullanılabilirlik yenilenir
- `NotchGeometryTests`: medya varken ve yokken açık ada ve panel boyutları.
- Geçici bir `ImageRenderer` testiyle resim kontrolü yapılır; bu test commit'lenmez. Kontrol edilen durumlar: medyasız, medyalı, soluk parlaklık düğmeleri.
- Tam test paketi çalıştırılır.
- Kullanıcı elle kontrol eder: düğmeler (ada MacBook'tayken ve A32'deyken) ve kilit.

## 7. Kapsam dışı

- Sessize alma düğmesi.
- Harici monitörün parlaklığı (DDC).
- Düğmelerin ayarlardan gizlenmesi.
