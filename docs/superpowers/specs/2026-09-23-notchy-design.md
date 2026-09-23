# Notchy — Tasarım Dokümanı (v1)

**Tarih:** 2026-09-23
**Durum:** Onaylandı (brainstorming), uygulama planı bekleniyor

## 1. Amaç

Notchy, [Alcove](https://tryalcove.com/) benzeri bir macOS uygulamasıdır: MacBook çentiğini (notch) iPhone'daki Dynamic Island gibi etkileşimli bir alana dönüştürür. v1; ses/parlaklık HUD'u, pil/şarj bildirimi, AirPods/Bluetooth bildirimi ve medya kontrolünü kapsar.

### Kısıtlar

- Yalnızca macOS, minimum **macOS 14 Sonoma**.
- Yalnızca **yerleşik çentikli ekranda** çalışır. Çentikli ekran yoksa ada gösterilmez.
- Mac App Store dışı dağıtım (event tap ve gizli framework kullanımı nedeniyle sandbox'sız).
- **Hafiflik kuralı:** Zamanlayıcıyla sorgulama (polling) yok; tüm modüller sistem bildirimleriyle olay tabanlı çalışır. Hedef: boşta ~%0 CPU, < 80 MB RAM.

### Kapsam dışı (v1)

Albüm kapağı, takvim, dosya rafı, kilit ekranı widget'ları, bildirim yansıtma, harici monitör desteği, otomatik güncelleme (Sparkle), imzalı/notarize dağıtım.

## 2. Mimari

**Teknoloji:** Swift 6.4 derleyicisi (Swift 5 dil modu — IOKit/CoreAudio/CGEventTap C geri çağrılarını sade tutmak için; tüm uygulama tipleri `@MainActor`), SwiftUI (arayüz) + AppKit (pencere, sistem entegrasyonu). Proje **XcodeGen** (`project.yml`) ile üretilir. Uygulama `LSUIElement = YES` (Dock simgesi yok); menü çubuğu simgesi + ayarlar penceresi vardır.

### Dizin yapısı

```
Notchy/
├─ App/            NotchyApp, AppDelegate, MenuBarController
├─ Notch/          NotchPanel (NSPanel), NotchGeometry, NotchViewModel (durum makinesi),
│                  NotchView (SwiftUI kabuk), NotchShape
├─ Activities/     Activity protokolü, ActivityPriority, ActivityQueue
├─ Modules/
│  ├─ Media/       MediaSource protokolü, MediaRemoteAdapterSource, MediaState, MediaViews
│  ├─ HUD/         MediaKeyTap (CGEventTap), VolumeController (CoreAudio),
│  │               BrightnessController (DisplayServices), HUDView
│  ├─ Battery/     BatteryMonitor (IOKit), BatteryView
│  └─ Bluetooth/   BluetoothMonitor (IOBluetooth), DeviceKind, DeviceView
├─ Settings/       SettingsStore (UserDefaults), SettingsView, OnboardingView
└─ Resources/      mediaremote-adapter (perl script + framework), Assets
NotchyTests/       Birim testleri
```

### Veri akışı

Her modül bir **monitör** içerir; sistemi dinler ve olay üretir. Olay oluştuğunda modül, merkezî `NotchViewModel`'e öncelikli bir `Activity` gönderir. ViewModel hangi içeriğin gösterileceğine ve adanın boyutuna karar verir. Modüller birbirini tanımaz; yalnızca `Activity` protokolü üzerinden konuşur. Her sistem kaynağı bir protokolün arkasındadır (ör. `MediaSource`, `PowerSource`, `BluetoothSource`), böylece testlerde sahte kaynak kullanılabilir.

## 3. Çentik penceresi ve durum makinesi

### Pencere

- Kenarlıksız, şeffaf `NSPanel`; `nonactivatingPanel` (odak çalmaz), seviye menü çubuğunun üstünde, `collectionBehavior`: `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`.
- Konum/boyut: `NSScreen.safeAreaInsets.top` (çentik yüksekliği) ve `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (çentik genişliği) ile hesaplanır.
- Çentikli ekran yoksa panel oluşturulmaz; menü çubuğu menüsünde "Çentikli ekran bulunamadı" gösterilir.
- `NSApplication.didChangeScreenParametersNotification` ile ekran değişince yeniden hesaplanır.
- Panel, genişlemiş boyuttan biraz büyüktür. Adanın dışındaki şeffaf alan tıklamaları geçirir (hit-test yalnızca ada şekli içinde).

### Durumlar

```
 closed ──(Activity geldi)──▶ peek ──(süre doldu)──▶ closed
   │                           │
   └──(fare üstüne geldi)──▶ expanded ◀──(fare üstüne geldi)
                               │
                               └──(fare ayrıldı + ~0.3 sn)──▶ closed
```

- **closed:** Çentikle aynı boyutta siyah şekil. Medya çalıyorsa ada hafifçe genişler, sağda küçük ekolayzır animasyonu görünür.
- **peek:** Kısa süreli bildirim (HUD, şarj, AirPods). Ada yana doğru uzar; varsayılan süre HUD için 1.5 sn, diğerleri için 3 sn (ayarlanabilir).
- **expanded:** Hover ile açılır (gecikme ayarlanabilir, varsayılan 0.1 sn). Medya bilgisi ve kontroller burada.

### Öncelik ve kurallar

- Öncelik: **HUD > Bluetooth > Pil > Medya**.
- Yeni peek, mevcut peek'in yerine geçer (eşit veya yüksek öncelikteyse); düşük öncelikli peek, mevcut peek bitince gösterilir, en fazla 1 bekleyen tutulur.
- `expanded` durumu peek'ler tarafından bölünmez; bu sırada gelen peek'ler atılır (HUD hariç — HUD değeri expanded görünümde küçük bir satır olarak güncellenir).
- Aynı türden art arda HUD olayları (ses tuşuna basılı tutma) yeni peek açmaz, mevcut peek'in değerini günceller ve süresini sıfırlar.

### Animasyon

Tüm geçişler SwiftUI `spring` animasyonuyla. `NotchShape`, alt köşeleri yuvarlak ve üst köşeleri içe kıvrık özel bir `Shape`'tir; genişlik/yükseklik animasyonlu değişir.

## 4. Modüller

### 4.1 Ses ve parlaklık HUD'u

- `MediaKeyTap`: `CGEventTap` ile `NX_SYSDEFINED` olaylarından ses artır/azalt/sessiz ve parlaklık artır/azalt tuşlarını yakalar ve yutar. **Erişilebilirlik izni** gerekir.
- `VolumeController`: CoreAudio varsayılan çıkış cihazının `VirtualMainVolume` ve `Mute` özellikleri. Adım 1/16; ⌥⇧ ile 1/64.
- `BrightnessController`: `DisplayServices.framework` (`DisplayServicesGetBrightness` / `DisplayServicesSetBrightness`) `dlopen` ile çalışma anında yüklenir. Adım 1/16; ⌥⇧ ile 1/64.
- CoreAudio özellik dinleyicisiyle dış kaynaklı ses değişiklikleri (Kontrol Merkezi vb.) de HUD olarak gösterilir.
- **İzin yoksa:** Tuşlar yakalanmaz, sistem HUD'u çalışır; Notchy yalnızca CoreAudio değişikliklerini gözlemleyip gösterir.
- **DisplayServices yüklenemezse:** Parlaklık tuşları yakalanmaz (sisteme bırakılır).

### 4.2 Pil ve şarj

- `IOPSNotificationCreateRunLoopSource` ile güç kaynağı değişiklikleri; `IOPSCopyPowerSourcesInfo` ile yüzde ve şarj durumu.
- Peek olayları: güç kablosu takıldı / çıkarıldı (yüzde + ikon), düşük pil %20 ve %10 (her eşik, şarj takılana kadar bir kez).
- Dahili pil yoksa modül devre dışıdır.

### 4.3 AirPods ve Bluetooth

- `IOBluetoothDevice.register(forConnectNotifications:selector:)` ve cihaz başına `register(forDisconnectNotification:)`.
- Yalnızca ses cihazları (Class of Device: audio/headphones) için peek; fare/klavye yok sayılır.
- Peek içeriği: cihaz adı, ikon (AirPods / AirPods Pro / AirPods Max / genel kulaklık — cihaz adı ve Bluetooth cihaz sınıfından), pil.
- Pil: `IOBluetoothDevice` üzerindeki gizli `batteryPercentLeft`, `batteryPercentRight`, `batteryPercentCase`, `batteryPercentSingle` özellikleri `responds(to:)` kontrolüyle okunur. Okunamazsa yalnızca "Bağlandı".
- Ayrılma olayında kısa "Bağlantı kesildi" peek'i.

### 4.4 Medya

- `mediaremote-adapter` (BSD-3, [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)) uygulama paketine gömülür.
- `MediaRemoteAdapterSource`: `/usr/bin/perl <script> <framework> stream` sürecini `Process` ile başlatır, stdout'tan satır satır JSON okur → `MediaState { title, artist, isPlaying, bundleID }`.
- Komutlar (play/pause, next, previous) adaptörün `send` komutuyla gönderilir.
- **closed:** Çalarken ekolayzır göstergesi.
- **expanded:** Şarkı adı, sanatçı, önceki / oynat-duraklat / sonraki düğmeleri. Trackpad'de iki parmakla yatay kaydırma (`scrollWheel`, eşik aşılınca bir kez tetiklenir) → önceki/sonraki.
- Albüm kapağı v1'de yoktur.
- **Hata:** Süreç çökerse 1 / 2 / 4 sn beklemeyle en fazla 3 yeniden başlatma; sonra modül gizlenir, ayarlarda "Medya bilgisi alınamıyor" gösterilir. Ayrıştırılamayan JSON satırı loglanıp atlanır.

## 5. Ayarlar, izinler ve ilk açılış

- **Menü çubuğu menüsü:** Ayarlar…, Hakkında, Çıkış (+ gerekirse "Çentikli ekran bulunamadı").
- **Ayarlar (SwiftUI, `UserDefaults` üzerinden `SettingsStore`):**
  - Modül aç/kapa: Medya, HUD, Pil, Bluetooth
  - Girişte başlat (`SMAppService.mainApp`)
  - Hover genişleme gecikmesi, peek süresi
  - İzin durumu: Erişilebilirlik verildi mi; değilse "İzin ver" düğmesi (`AXIsProcessTrustedWithOptions` + Sistem Ayarları bağlantısı)
- **İlk açılış:** Karşılama penceresi Erişilebilirlik izninin nedenini tek cümleyle açıklar; izin vermeden devam edilebilir.

## 6. Hata yönetimi

- Modüller birbirinden yalıtılmıştır; bir modülün başlatma hatası yalnızca o modülü devre dışı bırakır.
- Gizli API'ler (DisplayServices, AirPods pil özellikleri, MediaRemote adaptörü) çalışma anında yüklenir/kontrol edilir; yoksa ilgili özellik gizlenir, uygulama çökmez.
- Loglama: `os.Logger`, alt sistem `com.notchy`, kategori = modül adı.

## 7. Test

- **Birim testleri (XCTest):**
  - `NotchViewModel` durum geçişleri, öncelik ve peek değiştirme/bekletme kuralları
  - `NotchGeometry` hesapları (sahte ekran ölçüleriyle)
  - Adaptör JSON satırı ayrıştırma (geçerli, eksik alanlı, bozuk satır)
  - Pil eşik mantığı (%20/%10 yalnızca bir kez, şarjda sıfırlanma)
  - HUD adım hesabı (normal / ince adım, 0–1 sınırları)
- **Elle doğrulama listesi:** Şarj tak/çıkar, AirPods bağla/ayır, ses ve parlaklık tuşları (izinli ve izinsiz), Spotify / Apple Music / tarayıcıda YouTube, kaydırma hareketi, tam ekran uygulamada görünürlük, ekran değişimi.
- **Performans:** Activity Monitor ile boşta CPU ve RAM ölçümü; hedef boşta ~%0 CPU, < 80 MB RAM.
