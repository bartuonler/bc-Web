# 🎮 BC-Web - FiveM Panel Resource

Universal framework desteği ile modern FiveM web panel entegrasyonu.

## ✨ Özellikler

- ✅ **Universal Framework** - QBCore, QBX, ESX otomatik tespit
- ✅ **Inventory Uyumlu** - ox_inventory, qb-inventory, ps-inventory
- ✅ **Clothing Uyumlu** - illenium-appearance, qb-clothing, fivem-appearance
- ✅ **HTTP API** - Express.js ile RESTful API
- ✅ **WebSocket** - Gerçek zamanlı iletişim
- ✅ **Güvenli** - API key authentication
- ✅ **Performanslı** - Connection pooling, timeout protection

## 🚀 Hızlı Kurulum

```bash
# 1. Resource'u kopyala
[resources]/bc-Web/

# 2. Config'i düzenle
config/config.lua

# 3. server.cfg'ye ekle
ensure oxmysql
ensure bc-Web

# 4. Server'ı başlat
restart all
```

Detaylı kurulum: [KURULUM.md](./KURULUM.md)

## ⚙️ Yapılandırma

### config/config.lua
```lua
-- Framework (auto = otomatik tespit)
BCPanel.Framework = 'auto'      -- qb/qbx/esx/auto
BCPanel.Inventory = 'auto'      -- ox_inventory/qb-inventory/auto
BCPanel.Clothing = 'auto'       -- illenium-appearance/qb-clothing/auto
BCPanel.Garage = 'auto'         -- qb-garages/qbx_garages/auto

-- Database
BCPanel.dbName = 'fivem'

-- Web Panel
BCPanel.webPanel = 'http://localhost:3000/'
BCPanel.WebAPIKey = "your_secret_api_key"
```

## 📡 HTTP API Endpoints

Tüm endpoint'ler `http://server:30120/` üzerinden:

### Player Operations
- `GET /getOnlineUsers` - Online oyuncular
- `POST /giveItem/:cid/:item/:amount` - Item ver
- `POST /giveMoney/:cid/:type/:amount` - Para ver
- `POST /giveVehicle/:cid/:vehicle/:type` - Araç ver
- `POST /teleportPlayer/:cid/:x/:y/:z` - Işınla
- `POST /revivePlayer/:cid` - Revive
- `POST /healPlayer/:cid` - Heal
- `POST /killPlayer/:cid` - Kill
- `POST /sendPM/:cid/:message` - Özel mesaj
- `POST /kickPlayer/:discordId/:reason` - Kick
- `POST /banPlayer/:discordId/:reason` - Ban

### Server Operations
- `GET /getServerUptime` - Server uptime
- `GET /getData/:type` - İtem/Araç/Meslek listesi
- `GET /getBans` - Ban listesi
- `POST /unbanPlayer/:discordId` - Ban kaldır
- `GET /getAllLocations` - Lokasyon listesi
- `POST /newLocation/:name/:x/:y/:z/:w` - Lokasyon ekle
- `POST /deleteLocation/:name` - Lokasyon sil

## 🔒 Güvenlik

### API Key
```lua
-- config/config.lua
BCPanel.WebAPIKey = "güçlü-api-key-buraya"

-- Tüm HTTP istekleri header ile korunur:
Authorization: güçlü-api-key-buraya
```

### Resource Name Protection
Resource adı `bc-Web` olmalıdır. Değiştirilirse server otomatik kapatılır.

## 🛠️ Framework Uyumluluk

| Framework | Destek | Notlar |
|-----------|--------|--------|
| QBX | ✅ | Tam uyumlu |
| QBCore | ✅ | Tam uyumlu |
| ESX | ⚠️ | Temel destek |

| Inventory | Destek | Notlar |
|-----------|--------|--------|
| ox_inventory | ✅ | Önerilen |
| qb-inventory | ✅ | Tam uyumlu |
| ps-inventory | ✅ | Uyumlu |

| Clothing | Destek | Notlar |
|-----------|--------|--------|
| illenium-appearance | ✅ | Önerilen, otomatik tespit |
| fivem-appearance | ✅ | Uyumlu |
| qb-clothing | ✅ | Uyumlu |
| qbx_clothing | ✅ | Uyumlu |

## 📁 Dosya Yapısı

```
bc-Web/
├── config/
│   └── config.lua              # Ana yapılandırma
├── server/
│   ├── server.lua              # Ana Lua server kodu
│   ├── server.js               # HTTP API (Express)
│   ├── framework-detection.lua # Framework otomatik tespit
│   ├── autoLogCapture.lua      # Webhook yakalama
│   ├── wiki-integration.lua    # Wiki sistemi
│   └── panel_websocket.lua     # WebSocket entegrasyonu
├── client/
│   └── client.lua              # Client-side kod
├── fxmanifest.lua              # Resource manifest
├── KURULUM.md                  # Detaylı kurulum rehberi
└── README.md                   # Bu dosya
```

## 🐛 Sorun Giderme

**Framework tespit edilemedi:**
```
Çözüm: ensure bc-Web'i diğer resource'lardan sonra başlatın
```

**API bağlantısı yok:**
```
1. API Key'ler eşleşiyor mu? (config.lua == .env.local)
2. Port 30120 açık mı?
3. server.js çalışıyor mu? (node server/server.js)
```

**Clothing menüsü açılmıyor:**
```
1. Clothing resource çalışıyor mu?
2. Console'da tespit log'u var mı?
3. Manuel test: /clothingmenu
```

Daha fazla: [KURULUM.md](./KURULUM.md)

## 📦 Gereksinimler

- **oxmysql** - Database bağlantısı
- **Node.js** 14+ - HTTP API için
- **Framework** - QBCore/QBX/ESX
- **Inventory** - ox_inventory/qb-inventory

## 📄 Lisans

Proprietary - BC Development © 2026

## 🆘 Destek

- Dokümantasyon: [KURULUM.md](./KURULUM.md)
- Discord: [Sunucu linki]
- Web Panel: [bc-webpanel README](../bc-webpanel/README.md)

---

**Geliştirici:** BC Development  
**Versiyon:** 1.0.0  
**Son Güncelleme:** 18 Şubat 2026
