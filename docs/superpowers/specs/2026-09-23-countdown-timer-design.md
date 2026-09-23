# Zamanlayıcı — Tasarım Dokümanı

Tarih: 23.09.2026 · Dal: `feature/notchy-v1` · İlgili: [2026-09-23-quick-controls-design.md](2026-09-23-quick-controls-design.md)

> **Revizyon (23.09.2026):** Zamanlayıcı düğmesi kontrol satırının sağ grubunda, kilidin solunda duruyor.

## 1. Amaç

Açık adadan dakika girilerek bir geri sayım başlatılır. Kalan süre adada küçük olarak görünür. Süre dolunca ses çalar ve bildirim çıkar.

## 2. Açık adada

- Kontrol satırının sonuna, kilidin sağına, kendi grubunda bir zamanlayıcı düğmesi eklenir (`timer`, 13 pt). Düğme her zaman kullanılabilir. Bir geri sayım varken turuncu görünür.
- Geri sayım yokken düğmeye basınca giriş alanı açılır ya da kapanır.
- Giriş alanı kontrol satırının altında açılır. Küçük bir metin alanıdır:
  - 56 pt genişlikte, 13 pt yazıyla, "dk" yer tutucusu vardır.
  - Açılınca odak doğrudan alana gelir.
  - Enter geri sayımı başlatır. Yalnızca 1–999 arası tam dakika kabul edilir; başka bir değerde hiçbir şey olmaz.
  - Esc alanı kapatır.
- Geri sayım işlerken aynı satırda kalan süre (13 pt, eşit genişlikli rakamlar, beyaz) ve iki düğme görünür: duraklat/devam (`pause.fill` / `play.fill`) ile iptal (`xmark`). Düğmeler 13 pt ve 28×28 boyutundadır. Duraklatılınca süre donar.
- Satırların sırası: kontroller, zamanlayıcı, medya. Zamanlayıcı satırı yalnızca süre girilirken ve geri sayım varken görünür. Her ek satır adayı 36 pt uzatır.

## 3. Ada kapalıyken

- Geri sayım varken, çalışırken de duraklatılmışken de, çentiğin solunda turuncu `timer` simgesi ve kalan süre görünür (12 pt semibold, eşit genişlikli rakamlar).
- Kalan süre `m:ss` biçiminde, bir saat ve üzeri için `s:dd:ss` biçimindedir.
- Medya da çalıyorsa ekolayzır sağda kalır.
- Ada iki yandan `countdownSideWidth` = 76 pt genişler. Ada simetrik olduğu için sağ taraf da aynı ölçüde genişler.
- Sanal çentikte (harici ekran) geri sayım varken ada gizlenmez.

## 4. Süre dolunca

- Geri sayım kaldırılır ve yeni bir `PeekContent.timerDone` bildirimi gösterilir: solda "Süre doldu", sağda turuncu `bell.fill`. Bildirim 5 sn kalır (`timerDoneDuration`).
- Öncelik sırası: HUD, zamanlayıcı, Bluetooth, pil, medya.
- Uygulama tarafında `NSSound(named: "Glass")` bir kez çalar. Görünüm modeli bunu `onCountdownFinished` ile bildirir.

## 5. Ada açık tutma ve klavye

- Giriş alanı açıkken fare adadan ayrılsa da ada kapanmaz. Alan Enter ya da Esc ile kapandığında fare adada değilse ada normal kapanma gecikmesiyle kapanır.
- Ada başka bir nedenle kapanırsa giriş alanı da kapanır.
- `NotchPanel` şimdiye kadar hiç klavye odağı almıyordu. Artık yalnızca giriş alanı açıkken anahtar pencere olabilir (`acceptsKeyboard`).
  - Alan açılınca panel `makeKey()` ile odağı alır. Panel `nonactivatingPanel` olduğu için kullanılan uygulama önde kalır.
  - Alan kapanınca odak, panel sıradan çıkarılıp yeniden öne getirilerek önceki pencereye bırakılır.
  - Panel odağı başka bir tıklamayla kaybederse (`didResignKey`) giriş alanı kapanır.

## 6. Yapı

- **`NotchViewModel`:**
  - saat enjeksiyonu: `init(scheduler:now:)`; `now` varsayılan olarak `Date.init`
  - `@Published countdown: CountdownState?` (`.running(endDate:)` / `.paused(remaining:)`)
  - `@Published isEditingCountdown`
  - `toggleCountdownEntry()`, `cancelCountdownEntry()`, `startCountdown(minutes:)`, `pauseCountdown()`, `resumeCountdown()`, `cancelCountdown()`
  - `onCountdownFinished`
  - `islandContent`
- **`IslandContent`:** Adanın boyutunu belirleyen içerik bilgisidir: medya çalıyor mu, medya var mı, geri sayım var mı, süre giriliyor mu. `NotchLayout.islandSize(for:content:notch:)` ve `isHidden(state:content:isVirtualNotch:)` bunu kullanır.
- **Görünümler:**
  - `CountdownRowView`: giriş alanı ya da çalışan geri sayım
  - `ClosedContentView`: sol taraftaki geri sayım
  - `TimerDonePeekView`
  - `QuickControlsView`: zamanlayıcı düğmesi
- **Pencere ve uygulama:** `NotchPanel.acceptsKeyboard`, `NotchPanelController` içinde odak yönetimi, `AppCoordinator` içinde ses.
- **Biçim:** `CountdownFormat.string(from:)` (`m:ss` / `s:dd:ss`).

## 7. Test ve doğrulama

- Birim testleri şunları kapsar:
  - düğmeyle giriş alanının açılıp kapanması
  - başlatma; geçersiz değerin yok sayılması
  - duraklatma ve devam etmede kalan sürenin korunması
  - iptal
  - süre dolunca bildirimin çıkması, callback'in çağrılması ve bildirimin 5 sn kalması
  - süre girilirken adanın kapanmaması
  - biçimlendirme
  - ada boyutları ve gizlenme kuralı
- Geçici resim testiyle şu durumlar kontrol edilir: süre girme, çalışan geri sayım, kapalı adada geri sayım, "Süre doldu" bildirimi.
- Tam test paketi çalıştırılır.
- Kullanıcı elle kontrol eder:
  - klavyeyle dakika girme; önde çalışan uygulamanın odağı kaybetmemesi
  - Esc; başka yere tıklama
  - duraklat/devam, iptal; ses ve bildirim

## 8. Kapsam dışı

- +1 dk düğmesi, hazır süreler.
- Birden fazla zamanlayıcı.
- Kronometre (ileri sayım).
- Uygulama yeniden başlayınca zamanlayıcının sürmesi.
