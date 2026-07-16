-- =========================================================================
-- GLOWMATCH DATABASE SCHEMA FOR SUPABASE
-- Skema Database PostgreSQL untuk Katalog Kosmetik Hybrid & Auto-Calibration
-- =========================================================================

-- 1. TABEL: BRANDS
-- Menyimpan nama-nama brand kosmetik komersial.
CREATE TABLE IF NOT EXISTS brands (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read-only access on brands" ON brands FOR SELECT USING (true);


-- 2. TABEL: PRODUCTS
-- Menyimpan produk kosmetik beserta kategorinya.
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    brand_id INT REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL, -- 'Foundation', 'Concealer', 'Lipstick', dll.
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE (brand_id, name)
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read-only access on products" ON products FOR SELECT USING (true);


-- 3. TABEL: PRODUCT_SHADES
-- Menyimpan detail warna shade masing-masing produk (HEX Code, L*a*b* baseline,
-- dan offset kalibrasi dinamis).
CREATE TABLE IF NOT EXISTS product_shades (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(100) NOT NULL,
    hex_code VARCHAR(7) NOT NULL, -- Format HEX: '#E5C185'
    lab_l NUMERIC(5,2) NOT NULL,   -- Nilai CIE L* (Kecerahan)
    lab_a NUMERIC(5,2) NOT NULL,   -- Nilai CIE a* (Merah/Hijau)
    lab_b NUMERIC(5,2) NOT NULL,   -- Nilai CIE b* (Kuning/Biru)
    delta_l_offset NUMERIC(5,2) DEFAULT 0.00 NOT NULL, -- Kalibrasi offset komunitas
    affiliate_url TEXT, -- Link afiliasi belanja
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE (product_id, name)
);

ALTER TABLE product_shades ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read-only access on product_shades" ON product_shades FOR SELECT USING (true);


-- 4. TABEL: COMMUNITY_REVIEWS
-- Menyimpan ulasan kesesuaian shade asli dari para pengguna di lapangan.
CREATE TABLE IF NOT EXISTS community_reviews (
    id BIGSERIAL PRIMARY KEY,
    shade_id INT REFERENCES product_shades(id) ON DELETE CASCADE NOT NULL,
    user_id UUID, -- Terhubung ke auth.users Supabase jika login, null jika tamu
    feedback_score INT NOT NULL, -- 0: Pas (Perfect), -1: Terlalu Gelap, 1: Terlalu Terang
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE community_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read-only access on community_reviews" ON community_reviews FOR SELECT USING (true);
CREATE POLICY "Allow authenticated/public insert on community_reviews" ON community_reviews FOR INSERT WITH CHECK (true);


-- 5. FUNCTION TRIGGER: AUTO-CALIBRATION
-- Otomatis menghitung rata-rata feedback score komunitas dan memperbarui delta_l_offset
-- pada tabel product_shades untuk mengoreksi margin error deteksi warna.
CREATE OR REPLACE FUNCTION calculate_shade_delta_l_offset()
RETURNS TRIGGER AS $$
DECLARE
    avg_feedback NUMERIC;
    calculated_offset NUMERIC;
BEGIN
    -- Hitung rata-rata skor feedback untuk shade bersangkutan
    SELECT AVG(feedback_score) INTO avg_feedback
    FROM community_reviews
    WHERE shade_id = NEW.shade_id;

    -- Aturan Kalibrasi:
    -- Jika rata-rata masukan cenderung negatif (terlalu gelap),
    -- maka delta_l_offset digeser positif agar pencarian warna berikutnya
    -- menyarankan warna yang sedikit lebih terang (+).
    -- Kita gunakan faktor reduksi 0.8 sebagai peredam lonjakan ekstrim.
    calculated_offset := (avg_feedback * -0.80);

    -- Update offset di tabel product_shades secara otomatis
    UPDATE product_shades
    SET delta_l_offset = ROUND(calculated_offset, 2)
    WHERE id = NEW.shade_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 6. REGISTRASI TRIGGER PADA TABEL COMMUNITY_REVIEWS
-- Menjalankan kalkulator kalibrasi di atas setiap kali ada ulasan masuk/berubah.
DROP TRIGGER IF EXISTS trigger_update_shade_calibration ON community_reviews;
CREATE TRIGGER trigger_update_shade_calibration
AFTER INSERT OR UPDATE OR DELETE ON community_reviews
FOR EACH ROW
EXECUTE FUNCTION calculate_shade_delta_l_offset();
