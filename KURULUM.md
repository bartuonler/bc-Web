# 🚀 BC-Web FiveM Panel Script - Kurulum Rehberi

## 📦 Özellikler

### ✅ Universal Framework Desteği
- **QBCore** - Tam uyumlu
- **QBX** - Tam uyumlu
- **ESX** - Temel destek
- **Otomatik Tespit** - Framework'ü otomatik algılar

### ✅ Inventory Desteği
- **ox_inventory** - Tam uyumlu (önerilen)
- **qb-inventory** - Tam uyumlu
- **ps-inventory** - Uyumlu
- **Otomatik Tespit** - Resource'u otomatik algılar

### ✅ Clothing Desteği
- **illenium-appearance** - Tam uyumlu (önerilen)
- **fivem-appearance** - Uyumlu
- **qb-clothing** - Uyumlu
- **qbx_clothing** - Uyumlu
- **Otomatik Tespit** - Client-side otomatik algılar

### ✅ Garage Desteği
- **qb-garages** - Uyumlu
- **qbx_garages** - Uyumlu
- **cd_garage** - Uyumlu

---

## ⚙️ Kurulum

### 1. Resource'u Kopyala
```bash
# bc-Web klasörünü server resources klasörüne kopyalayın
[resources]/bc-Web/
```

### 2. Config Ayarları
```lua
-- config/config.lua dosyasını düzenleyin

BCPanel.Framework = 'auto'  -- 'qb', 'qbx', 'esx' veya 'auto'
BCPanel.Inventory = 'auto'  -- 'ox_inventory', 'qb-inventory' veya 'auto'
BCPanel.Clothing = 'auto'   -- 'illenium-appearance', 'qb-clothing' veya 'auto'
BCPanel.Garage = 'auto'     -- 'qb-garages', 'qbx_garages' veya 'auto'

BCPanel.dbName = 'bc-qbx'   -- FiveM database adı
BCPanel.WebAPIKey = "your_secret_key_here"  -- Web panelinden alın
```

### 3. server.cfg'ye Ekle
```bash
ensure bc-Web
```

### 4. Dependency'leri Kontrol Et
```lua
# Gerekli bağımlılıklar:
- oxmysql (zorunlu)
- PolyZone (opsiyonel - blip sistemi için)
```

---

## 🔧 Otomatik Tespit Sistemi

Resource başlatıldığında otomatik olarak:
- ✅ Framework'ünüzü tespit eder
- ✅ Inventory sisteminizi tespit eder
- ✅ Clothing scriptinizi tespit eder
- ✅ Garage sisteminizi tespit eder

### Console Çıktısı:
```
========================================
[BC-Web] Sistem Tespiti Başlatılıyor...
========================================
[BC-Web] Framework tespit edildi: QBX
[BC-Web] Inventory tespit edildi: ox_inventory
[BC-Web] Clothing tespit edildi: illenium-appearance
[BC-Web] Garage tespit edildi: qbx_garages
========================================
[BC-Web] Tespit Tamamlandı!
  Framework: qbx
  Inventory: ox_inventory
  Clothing:  illenium-appearance
  Garage:    qbx_garages
========================================
```

---

## 🌐 Web Panel Bağlantısı

### 1. API Key Oluştur
```
Web Panel → Ayarlar → Site Ayarları → Web API Key
API Key'i kopyalayıp config.lua'ya yapıştırın
```

### 2. .env.local Ayarları
```bash
# bc-webpanel/.env.local

FIVEM_API_URL=http://localhost:30120
FIVEM_API_SECRET=your_secret_key_here  # Config.lua'daki ile aynı olmalı!
```

### 3. Bağlantıyı Test Et
```
Web Panel → Yetkili Paneli → Online Oyuncular
Oyuncular görünüyorsa bağlantı başarılı! ✅
```

---

## 🔄 Framework Uyumluluk Tablosu

| Özellik | QB | QBX | ESX | Notlar |
|---------|-----|-----|-----|--------|
| **Player Management** | ✅ | ✅ | ✅ | Tam uyumlu |
| **Item Verme** | ✅ | ✅ | ✅ | ox/qb inventory |
| **Para Verme** | ✅ | ✅ | ✅ | Cash/Bank |
| **Araç Verme** | ✅ | ✅ | ⚠️ | player_vehicles |
| **Işınlama** | ✅ | ✅ | ✅ | SetEntityCoords |
| **Revive** | ✅ | ✅ | ✅ | Framework events |
| **Heal** | ✅ | ✅ | ✅ | SetEntityHealth |
| **Kill** | ✅ | ✅ | ✅ | Framework events |
| **Clothing Menu** | ✅ | ✅ | ⚠️ | Otomatik tespit |
| **Kick/Ban** | ✅ | ✅ | ✅ | DropPlayer |

✅ = Tam Uyumlu  
⚠️ = Kısmi Uyumlu  
❌ = Desteklenmiyor

---

## 📋 Sistem Gereksinimleri

### FiveM Server
- **oxmysql** - Zorunlu
- **QBCore/QBX/ESX** - Framework
- **ox_inventory** veya **qb-inventory** - Inventory
- **illenium-appearance** (önerilen) - Clothing
- **Node.js** 14+ - HTTP API için

### Web Panel
- **Node.js** 18+
- **MySQL** 8.0+
- **Next.js** 14+
- **Prisma** ORM

---

## 🐛 Sorun Giderme

### "Framework tespit edilemedi"
- ✅ `qbx_core`, `qb-core` veya `es_extended` çalışıyor mu?
- ✅ `ensure bc-Web` diğer resource'lardan sonra mı?

### "Inventory tespit edilemedi"
- ✅ `ox_inventory` veya `qb-inventory` çalışıyor mu?
- ✅ Config'de `BCPanel.oxInventory` doğru ayarlı mı?

### "Clothing menüsü açılmıyor"
- ✅ Client console'da hata var mı?
- ✅ İlgili clothing resource çalışıyor mu?
- ✅ Manuel test: `/clothingmenu` komutu çalışıyor mu?

### "API bağlantısı başarısız"
- ✅ `BCPanel.WebAPIKey` doğru mu?
- ✅ `.env.local`'daki `FIVEM_API_SECRET` aynı mı?
- ✅ `FIVEM_API_URL` doğru mu? (http://localhost:30120)
- ✅ Firewall/Port forwarding ayarları?

---

## 📝 API Endpoint'leri

Tüm endpoint'ler `http://your-server:30120/` üzerinden:

```
GET  /getData/:type              # İtem/Araç/Meslek listesi
GET  /getOnlineUsers             # Online oyuncular
GET  /getServerUptime            # Server çalışma süresi
GET  /getBans                    # Ban listesi
POST /unbanPlayer/:discordId     # Ban kaldır
POST /banPlayerByCitizenId/:cid/:reason  # Citizen ID ile ban
# ... daha fazlası için server.js'e bakın
```

---

## 🎯 Önerilen Ayarlar

### Performans İçin:
```lua
BCPanel.Framework = 'qbx'              -- Manuel set (daha hızlı)
BCPanel.Inventory = 'ox_inventory'     -- ox_inventory (en hızlı)
BCPanel.Clothing = 'illenium-appearance'  -- Modern UI
```

### Uyumluluk İçin:
```lua
BCPanel.Framework = 'auto'  -- Otomatik tespit
BCPanel.Inventory = 'auto'  -- Otomatik tespit
BCPanel.Clothing = 'auto'   -- Otomatik tespit
```

---

## 📦 Dosya Yapısı

```
bc-Web/
├── config/
│   └── config.lua           # Ana yapılandırma
├── server/
│   ├── server.lua           # Ana server kodu
│   ├── server.js            # HTTP API (Express)
│   ├── framework-detection.lua  # Otomatik tespit
│   ├── autoLogCapture.lua   # Webhook yakalama
│   ├── wiki-integration.lua # Wiki sistemi
│   └── panel_websocket.lua  # WebSocket
├── client/
│   └── client.lua           # Client-side kod
├── fxmanifest.lua           # Resource manifest
├── blips.json               # Blip ayarları
├── stashs.json              # Stash ayarları
├── bans.json                # Ban listesi
└── settings.json            # Runtime ayarları
```

---

**Geliştirici:** BC Development  
**Versiyon:** 1.0.0  
**Tarih:** 18 Şubat 2026  
**Lisans:** Proprietary
