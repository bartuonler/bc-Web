
-- Discord ID çekme fonksiyonu (FiveM'den direkt)
local function GetDiscordIdFromSource(source)
    local identifiers = GetPlayerIdentifiers(source)
    
    for _, identifier in ipairs(identifiers) do
        if string.match(identifier, "discord:") then
            local discordId = string.match(identifier, "discord:(%d+)")
            return discordId
        end
    end
    
    return nil
end

-- Discord ID'yi license stringinden çek (fallback) - TÜM kolonları tara
local function GetDiscordIdFromLicense(license, license2, license3, license4, license5)
    local discordId = nil
    local licenses = {license, license2, license3, license4, license5}
    
    for i, lic in ipairs(licenses) do
        if lic and lic ~= '' then
            local match = string.match(lic, "discord:(%d+)")
            if match then
                discordId = match
                print("^2[WIKI] Discord ID bulundu (license" .. (i == 1 and "" or tostring(i)) .. "): " .. discordId)
                break
            end
        end
    end
    
    if not discordId then
        print("^3[WIKI] Discord ID bulunamadı! License kolonları:")
        for i, lic in ipairs(licenses) do
            print("^3  license" .. (i == 1 and "" or tostring(i)) .. ": " .. (lic or "NULL"))
        end
    end
    
    return discordId
end

-- Wiki karakteri oluştur veya güncelle
local function CreateOrUpdateWikiCharacter(citizenid)
    if not citizenid then return end
    
    -- Karakter bilgilerini çek
    MySQL.query('SELECT citizenid, charinfo, license, license2, license3, license4, license5 FROM players WHERE citizenid = ?', {citizenid}, function(result)
        if result and result[1] then
            local char = result[1]
            local charinfo = json.decode(char.charinfo)
            
            -- Discord ID'yi çek
            local discordId = GetDiscordIdFromLicense(
                char.license, 
                char.license2, 
                char.license3, 
                char.license4, 
                char.license5
            )
            
            if not discordId then
                print("^3[WIKI] Discord ID bulunamadı: " .. citizenid)
                return
            end
            
            -- Wiki karakteri var mı kontrol et
            MySQL.query('SELECT id FROM wiki_characters WHERE citizenid = ?', {citizenid}, function(wikiResult)
                if wikiResult and #wikiResult > 0 then
                    -- Güncelle
                    MySQL.update([[
                        UPDATE wiki_characters 
                        SET discord_id = ?,
                            updated_at = NOW()
                        WHERE citizenid = ?
                    ]], {
                        discordId,
                        citizenid
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            print("^2[WIKI] Karakter güncellendi: " .. citizenid .. " (Discord: " .. discordId .. ")")
                        end
                    end)
                else
                    -- Yeni oluştur
                    MySQL.insert([[
                        INSERT INTO wiki_characters 
                        (citizenid, discord_id, age, gender, nationality, life_status, is_published, created_at, updated_at) 
                        VALUES (?, ?, ?, ?, ?, 'Canlı', 0, NOW(), NOW())
                    ]], {
                        citizenid,
                        discordId,
                        nil, -- age (kullanıcı doldursun)
                        charinfo.gender == 0 and 'Erkek' or 'Kadın',
                        charinfo.nationality or nil,
                    }, function(insertId)
                        if insertId then
                            print("^2[WIKI] Yeni karakter eklendi: " .. citizenid .. " (Discord: " .. discordId .. ")")
                        end
                    end)
                end
            end)
        end
    end)
end

-- Oyuncu giriş yaptığında wiki'yi güncelle
AddEventHandler('playerConnecting', function()
    local src = source
    
    -- Biraz bekle ki karakter yüklensin
    SetTimeout(5000, function()
        -- Framework detection
        local Player = nil
        if GetResourceState('qbx_core') == 'started' then
            Player = exports.qbx_core:GetPlayer(src)
        elseif GetResourceState('qb-core') == 'started' then
            local QBCore = exports['qb-core']:GetCoreObject()
            Player = QBCore.Functions.GetPlayer(src)
        end
        
        if Player and Player.PlayerData and Player.PlayerData.citizenid then
            local citizenid = Player.PlayerData.citizenid
            CreateOrUpdateWikiCharacter(citizenid)
        end
    end)
end)

-- Manuel olarak tüm karakterleri wiki'ye ekle (konsol komutu)
RegisterCommand('wiki:syncall', function(source, args, rawCommand)
    if source ~= 0 then
        print("^1[WIKI] Bu komut sadece sunucu konsolundan çalıştırılabilir!")
        return
    end
    
    print("^3[WIKI] Tüm karakterler wiki ile senkronize ediliyor...")
    
    MySQL.query('SELECT citizenid FROM players', {}, function(result)
        if result then
            local count = 0
            for _, char in ipairs(result) do
                CreateOrUpdateWikiCharacter(char.citizenid)
                count = count + 1
                
                -- Rate limiting (100 karakterde bir bekle)
                if count % 100 == 0 then
                    Wait(1000)
                end
            end
            print("^2[WIKI] " .. count .. " karakter senkronize edildi!")
        end
    end)
end, true)

-- Web panelden tetiklenebilir senkronizasyon
RegisterNetEvent('BC-Web:callback:syncWikiCharacters', function(cb)
    -- Web panel için güvenlik kontrolü devre dışı
    if false and GetInvokingResource() ~= "BC-Web" then
        cb({
            success = false,
            message = "Not Authorized!",
            author = "Macius"
        })
        return
    end
    
    MySQL.query('SELECT citizenid FROM players', {}, function(result)
        if result then
            local count = 0
            for _, char in ipairs(result) do
                CreateOrUpdateWikiCharacter(char.citizenid)
                count = count + 1
                
                if count % 100 == 0 then
                    Wait(100)
                end
            end
            
            cb({
                success = true,
                message = count .. " karakter wiki ile senkronize edildi!",
                author = "Macius"
            })
        else
            cb({
                success = false,
                message = "Karakterler çekilemedi!",
                author = "Macius"
            })
        end
    end)
end)

-- Discord ID'leri düzelt (players tablosundaki discordid kolonunu temizle)
RegisterCommand('wiki:fixdiscord', function(source, args, rawCommand)
    if source ~= 0 then
        print("^1[WIKI] Bu komut sadece sunucu konsolundan çalıştırılabilir!")
        return
    end
    
    print("^3[WIKI] Discord ID'ler düzeltiliyor...")
    
    MySQL.query('SELECT citizenid, license, discordid FROM players', {}, function(result)
        if result then
            local count = 0
            local fixed = 0
            
            for _, char in ipairs(result) do
                count = count + 1
                local citizenid = char.citizenid
                local currentDiscordId = char.discordid
                
                -- Mevcut discordid doğru mu?
                local isValid = currentDiscordId and tonumber(currentDiscordId) and string.len(tostring(currentDiscordId)) >= 17
                
                if not isValid then
                    -- license stringinden discord ID çek
                    local discordId = string.match(char.license or "", "discord:(%d+)")
                    
                    if discordId then
                        -- Düzelt
                        MySQL.update('UPDATE players SET discordid = ? WHERE citizenid = ?', {
                            discordId,
                            citizenid
                        }, function(affectedRows)
                            if affectedRows > 0 then
                                print("^2[WIKI] " .. citizenid .. " düzeltildi: " .. discordId)
                                fixed = fixed + 1
                            end
                        end)
                    else
                        -- Discord ID bulunamadı, NULL yap
                        MySQL.update('UPDATE players SET discordid = NULL WHERE citizenid = ?', {
                            citizenid
                        })
                        print("^3[WIKI] " .. citizenid .. " - Discord ID bulunamadı, NULL yapıldı")
                    end
                end
                
                if count % 50 == 0 then
                    Wait(100)
                end
            end
            
            Wait(2000)
            print("^2[WIKI] Discord ID düzeltme tamamlandı!")
            print("^2[WIKI] Toplam: " .. count .. " | Düzeltilen: " .. fixed)
        end
    end)
end, true)

print("^2[WIKI] Wiki Integration yüklendi!")
print("^3[WIKI] Konsol komutları:")
print("^3[WIKI]   - wiki:syncall     (Wiki karakterlerini senkronize et)")
print("^3[WIKI]   - wiki:fixdiscord  (Discord ID'leri düzelt)")


print("^2[WIKI] Wiki Integration yüklendi!")
print("^3[WIKI] Konsol komutları:")
print("^3[WIKI]   - wiki:syncall     (Wiki karakterlerini senkronize et)")
print("^3[WIKI]   - wiki:fixdiscord  (Discord ID'leri düzelt)")

