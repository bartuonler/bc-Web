-- ═══════════════════════════════════════════════════════════════
-- BC-WEB FIVEM SCRIPT - SQL KURULUM (25.02.2026 - GÜNCELLENMİŞ)
-- ═══════════════════════════════════════════════════════════════
-- Bu SQL dosyasını FiveM karakter veritabanınızda (örn: bc-qbx) çalıştırın.
-- Web panel (bc-webpanel) için ayrı veritabanı kullanıyorsanız, bu dosya
-- SADECE FiveM tarafındaki karakter veritabanına uygulanmalıdır.
--
-- İçerik:
-- 1) site_settings  : Script <-> Web panel API key saklama
-- 2) bc_playtime    : metadata.playtime senkronizasyonu için playtime cache tablosu
-- 3) blips          : Panelde kullanılan harita işaretçileri
-- 4) players        : bc-Web ve panelin kullandığı ek sütunlar + indeksler
-- ═══════════════════════════════════════════════════════════════

USE `bc-qbx`;

-- ═══════════════════════════════════════════════════════════════
-- 1. SITE AYARLARI TABLOSU (Web API Key için)
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `site_settings` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `setting_key` VARCHAR(100) UNIQUE NOT NULL,
  `setting_value` TEXT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════
-- 2. BC_PLAYTIME (bc-Web playtime senkronizasyonu)
-- ═══════════════════════════════════════════════════════════════
-- server.lua'daki "PLAYTIME TRACKING SYSTEM (bc_playtime)" bloğu bu tabloyu kullanır.
-- metadata.playtime değerlerini buraya yazar ve panel bu tablodan okuyabilir.
CREATE TABLE IF NOT EXISTS `bc_playtime` (
  `cid` VARCHAR(50) PRIMARY KEY,
  `time` INT UNSIGNED DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════
-- 3. BLIPS (Harita İşaretçileri - Paneldeki Blip Listesi/Canlı Harita için)
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `blips` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `type` INT NOT NULL,
  `scale` FLOAT DEFAULT 1.0,
  `color` INT DEFAULT 0,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT DEFAULT 0.0,
  `created_by` VARCHAR(100),
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- İndeksler (performans için)
ALTER TABLE `blips` ADD INDEX IF NOT EXISTS `idx_name` (`name`);
ALTER TABLE `blips` ADD INDEX IF NOT EXISTS `idx_type` (`type`);

-- ═══════════════════════════════════════════════════════════════
-- 4. PLAYERS TABLOSU - EK SÜTUNLAR + İNDEKSLER
-- ═══════════════════════════════════════════════════════════════
-- BC-Web ve yeni Next.js paneli players tablosunda şu alanları bekler:
--  - last_updated : Son aktivite tarihi (timestamp)
--  - discordid    : Discord ID eşlemesi
--  - jailtime     : Kamu hapis süresi
--  - communityservice : Kamu hizmeti süresi
-- Bu alanlar yoksa eklenir ve gerekli indeksler oluşturulur.

-- last_updated sütunu (yoksa ekle)
ALTER TABLE `players` 
  ADD COLUMN IF NOT EXISTS `last_updated` TIMESTAMP NOT NULL 
    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- discordid / jailtime / communityservice sütunları (yoksa ekle)
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `discordid` VARCHAR(50) NULL DEFAULT NULL AFTER `license`;
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `jailtime` INT DEFAULT 0;
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `communityservice` INT DEFAULT 0;

-- İndeksler (yoksa ekle)
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_last_updated` (`last_updated`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_discordid` (`discordid`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_license` (`license`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_citizenid` (`citizenid`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_jailtime` (`jailtime`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_communityservice` (`communityservice`);

-- ═══════════════════════════════════════════════════════════════
-- KURULUM / GÜNCELLEME NOTLARI
-- ═══════════════════════════════════════════════════════════════
-- 1) Bu dosya, eski 8.12.2025 sürümünün yerini alır ve
--    bc-Web scriptinin 25.02.2026 itibarıyla ihtiyaç duyduğu tüm
--    tabloları ve sütunları içerir.
-- 2) Eğer MySQL sürümünüz ALTER TABLE ... IF NOT EXISTS desteklemiyorsa,
--    ilgili satırlarda "Duplicate column" / "Duplicate key" hatası alırsanız
--    bunlar göz ardı edilebilir (kolon/indeks zaten var demektir).
-- 3) Uygulama: phpMyAdmin'de bc-qbx veritabanını seçip bu dosyayı çalıştırın
--    veya mysql konsolundan:
--       mysql -u root -p bc-qbx < BC_WEB_SCRIPT_SQL_25.02.2026.sql
-- ═══════════════════════════════════════════════════════════════
