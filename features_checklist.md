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

---

## 3. Infrastruktur & Stabilitas Sistem (Core)

| Status | Modul | Deskripsi Kestabilan | Lokasi Kode / File Utama |
| :---: | :--- | :--- | :--- |
| **[x]** | **Rasio Kamera Bebas Distorsi** | Layout pratinjau kamera menggunakan BoxFit.cover aspek rasio sensor asli agar wajah tidak lonjong/gepeng di semua tipe HP. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **PopScope Safe Teardown** | Pencegahan crash native FlutterJNI dengan menutup/menghentikan stream kamera secara asinkron sebelum navigasi back. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **Safe Exit Root Route** | Navigasi keluar aplikasi otomatis menggunakan `SystemNavigator.pop()` jika tombol kembali ditekan di halaman paling awal. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **Double Buffer / Blink Block** | Penyetelan bendera status `_isCameraDisposed` instan agar tidak terjadi kedipan merah (*deactivated widget error*) saat keluar. | `ar_try_on_page.dart` & `scanner_page.dart` |
| **[x]** | **Lag-Free AR Tracking** | Pengurangan latensi deteksi wajah dengan mengalihkan ML Kit ke mode Fast dan mengoptimalkan konversi YUV di memori native (WriteBuffer) sehingga filter kosmetik menempel selaras dengan pergerakan kepala. | `ar_try_on_page.dart` & `scanner_bloc.dart` |

---

## 4. Rencana Fitur & Optimalisasi Mendatang (Future Roadmap)

| Status | Fitur / Optimalisasi | Rincian Fungsionalitas | Estimasi Modul Layer |
| :---: | :--- | :--- | :--- |
| **[ ]** | **Riasan Mata AR (Eyeshadow & Eyeliner)** | Riasan kelopak mata dan garis eyeliner presisi menggunakan kontur mata ML Kit (`leftEye` & `rightEye`). | `lib/features/premium_subscription/presentation/widgets/` |
| **[ ]** | **One-Tap Makeup Looks (Presets)** | Fitur menerapkan langsung kombinasi lipstik, blush-on, dan foundation kurasi profesional dalam sekali ketuk (misal: "Korean Glass Look", "Office Glam", "Cyber Punk"). | `lib/features/premium_subscription/presentation/pages/ar_try_on_page.dart` |
| **[ ]** | **Dynamic ML Kit Frame Throttling** | Pembatasan deteksi ML Kit ke 15-20 FPS ditambah interpolasi kanvas 60 FPS untuk menghemat baterai HP hingga 40%. | `lib/features/premium_subscription/presentation/pages/ar_try_on_page.dart` |
| **[ ]** | **Pencari Kecocokan Shade Otomatis** | Auto-highlighting warna kosmetik yang serasi di katalog/kamera berdasarkan hasil scan warna kulit & undertone di Isar DB. | `lib/features/scanner/presentation/pages/results_page.dart` |
| **[ ]** | **Tekstur Bedak Realistis (Satin/Matte/Dewy)**| Efek dasaran wajah dengan kilau specular 3D dinamis pada dahi, dagu, dan tulang hidung. | `lib/features/premium_subscription/presentation/widgets/` |
