# Harici ekran desteği — Tasarım Dokümanı

Tarih: 23.09.2026 · Dal: `feature/notchy-v1` · Ana tasarım: [2026-09-23-notchy-design.md](2026-09-23-notchy-design.md)

## 1. Amaç

Ada yalnızca MacBook'un çentikli ekranında değil, bağlı her ekranda kullanılabilir. Tek bir ada vardır ve fare hangi ekrandaysa orada durur.

## 2. Ekran seçimi

- Ada, fare imlecinin bulunduğu ekrandadır. Bu ekran, çerçevesi `NSEvent.mouseLocation`'ı içeren ekrandır; üst kenar da buna dahildir. İmleç hiçbir ekranda değilse ada olduğu yerde kalır.
- Fare başka bir ekrana geçince panel o ekrana taşınır. Tek bir `NotchPanel` kullanılır, her ekran için ayrı pencere açılmaz.
- Ada `expanded` durumundayken taşınmaz. Fare adadan ayrıldığı için ada 0,3 sn sonra kapanır ve kapandıktan sonra taşınır.
- Ekran bir `peek` sırasında değişirse peek, kalan süresiyle yeni ekranda devam eder. Durum makinesi değişmez.
- `NSApplication.didChangeScreenParametersNotification` geldiğinde panel, farenin o anki ekranına yeniden kurulur.

## 3. Çentik yerleşimi

- **Fiziksel çentiği olan ekran:** `safeAreaInsets.top > 0` ise ve üstteki yardımcı alanlar varsa, bugünkü gibi gerçek çentik boyutu kullanılır (`isVirtual = false`).
- **Diğer ekranlar:** Sanal çentik kullanılır (`isVirtual = true`).
  - Genişlik 185 pt'dir. Bu, kullanıcının MacBook Pro'sundaki çentik genişliğidir.
  - Yükseklik o ekranın menü çubuğu kadardır (`frame.maxY - visibleFrame.maxY`). Bu değer 0 ise 24 pt kullanılır; menü çubuğu gizliyse veya o ekranda hiç yoksa değer 0 olur.
  - Konumu ekranın üst kenarında, yatayda ortadadır. Bu, bugünkü `panelFrame` hesabıyla aynıdır.
- Ada boyutları (`NotchLayout.islandSize`) yine çentik boyutundan hesaplanır. Sanal çentik için ek bir kural yoktur.

## 4. Sanal çentikte görünürlük

- Ada yalnızca şu üç koşul birlikte sağlanınca gizlenir: sanal çentik, `closed` durumu ve çalan medya olmaması.
- Ada gizliyken de hover alanı, yani kapalı adanın dikdörtgeni çalışır. Fare bu alana gelince ada `hoverDelay` kadar sonra açılır.
- Görünürlük opaklıkla değişir ve mevcut yay animasyonuyla (0,38 sn) yumuşak geçer.
- Fiziksel çentikli ekranda görünürlük davranışı değişmez.
- Bilinen ödün: Ada gizliyken de bu alan fareyi yakalar, bu yüzden oraya yapılan tıklama menü çubuğuna gitmez.

## 5. Modüllerin çalışma koşulu

- `ModuleStatus.hasNotch` yerine `hasScreen` gelir. En az bir ekran varsa `true` olur.
- Modüller, ayarlarda açıksa ve `hasScreen` `true` ise çalışır. Böylece kapak kapalıyken yalnız harici ekranla da, çentiği olmayan Mac'lerde de çalışırlar.
- Panel denetleyicisi ekranın var olup olmadığını ilk kurulumda bir kez bildirir. Sonra yalnızca bu durum değişince bildirir; ekranlar arası her taşınmada bildirmez.
- "Çentikli ekran bulunamadı" menü öğesi ve ayarlardaki uyarı kaldırılır.
- Hiç ekran yoksa (çok nadir) modüller durur ve ses tuşları sistem göstergesine kalır. v1'in davranışı böylece korunur.

## 6. Değişecek dosyalar

- `Notchy/Notch/NotchGeometry.swift`: `NotchPlacement`, `placement(...)`, `screenIndex(containing:in:)`.
- `Notchy/Notch/NotchLayout.swift`: `isHidden(state:isMediaPlaying:isVirtualNotch:)`.
- `Notchy/Notch/NotchPanelController.swift`: farenin ekranını izler, paneli taşır ve `onScreenAvailabilityChange` bildirimini gönderir.
- `Notchy/Notch/NotchView.swift`: `isVirtualNotch` parametresi ve gizleme.
- `hasNotch` yerine `hasScreen` gelir ve uyarılar kaldırılır:
  - `Notchy/App/AppCoordinator.swift` (`ModuleLifecycle`)
  - `Notchy/Settings/ModuleStatus.swift`
  - `Notchy/App/MenuBarController.swift`
  - `Notchy/Settings/SettingsView.swift`
- Testler: `NotchyTests/NotchGeometryTests.swift`, `NotchyTests/AppCoordinatorTests.swift`.
- Belgeler:
  - v1 tasarımında: §1'deki kısıt, kapsam dışı listesi ve §3'teki "Çentikli ekran yoksa…" maddesi.
  - `README.md`: özellikler ve gereksinimler.

## 7. Test ve doğrulama

- Birim testleri şunları kapsar:
  - yerleşim: fiziksel çentik, sanal çentik, menü çubuğu olmayan ekran
  - ekran seçimi: iki ekran, üst kenar, ekran dışı
  - gizlenme kuralı
  - modüllerin çalışma koşulu (`hasScreen`)
- Tam test paketi çalıştırılır.
- Elle kontrol (kullanıcı):
  - fareyi iki ekran arasında gezdirmek
  - harici ekranda ada boştayken görünmüyor mu, müzik çalarken ekolayzır görünüyor mu
  - harici ekranda ses tuşu, ayrıca üst ortaya gelince adanın açılması
  - ada açıkken fareyi diğer ekrana götürmek
  - kapak kapalıyken kullanmak

## 8. Kapsam dışı

- İki ekranda aynı anda ada.
- Harici ekran desteğini açıp kapatan bir ayar. Gerekirse sonra eklenir.
- Sanal çentik boyutunun ayarlanabilmesi.
