BCPanel = {}

-- FRAMEWORK SECIMI (Otomatik tespit icin 'auto' birakin)
BCPanel.Framework = 'auto' -- 'qb', 'qbx', 'auto'

-- INVENTORY SISTEMI
BCPanel.Inventory = 'auto' -- 'ox_inventory', 'qb-inventory', 'ps-inventory', 'auto'
BCPanel.oxInventory = true -- Otomatik tespit icin true birakin

-- CLOTHING SISTEMI
BCPanel.Clothing = 'auto' -- 'illenium-appearance', 'qb-clothing', 'fivem-appearance', 'auto'

-- GARAGE SISTEMI
BCPanel.Garage = 'auto' -- 'qb-garages', 'qbx_garages', 'cd_garage', 'jg-advancedgarages', 'auto'

-- TELEFON SISTEMI
BCPanel.Phone = 'auto' -- 'qs-smartphone', 'gksphone', 'npphone', 'lb-phone', 'roadphone', 'auto'

-- GALERI/DEALERSHIP SISTEMI
BCPanel.Dealership = 'auto' -- 'jg-dealership', 'qb-dealership', 'qbx-dealership', 'auto'

-- SABIT ID SISTEMI (SHX-SID)
-- SHX-SID yukluyse oyunculara sabit ID atar (source yerine)
-- Web panelde sabit ID gosterilir
BCPanel.StaticID = 'auto' -- 'shx-sid', 'none', 'auto'

-- DEBUG MODU (true = detayli log, false = sadece ozet tablo)
BCPanel.Debug = true

-- DATABASE
BCPanel.dbName = 'Qbox_9B1B08'
-- Panel URL: Next.js "next start" ciktisindaki URL ile ayni olmali
-- Orn: http://localhost:3000 veya ag IP'n (192.168.x.x:3000)
BCPanel.webPanel = 'http://juiceroleplay.com/'

-- WEB API KEY (Site ayarlarindan alin)
-- Site panelinden: Ayarlar > Web API Key > API Key'i kopyala ve buraya yapistir
BCPanel.WebAPIKey = "MVrIvKkXRaqkXJMT5NDKKVUTV6H1atpN"

-- WEBSOCKET GÜVENLİK ANAHTARI (SaaS Panelindeki Yeni Sistem)
-- Panelinden "Websocket Güvenlik Anahtarı" kısmından kopyalayın.
BCPanel.WebSocketKey = "BURAYA_WEBSOCKET_ANAHTARINI_GIRIN"

-- mysqldump yolu (sunucunuza gore degistirin)
BCPanel.mysqldumpPath = 'C:/xampp/mysql/bin/mysqldump.exe'
-- Alternatif yollar:
-- BCPanel.mysqldumpPath = 'D:/xampp/mysql/bin/mysqldump.exe'
-- BCPanel.mysqldumpPath = 'C:/laragon/bin/mysql/mysql-8.0/bin/mysqldump.exe'
-- BCPanel.mysqldumpPath = 'C:/Program Files/MySQL/MySQL Server 8.0/bin/mysqldump.exe'

BCPanel.Stash = {maxweight = 4000000, slots = 500}

-- Framework Events (QBX/QBCore)
BCPanel.Events = {
    qbx = {
        kill = 'hospital:client:KillPlayer',
        revive = 'hospital:client:Revive',
        heal = 'hospital:client:HealPlayer',
        clothing = 'qbx_clothing:client:openMenu'
    },
    qb = {
        kill = 'hospital:client:KillPlayer',
        revive = 'hospital:client:Revive',
        heal = 'hospital:client:HealPlayer',
        clothing = 'qb-clothing:client:openMenu'
    }
}

-- ITEM LISTESI AYARLARI
-- Otomatik tespit basarisiz olursa manuel path belirleyin
-- ORNEK MANUEL KULLANIM:
-- BCPanel.ItemListPath = "C:/sunucu/server-data/resources/[ox]/ox_inventory/data/items.lua"
-- BCPanel.ItemListPathManual = true
-- OTOMATIK TESPIT (ONERILEN):
BCPanel.ItemListPath = ""
BCPanel.ItemListPathManual = false

-- ITEM RESIM DIZINI (itemImage HTTP handler icin)
-- ox_inventory'nin web/images klasorunun tam yolu
-- Ornek: BCPanel.itemImagePath = "C:/sunucu/server-data/resources/[ox]/ox_inventory/web/images"
BCPanel.itemImagePath = ""  -- Bos birak (otomatik tespit: GetResourcePath('ox_inventory') kullanilir)

-- ARAC LISTESI AYARLARI
-- Otomatik tespit basarisiz olursa manuel path belirleyin
-- ORNEK MANUEL KULLANIM:
-- BCPanel.VehicleListPath = "C:/sunucu/server-data/resources/[qb]/qb-core/shared/vehicles.lua"
-- BCPanel.VehicleListPathManual = true
-- OTOMATIK TESPIT (ONERILEN):
BCPanel.VehicleListPath = ""
BCPanel.VehicleListPathManual = false

-- HAPIS & KAMU HIZMETI SCRIPT AYARLARI
-- Sunucunuzdaki hapis scriptinin resource adini yazin
-- Otomatik tespit icin 'auto' birakin
BCPanel.JailScript = 'auto'  -- Orn: 'qb-jail', 'okokJail', 'ps-jail', 'rcore_jail', 'custom'

-- Hapis event adlari (script'e gore degisir)
-- 'auto' birakirsaniz yaygin event adlari denenir
BCPanel.JailEvents = {
    sendToJail      = 'auto',  -- Orn: 'qb-jail:server:JailPlayer', 'jail:sendToJail'
    releaseFromJail = 'auto',  -- Orn: 'qb-jail:server:UnJailPlayer', 'jail:releaseByAdmin'
    sendToService   = 'auto',  -- Kamu hizmeti - Orn: 'cs:sendToService'
    removeService   = 'auto',  -- Kamu serbest - Orn: 'cs:forceRemoveService'
}

-- OYUN ICI CHAT SISTEMI - QBCore/QBX uyumlu
BCPanel.sendMessage = function(src, text, author)
    if src == -1 then
        -- Tum oyunculara mesaj (oyun ici chat)
        local displayAuthor = author or 'DUYURU'
        if displayAuthor == 'DUYURU' then
            displayAuthor = 'WEB Duyuru'
        end

        -- Chat export'unu kullan (varsa)
        if GetResourceState('qbx_chat') == 'started' then
            exports['qbx_chat']:System({
                template = '<div class="chat-message system"><b>[{0}]</b> {1}</div>',
                args = {displayAuthor, text}
            })
        elseif GetResourceState('qb-chat') == 'started' then
            exports['qb-chat']:System({
                template = '<div class="chat-message system"><b>[{0}]</b> {1}</div>',
                args = {displayAuthor, text}
            })
        else
            -- Fallback: Standart chat:addMessage
            TriggerClientEvent('chat:addMessage', -1, {
                color = {255, 255, 0},
                multiline = false,
                args = {'['..displayAuthor..']', text}
            })
        end
    else
        -- Tek oyuncuya ozel mesaj (oyun ici chat)
        TriggerClientEvent('chat:addMessage', src, {
            template = '<div class="chat-message pm"><b>[Ozel Mesaj] {0}</b> {1}</div>',
            args = {author or 'Admin', text}
        })
    end
end


-- ============================================
-- GLOBAL DEBUG PRINT OVERRIDE
-- BCPanel.Debug = true iken sadece HATA ve UYARI mesajlari basilir
-- BCPanel.Debug = true iken tum mesajlar basilir
-- ============================================
