# Rencana Kesiapan Rilis (Release Readiness Plan) GlowMatch

Rencana ini merinci langkah-langkah persiapan perilisan GlowMatch ke **Google Play Store** dan **Apple App Store** yang telah diurutkan berdasarkan skala prioritas pengerjaan dari yang paling mendesak (Prioritas 1) hingga tahap akhir (Prioritas 5).

---

## 🚀 Prioritas 1: Kesiapan Pipeline Build & Perbaikan Skema Git (Segera)

Langkah awal untuk memastikan sistem integrasi otomatis (Codemagic CI/CD) dapat berjalan dengan lancar tanpa kegagalan.

### 📋 Daftar Tugas:
*   [ ] **Men-share Skema `ios-production` di Xcode:**
    *   *Deskripsi:* Skema `ios-production.xcscheme` saat ini diabaikan oleh Git karena berada di folder lokal user (`xcuserdata`). Buka proyek iOS di Xcode -> Buka **Product > Scheme > Manage Schemes** -> Centang kolom **Shared** pada skema `ios-production`.
    *   *Hasil:* File skema akan dipindahkan ke folder `ios/Runner.xcodeproj/xcshareddata/xcschemes/` dan dapat di-commit ke repositori Git agar dideteksi oleh Codemagic.
*   [ ] **Pembersihan Log Konsol (`debugPrint`):**
    *   *Deskripsi:* Menghapus atau membungkus log konsol dengan check mode `if (kDebugMode)` di seluruh codebase agar tidak membocorkan data performa atau informasi sensitif pada versi rilis produksi.

---

## 🔑 Prioritas 2: Akun Developer Resmi & Produk In-App Purchase (IAP) (Waktu: 3 - 7 Hari)

Langkah administratif penting yang memerlukan waktu verifikasi resmi dari pihak Apple dan Google.

### 📋 Daftar Tugas:
*   [ ] **Pendaftaran Akun Apple Developer Program ($99/tahun):**
    *   *Deskripsi:* Daftarkan badan usaha atau perorangan ke Apple Developer Portal. Memerlukan verifikasi KTP/Paspor (biasanya selesai dalam 2-4 hari kerja).
*   [ ] **Pendaftaran Akun Google Play Console ($25 sekali bayar):**
    *   *Deskripsi:* Daftarkan akun developer Google Play Console untuk mempublikasikan aplikasi Android.
*   [ ] **Pendaftaran Produk Premium Langganan (IAP):**
    *   *Deskripsi:* Daftarkan produk/subscription premium pada dashboard Google Play Console (In-App Products) dan App Store Connect (In-App Purchases) dengan ID produk yang seragam.
*   [ ] **Integrasi RevenueCat Portal Produksi:**
    *   *Deskripsi:* Buat project produksi di RevenueCat, tautkan kredensial Google Play Developer API dan App Store Connect Shared Secret, lalu perbarui API Key RevenueCat pada file `lib/main_prod.dart`.

---

## ☁️ Prioritas 3: Transisi Arsitektur Cloud & Autentikasi Pengguna (Waktu: 3 - 5 Hari)

Memodifikasi arsitektur data agar siap menampung basis pengguna berskala besar secara dinamis tanpa mengandalkan database luring statis.

### 📋 Daftar Tugas:
*   [ ] **Migrasi Katalog Kosmetik ke Cloud (Firestore/Supabase):**
    *   *Deskripsi:* Pindahkan katalog produk (Wardah, Maybelline, Make Over) dari seeding lokal Isar ke database cloud sehingga admin bisa melakukan *update* shade/merek baru secara real-time tanpa merilis update aplikasi.
*   [ ] **Implementasi Login Pengguna (Google & Apple ID):**
    *   *Deskripsi:* Integrasikan sistem autentikasi (Firebase Auth / Supabase Auth) agar pengguna dapat melakukan pendaftaran akun secara sah.
*   [ ] **Sinkronisasi Virtual Pouch & Riwayat (User Cloud Sync):**
    *   *Deskripsi:* Hubungkan data *Virtual Pouch* kosmetik dan hasil deteksi riasan pengguna ke database cloud masing-masing akun agar data tetap aman saat pengguna berganti HP.
*   [ ] **Penyusunan Struktur Cache (Offline-First):**
    *   *Deskripsi:* Atur database lokal Isar sebagai cache utama luring agar aplikasi tetap responsif tanpa lag, lalu sinkronkan dengan cloud secara latar belakang (*background sync*) saat terkoneksi internet.

---

## 🛡️ Prioritas 4: Sertifikat Tanda Tangan & Uji Coba Rilis (Waktu: 2 - 3 Hari)

Melakukan penandatanganan kode produksi yang sah dan melakukan distribusi uji coba terbatas.

### 📋 Daftar Tugas:
*   [ ] **Pembuatan Keystore Produksi Android (`key.jks`):**
    *   *Deskripsi:* Buat keystore tanda tangan aplikasi rilis Android menggunakan Java keytool dan simpan sandinya dengan aman.
*   [ ] **Konfigurasi Variabel Keystore di Codemagic:**
    *   *Deskripsi:* Unggah berkas `key.jks` ke variabel lingkungan Codemagic agar file `android/app/build.gradle.kts` membacanya secara otomatis saat proses build AAB.
*   [ ] **Sertifikat Distribusi App Store iOS:**
    *   *Deskripsi:* Unduh sertifikat rilis `.p12` dan profil provisi `.mobileprovision` dari portal developer Apple, lalu unggah ke tab *Signing* Codemagic.
*   [ ] **Verifikasi Proteksi Rilis (R8/Proguard):**
    *   *Deskripsi:* Pastikan kelas Isar dan Google ML Kit dikecualikan dari pembersihan kode rilis (*obfuscation*) di file `proguard-rules.pro` untuk mencegah force close di Play Store.
*   [ ] **Uji Coba Rilis Internal:**
    *   *Deskripsi:* Kirim berkas rilis ke Google Play Console (Internal Sharing) dan TestFlight iOS untuk diuji coba oleh tim internal.

---

## 🏷️ Prioritas 5: Listing Toko Aplikasi & Pengajuan Publik (Waktu: 2 Hari)

Tahap akhir pemolesan identitas aplikasi pada halaman toko dan pengiriman aplikasi untuk ditinjau (*review*).

### 📋 Daftar Tugas:
*   [ ] **Persiapan Aset Visual Toko:**
    *   *Deskripsi:* Siapkan screenshot aplikasi untuk berbagai ukuran layar iPhone (6.7" & 5.5") dan tablet/HP Android, ikon aplikasi berkualitas tinggi, serta grafis fitur (*feature graphic*).
*   [ ] **Dokumen Kebijakan Privasi (Privacy Policy):**
    *   *Deskripsi:* Sediakan tautan URL halaman kebijakan privasi yang sah untuk ditampilkan di halaman toko (syarat wajib dari Apple & Google).
*   [ ] **Pengiriman Peninjauan Aplikasi (App Submission):**
    *   *Deskripsi:* Isi deskripsi aplikasi, kategori, kata kunci (*keywords*), lalu unggah berkas akhir `.aab` (Android App Bundle) dan `.ipa` ke Google Play Console & App Store Connect untuk ditinjau oleh tim Apple & Google hingga rilis publik.
