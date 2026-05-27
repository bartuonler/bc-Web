-- ============================================
-- BC-Web Silah Hasarı Sistemi (Client-side)
-- Oyun içi hasar override - restart gerektirmez
-- Web panelden gelen değerlerle çalışır
-- ============================================

local WeaponDamageEnabled = false
local WeaponDamages = {}    -- { [hash] = { Head = X, Body = X, Arms = X, Legs = X } }
local DefaultDamage = { Head = 1, Body = 1, Arms = 1, Legs = 1 }
local BoneGroups = {}       -- { Head = { [boneId] = true }, Arms = {...}, Legs = {...} }
local lastHealth = 200
local lastArmour = 0

-- Kemik ID'sinden bölge belirle
local function GetHitZone(boneIndex)
    if BoneGroups.Head and BoneGroups.Head[boneIndex] then return 'Head' end
    if BoneGroups.Arms and BoneGroups.Arms[boneIndex] then return 'Arms' end
    if BoneGroups.Legs and BoneGroups.Legs[boneIndex] then return 'Legs' end
    return 'Body'
end

-- Silah hash'ini config'deki WEAPON_XXX formatıyla eşleştir
local weaponHashCache = {}
local function GetWeaponDamageConfig(weaponHash)
    if weaponHashCache[weaponHash] ~= nil then
        return weaponHashCache[weaponHash]
    end

    -- Direkt hash ile dene
    local config = WeaponDamages[weaponHash]
    if config then
        weaponHashCache[weaponHash] = config
        return config
    end

    -- Hash yoksa nil döndür (default damage kullanılacak)
    weaponHashCache[weaponHash] = false
    return false
end

-- Web panelden gelen sync event
RegisterNetEvent('BC-Web:weaponDamage:sync', function(data)
    if not data then return end

    WeaponDamageEnabled = data.enabled == true

    if data.defaultDamage then
        DefaultDamage = data.defaultDamage
    end

    if data.bones then
        -- Bones formatını düzelt (JSON'dan gelince string key olabilir)
        BoneGroups = {}
        for zone, bones in pairs(data.bones) do
            BoneGroups[zone] = {}
            for boneId, v in pairs(bones) do
                BoneGroups[zone][tonumber(boneId)] = true
            end
        end
    end

    -- Silah isimlerini hash'e çevir
    WeaponDamages = {}
    weaponHashCache = {} -- Cache temizle
    if data.weapons then
        for weaponName, dmg in pairs(data.weapons) do
            local hash = GetHashKey(weaponName)
            WeaponDamages[hash] = dmg
        end
    end
end)

-- Spawn olunca config iste
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('BC-Web:weaponDamage:requestSync')
end)

RegisterNetEvent('esx:playerLoaded', function()
    Wait(2000)
    TriggerServerEvent('BC-Web:weaponDamage:requestSync')
end)

-- Resource başlatılınca da config iste
CreateThread(function()
    Wait(3000)
    TriggerServerEvent('BC-Web:weaponDamage:requestSync')
end)

-- ============================================
-- ANA HASAR OVERRIDE SİSTEMİ
-- gameEventTriggered ile hasar algılama
-- ============================================
AddEventHandler('gameEventTriggered', function(eventName, eventData)
    if not WeaponDamageEnabled then return end
    if eventName ~= 'CEventNetworkEntityDamage' then return end

    local victim = eventData[1]
    local attacker = eventData[2]
    local weaponHash = eventData[7]
    local boneIndex = eventData[10]

    -- Sadece oyuncu ped'leri
    if not victim or not DoesEntityExist(victim) then return end
    if not IsPedAPlayer(victim) then return end

    local playerPed = PlayerPedId()

    -- Sadece biz vurulduysak hasar override yap
    if victim ~= playerPed then return end

    -- Silah hasar config'ini al
    local dmgConfig = GetWeaponDamageConfig(weaponHash)
    local damageValues

    if dmgConfig then
        damageValues = dmgConfig
    else
        damageValues = DefaultDamage
    end

    -- Vurulan bölgeyi belirle
    local zone = GetHitZone(boneIndex)
    local customDamage = damageValues[zone] or damageValues.Body or 1

    -- Mevcut can/zırh al
    local currentHealth = GetEntityHealth(playerPed)
    local currentArmour = GetPedArmour(playerPed)

    -- Önce oyunun verdiği hasarı geri al (sağlığı eski haline getir)
    SetEntityHealth(playerPed, lastHealth)
    SetPedArmour(playerPed, lastArmour)

    -- Şimdi custom hasarı uygula
    local remainingDamage = customDamage

    -- Önce zırhtan düş
    if lastArmour > 0 and remainingDamage > 0 then
        local armourDamage = math.min(lastArmour, remainingDamage)
        SetPedArmour(playerPed, lastArmour - armourDamage)
        remainingDamage = remainingDamage - armourDamage
        lastArmour = lastArmour - armourDamage
    end

    -- Kalan hasar candan düş
    if remainingDamage > 0 then
        local newHealth = math.max(100, lastHealth - remainingDamage) -- 100 = ölü (GTA health offset)
        SetEntityHealth(playerPed, newHealth)
        lastHealth = newHealth
    end
end)

-- Can/zırh takibi (her frame değil, 200ms arayla)
CreateThread(function()
    while true do
        Wait(200)
        if WeaponDamageEnabled then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                lastHealth = GetEntityHealth(ped)
                lastArmour = GetPedArmour(ped)
            end
        else
            Wait(2000) -- Sistem kapalıysa daha az kontrol
        end
    end
end)

print('[BC-Web] Silah Hasari client yuklendi')
