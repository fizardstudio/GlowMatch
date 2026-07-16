# GlowMatch Feature Implementation Checklist (Cetak Biru v2.2)

Daftar ceklist ini mencatat seluruh modul dan fitur aplikasi GlowMatch untuk mempermudah pelacakan status implementasi saat ingin melanjutkan pengembangan di kemudian hari.

---

## 1. Fitur Bebas (FREE TIER)

| Status | Fitur | Detail Fungsionalitas | Lokasi Kode / File Utama |
| :---: | :--- | :--- | :--- |
| **[x]** | **Basic Undertone Scanner** | Memindai wajah secara real-time lewat kamera depan untuk mendeteksi kecerahan kulit dasar dan undertone (*Warm/Cool/Neutral*). | `lib/features/scanner/presentation/` |
| **[x]** | **Color Wheel Reference** | Panduan interaktif teknik *color correcting* secara dinamis dan luring. | `lib/features/scanner/presentation/` |
| **[x]** | **Standard Shade Catalog** | Katalog shade warna standar kosmetik global luring. | `lib/core/data/models/standard_shade.dart` |
| **[x]** | **Cross-Brand Shade Converter** | Pencarian padanan kosmetik lintas merek komersial dengan kalkulasi jarak warna CIELAB Delta E76 luring. | `lib/features/catalog/presentation/pages/shade_converter_page.dart` |
| **[x]** | **Community Validation Loop** | Fitur voting kecocokan komunitas (*Perfect / Too Dark / Too Light*) yang langsung disimpan luring ke database Isar. | `lib/features/scanner/presentation/pages/results_page.dart` |
| **[x]** | **Community Offset Delta L** | Kalibrasi otomatis kecerahan formula Delta E menggunakan rata-rata ulasan komunitas agar rekomendasi semakin cerdas. | `lib/features/catalog/data/repositories/shade_matcher_repository_impl.dart` |
| **[x]** | **Virtual Makeup Pouch** | Pencatatan tanggal buka kosmetik luring, masa kadaluwarsa PAO, notifikasi lokal, dan progress bar gradien. | `lib/features/pouch/presentation/pages/makeup_pouch_page.dart` |
| **[x]** | **Gallery Scanner Upload** | Mengunggah foto selfie dari galeri HP untuk dianalisis warna kulit & undertone secara luring tanpa menggunakan kamera live. | `lib/features/scanner/presentation/pages/scanner_page.dart` |
| **[x]** | **Filter Preferensi Riasan** *(Subjektif)* | Filter khusus pada hasil pemindaian untuk memilih hasil rekomendasi yang murni *Natural*, *Brightening (Tone-Up)*, atau *Sun-Kissed (Tanned)*. | `lib/features/scanner/presentation/pages/results_page.dart` |

---

## 2. Fitur Premium (PREMIUM TIER)

| Status | Fitur | Detail Fungsionalitas | Lokasi Kode / File Utama |
| :---: | :--- | :--- | :--- |
| **[x]** | **Advanced Color Mixing** | Simulator pencampuran 2-3 kosmetik cair dengan rasio dinamis di ruang warna linear (HEX Code real-time). | `lib/features/color_mixer/` |
| **[x]** | **Brand Matcher & Affiliate** | Pencocokan Delta E otomatis ke database produk komersial nyata lengkap dengan tombol affiliate Tokopedia/Shopee. | `lib/features/scanner/presentation/pages/results_page.dart` |
| **[x]** | **Split-Screen AR Try-On** | Kamera depan AR Try-On split-screen dengan divider geser dinamis. | `lib/features/premium_subscription/presentation/pages/ar_try_on_page.dart` |
| **[x]** | **Matte & Glossy Overlay** | Riasan bibir presisi 3D Face Mesh dengan finishing Matte dan Glossy (Specular preservation). | `lib/features/premium_subscription/presentation/widgets/lip_filter_painter.dart` |
| **[x]** | **Blush-on Outward Shift** | Rona pipi bergradasi lembut yang terkalibrasi dinamis bergeser keluar 22% ke tulang pipi berdasarkan lebar mata. | `lib/features/premium_subscription/presentation/widgets/lip_filter_painter.dart` |
| **[x]** | **Paywall & Offline Access** | Validasi status langganan premium melalui database Isar dan timer gratis demo 1 menit. | `lib/features/premium_subscription/data/models/app_settings.dart` |
| **[x]** | **2D Photo Makeup Try-On** | Uji coba riasan wajah lengkap (dasaran/foundation, lipstik, & blush-on) secara interaktif langsung pada foto statis hasil unggahan menggunakan pemetaan titik Face Mesh. | `lib/features/premium_subscription/presentation/pages/photo_try_on_page.dart` |
| **[x]** | **Seasonal Color Palette & Hijab** | Klasifikasi tipe warna wajah ke dalam 12 Musim Warna (*Value, Chroma, Hue*) serta rekomendasi warna Hijab yang cocok. | `lib/features/scanner/presentation/pages/results_page.dart` & `lib/core/utils/color_calculator.dart` |
| **[x]** | **AI Makeup Detector from Photo** | Deteksi otomatis warna riasan (lipstik, blush-on, foundation) dari foto unggahan galeri/kamera, lalu mencocokkannya ke shade produk komersial di database. | `lib/features/premium_subscription/presentation/pages/makeup_detector_page.dart` |
| **[x]** | **Riasan Mata AR (Eyeshadow & Eyeliner)** | Riasan kelopak mata (gradien linear lokal, anti-bleed eyeball clip) dan garis eyeliner presisi (custom filled polygon & tapering ketebalan dinamis) menggunakan kontur mata ML Kit (`leftEye` & `rightEye`). | `lib/features/premium_subscription/presentation/widgets/` |
| **[x]** | **One-Tap Makeup Looks (Presets)** | Fitur menerapkan langsung kombinasi lipstik, blush-on, eyeliner, eyeshadow, dan foundation kurasi profesional dalam sekali ketuk (misal: "Clean Girl", "Korean Glass Skin", "Douyin Sweetheart", "Old Money Glam"). | `lib/features/premium_subscription/presentation/pages/ar_try_on_page.dart` |
| **[x]** | **Pencari Kecocokan Shade Otomatis** | Auto-highlighting warna kosmetik yang serasi di katalog/kamera berdasarkan hasil scan warna kulit & undertone di Isar DB. | `lib/features/scanner/presentation/pages/results_page.dart` |
| **[x]** | **Tekstur Bedak Realistis (Satin/Matte/Dewy)**| Efek dasaran wajah dengan kilau specular 3D dinamis pada dahi, dagu, dan tulang hidung. | `lib/features/premium_subscription/presentation/widgets/` |

---

## 3. Infrastruktur & Stabilitas Sistem (Core)

| Status | Modul | Deskripsi Kestabilan | Lokasi Kode / File Utama |
| :---: | :--- | :--- | :--- |
| **[x]** | **Rasio Kamera Bebas Distorsi** | Layout pratinjau kamera menggunakan BoxFit.cover aspek rasio sensor asli agar wajah tidak lonjong/gepeng di semua tipe HP. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **PopScope Safe Teardown** | Pencegahan crash native FlutterJNI dengan menutup/menghentikan stream kamera secara asinkron sebelum navigasi back. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **Safe Exit Root Route** | Navigasi keluar aplikasi otomatis menggunakan `SystemNavigator.pop()` jika tombol kembali ditekan di halaman paling awal. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **Double Buffer / Blink Block** | Penyetelan bendera status `_isCameraDisposed` instan agar tidak terjadi kedipan merah (*deactivated widget error*) saat keluar. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **Lag-Free AR Tracking** | Pengurangan latensi deteksi wajah dengan mengalihkan ML Kit ke mode Fast dan mengoptimalkan konversi YUV di memori native (WriteBuffer) sehingga filter kosmetik menempel selaras dengan pergerakan kepala. | `ar_try_on_page.dart` & `scanner_bloc.dart` |
| **[x]** | **Dynamic ML Kit Frame Throttling** | Pembatasan deteksi ML Kit ke 15 FPS ditambah interpolasi kanvas 60 FPS menggunakan Ticker untuk menghemat baterai HP hingga 40% dan mencegah panas. | `lib/features/premium_subscription/presentation/pages/ar_try_on_page.dart` |

---

## 4. Persiapan Rilis Google Play Store & Rencana Masa Depan

| Status | Item Persiapan Rilis | Detail Fungsionalitas / Tugas | Estimasi Modul Layer |
| :---: | :--- | :--- | :--- |
| **[ ]** | **Integrasi Pembayaran Resmi (IAP)** | Integrasi dengan SDK Google Play Billing (menggunakan RevenueCat atau package `in_app_purchase`) untuk pemrosesan langganan Premium. | `lib/features/premium_subscription/` |
| **[ ]** | **Kebijakan Privasi Data Wajah (Offline Disclosures)** | Menyediakan dokumen Privacy Policy publik yang menegaskan pemrosesan wajah 100% lokal offline (on-device) tanpa pengiriman data ke server luar. | Syarat Wajib Google Console |
| **[ ]** | **Fitur Cadangan Data (Backup & Restore)** | Fitur ekspor/impor data pouch kosmetik lokal ke Google Drive pengguna dalam format JSON agar data aman saat ganti ponsel. | `lib/features/pouch/` |
| **[ ]** | **Onboarding Screen & Panduan Pengguna** | Slide pengenalan aplikasi saat dibuka pertama kali yang memandu cara scan wajah dengan cahaya optimal dan cara mengelola pouch. | `lib/features/scanner/` |
| **[x]** | **Social Sharing (Growth Hacking)** | Tombol membagikan hasil foto makeup AR/2D Try-on langsung ke Instagram/TikTok dengan watermark promosi GlowMatch. | `lib/features/premium_subscription/` |
| **[x]** | **Notifikasi Expiry Pouch Otomatis** | Sistem background task scheduler untuk notifikasi lokal saat produk pouch kosmetik mendekati kadaluwarsa (PAO). | `lib/features/pouch/` |
| **[x]** | **Rekomendasi Lipstik & Blush Offline** | Menyimpan palet kecocokan lipstik/blush secara offline berdasarkan kontras wajah dan undertone luring. | `lib/features/premium_subscription/` |
| **[x]** | **Kamus Kandungan Skincare Offline (dengan OCR Scanner Kamera)** | Kamus luring kandungan skincare aktif (misal: BHA, Retinol) dengan pemindai teks OCR kamera untuk mendeteksi kecocokan tipe kulit secara offline. | `lib/features/scanner/` |
| **[ ]** | **Panduan Kontur Wajah Interaktif (Live AR Guide Overlay)** | Garis pandu shading kontur wajah interaktif secara real-time pada kamera AR berdasarkan deteksi tipe bentuk wajah (Round/Square/Oval). | `lib/features/premium_subscription/` |
| **[ ]** | **Supabase Hybrid Sync & Auto-Calibration**| Sistem sinkronisasi ulasan komunitas luring ke daring untuk kalibrasi dinamis nilai Delta L kosmetik global (Supabase Integration). | Arsitektur Supabase & Isar |
