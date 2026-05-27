-- ============================================
-- BC-Web Silah Hasarı Sistemi (Server-side)
-- Web panelden silah hasarlarını çeker, client'lara dağıtır
-- Restart gerektirmez - otomatik güncelleme
-- ============================================

local WeaponConfig = {
    enabled = false,
    defaultDamage = { Head = 1, Body = 1, Arms = 1, Legs = 1 },
    weapons = {},
    lastUpdate = 0
}

local UPDATE_INTERVAL = 30 -- 30 saniyede bir web panelden güncelle (saniye)

-- Kemik Hash Değerleri
local BoneGroups = {
    Head = {
        [31086] = true, -- SKEL_Head
        [39317] = true, -- SKEL_Neck_1
    },
    Arms = {
        [11816] = true, -- SKEL_L_Clavicle
        [58271] = true, -- SKEL_L_UpperArm
        [61320] = true, -- SKEL_L_Forearm
        [22711] = true, -- SKEL_L_Hand
        [10706] = true, -- SKEL_R_Clavicle
        [40269] = true, -- SKEL_R_UpperArm
        [28252] = true, -- SKEL_R_Forearm
        [36864] = true, -- SKEL_R_Hand
    },
    Legs = {
        [14201] = true, -- SKEL_L_Thigh
        [2108]  = true, -- SKEL_L_Calf
        [65245] = true, -- SKEL_L_Foot
        [43536] = true, -- SKEL_R_Thigh
        [51200] = true, -- SKEL_R_Calf
        [63931] = true, -- SKEL_R_Foot
    }
}

-- Web panelden silah hasarlarını çek
local function FetchWeaponDamages()
    if not BCPanel or not BCPanel.webPanel or not BCPanel.WebAPIKey then
        return
    end

    local url = BCPanel.webPanel
    -- URL sonundaki / temizle
    if url:sub(-1) == '/' then url = url:sub(1, -2) end
    url = url .. '/api/fivem/weapon-damages?apiKey=' .. BCPanel.WebAPIKey

    PerformHttpRequest(url, function(statusCode, responseText, headers)
        if statusCode ~= 200 then
            if BCPanel.Debug then
                print('^1[BC-Web WeaponDamage] API hatasi: HTTP ' .. tostring(statusCode) .. '^0')
            end
            return
        end

        local ok, data = pcall(json.decode, responseText)
        if not ok or not data then
            if BCPanel.Debug then
                print('^1[BC-Web WeaponDamage] JSON parse hatasi^0')
            end
            return
        end

        local prevEnabled = WeaponConfig.enabled
        WeaponConfig.enabled = data.enabled == true
        WeaponConfig.defaultDamage = data.defaultDamage or { Head = 1, Body = 1, Arms = 1, Legs = 1 }
        WeaponConfig.weapons = data.weapons or {}
        WeaponConfig.lastUpdate = os.time()

        -- Tüm online oyunculara güncel config'i gönder
        TriggerClientEvent('BC-Web:weaponDamage:sync', -1, {
            enabled = WeaponConfig.enabled,
            defaultDamage = WeaponConfig.defaultDamage,
            weapons = WeaponConfig.weapons,
            bones = BoneGroups,
        })

        if BCPanel.Debug or (prevEnabled ~= WeaponConfig.enabled) then
            local weaponCount = 0
            for _ in pairs(WeaponConfig.weapons) do weaponCount = weaponCount + 1 end
            print('^2[BC-Web WeaponDamage] Guncellendi: ' .. (WeaponConfig.enabled and 'ACIK' or 'KAPALI') .. ' | ' .. weaponCount .. ' silah^0')
        end
    end, 'GET', '', { ['Content-Type'] = 'application/json' })
end

-- Oyuncu bağlandığında güncel config'i gönder
RegisterNetEvent('BC-Web:weaponDamage:requestSync', function()
    local src = source
    TriggerClientEvent('BC-Web:weaponDamage:sync', src, {
        enabled = WeaponConfig.enabled,
        defaultDamage = WeaponConfig.defaultDamage,
        weapons = WeaponConfig.weapons,
        bones = BoneGroups,
    })
end)

-- Periyodik güncelleme
CreateThread(function()
    Wait(5000) -- Sunucu başlatılınca 5 sn bekle
    while true do
        FetchWeaponDamages()
        Wait(UPDATE_INTERVAL * 1000)
    end
end)

print('^2[BC-Web] Silah Hasari sistemi yuklendi (30sn arayla web panelden guncellenir)^0')
