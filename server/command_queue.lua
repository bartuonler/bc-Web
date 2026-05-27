--[[
    BC-Web Command Queue (DB Polling)
    Panel -> panel_commands (MySQL) -> Bu script isler
    
    server.lua'daki mevcut fonksiyonlari kullanir.
    Gereksiz HTTP/Express/WebSocket bagimliligi olmadan calisir.
]]

-- ============================================
-- CONFIG
-- ============================================
local QUEUE_CFG = {
    pollInterval   = 2000,   -- ms - komut kontrol araligi
    cleanupHours   = 24,     -- saat - eski kayitlari sil
    maxBatch       = 10,     -- tek seferde max komut
    debug          = (BCPanel and BCPanel.Debug) or false,  -- BCPanel.Debug ile senkron
}

local function qdbg(...) if QUEUE_CFG.debug then print('[BC-Web Queue]', ...) end end

-- ============================================
-- PLAYER COORD CACHE (Canli Harita icin)
-- ============================================
local PlayerCoordsCache = {}

RegisterNetEvent('BC-Web:server:updatePlayerCoords', function(x, y, z, heading)
    local src = source
    PlayerCoordsCache[tostring(src)] = {
        x = x, y = y, z = z, heading = heading,
        time = os.time()
    }
end)

-- Oyuncu cikinca cache'den sil
AddEventHandler('playerDropped', function()
    PlayerCoordsCache[tostring(source)] = nil
end)

-- ============================================
-- SAFE QUERY WRAPPER
-- ============================================
local function QueueQuery(q, p)
    local ok, result = pcall(function()
        return MySQL.query.await(q, p or {})
    end)
    if not ok then
        print("^1[BC-Web Queue] MySQL Hata: " .. tostring(result) .. "^0")
        return nil
    end
    return result
end

-- ============================================
-- INVENTORY DETECTION HELPER

-- ============================================
-- QBCORE HELPER (command_queue icin)
-- ============================================
local QBCore = nil
CreateThread(function()
    Wait(2000)
    if GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and core then QBCore = core; print('^2[BC-Web Queue] QBCore yuklendi^0') end
    elseif GetResourceState('qbx_core') == 'started' then
        -- QBX'te QBCore compat layer varsa kullan
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and core then QBCore = core; print('^2[BC-Web Queue] QBCore compat yuklendi (QBX)^0') end
    end
end)

-- ============================================
local function GetInvSystem()
    if InventorySystem then return InventorySystem end
    if BCPanel and BCPanel.oxInventory then return 'ox_inventory' end
    if GetResourceState('ox_inventory') == 'started' then return 'ox_inventory' end
    return 'default'
end

-- ============================================
-- -- HELPER: Framework-agnostic Player bulma
-- (server.lua'daki GetPlayer, GetPlayerByCitizenId, GetPlayerFromDiscord kullanir)
-- ============================================
local function FindPlayerByCitizenId(cid)
    if not cid then return nil, nil end
    cid = tostring(cid):gsub("^%s+", ""):gsub("%s+$", "")
    -- server.lua'da tanimli GetPlayerByCitizenId fonksiyonunu kullanamayiz (local)
    -- O yuzden ayni mantigi burada implement ediyoruz

    local fw = FrameworkType or (BCPanel and BCPanel.DetectedFramework) or (BCPanel and BCPanel.Framework) or 'qb'

    -- Eger sayisal bir deger ise (server ID / source), once direkt source olarak dene
    -- Bu sayede Discord bot komutu oyuncu server ID'si ile de calisabilir
    local numericSrc = tonumber(cid)
    if numericSrc then
        local p = nil
        if fw == 'qbx' then
            pcall(function() p = exports.qbx_core:GetPlayer(numericSrc) end)
        elseif fw == 'qb' then
            pcall(function()
                local core = exports['qb-core']:GetCoreObject()
                p = core.Functions.GetPlayer(numericSrc)
            end)
        end
        if p then return p, numericSrc end
    end

    -- citizenid ile tum oyunculari tara
    for _, playerId in pairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            local p = nil
            if fw == 'qbx' then
                pcall(function() p = exports.qbx_core:GetPlayer(src) end)
            elseif fw == 'qb' then
                pcall(function()
                    local core = exports['qb-core']:GetCoreObject()
                    p = core.Functions.GetPlayer(src)
                end)
            end
            if p then
                if (fw == 'qbx' or fw == 'qb') and p.PlayerData and p.PlayerData.citizenid == cid then
                    return p, src
                end
            end
        end
    end
    return nil, nil
end

local function FindPlayerByDiscord(did)
    if not did then return nil, nil end
    did = tostring(did):gsub("discord:", "")
    for _, playerId in pairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            local d = GetPlayerIdentifierByType(src, 'discord')
            if d and d:gsub("discord:", "") == did then
                local p = nil
                local fw = FrameworkType or (BCPanel and BCPanel.DetectedFramework) or (BCPanel and BCPanel.Framework) or 'qb'
                if fw == 'qbx' then
                    pcall(function() p = exports.qbx_core:GetPlayer(src) end)
                elseif fw == 'qb' then
                    pcall(function()
                        local core = exports['qb-core']:GetCoreObject()
                        p = core.Functions.GetPlayer(src)
                    end)
                end
                return p, src
            end
        end
    end
    return nil, nil
end

local function GetPlayerSource(player)
    if not player then return nil end
    local fw = FrameworkType or (BCPanel and BCPanel.DetectedFramework) or (BCPanel and BCPanel.Framework) or 'qb'
    if fw == 'qbx' or fw == 'qb' then
        return player.PlayerData and player.PlayerData.source
    end
    return nil
end

local function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return {x=0,y=0,z=0,heading=0} end
    local v = GetEntityCoords(ped)
    return {
        x = math.floor(v.x*100)/100,
        y = math.floor(v.y*100)/100,
        z = math.floor(v.z*100)/100,
        heading = math.floor(GetEntityHeading(ped)*100)/100,
    }
end

local function BuildPlayerInfo(src, player, withCoords)
    local fw = FrameworkType or (BCPanel and BCPanel.DetectedFramework) or (BCPanel and BCPanel.Framework) or 'qb'
    -- QBCore / QBX
    local ci  = player.PlayerData.charinfo  or {}
    local m   = player.PlayerData.money     or {}
    local j   = player.PlayerData.job       or {}
    local info = {
        source      = src,
        name        = GetPlayerName(src) or '',
        citizenid   = player.PlayerData.citizenid or '',
        firstname   = ci.firstname or '',
        lastname    = ci.lastname  or '',
        phone       = ci.phone     or '',
        birthdate   = ci.birthdate or '',
        gender      = ci.gender,
        nationality = ci.nationality or '',
        cash        = m.cash   or 0,
        bank        = m.bank   or 0,
        crypto      = m.crypto or 0,
        job         = j.label  or j.name or '',
        jobGrade    = j.grade and j.grade.name or '',
        ping        = GetPlayerPing(src),
        discord     = GetPlayerIdentifierByType(src, 'discord')  or '',
        discordid   = GetPlayerIdentifierByType(src, 'discord')  or '',
        license     = GetPlayerIdentifierByType(src, 'license')  or '',
        steam       = GetPlayerIdentifierByType(src, 'steam')    or '',
    }
    if withCoords then
        info.coords = PlayerCoordsCache[tostring(src)] or GetPlayerCoords(src)
    end
    -- SHX-SID desteÄŸi: sabit ID varsa ekle
    local hasSid = BCPanel and BCPanel.DetectedStaticID and BCPanel.DetectedStaticID ~= 'none'
    if hasSid then
        local ok, sid = pcall(function()
            return exports['shx-sid']:GetStaticId(src)
        end)
        if ok and sid then
            info.staticId = sid
        end
    end
    return info
end

local function GetAllPlayers()
    local fw = FrameworkType or (BCPanel and BCPanel.DetectedFramework) or (BCPanel and BCPanel.Framework) or 'qb'
    local result = {}
    if fw == 'qbx' then
        pcall(function()
            local core = exports['qbx_core']:GetCoreObject()
            if core and core.Functions and core.Functions.GetQBPlayers then
                result = core.Functions.GetQBPlayers()
            end
        end)
    elseif fw == 'qb' then
        pcall(function()
            local core = exports['qb-core']:GetCoreObject()
            if core and core.Functions and core.Functions.GetQBPlayers then
                result = core.Functions.GetQBPlayers()
            end
        end)
    end
    -- Fallback: hic oyuncu bulunamadiysa GetPlayers ile dene
    if not next(result) then
        for _, playerId in pairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local p = nil
                if fw == 'qbx' then
                    pcall(function() p = exports.qbx_core:GetPlayer(src) end)
                elseif fw == 'qb' then
                    pcall(function()
                        local core = exports['qb-core']:GetCoreObject()
                        p = core.Functions.GetPlayer(src)
                    end)
                end
                if p then result[src] = p end
            end
        end
    end
    return result
end

-- ============================================
-- COMMAND HANDLERS (CMD tablosu)
-- ============================================
local CMD = {}

-- Online oyuncular
CMD['getOnlineUsers'] = function(p)
    local list = {}
    for src, pl in pairs(GetAllPlayers()) do
        if pl then list[#list+1] = BuildPlayerInfo(src, pl, false) end
    end
    return {success=true, players=list, count=#list}
end

-- ============================================
-- SQL TUNNEL (SaaS'ın MySQL yerine doğrudan 
-- FiveM içinden sorgu çalıştırması için)
-- ============================================
CMD['executeSQL'] = function(p)
    if not p or not p.query then
        return {success=false, message='Eksik SQL sorgusu.'}
    end

    local params = p.params or {}

    -- MySQL.query.await: CreateThread / coroutine gerektirmez (FiveM export context'inde çalışır)
    local ok, result = pcall(function()
        return MySQL.query.await(p.query, params)
    end)

    if ok then
        return {success=true, data=result}
    else
        return {success=false, message='SQL Hatasi (FiveM): '..tostring(result)}
    end
end

-- ============================================
-- VDS YÖNETİMİ (Resource işlemleri)
-- ============================================
CMD['getResources'] = function(p)
    local resources = {}
    local num = GetNumResources()
    for i=0, num-1 do
        local name = GetResourceByFindIndex(i)
        if name then
            local state = GetResourceState(name)
            local path = GetResourcePath(name)
            table.insert(resources, {
                name = name,
                state = state,
                path = path
            })
        end
    end
    return {success=true, resources=resources}
end

CMD['startResource'] = function(p)
    if not p or not p.resourceName then return {success=false, message="Eksik kaynak adi"} end
    ExecuteCommand("start " .. p.resourceName)
    return {success=true, message=p.resourceName .. " başlatıldı."}
end

CMD['stopResource'] = function(p)
    if not p or not p.resourceName then return {success=false, message="Eksik kaynak adi"} end
    ExecuteCommand("stop " .. p.resourceName)
    return {success=true, message=p.resourceName .. " durduruldu."}
end

CMD['restartResource'] = function(p)
    if not p or not p.resourceName then return {success=false, message="Eksik kaynak adi"} end
    ExecuteCommand("restart " .. p.resourceName)
    return {success=true, message=p.resourceName .. " yeniden başlatıldı."}
end

CMD['getOnlineUsersWithCoords'] = function(p)
    local list = {}
    for src, pl in pairs(GetAllPlayers()) do
        if pl then list[#list+1] = BuildPlayerInfo(src, pl, true) end
    end
    return {success=true, players=list, count=#list}
end

-- Oyuncu online mi kontrol
CMD['isPlayerOnline'] = function(p)
    if p.citizenid then
        local pl, src = FindPlayerByCitizenId(p.citizenid)
        if pl and src then
            return {success=true, online=true, source=src}
        end
    end
    if p.discordid then
        local pl, src = FindPlayerByDiscord(p.discordid)
        if pl and src then
            return {success=true, online=true, source=src}
        end
    end
    return {success=true, online=false}
end

-- Item islemleri
CMD['giveItem'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    local item   = p.item or p.itemName
    local amount = tonumber(p.amount) or 1
    local ok, err = pcall(function()
        if GetInvSystem() == 'ox_inventory' then
            exports.ox_inventory:AddItem(src, item, amount)
        elseif pl.Functions and pl.Functions.AddItem then
            pl.Functions.AddItem(item, amount)
        end
    end)
    if not ok then return {success=false, message='Item hata: '..tostring(err)} end
    TriggerClientEvent('inventory:client:ItemBox', src, nil, 'add', amount)
    return {success=true, message=item..' x'..amount..' verildi'}
end

CMD['removeItem'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    local item   = p.item or p.itemName
    local amount = tonumber(p.amount) or 1
    local ok, err = pcall(function()
        if GetInvSystem() == 'ox_inventory' then
            exports.ox_inventory:RemoveItem(src, item, amount)
        elseif pl.Functions and pl.Functions.RemoveItem then
            pl.Functions.RemoveItem(item, amount, p.slot)
        end
    end)
    if not ok then return {success=false, message='Item silme hata: '..tostring(err)} end
    TriggerClientEvent('inventory:client:ItemBox', src, nil, 'remove', amount)
    return {success=true, message=item..' x'..amount..' silindi'}
end

CMD['clearInventory'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    local ok, err = pcall(function()
        if GetInvSystem() == 'ox_inventory' then
            exports.ox_inventory:ClearInventory(src)
        elseif pl.Functions and pl.Functions.ClearInventory then
            pl.Functions.ClearInventory()
        end
    end)
    if not ok then return {success=false, message='Envanter temizleme hata: '..tostring(err)} end
    return {success=true, message='Envanter temizlendi'}
end

CMD['getPlayerInventory'] = function(p)
    local pl, src
    if p.citizenid then
        pl, src = FindPlayerByCitizenId(p.citizenid)
    elseif p.source then
        src = tonumber(p.source)
        local fw = FrameworkType or (BCPanel and BCPanel.DetectedFramework) or (BCPanel and BCPanel.Framework) or 'qb'
        if fw == 'qbx' then
            pcall(function() pl = exports.qbx_core:GetPlayer(src) end)
        elseif fw == 'qb' then
            pcall(function()
                local core = exports['qb-core']:GetCoreObject()
                pl = core.Functions.GetPlayer(src)
            end)
        end
    end
    if not pl then return {success=false, message='Oyuncu online degil'} end
    return {success=true, inventory=pl.PlayerData.items or {}, money=pl.PlayerData.money or {}}
end

-- Para
CMD['giveMoney'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    local t = p.moneyType or 'cash'
    local a = tonumber(p.amount) or 0
    if pl.Functions and pl.Functions.AddMoney then
        pl.Functions.AddMoney(t, a, 'bc-web')
    end
    return {success=true, message=t..' '..a..' verildi'}
end

-- Meslek
CMD['setJob'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    if pl.Functions and pl.Functions.SetJob then
        pl.Functions.SetJob(p.jobName, tonumber(p.grade) or 0)
    end
    return {success=true, message='Meslek: '..tostring(p.jobName)}
end

-- Arac
CMD['giveVehicle'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    -- Kalici arac ise DB'ye kaydet
    if not p.temporary then
        pcall(function()
            local plate = 'PANEL'..math.random(100,999)
            QueueQuery('INSERT INTO player_vehicles (citizenid,vehicle,hash,mods,plate,garage,state) VALUES(?,?,?,?,?,?,?)',
                {p.citizenid, p.vehicle, GetHashKey(p.vehicle), '{}', plate, 'pillboxgarage', 0})
        end)
    end
    -- Client-side spawn
    TriggerClientEvent('BC-Web:client:spawnVehicle', src, p.vehicle, nil, nil)
    return {success=true, message='Arac: '..tostring(p.vehicle)}
end

-- Teleport
CMD['teleportPlayer'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    SetEntityCoords(GetPlayerPed(src),
        tonumber(p.x) or 0, tonumber(p.y) or 0, tonumber(p.z) or 0, false,false,false,false)
    return {success=true, message='Isinlandi'}
end

-- Revive
CMD['revivePlayer'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    -- Metadata guncelle
    if pl.Functions and pl.Functions.SetMetaData then
        pcall(function()
            pl.Functions.SetMetaData('health', 200)
            pl.Functions.SetMetaData('armor', 0)
            pl.Functions.SetMetaData('isdead', false)
            pl.Functions.SetMetaData('inlaststand', false)
        end)
    end
    -- Client-side revive events
    TriggerClientEvent('hospital:client:Revive', src)
    TriggerClientEvent('BC-Web:client:healPlayer', src)
    return {success=true, message='Canlandirildi'}
end

-- Heal
CMD['healPlayer'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    if pl.Functions and pl.Functions.SetMetaData then
        pcall(function() pl.Functions.SetMetaData('health', 200) end)
    end
    TriggerClientEvent('BC-Web:client:healPlayer', src, true)
    return {success=true, message='Iyilestirildi'}
end

-- Kill
CMD['killPlayer'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    TriggerClientEvent('BC-Web:client:killPlayer', src)
    return {success=true, message='Olduruldu'}
end

-- PM
CMD['sendPM'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    TriggerClientEvent('chat:addMessage', src, {
        template = '<div class="chat-message panel-message"><b>[PANEL]</b> {0}</div>',
        args = {p.message or ''}
    })
    return {success=true, message='PM gonderildi'}
end

-- Duyuru
CMD['announcement'] = function(p)
    TriggerClientEvent('chat:addMessage', -1, {
        template = '<div class="chat-message announcement"><b>[DUYURU]</b> {0}</div>',
        args = {p.message or ''}
    })
    return {success=true, message='Duyuru gonderildi'}
end

-- Kick
CMD['kickPlayer'] = function(p)
    local pl, src
    if p.citizenid then
        pl, src = FindPlayerByCitizenId(p.citizenid)
    elseif p.discordid then
        pl, src = FindPlayerByDiscord(p.discordid)
    end
    if not pl or not src then return {success=false, message='Oyuncu online degil'} end
    DropPlayer(src, p.reason or 'Panel tarafindan atildiniz')
    return {success=true, message='Kicklendi'}
end

-- Ban
CMD['banPlayer'] = function(p)
    local pl, src
    if p.citizenid then
        pl, src = FindPlayerByCitizenId(p.citizenid)
    elseif p.discordid then
        pl, src = FindPlayerByDiscord(p.discordid)
    end
    if pl and src then
        DropPlayer(src, 'BANNED: '..(p.reason or ''))
    end
    pcall(function()
        QueueQuery("INSERT INTO bans (name,discord,reason,expire,bannedby) VALUES(?,?,?,?,?)",
            {'Panel Ban', p.discordid or p.citizenid or 'unknown', p.reason or 'Panel ban', -1, 'bc-Web'})
    end)
    return {success=true, message='Banlandi'}
end

-- Unban
CMD['unbanPlayer'] = function(p)
    local did = p.discordid or ''
    pcall(function()
        QueueQuery("DELETE FROM bans WHERE discord=? OR discord=?",
            {did, 'discord:'..did:gsub('discord:','')})
    end)
    return {success=true, message='Ban kaldirildi'}
end

-- Kiyafet menusu
CMD['giveClothingMenu'] = function(p)
    local pl, src = FindPlayerByCitizenId(p.citizenid)
    if not pl then return {success=false, message='Oyuncu online degil'} end
    -- client.lua'daki universal clothing handler'i tetikle
    TriggerClientEvent('BC-Web:client:openClothingMenu', src)
    return {success=true, message='Kiyafet menusu acildi'}
end

-- Server uptime
CMD['getServerUptime'] = function()
    return {success=true, uptime=GetGameTimer()/1000}
end

-- Playtime verisi (bakiye odul sistemi icin)
-- bc_playtime tablosundan toplam sure + aktif session suresini hesaplar
-- discordId ile birlikte dondurur
CMD['getPlaytimeData'] = function(p)
    local result = {}
    local now = os.time()

    -- 1) bc_playtime tablosundan tum kayitli sureleri al
    local dbPlaytimes = {}
    pcall(function()
        local rows = QueueQuery('SELECT cid, time FROM bc_playtime WHERE time > 0', {})
        if rows and type(rows) == 'table' then
            for _, row in ipairs(rows) do
                dbPlaytimes[row.cid] = tonumber(row.time) or 0
            end
        end
    end)

    -- 2) Tum online oyuncularin aktif session suresini hesapla
    local onlineSessions = {}
    if type(PlayerSessions) == 'table' then
        for src, session in pairs(PlayerSessions) do
            if session and session.citizenid and session.joinTime then
                local activeMinutes = math.floor((now - session.joinTime) / 60)
                onlineSessions[session.citizenid] = activeMinutes
            end
        end
    end

    -- 3) Tum citizenid'leri topla (DB + online)
    local allCids = {}
    for cid, _ in pairs(dbPlaytimes) do allCids[cid] = true end
    for cid, _ in pairs(onlineSessions) do allCids[cid] = true end

    -- 4) Her citizenid icin discordId bul ve toplam sureyi hesapla
    for cid, _ in pairs(allCids) do
        local dbTime = dbPlaytimes[cid] or 0
        local activeTime = onlineSessions[cid] or 0
        local totalMinutes = dbTime + activeTime

        if totalMinutes > 0 then
            local discordId = nil
            local isOnline = false

            -- Online oyunculardan ara
            if type(PlayerSessions) == 'table' then
                for src, session in pairs(PlayerSessions) do
                    if session and session.citizenid == cid then
                        pcall(function()
                            local did = GetPlayerIdentifierByType(tonumber(src), 'discord')
                            if did then
                                discordId = tostring(did):gsub('discord:', '')
                            end
                        end)
                        isOnline = true
                        break
                    end
                end
            end

            -- Online degilse DB'den ara
            if not discordId then
                pcall(function()
                    local rows = QueueQuery(
                        "SELECT JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.discord')) as discord FROM players WHERE citizenid = ? LIMIT 1",
                        {cid}
                    )
                    if rows and rows[1] and rows[1].discord and rows[1].discord ~= 'null' then
                        discordId = tostring(rows[1].discord):gsub('discord:', '')
                    end
                end)
            end

            if discordId and discordId ~= '' and discordId ~= 'nil' then
                result[#result+1] = {
                    citizenid = cid,
                    discordId = discordId,
                    playTime = totalMinutes,
                    dbTime = dbTime,
                    activeTime = activeTime,
                    isOnline = isOnline,
                }
            end
        end
    end

    return {success=true, players=result, count=#result, timestamp=now}
end

-- Stash
CMD['getStash'] = function(p)
    local data = {}
    pcall(function()
        local r = QueueQuery("SELECT items FROM stashitems WHERE stash=?", {p.stashId or p.citizenid or ''})
        if r and r[1] then data = json.decode(r[1].items) or {} end
    end)
    return {success=true, message=data}
end

-- ============================================
-- GET DATA COMMANDS (Panel Listeler sayfasi icin)
-- ============================================

CMD['getData_vehicles'] = function()
    local vehicles = {}

    -- 1) QBX shared vehicles
    local s, qbxVeh = pcall(function() return require '@qbx_core.shared.vehicles' end)
    if s and qbxVeh and next(qbxVeh) then
        for model, vData in pairs(qbxVeh) do
            vehicles[#vehicles+1] = {
                model = model,
                name = vData.name or model,
                brand = vData.brand or '',
                price = vData.price or 0,
                category = vData.category or '',
                type = vData.type or 'automobile',
                hash = vData.hash and tostring(vData.hash) or nil
            }
        end
        return {success=true, vehicles=vehicles, source='qbx_shared', count=#vehicles}
    end

    -- 2) QBCore.Shared.Vehicles
    if QBCore then
        local s2, qbVeh = pcall(function() return QBCore.Shared.Vehicles end)
        if s2 and qbVeh and next(qbVeh) then
            for model, vData in pairs(qbVeh) do
                vehicles[#vehicles+1] = {
                    model = type(model) == 'string' and model or (vData.model or ''),
                    name = vData.name or tostring(model),
                    brand = vData.brand or '',
                    price = vData.price or 0,
                    category = vData.category or '',
                    type = vData.type or 'automobile',
                    hash = vData.hash and tostring(vData.hash) or nil
                }
            end
            return {success=true, vehicles=vehicles, source='qbcore_shared', count=#vehicles}
        end
    end

    return {success=false, message='Vehicles bulunamadi', vehicles={}}
end

CMD['getData_items'] = function()
    local items = {}

    -- 1) ox_inventory export
    if GetResourceState('ox_inventory') == 'started' then
        local s, oxItems = pcall(function() return exports.ox_inventory:Items() end)
        if s and oxItems and next(oxItems) then
            for k, v in pairs(oxItems) do
                local name = type(k) == 'string' and k or (v.name or '')
                if name ~= '' then
                    items[#items+1] = {
                        name = name,
                        label = v.label or name,
                        weight = v.weight or 0,
                        stack = (v.stack == nil or v.stack == true) and true or false,
                        description = v.description or ''
                    }
                end
            end
            return {success=true, items=items, source='ox_inventory', count=#items}
        end
    end

    -- 2) QBX shared items
    local s2, qbxItems = pcall(function() return require '@qbx_core.shared.items' end)
    if s2 and qbxItems and next(qbxItems) then
        for k, v in pairs(qbxItems) do
            local name = type(k) == 'string' and k or (v.name or '')
            if name ~= '' then
                items[#items+1] = {
                    name = name,
                    label = v.label or name,
                    weight = v.weight or 0,
                    stack = (v.stack == nil or v.stack == true) and true or false,
                    description = v.description or ''
                }
            end
        end
        return {success=true, items=items, source='qbx_shared', count=#items}
    end

    -- 3) QBCore.Shared.Items
    if QBCore then
        local s3, qbItems = pcall(function() return QBCore.Shared.Items end)
        if s3 and qbItems and next(qbItems) then
            for k, v in pairs(qbItems) do
                local name = type(k) == 'string' and k or (v.name or '')
                if name ~= '' then
                    items[#items+1] = {
                        name = name,
                        label = v.label or name,
                        weight = v.weight or 0,
                        stack = (v.stack == nil or v.stack == true) and true or false,
                        description = v.description or ''
                    }
                end
            end
            return {success=true, items=items, source='qbcore_shared', count=#items}
        end
    end

    return {success=false, message='Items bulunamadi', items={}}
end

CMD['getData_jobs'] = function()
    local jobs = {}

    -- 1) QBX shared jobs
    local s, qbxJobs = pcall(function() return require '@qbx_core.shared.jobs' end)
    if s and qbxJobs and next(qbxJobs) then
        for jobName, jobData in pairs(qbxJobs) do
            local grades = {}
            if jobData.grades then
                for gName, gData in pairs(jobData.grades) do
                    grades[gName] = {name=gData.name or gName, payment=gData.payment or 0}
                end
            end
            jobs[#jobs+1] = {name=jobName, label=jobData.label or jobName, grades=grades}
        end
        return {success=true, jobs=jobs, source='qbx_shared', count=#jobs}
    end

    -- 2) qbx_core export
    local s2, jList = pcall(function() return exports.qbx_core:GetJobs() end)
    if s2 and jList and next(jList) then
        for jobName, jobData in pairs(jList) do
            local grades = {}
            if jobData.grades then
                for gName, gData in pairs(jobData.grades) do
                    grades[gName] = {name=gData.name or gName, payment=gData.payment or 0}
                end
            end
            jobs[#jobs+1] = {name=jobName, label=jobData.label or jobName, grades=grades}
        end
        return {success=true, jobs=jobs, source='qbx_export', count=#jobs}
    end

    -- 3) QBCore.Shared.Jobs
    if QBCore then
        local s3, qbJobs = pcall(function() return QBCore.Shared.Jobs end)
        if s3 and qbJobs and next(qbJobs) then
            for jobName, jobData in pairs(qbJobs) do
                local grades = {}
                if jobData.grades then
                    for gName, gData in pairs(jobData.grades) do
                        grades[gName] = {name=gData.name or gName, payment=gData.payment or 0}
                    end
                end
                jobs[#jobs+1] = {name=jobName, label=jobData.label or jobName, grades=grades}
            end
            return {success=true, jobs=jobs, source='qbcore_shared', count=#jobs}
        end
    end

    return {success=false, message='Jobs bulunamadi', jobs={}}
end

-- ============================================
-- COMMAND PROCESSOR
-- ============================================
local function processCommand(row)
    local handler = CMD[row.command]
    if not handler then
        return {success=false, message='Bilinmeyen komut: '..tostring(row.command)}
    end
    local payload = {}
    if row.payload then
        local ok, parsed = pcall(json.decode, row.payload)
        if ok and parsed then payload = parsed end
    end
    return handler(payload)
end

-- ============================================
-- MAIN POLLING LOOP
-- ============================================
local queueAlive = true

CreateThread(function()
    -- Framework ve oxmysql yuklenene kadar bekle
    Wait(8000)

    -- panel_commands tablosunun varligini garanti et
    pcall(function()
        QueueQuery([[
            CREATE TABLE IF NOT EXISTS panel_commands (
                id INT AUTO_INCREMENT PRIMARY KEY,
                command VARCHAR(100) NOT NULL,
                payload TEXT DEFAULT NULL,
                status ENUM('pending','processing','done','error') DEFAULT 'pending',
                result TEXT DEFAULT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                processed_at DATETIME DEFAULT NULL,
                expires_at DATETIME DEFAULT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]], {})
    end)

    print('^2[BC-Web Queue] DB polling aktif | Aralik: '..QUEUE_CFG.pollInterval..'ms | Batch: '..QUEUE_CFG.maxBatch..'^0')

    while queueAlive do
        Wait(QUEUE_CFG.pollInterval)

        local ok, rows = pcall(function()
            return MySQL.query.await(
                "SELECT id, command, payload FROM panel_commands WHERE status='pending' ORDER BY created_at ASC LIMIT ?",
                {QUEUE_CFG.maxBatch}
            )
        end)

        if ok and rows and #rows > 0 then
            for _, row in ipairs(rows) do
                -- Status -> processing
                pcall(function()
                    MySQL.query.await("UPDATE panel_commands SET status='processing' WHERE id=?", {row.id})
                end)

                -- Komutu isle
                local s, res = pcall(processCommand, row)

                if s then
                    pcall(function()
                        MySQL.query.await(
                            "UPDATE panel_commands SET status='done', result=?, processed_at=NOW() WHERE id=?",
                            {json.encode(res), row.id}
                        )
                    end)
                    qdbg(row.command, '#'..row.id, res.success and '^2OK^0' or '^1FAIL^0')
                else
                    pcall(function()
                        MySQL.query.await(
                            "UPDATE panel_commands SET status='error', result=?, processed_at=NOW() WHERE id=?",
                            {json.encode({success=false, message=tostring(res)}), row.id}
                        )
                    end)
                    print('^1[BC-Web Queue] HATA: '..row.command..' #'..row.id..' -> '..tostring(res)..'^0')
                end
            end
        end
    end
end)

-- Temizlik (her cleanupHours saatte bir eski kayitlari sil)
CreateThread(function()
    while queueAlive do
        Wait(QUEUE_CFG.cleanupHours * 3600000)
        pcall(function()
            MySQL.query.await("DELETE FROM panel_commands WHERE created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)", {QUEUE_CFG.cleanupHours})
        end)
        qdbg('Eski kayitlar temizlendi')
    end
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() then queueAlive = false end
end)

print('^2[BC-Web] Command Queue sistemi yuklendi - DB polling ile calisacak^0')


-- ============================================
-- AUTO CACHE: Items, Jobs, Vehicles -> DB
-- FiveM basladiginda otomatik olarak verileri
-- items_cache / job_positions tablolarina yazar
-- Panel bu tablolardan okur (FiveM API gerekmez)
-- ============================================
CreateThread(function()
    -- Framework, ox_inventory vs. yuklensin
    Wait(15000)
    print('^3[BC-Web AutoCache] Veri cache baslaniyor...^0')

    -- ITEMS CACHE
    pcall(function()
        local items = {}

        -- 1) ox_inventory export
        if GetResourceState('ox_inventory') == 'started' then
            local s, oxItems = pcall(function() return exports.ox_inventory:Items() end)
            if s and oxItems and next(oxItems) then
                items = oxItems
                print('^2[BC-Web AutoCache] Items: ox_inventory export OK^0')
            end
        end

        -- 2) QBX shared items
        if not next(items) then
            local s2, qbxItems = pcall(function() return require '@qbx_core.shared.items' end)
            if s2 and qbxItems and next(qbxItems) then
                items = qbxItems
                print('^2[BC-Web AutoCache] Items: qbx_core shared OK^0')
            end
        end

        -- 3) QBCore Shared.Items
        if not next(items) and QBCore then
            local s3, qbItems = pcall(function() return QBCore.Shared.Items end)
            if s3 and qbItems and next(qbItems) then
                items = qbItems
                print('^2[BC-Web AutoCache] Items: QBCore.Shared.Items OK^0')
            end
        end

        if next(items) then
            -- items_cache tablosunu olustur
            QueueQuery([[
                CREATE TABLE IF NOT EXISTS items_cache (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL UNIQUE,
                    label VARCHAR(200) DEFAULT NULL,
                    weight INT DEFAULT 0,
                    stack TINYINT DEFAULT 1,
                    description TEXT DEFAULT NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])
            QueueQuery('DELETE FROM items_cache')

            local count = 0
            if type(items) == 'table' then
                for k, v in pairs(items) do
                    local name = type(k) == 'string' and k or (v.name or '')
                    local label = v.label or name
                    local weight = v.weight or 0
                    local stack = (v.stack == nil or v.stack == true) and 1 or 0
                    local desc = v.description or ''
                    if name ~= '' then
                        QueueQuery('INSERT IGNORE INTO items_cache (name, label, weight, stack, description) VALUES (?, ?, ?, ?, ?)',
                            {name, label, weight, stack, desc})
                        count = count + 1
                    end
                end
            end
            print('^2[BC-Web AutoCache] Items cached: '..count..' adet^0')
        else
            print('^3[BC-Web AutoCache] Items bulunamadi, cache atlandÄ±^0')
        end
    end)

    Wait(1000)

    -- JOBS CACHE
    pcall(function()
        local jobs = {}

        -- 1) QBX shared jobs
        local s, qbxJobs = pcall(function() return require '@qbx_core.shared.jobs' end)
        if s and qbxJobs and next(qbxJobs) then
            jobs = qbxJobs
            print('^2[BC-Web AutoCache] Jobs: qbx_core shared OK^0')
        end

        -- 2) QBX export
        if not next(jobs) then
            local s2, jList = pcall(function() return exports.qbx_core:GetJobs() end)
            if s2 and jList and next(jList) then
                jobs = jList
                print('^2[BC-Web AutoCache] Jobs: qbx_core GetJobs OK^0')
            end
        end

        -- 3) QBCore Shared.Jobs
        if not next(jobs) and QBCore then
            local s3, qbJobs = pcall(function() return QBCore.Shared.Jobs end)
            if s3 and qbJobs and next(qbJobs) then
                jobs = qbJobs
                print('^2[BC-Web AutoCache] Jobs: QBCore.Shared.Jobs OK^0')
            end
        end

        if next(jobs) then
            QueueQuery([[
                CREATE TABLE IF NOT EXISTS job_positions (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL UNIQUE,
                    label VARCHAR(200) NOT NULL,
                    grades TEXT DEFAULT NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])
            QueueQuery('DELETE FROM job_positions')

            local count = 0
            for jobName, jobData in pairs(jobs) do
                local label = jobData.label or jobName
                local gradesJson = '{}'
                if jobData.grades then
                    local ok, encoded = pcall(json.encode, jobData.grades)
                    if ok and type(encoded) == 'string' then gradesJson = encoded end
                end
                QueueQuery('INSERT IGNORE INTO job_positions (name, label, grades) VALUES (?, ?, ?)',
                    {jobName, label, gradesJson})
                count = count + 1
            end
            print('^2[BC-Web AutoCache] Jobs cached: '..count..' adet^0')
        else
            print('^3[BC-Web AutoCache] Jobs bulunamadi, cache atlandÄ±^0')
        end
    end)

    Wait(1000)

    -- VEHICLES -> ox_inventory_items seklinde degil, arac verisi zaten player_vehicles'da
    -- Ama QBX shared vehicles listesini de cache'leyelim
    pcall(function()
        local vehicles = {}

        local s, qbxVeh = pcall(function() return require '@qbx_core.shared.vehicles' end)
        if s and qbxVeh and next(qbxVeh) then
            vehicles = qbxVeh
            print('^2[BC-Web AutoCache] Vehicles: qbx_core shared OK^0')
        end

        if not next(vehicles) and QBCore then
            local s2, qbVeh = pcall(function() return QBCore.Shared.Vehicles end)
            if s2 and qbVeh and next(qbVeh) then
                vehicles = qbVeh
                print('^2[BC-Web AutoCache] Vehicles: QBCore.Shared.Vehicles OK^0')
            end
        end

        if next(vehicles) then
            QueueQuery([[
                CREATE TABLE IF NOT EXISTS vehicles_cache (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    model VARCHAR(100) NOT NULL UNIQUE,
                    name VARCHAR(200) DEFAULT NULL,
                    brand VARCHAR(200) DEFAULT NULL,
                    category VARCHAR(100) DEFAULT NULL,
                    price INT DEFAULT 0,
                    hash VARCHAR(50) DEFAULT NULL,
                    type VARCHAR(50) DEFAULT NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])
            QueueQuery('DELETE FROM vehicles_cache')

            local count = 0
            for model, vData in pairs(vehicles) do
                local name = vData.name or model
                local brand = vData.brand or ''
                local price = vData.price or 0
                local category = vData.category or ''
                local vtype = vData.type or nil
                local vhash = vData.hash and tostring(vData.hash) or nil
                QueueQuery('INSERT IGNORE INTO vehicles_cache (model, name, brand, category, price, hash, type) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    {model, name, brand, category, price, vhash, vtype})
                count = count + 1
            end
            print('^2[BC-Web AutoCache] Vehicles cached: '..count..' adet^0')
        else
            print('^3[BC-Web AutoCache] Vehicles bulunamadi, cache atlandÄ±^0')
        end
    end)

    print('^2[BC-Web AutoCache] Tamamlandi!^0')
end)

-- ============================================
-- EXPORT FOR SOCKET.JS (WebSocket)
-- ============================================
exports('getPanelConfig', function()
    return {
        siteUrl = BCPanel.webPanel,
        apiKey = BCPanel.WebSocketKey or BCPanel.WebAPIKey
    }
end)

exports('handlePanelCommand', function(command, payload)
    local handler = CMD[command]
    if not handler then
        return {success=false, message='Bilinmeyen komut (socket): '..tostring(command)}
    end
    
    local ok, result = pcall(handler, payload or {})
    if ok then
        return result
    else
        return {success=false, message='Lua Hata: '..tostring(result)}
    end
end)
