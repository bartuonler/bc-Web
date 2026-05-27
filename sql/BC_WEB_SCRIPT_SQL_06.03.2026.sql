-- ═══════════════════════════════════════════════════════════════════════
-- BC-WEB FiveM Script - EKSIKSIZ SQL KURULUM DOSYASI (06.03.2026)
-- ═══════════════════════════════════════════════════════════════════════
--
-- Bu SQL dosyasını FiveM karakter veritabanınızda çalıştırın.
-- Örnek: bc-qbx, qbcoreframework, qb-core vb.
--
-- ⚠️  Web panel (bcdevpanel) veritabanına UYGULAMAYIN!
--     Bu dosya SADECE FiveM tarafındaki karakter veritabanı içindir.
--
-- İÇERİK:
--   BÖLÜM 1: bc-Web'in Oluşturduğu Tablolar
--     1.1) site_settings      - Script ↔ Web panel API key saklama
--     1.2) bc_playtime         - Oyun süresi senkronizasyon cache tablosu
--     1.3) blips               - Harita işaretçileri (Canlı harita & Blip listesi)
--     1.4) ox_inventory_items  - Panelden eklenen özel item'lar (OX Inventory)
--     1.5) job_positions       - Panelden eklenen özel meslekler
--
--   BÖLÜM 2: Wiki Sistemi Tabloları (Script ↔ Panel paylaşımlı)
--     2.1) wiki_characters     - Karakter wiki profilleri
--     2.2) wiki_developments   - Karakter gelişim kayıtları
--
--   BÖLÜM 3: players Tablosu Ek Sütunlar
--     3.1) last_updated, discordid, jailtime, communityservice sütunları
--     3.2) Performans indeksleri
--
--   BÖLÜM 4: Referans Tablolar (Framework tarafından oluşturulan, bc-Web'in
--            OKUDUĞU / GÜNCELLEDIĞI tablolar - bilgi amaçlı listelenir)
--
-- UYUMLULUK:
--   - QBCore / QBX / ESX (players tablosu olan tüm frameworkler)
--   - MySQL 5.7+ / MariaDB 10.2+
--   - oxmysql / mysql-async / ghmattimysql
--   - OX Inventory / QB Inventory / QS Inventory
--
-- KURULUM:
--   1) phpMyAdmin'de FiveM veritabanınızı seçin
--   2) SQL sekmesine bu dosyanın içeriğini yapıştırın
--   3) Çalıştırın
--   veya terminal:
--      mysql -u root -p fivem_db < BC_WEB_SCRIPT_SQL_06.03.2026.sql
--
-- NOT: "IF NOT EXISTS" ve "IF NOT EXISTS" kullanıldığı için güvenle
--      tekrar tekrar çalıştırılabilir. Mevcut veri silinmez.
-- ═══════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════
-- BÖLÜM 1: BC-WEB'İN OLUŞTURDUĞU TABLOLAR
-- ═══════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────
-- 1.1) SITE_SETTINGS - Script ↔ Web Panel API Key
-- ─────────────────────────────────────────────────────────────────────
-- bc-Web server.lua başlatıldığında webApiKey'i bu tabloya yazar.
-- Panel, bu key ile FiveM sunucusuna komut gönderir.
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `site_settings` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `setting_key` VARCHAR(100) UNIQUE NOT NULL,
  `setting_value` TEXT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ─────────────────────────────────────────────────────────────────────
-- 1.2) BC_PLAYTIME - Oyun Süresi Senkronizasyon Cache
-- ─────────────────────────────────────────────────────────────────────
-- server.lua "PLAYTIME TRACKING SYSTEM" bloğu bu tabloyu kullanır.
-- metadata.playtime değerlerini periyodik olarak buraya yazar.
-- Panel sıralama/istatistik için bu tablodan okur.
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `bc_playtime` (
  `cid` VARCHAR(50) PRIMARY KEY,
  `time` INT UNSIGNED DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ─────────────────────────────────────────────────────────────────────
-- 1.3) BLIPS - Harita İşaretçileri
-- ─────────────────────────────────────────────────────────────────────
-- Panel üzerinden eklenen/düzenlenen blip'ler burada saklanır.
-- Canlı harita ve blip listesi sayfaları bu tabloyu kullanır.
-- ─────────────────────────────────────────────────────────────────────
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

-- Blip indeksleri
ALTER TABLE `blips` ADD INDEX IF NOT EXISTS `idx_blips_name` (`name`);
ALTER TABLE `blips` ADD INDEX IF NOT EXISTS `idx_blips_type` (`type`);


-- ─────────────────────────────────────────────────────────────────────
-- 1.4) OX_INVENTORY_ITEMS - Panel Üzerinden Eklenen Özel Item'lar
-- ─────────────────────────────────────────────────────────────────────
-- Panel "Item Yönetimi" sayfasından eklenen item'lar bu tabloya yazılır.
-- server.lua manageItem callback'i bu tabloyu Create IF NOT EXISTS ile
-- runtime'da da oluşturur, ancak önceden oluşturmak daha güvenlidir.
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ox_inventory_items` (
  `name` VARCHAR(100) NOT NULL PRIMARY KEY,
  `label` VARCHAR(200) NOT NULL,
  `weight` INT DEFAULT 0,
  `stack` TINYINT(1) DEFAULT 1,
  `description` TEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ─────────────────────────────────────────────────────────────────────
-- 1.5) JOB_POSITIONS - Panel Üzerinden Eklenen Özel Meslekler
-- ─────────────────────────────────────────────────────────────────────
-- Panel "Meslek Yönetimi" sayfasından eklenen meslekler bu tabloya yazılır.
-- server.lua manageJob callback'i bu tabloyu Create IF NOT EXISTS ile
-- runtime'da da oluşturur, ancak önceden oluşturmak daha güvenlidir.
-- grades kolonu JSON formatında rütbe bilgisi içerir.
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `job_positions` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL UNIQUE,
  `label` VARCHAR(200) NOT NULL,
  `grades` TEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ═══════════════════════════════════════════════════════════════════════
-- BÖLÜM 2: WİKİ SİSTEMİ TABLOLARI
-- ═══════════════════════════════════════════════════════════════════════
-- Bu tablolar hem bc-Web FiveM scripti (wiki-integration.lua) hem de
-- Next.js web paneli (Prisma ORM) tarafından kullanılır.
--
-- ⚠️  Bu tabloları SADECE FiveM veritabanında oluşturun.
--     Panel veritabanı (bcdevpanel) Prisma migration ile kendi wiki
--     tablolarını yönetir.
--
-- Wiki-integration.lua: Oyuncu giriş yaptığında veya /wikisync komutu
-- çalıştığında players tablosundan charinfo + discord bilgisi alıp
-- bu tablolara yazar/günceller.
-- ═══════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────
-- 2.1) WIKI_CHARACTERS - Karakter Wiki Profilleri
-- ─────────────────────────────────────────────────────────────────────
-- Her karakter için wiki sayfası profili.
-- wiki-integration.lua: citizenid, discord_id, gender, nationality yazar
-- Panel: character_photo, short_summary, character_story, life_status,
--        values_beliefs, is_published alanlarını kullanıcı doldurur
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `wiki_characters` (
  `citizenid` VARCHAR(50) PRIMARY KEY,
  `discord_id` VARCHAR(50) NOT NULL,
  `character_photo` TEXT,
  `short_summary` TEXT,
  `life_status` VARCHAR(50) DEFAULT 'Canlı',
  `character_story` TEXT,
  `values_beliefs` TEXT,
  `is_published` TINYINT(1) DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_wiki_discord_id` (`discord_id`),
  INDEX `idx_wiki_is_published` (`is_published`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- wiki-integration.lua INSERT'te kullandığı ek sütunlar (Prisma'da yok, uyumluluk için)
-- age: charinfo.birthdate'den hesaplanabilir, kullanıcı da doldurabili
-- gender: charinfo.gender'dan otomatik set edilir (0=Erkek, 1=Kadın)
-- nationality: charinfo.nationality'den otomatik set edilir
ALTER TABLE `wiki_characters` ADD COLUMN IF NOT EXISTS `age` VARCHAR(10) DEFAULT NULL AFTER `discord_id`;
ALTER TABLE `wiki_characters` ADD COLUMN IF NOT EXISTS `gender` VARCHAR(20) DEFAULT NULL AFTER `age`;
ALTER TABLE `wiki_characters` ADD COLUMN IF NOT EXISTS `nationality` VARCHAR(100) DEFAULT NULL AFTER `gender`;


-- ─────────────────────────────────────────────────────────────────────
-- 2.2) WIKI_DEVELOPMENTS - Karakter Gelişim Kayıtları
-- ─────────────────────────────────────────────────────────────────────
-- Her karakter için kronolojik gelişim/olay kayıtları.
-- Panel tarafında kullanıcılar kendi karakterlerine gelişim ekler,
-- yetkililer onaylar/reddeder (status: beklemede/onaylandi/reddedildi).
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `wiki_developments` (
  `id` VARCHAR(50) PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `content` TEXT NOT NULL,
  `development_date` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `status` VARCHAR(50) DEFAULT 'beklemede',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_wikidev_citizenid` (`citizenid`),
  INDEX `idx_wikidev_status` (`status`),
  FOREIGN KEY (`citizenid`) REFERENCES `wiki_characters`(`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ═══════════════════════════════════════════════════════════════════════
-- BÖLÜM 3: PLAYERS TABLOSU - EK SÜTUNLAR VE İNDEKSLER
-- ═══════════════════════════════════════════════════════════════════════
-- BC-Web ve Next.js paneli, mevcut players tablosunda aşağıdaki ek
-- sütunları kullanır. Eğer yoksa otomatik eklenir.
--
-- Kullanılan mevcut players sütunları (framework tarafından oluşturulan):
--   citizenid (PK), license, license2-5, charinfo (JSON),
--   money (JSON), job (JSON), gang (JSON), metadata (JSON),
--   inventory (JSON)
--
-- bc-Web'in eklediği sütunlar:
--   last_updated   → Son aktivite tarihi (TIMESTAMP)
--   discordid      → Discord ID eşlemesi (server.lua otomatik set eder)
--   jailtime       → Hapis ceza süresi (columns modu için)
--   communityservice → Kamu hizmeti süresi (columns modu için)
-- ═══════════════════════════════════════════════════════════════════════

-- 3.1) Ek sütunlar (yoksa ekle)
ALTER TABLE `players`
  ADD COLUMN IF NOT EXISTS `last_updated` TIMESTAMP NOT NULL
    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

ALTER TABLE `players`
  ADD COLUMN IF NOT EXISTS `discordid` VARCHAR(50) NULL DEFAULT NULL AFTER `license`;

ALTER TABLE `players`
  ADD COLUMN IF NOT EXISTS `jailtime` INT DEFAULT 0;

ALTER TABLE `players`
  ADD COLUMN IF NOT EXISTS `communityservice` INT DEFAULT 0;

-- 3.2) Performans indeksleri (yoksa ekle)
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_players_last_updated` (`last_updated`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_players_discordid` (`discordid`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_players_license` (`license`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_players_citizenid` (`citizenid`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_players_jailtime` (`jailtime`);
ALTER TABLE `players` ADD INDEX IF NOT EXISTS `idx_players_communityservice` (`communityservice`);


-- ═══════════════════════════════════════════════════════════════════════
-- BÖLÜM 4: REFERANS TABLOLAR (BİLGİ AMAÇLI)
-- ═══════════════════════════════════════════════════════════════════════
-- Aşağıdaki tablolar bc-Web tarafından OLUŞTURULMAZ, sadece OKUNUR veya
-- GÜNCELLENİR. Bu tablolar FiveM framework veya envanter sistemi
-- tarafından zaten oluşturulmuş olmalıdır.
--
-- Eğer bu tablolar veritabanınızda yoksa, ilgili modülün kurulu
-- olmadığı anlamına gelir ve panel o özelliği devre dışı bırakır.
--
-- ┌─────────────────────┬──────────────┬─────────────────────────────┐
-- │ Tablo               │ İşlem        │ Açıklama                    │
-- ├─────────────────────┼──────────────┼─────────────────────────────┤
-- │ players             │ SELECT/UPDATE│ Framework karakter tablosu  │
-- │                     │ /DELETE      │ (QBCore/QBX/ESX)            │
-- ├─────────────────────┼──────────────┼─────────────────────────────┤
-- │ player_vehicles     │ SELECT/UPDATE│ Araç listesi, plaka değiş., │
-- │                     │ /DELETE      │ araç silme, araç verme      │
-- ├─────────────────────┼──────────────┼─────────────────────────────┤
-- │ inventories         │ SELECT       │ OX Inventory stash/glovebox │
-- │                     │              │ /trunk envanter verileri     │
-- ├─────────────────────┼──────────────┼─────────────────────────────┤
-- │ ox_inventory        │ SELECT/DELETE│ OX Inventory stash listesi  │
-- │                     │              │ (getAllStashs, getStash)     │
-- ├─────────────────────┼──────────────┼─────────────────────────────┤
-- │ stashitems          │ SELECT       │ QB Inventory stash verileri │
-- │                     │              │ (framework-detection.lua)   │
-- ├─────────────────────┼──────────────┼─────────────────────────────┤
-- │ player_items        │ SELECT       │ QB Inventory oyuncu item'ları│
-- │                     │              │ (framework-detection.lua)   │
-- ├─────────────────────┼──────────────┼─────────────────────────────┤
-- │ xt_prison           │ SELECT/INSERT│ xt-Prison eklentisi (opsion.)│
-- │                     │ /UPDATE/DEL  │ Hapis sistemi (varsa kullanır│
-- └─────────────────────┴──────────────┴─────────────────────────────┘
--
-- NOT: xt_prison tablosu opsiyoneldir. Eğer xt-Prison eklentisi
-- kuruluysa bc-Web onu otomatik algılar ve kullanır. Yoksa metadata
-- veya jailtime/communityservice sütunları üzerinden çalışır.
-- ═══════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════
-- BÖLÜM 5: JSON DOSYA TABANLI VERİ DEPOLAMA (SQL DIŞI)
-- ═══════════════════════════════════════════════════════════════════════
-- bc-Web ayrıca disk üzerinde JSON dosyaları ile veri saklar:
--
--   bc-Web/data/bans.json     → Ban listesi ({"discord:ID": {author,reason}})
--   bc-Web/data/blips.json    → Blip listesi (runtime cache)
--   bc-Web/data/stashs.json   → Stash listesi (runtime cache)
--   bc-Web/settings.json      → Sunucu ayarları (sqlSaveInterval, locations)
--
-- Bu dosyalar SQL'e dahil değildir, script tarafından otomatik
-- oluşturulur/güncellenir. Yedekleme yaparken bu dosyaları da
-- kopyalayın.
-- ═══════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════
-- KURULUM DOĞRULAMA
-- ═══════════════════════════════════════════════════════════════════════
SELECT '✅ BC-Web Script SQL kurulumu tamamlandı!' AS durum
UNION ALL
SELECT CONCAT('   Tablolar: site_settings, bc_playtime, blips, ox_inventory_items, job_positions, wiki_characters, wiki_developments')
UNION ALL
SELECT CONCAT('   players tablosu: last_updated, discordid, jailtime, communityservice sütunları + indeksler eklendi')
UNION ALL
SELECT CONCAT('   Tarih: 06.03.2026 | Sürüm: 3.0');
