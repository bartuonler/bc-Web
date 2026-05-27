-- ═══════════════════════════════════════════════════════════════
-- BC-WEB FIVEM SCRIPT - SQL KURULUM (8.12.2025 - Güncellenmiş)
-- ═══════════════════════════════════════════════════════════════
-- Bu SQL dosyasını bc-qbx veritabanında çalıştırın.
-- Web panel (htdocs) için bc-web, FiveM script için bc-qbx kullanılır.
-- site_settings: Web API Key için (bc-qbx veya bc-web'de olabilir - config'e göre)
-- bc_playtime: server.lua playtime senkronizasyonu için
-- blips, players kolonları: Panel özellikleri için
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
-- 2. BC_PLAYTIME (server.lua - playtime senkronizasyonu)
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `bc_playtime` (
  `cid` VARCHAR(50) PRIMARY KEY,
  `time` INT UNSIGNED DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════
-- 3. BLIPS (Harita İşaretçileri - BC_PANEL_SCRIPT_SETUP)
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

-- ═══════════════════════════════════════════════════════════════
-- 4. PLAYERS TABLOSU - EK KOLONLAR
-- ═══════════════════════════════════════════════════════════════
-- discordid: WL kontrolü, kullanıcı eşlemesi (ADD_DISCORDID_TO_PLAYERS)
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `discordid` VARCHAR(50) NULL DEFAULT NULL AFTER `license`;
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `jailtime` INT DEFAULT 0;
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `communityservice` INT DEFAULT 0;

-- Eski MySQL/MariaDB (IF NOT EXISTS desteklemiyorsa) - hata alırsanız yukarıdakileri kaldırıp sadece şunları kullanın:
-- ALTER TABLE `players` ADD COLUMN `discordid` VARCHAR(50) NULL DEFAULT NULL AFTER `license`;
-- ALTER TABLE `players` ADD COLUMN `jailtime` INT DEFAULT 0;
-- ALTER TABLE `players` ADD COLUMN `communityservice` INT DEFAULT 0;

-- İndeksler
ALTER TABLE `blips` ADD INDEX IF NOT EXISTS `idx_name` (`name`);
ALTER TABLE `blips` ADD INDEX IF NOT EXISTS `idx_type` (`type`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_discordid` (`discordid`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_jailtime` (`jailtime`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_communityservice` (`communityservice`);

-- Eski MySQL'de IF NOT EXISTS indeks hatası alırsanız, sadece şu satırları çalıştırın:
-- ALTER TABLE `players` ADD INDEX `idx_discordid` (`discordid`);

-- ═══════════════════════════════════════════════════════════════
-- KURULUM TAMAMLANDI!
-- ═══════════════════════════════════════════════════════════════
-- Sonraki Adımlar:
-- 1. bc-web SQL'i de çalıştırın (31.01.2026_web_sql.sql - htdocs için)
-- 2. Site panelinden Web API Key oluştur (Ayarlar > Web API Key)
-- 3. Script config dosyasına API Key'i ekle (config/config.lua)
-- 4. Script'i yeniden başlat: ensure bc-Web
-- ═══════════════════════════════════════════════════════════════
