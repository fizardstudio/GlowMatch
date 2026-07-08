Berikut adalah penjelasan dan logika di balik kelima fitur tambahan GlowMatch:

### 1. Cross-Brand Shade Converter (Fitur FREE)

**Konsep:** Pengguna memasukkan *shade* dari satu merek, dan aplikasi mencari padanannya di merek lain.
**Logika Aplikasi:** Kita tidak mungkin memetakan Merek A ke Merek B secara manual satu per satu karena datanya akan terlalu masif (jutaan kombinasi). Logika yang tepat adalah membuat **"Global Standard Index"** (Nilai Standar Global). Setiap produk di-konversi dulu ke nilai standar ini, baru dicari produk lain dengan nilai standar yang sama.

```dart
// 1. Define standard index based on lightness (0-100) and undertone (Warm/Cool/Neutral)
// 2. Database structure for products: { brand: 'Somethinc', name: 'Nina', lightness: 45, undertone: 'Warm' }

String findMatch(Product userProduct, String targetBrand) {
    // Get the standard values of the user's current product
    int targetLightness = userProduct.lightness;
    String targetUndertone = userProduct.undertone;
    
    // Query the database to find a product in the target brand with matching values
    // Using a tolerance margin (+/- 2) for lightness since exact match is rare
    return db.query(
        "SELECT * FROM products WHERE brand = $targetBrand AND undertone = $targetUndertone AND lightness BETWEEN ${targetLightness - 2} AND ${targetLightness + 2}"
    );
}

```

### 2. Community Validation / Feedback Loop (Fitur FREE)

**Konsep:** Pengguna memberikan *vote* apakah rekomendasi AI tersebut akurat di kulit mereka.
**Logika Aplikasi:**
Kita menggunakan sistem bobot (*Weighted Scoring*). Setiap *shade* rekomendasi memiliki skor dasar. Jika pengguna bilang "Cocok", skor bertambah. Jika bilang "Kegelapan", kita mencatat bahwa produk ini ternyata lebih gelap dari perhitungan matematis aslinya.

```dart
// Function to update the product matching accuracy based on user feedback
void updateUserFeedback(String productId, String feedbackType) {
    // Fetch current product data
    Product product = db.getProduct(productId);
    
    // Adjust the internal logic parameters based on community votes
    if (feedbackType == 'TOO_DARK') {
        // Decrease the lightness index slightly so the AI learns it's actually a darker shade
        product.adjustLightnessIndex(-0.1); 
    } else if (feedbackType == 'TOO_LIGHT') {
        // Increase the lightness index
        product.adjustLightnessIndex(+0.1);
    } else if (feedbackType == 'PERFECT_MATCH') {
        // Increase confidence score for this specific recommendation
        product.increaseConfidenceScore();
    }
    
    // Save updated data to database
    db.save(product);
}

```

### 3. Virtual Makeup Pouch & Expiration Reminder (Fitur FREE)

**Konsep:** Pengguna menyimpan daftar produk yang mereka miliki, dan aplikasi mengingatkan jika sudah kedaluwarsa.
**Logika Aplikasi:**
Kosmetik biasanya menggunakan PAO (*Period After Opening*), misalnya "12M" (12 bulan setelah dibuka). Logikanya adalah membandingkan tanggal saat produk didaftarkan (dibuka) ditambah rentang PAO dengan tanggal hari ini.

```dart
// Check if a cosmetic item is expired based on opened date and PAO (Period After Opening)
bool isProductExpired(DateTime dateOpened, int paoMonths) {
    // Calculate the exact expiration date
    DateTime expirationDate = dateOpened.add(Duration(days: paoMonths * 30));
    
    // Get the current current date
    DateTime currentDate = DateTime.now();
    
    // Return true if current date has passed the expiration date
    return currentDate.isAfter(expirationDate);
}

// Logic to trigger background local notification (e.g., using Flutter Local Notifications)
// if (isProductExpired) -> triggerNotification("Produk foundation kamu sudah kedaluwarsa!");

```

### 4. Seasonal Color Palette & Hijab Options (Fitur PREMIUM)

**Konsep:** Memberikan palet warna spesifik untuk kosmetik dan kain hijab berdasarkan analisis "12 Musim Warna".
**Logika Aplikasi:**
Menggunakan struktur *Decision Tree* (Pohon Keputusan). Setelah kamera mendeteksi *Skin Tone* (Kecerahan) dan *Undertone* (Rona Bawah), logikanya akan mengkategorikan pengguna ke dalam salah satu dari 12 musim (misal: *True Autumn*), lalu menarik data palet warna (kumpulan *Hex Code*) dari *database* yang sudah dirancang oleh *designer* khusus untuk musim tersebut.

```dart
// Enum definition for skin undertones and tones
enum Undertone { cool, warm, neutral }
enum SkinTone { light, medium, dark }

// Function to determine the color season based on analysis
String determineColorSeason(Undertone undertone, SkinTone tone) {
    // Decision tree logic to map physical traits to a season
    if (undertone == Undertone.cool && tone == SkinTone.light) {
        return "True Summer"; // Returns the season profile
    } else if (undertone == Undertone.warm && tone == SkinTone.medium) {
        return "True Autumn";
    }
    // ... other conditions ...
    return "Neutral Spring";
}

// After season is determined, fetch the corresponding JSON array of Hex Codes
// for Hijab colors and Lipstick colors to render on the UI.

```

### 5. Split-Screen AR Try-On (Fitur PREMIUM)

**Konsep:** Layar terbelah dua; sisi kiri wajah asli, sisi kanan wajah dengan filter lipstik/blush on secara *real-time*.
**Logika Aplikasi:**
Ini adalah logika yang paling kompleks karena melibatkan *Computer Vision*. Kita menggunakan *Google ML Kit* untuk mendeteksi koordinat bibir (*Face Mesh*). Kemudian, kita melakukan *rendering* lapisan warna (*Shader*) tepat di atas poligon bibir tersebut dengan rasio *blend mode* tertentu (misalnya *Multiply* agar tekstur garis bibir asli tetap terlihat).

Untuk *split-screen*, kita menggunakan komponen UI (*Widget* di Flutter) yang bernama `ClipRect` untuk memotong tampilan AR hanya di setengah layar berdasarkan posisi jari pengguna (Slider).

```dart
// Pseudo-logic for AR rendering and Split Screen interaction

void renderARView(CameraImage frame, double sliderPosition) {
    // 1. Detect facial landmarks (lips) from the camera frame using ML Kit
    List<Point> lipCoordinates = mlKit.detectLips(frame);
    
    // 2. Generate the color overlay (shader) on the lip coordinates
    Shader lipstickLayer = createColorOverlay(lipCoordinates, targetHexColor, blendMode: 'multiply');
    
    // 3. Render logic for the split screen UI
    // If the pixel's X-axis is to the right of the slider, render the AR layer
    // Otherwise, render the raw camera feed
    if (pixel.x > sliderPosition) {
        draw(lipstickLayer);
    } else {
        draw(rawCameraFrame);
    }
}

```