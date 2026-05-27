
-- Framework Detection (Client-side)
local FrameworkType = nil
local QBCore = nil

if GetResourceState('qbx_core') == 'started' then
    FrameworkType = 'qbx'
    QBCore = exports.qbx_core
elseif GetResourceState('qb-core') == 'started' then
    FrameworkType = 'qb'
    QBCore = exports['qb-core']:GetCoreObject()
else
    FrameworkType = 'standalone'
    -- Fallback: QBCore'u nil bırak, kullanımdan önce kontrol edilecek
    QBCore = nil
end

local Blips = {}
local Stashs = {}
local PlayerData = nil
local PlayerJob = nil
local PlayerGang = nil
local currentStash = false

local function loads()
    TriggerServerEvent('BC-Web:server:getBlips')
    TriggerServerEvent('BC-Web:server:getStashs')
    TriggerServerEvent('BC-Web:server:startTimer')
end

local function generateBlips()
    for i = 1, #Blips do
        local blip = AddBlipForCoord(Blips[i].x, Blips[i].y, Blips[i].z)
        SetBlipSprite(blip, Blips[i].bliptype)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, tonumber(Blips[i].scale * 1.0))
        SetBlipColour(blip, Blips[i].color)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Blips[i].name)
        EndTextCommandSetBlipName(blip)
        Blips[i].blip = blip

    end
end

-- CANLI HARİTA: Oyuncu koordinatlarını server'a gönder
local lastCoordsUpdate = 0
local lastSentCoords = vector3(0, 0, 0)
CreateThread(function()
    while true do
        Wait(5000) -- 5 SANİYE - 500 oyuncuda sunucu yükü azaltılır
        local ped = PlayerPedId()
        if ped and ped > 0 then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            -- Sadece 5 metreden fazla hareket ettiyse gönder (gereksiz event azaltır)
            local dist = #(coords - lastSentCoords)
            if dist > 5.0 then
                TriggerServerEvent('BC-Web:server:updatePlayerCoords', coords.x, coords.y, coords.z, heading)
                lastSentCoords = coords
            end
        end
    end
end)

-- ⚡ CANLI HARİTA: POV Canlı Video Stream Sistemi (ULTRA OPTİMİZE - Oyuncuyu HİÇ etkilemez)
-- Screenshot çok nadir alınır (60 saniyede bir) + Cache sistemi ile optimize
local povActive = false
local povStreamThread = nil
local povStreamInterval = 60000 -- ⚡ 60 SANİYE - Minimal screenshot alma (oyuncuyu HİÇ etkilemez)
local lastScreenshotTime = 0 -- Son screenshot zamanı

-- ⚡ CANLI VİDEO STREAM: Render Target ile optimize screenshot alma (oyuncuyu etkilemez, akıcı video)
-- UI gizlenmez, oyuncu normal oyununu oynar, sadece screenshot alınır
-- ⚡ PAKET BOYUTU KONTROLÜ: Screenshot boyutunu sınırla (serialization hatası önleme)
local function takeScreenshotOptimized(callback)
    -- 1. screenshot-basic (en yaygın) - RENDER TARGET ile optimize
    if GetResourceState('screenshot-basic') == 'started' then
        local ok, err = pcall(function()
            exports['screenshot-basic']:requestScreenshot(function(data)
                if data and callback then
                    -- ⚡ PAKET BOYUTU KONTROLÜ: 30KB'den büyükse reddet (ULTRA KÜÇÜK paket = lag yok)
                    if type(data) == 'string' and string.len(data) > 30000 then
                        print("^3[BC-Web] Screenshot çok büyük (" .. string.len(data) .. " bytes), reddediliyor...^7")
                        return
                    end
                    callback(data)
                end
            end, {
                encoding = 'base64',
                quality = 0.03, -- ⚡ ULTRA DÜŞÜK KALİTE - Minimal paket boyutu (30KB), lag yok
                hideHud = false, -- ⚡ UI gizlenmez - oyuncu UI'ını kaybetmez
                hideMinimap = false, -- ⚡ Minimap gizlenmez
                hideChat = false, -- ⚡ Chat gizlenmez
                renderTarget = true -- ⚡ RENDER TARGET - Daha hızlı, lag yok
            })
        end)
        if ok then return true end
    end
    
    -- 2. screenshot-core - RENDER TARGET ile optimize
    if GetResourceState('screenshot-core') == 'started' then
        local ok, err = pcall(function()
            exports['screenshot-core']:requestScreenshot(function(data)
                if data and callback then
                    -- ⚡ PAKET BOYUTU KONTROLÜ: 30KB'den büyükse reddet
                    if type(data) == 'string' and string.len(data) > 30000 then
                        print("^3[BC-Web] Screenshot çok büyük (" .. string.len(data) .. " bytes), reddediliyor...^7")
                        return
                    end
                    callback(data)
                end
            end, {
                encoding = 'base64',
                quality = 0.03, -- ⚡ ULTRA DÜŞÜK KALİTE - Minimal paket boyutu (30KB)
                hideHud = false,
                hideMinimap = false,
                hideChat = false,
                renderTarget = true -- ⚡ RENDER TARGET - Daha hızlı, lag yok
            })
        end)
        if ok then return true end
    end
    
    -- 3. screenshot (Standart FiveM)
    local ok, err = pcall(function()
        if exports.screenshot then
            exports.screenshot:requestScreenshot(function(data)
                if data and callback then
                    -- ⚡ PAKET BOYUTU KONTROLÜ: 50KB'den büyükse reddet
                    if type(data) == 'string' and string.len(data) > 50000 then
                        print("^3[BC-Web] Screenshot çok büyük (" .. string.len(data) .. " bytes), reddediliyor...^7")
                        return
                    end
                    callback(data)
                end
            end, {
                encoding = 'base64',
                quality = 0.05 -- ⚡ ULTRA DÜŞÜK KALİTE - Minimal paket boyutu
            })
            return true
        end
    end)
    if ok then return true end
    
    -- 4. Fallback: Tüm screenshot resource'larını tara
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if GetResourceState(resourceName) == 'started' then
            local lowerName = string.lower(resourceName)
            if string.find(lowerName, 'screenshot') then
                local ok, err = pcall(function()
                    if exports[resourceName] and exports[resourceName].requestScreenshot then
                        exports[resourceName]:requestScreenshot(function(data)
                            if data and callback then
                                -- ⚡ PAKET BOYUTU KONTROLÜ: 50KB'den büyükse reddet
                                if type(data) == 'string' and string.len(data) > 50000 then
                                    print("^3[BC-Web] Screenshot çok büyük (" .. string.len(data) .. " bytes), reddediliyor...^7")
                                    return
                                end
                                callback(data)
                            end
                        end, {
                            encoding = 'base64',
                            quality = 0.05 -- ⚡ ULTRA DÜŞÜK KALİTE - Minimal paket boyutu
                        })
                        return true
                    end
                end)
                if ok then return true end
            end
        end
    end
    
    return false
end

RegisterNetEvent('BC-Web:client:startPOV', function()
    -- POV removed
end)

RegisterNetEvent('BC-Web:client:stopPOV', function()
    -- POV removed
    -- print("^3[BC-Web] POV durduruldu^7") -- DEVRE DIŞI
end)

-- Tek seferlik screenshot isteği (web panel'den istek geldiğinde)
RegisterNetEvent('BC-Web:client:requestScreenshot', function()
    takeScreenshotOptimized(function(screenshotData)
        if screenshotData and type(screenshotData) == 'string' and string.len(screenshotData) > 0 then
            if string.len(screenshotData) > 30000 then
                print("^3[BC-Web] Screenshot çok büyük, gönderilmiyor (Boyut: " .. string.len(screenshotData) .. " bytes)^7")
                return
            end
            TriggerServerEvent('BC-Web:server:receivePOVScreenshot', screenshotData)
            lastScreenshotTime = GetGameTimer()
        end
    end)
end)

-- Araç spawn event'i (Web Panel'den) - Framework uyumlu
RegisterNetEvent('BC-Web:client:spawnVehicle', function(vehicle, plate, mods)
    if not vehicle or vehicle == '' then
        print("^1[BC-Web] Hata: Araç modeli boş!^7")
        return
    end
    
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        print("^1[BC-Web] Hata: Ped bulunamadı!^7")
        return
    end
    
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Araç modelini yükle
    local vehicleHash = GetHashKey(vehicle)
    if not IsModelInCdimage(vehicleHash) then
        print("^1[BC-Web] Hata: Araç modeli geçersiz: " .. vehicle .. "^7")
        if FrameworkType == 'qbx' and exports.qbx_core then
            exports.qbx_core:Notify("Araç modeli geçersiz: " .. vehicle, "error")
        elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify("Araç modeli geçersiz: " .. vehicle, "error")
        end
        return
    end
    
    RequestModel(vehicleHash)
    
    local timeout = 0
    while not HasModelLoaded(vehicleHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(vehicleHash) then
        print("^1[BC-Web] Hata: Araç modeli yüklenemedi: " .. vehicle .. "^7")
        if FrameworkType == 'qbx' and exports.qbx_core then
            exports.qbx_core:Notify("Araç modeli yüklenemedi!", "error")
        elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify("Araç modeli yüklenemedi!", "error")
        end
        return
    end
    
    -- Araç spawn et
    local veh = CreateVehicle(vehicleHash, coords.x + 2.0, coords.y + 2.0, coords.z, heading, true, false)
    if not veh or veh == 0 then
        print("^1[BC-Web] Hata: Araç spawn edilemedi!^7")
        SetModelAsNoLongerNeeded(vehicleHash)
        return
    end
    
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetModelAsNoLongerNeeded(vehicleHash)
    
    -- Plaka ayarla (plaka yoksa oluştur)
    local finalPlate = plate
    if not finalPlate or finalPlate == '' then
        finalPlate = string.upper(string.sub(tostring(math.random(10000000, 99999999)), 1, 8))
    end
    SetVehicleNumberPlateText(veh, finalPlate)
    
    -- Modları uygula (renk, motor, fren, şanzıman, süspansiyon, vb.)
    if mods and type(mods) == 'table' then
        SetVehicleModKit(veh, 0)
        
        -- Renk
        if mods.color1 ~= nil or mods.color2 ~= nil then
            SetVehicleColours(veh, tonumber(mods.color1) or 0, tonumber(mods.color2) or 0)
        end
        
        -- Performance modları
        if mods.engine ~= nil then
            SetVehicleMod(veh, 11, tonumber(mods.engine) or 0, false)
        end
        if mods.brakes ~= nil then
            SetVehicleMod(veh, 12, tonumber(mods.brakes) or 0, false)
        end
        if mods.transmission ~= nil then
            SetVehicleMod(veh, 13, tonumber(mods.transmission) or 0, false)
        end
        if mods.suspension ~= nil then
            SetVehicleMod(veh, 15, tonumber(mods.suspension) or 0, false)
        end
        
        -- Görsel modlar (random modlar)
        if mods.spoilers ~= nil then
            SetVehicleMod(veh, 0, tonumber(mods.spoilers) or 0, false)
        end
        if mods.sideskirt ~= nil then
            SetVehicleMod(veh, 3, tonumber(mods.sideskirt) or 0, false)
        end
        if mods.hood ~= nil then
            SetVehicleMod(veh, 7, tonumber(mods.hood) or 0, false)
        end
        if mods.grille ~= nil then
            SetVehicleMod(veh, 6, tonumber(mods.grille) or 0, false)
        end
        if mods.frontwheels ~= nil then
            SetVehicleMod(veh, 23, tonumber(mods.frontwheels) or 0, false)
        end
        if mods.backwheels ~= nil then
            SetVehicleMod(veh, 24, tonumber(mods.backwheels) or 0, false)
        end
        
        print("^2[BC-Web] Araç modları uygulandı (Renk: " .. tostring(mods.color1) .. ", Motor: " .. tostring(mods.engine) .. ", Fren: " .. tostring(mods.brakes) .. ", Şanzıman: " .. tostring(mods.transmission) .. ", Süspansiyon: " .. tostring(mods.suspension) .. ")^7")
    end
    
    -- Oyuncuyu araca bindir
    TaskWarpPedIntoVehicle(ped, veh, -1)
    
    -- Anahtar verme - ÖNCE ENTITY İLE DENE (admin menü gibi - daha güvenilir)
    if veh and veh > 0 then
        -- Araç spawn olsun ve network sync olsun diye bekle
        Wait(5000) -- 5 saniye bekle (GetVehiclesFromPlate ve entity sync için gerekli - artırıldı)
        
        -- Plaka'yı tekrar kontrol et (sync için)
        local actualPlate = GetVehicleNumberPlateText(veh)
        if actualPlate and actualPlate ~= '' then
            finalPlate = actualPlate
        end
        
        local netId = VehToNet(veh)
		
        -- JG Advanced Garages kuruluysa aracı "outside vehicle" olarak kaydet
        if GarageSystem == 'jg_garages' then
            TriggerServerEvent('BC-Web:server:registerOutsideVehicle', finalPlate, netId)
        end
		
        -- 1. ÖNCELİK: qbx_vehiclekeys varsa direkt client-side export dene (en güvenilir)
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            local success = pcall(function()
                if exports.qbx_vehiclekeys and exports.qbx_vehiclekeys.GiveKeys then
                    exports.qbx_vehiclekeys:GiveKeys(PlayerId(), veh)
                    print("^2[BC-Web] Anahtar verildi: qbx_vehiclekeys (Client-side Direct Export, Veh: " .. veh .. ", Plate: " .. finalPlate .. ")^7")
                    return true
                end
                return false
            end)
            
            if success then
                -- Başarılı, bildirim gönder
                if FrameworkType == 'qbx' and exports.qbx_core then
                    exports.qbx_core:Notify("Araç anahtarları verildi! Plaka: " .. finalPlate, "success")
                elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
                    QBCore.Functions.Notify("Araç anahtarları verildi! Plaka: " .. finalPlate, "success")
                end
            else
                -- Client-side başarısız, server-side'a gönder (entity ile)
                TriggerServerEvent('BC-Web:server:giveVehicleKeysByEntity', netId, finalPlate)
                print("^3[BC-Web] Anahtar verme isteği server-side'a gönderildi (Entity NetId: " .. netId .. ", Plate: " .. finalPlate .. ")^7")
            end
        else
            -- qbx_vehiclekeys yoksa plaka ile server-side'a gönder
            Wait(1000) -- Plaka sync olsun
            TriggerServerEvent('BC-Web:server:giveVehicleKeys', finalPlate, vehicle)
            print("^3[BC-Web] Anahtar verme isteği server-side'a gönderildi (Plate: " .. finalPlate .. ")^7")
        end
    end
    
    -- Framework uyumlu bildirim
    if FrameworkType == 'qbx' and exports.qbx_core then
        exports.qbx_core:Notify("Araç spawn edildi! Plaka: " .. finalPlate, "success")
    elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify("Araç spawn edildi! Plaka: " .. finalPlate, "success")
    end
end)

-- Heal Player Event (Server'dan)
RegisterNetEvent('BC-Web:client:healPlayer', function(onlyHealth)
    local ped = PlayerPedId()
    if ped and ped > 0 then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        -- Zırh verme - sadece can ver (onlyHealth true ise)
        if not onlyHealth then
            SetPedArmour(ped, 100)
        end
        
        -- Framework uyumlu bildirim
        if FrameworkType == 'qbx' and exports.qbx_core then
            exports.qbx_core:Notify("Heal edildiniz!", "success")
        elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify("Heal edildiniz!", "success")
        end
    end
end)

-- Kill Player Event (Server'dan) - ÇOK BASIT
RegisterNetEvent('BC-Web:client:killPlayer', function()
    local ped = PlayerPedId()
    if ped and ped > 0 then
        SetEntityHealth(ped, 0)
        SetPedArmour(ped, 0)
        
        -- Framework-specific kill events (opsiyonel - ek güvenlik için)
        if FrameworkType == 'qbx' or FrameworkType == 'qb' then
            TriggerEvent('hospital:client:KillPlayer')
            TriggerEvent('qbx_medical:client:kill')
            TriggerEvent('qb-ambulancejob:client:kill')
        end
    end
end)

local function onStashListener()
    CreateThread(function()
        while currentStash do
            if IsControlJustPressed(0, 38) then
                -- Framework uyumlu key press
                if FrameworkType == 'qbx' then
                    exports.qbx_core:KeyPressed()
                else
                    exports['qb-core']:KeyPressed()
                end
                
                if (currentStash.type == "job" and PlayerJob.name == currentStash.job) or (currentStash.type == "gang" and PlayerGang.name == currentStash.job) or (not currentStash.type or currentStash.type == "kisisel" or currentStash.job == "none") then
                    local stashname = "bscript_"..PlayerData.citizenid
                    if currentStash.type and currentStash.job ~= "none" then
                        stashname = "bscript_"..currentStash.type.."_"..currentStash.job.."_"..string.gsub(currentStash.name, " ", "_")
                    end
                    
                    -- Framework uyumlu bildirim
                    if FrameworkType == 'qbx' and exports.qbx_core then
                        exports.qbx_core:Notify("Depoya erişiliyor.", "success")
                    elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
                        QBCore.Functions.Notify("Depoya erişiliyor.", "success")
                    end
                    
                    if BCPanel.oxInventory then
                        exports.ox_inventory:openInventory('stash', {id=stashname, owner=false})
                    else
                        TriggerServerEvent('BC-Web:server:openStash',stashname,BCPanel.Stash)
                    end
                else
                    -- Framework uyumlu hata bildirimi
                    if FrameworkType == 'qbx' and exports.qbx_core then
                        exports.qbx_core:Notify("Bu depoya erişimin yok.", "error")
                    elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
                        QBCore.Functions.Notify("Bu depoya erişimin yok.", "error")
                    end
                end
                currentStash = nil
            end
            Wait(1)
        end
    end)
end

local function generateStashs()
    for i = 1, #Stashs do
        local v = Stashs[i]
        v.poly = BoxZone:Create(
            vector3(v.x,v.y,v.z), 1.5, 2.5, {
            name="bscriptStash"..v.name,
            debugPoly = true,
            heading = v.w,
            minZ = v.z - 1,
            maxZ = v.z + 1,
        })
        v.poly:onPlayerInOut(function(isPointInside)
            if isPointInside then
                -- Framework uyumlu text draw
                if FrameworkType == 'qbx' and exports.qbx_core then
                    exports.qbx_core:DrawText("[E] - Depo", 'left')
                elseif FrameworkType == 'qb' and exports['qb-core'] then
                    exports['qb-core']:DrawText("[E] - Depo", 'left')
                end
                currentStash = v
                onStashListener()
            else
                -- Framework uyumlu text hide
                if FrameworkType == 'qbx' and exports.qbx_core then
                    exports.qbx_core:HideText()
                elseif FrameworkType == 'qb' and exports['qb-core'] then
                    exports['qb-core']:HideText()
                end
                currentStash = nil
            end
        end)
    end
end

RegisterNetEvent('BC-Web:client:updateBlips',function(data)
    for i=1,#Blips do
        RemoveBlip(Blips[i].blip)
    end
    Blips = data
    generateBlips()
end)

RegisterNetEvent('BC-Web:client:updateStashs',function(data)
    for i=1,#Stashs do
        Stashs[i].poly:destroy()
    end
    Stashs = data
    generateStashs()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    for i=1,#Blips do
        RemoveBlip(Blips[i].blip)
    end
end)

RegisterCommand('load',function()
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    loads()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate',function(gang)
    PlayerGang = gang
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
end)

-- OTOMATIK CLOTHING SCRIPT ALGILAMA
-- Tüm resource'ları tarayıp clothing script'ini bulur
RegisterNetEvent('BC-Web:client:openClothingMenu', function()
    local numResources = GetNumResources()
    local clothingResource = nil
    local clothingMethod = nil
    local clothingExport = nil
    
    -- Pattern'ler (appearance, clothing, cloth, skin, outfit, character)
    local patterns = {'appearance', 'clothing', 'cloth', 'skin', 'outfit', 'character'}
    
    -- Öncelik sırası (illenium-appearance önerilen)
    local priorityPatterns = {'illenium-appearance', 'illenium_appearance', 'fivem-appearance', 'fivem_appearance', 'qbx_clothing', 'qb-clothing', 'qb_clothing', 'cd_clothing', 'esx_clotheshop', 'esx_skin'}
    
    -- Önce öncelikli scriptleri kontrol et
    for _, priorityPattern in ipairs(priorityPatterns) do
        for i = 0, numResources - 1 do
            local resourceName = GetResourceByFindIndex(i)
            if GetResourceState(resourceName) == 'started' and string.match(string.lower(resourceName), string.lower(priorityPattern)) then
                -- Export kontrolü
                local exportNames = {'openClothingMenu', 'openMenu', 'open', 'openClothing', 'openCharacter'}
                for _, exportName in ipairs(exportNames) do
                    local success = pcall(function()
                        if exports[resourceName] and exports[resourceName][exportName] then
                            return true
                        end
                        return false
                    end)
                    
                    if success then
                        clothingResource = resourceName
                        clothingMethod = 'export'
                        clothingExport = exportName
                        break
                    end
                end
                
                -- Export yoksa event bazlı
                if not clothingResource then
                    clothingResource = resourceName
                    clothingMethod = 'event'
                end
                
                if clothingResource then break end
            end
        end
        if clothingResource then break end
    end
    
    -- Öncelikli scriptlerde bulunamadıysa, tüm resource'ları tara
    if not clothingResource then
        for i = 0, numResources - 1 do
            local resourceName = GetResourceByFindIndex(i)
            if GetResourceState(resourceName) == 'started' then
                local lowerName = string.lower(resourceName)
                
                -- Pattern matching
                local matches = false
                for _, pattern in ipairs(patterns) do
                    if string.match(lowerName, pattern) then
                        matches = true
                        break
                    end
                end
                
                if matches then
                    -- Export kontrolü
                    local exportNames = {'openClothingMenu', 'openMenu', 'open', 'openClothing', 'openCharacter'}
                    for _, exportName in ipairs(exportNames) do
                        local success = pcall(function()
                            if exports[resourceName] and exports[resourceName][exportName] then
                                return true
                            end
                            return false
                        end)
                        
                        if success then
                            clothingResource = resourceName
                            clothingMethod = 'export'
                            clothingExport = exportName
                            break
                        end
                    end
                    
                    -- Export yoksa event bazlı
                    if not clothingResource then
                        clothingResource = resourceName
                        clothingMethod = 'event'
                    end
                    
                    if clothingResource then break end
                end
            end
        end
    end
    
    local opened = false
    local openedMethod = nil
    
    -- Algılanan script'i kullan
    if clothingResource then
        if clothingMethod == 'export' and clothingExport then
            -- tgiann-clothing: openMenu export'u parametre ister (https://tgiann.gitbook.io/tgiann/scripts/tgiann-clothing/events-exports)
            local resourceLower = string.lower(clothingResource)
            local isTgiannClothing = (string.find(resourceLower, "tgiann") and string.find(resourceLower, "clothing"))
            
            local success = false
            if isTgiannClothing and clothingExport == "openMenu" then
                success = pcall(function()
                    if exports[clothingResource] and exports[clothingResource][clothingExport] then
                        -- allowedMenus: [0]=Yüz, [1]=Kıyafet, [2]=Berber, [3]=Makyaj, [4]=Dövme - hepsi açık; adminMode=true
                        exports[clothingResource][clothingExport]({
                            allowedMenus = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true },
                            clotheList = nil,
                            adminMode = true
                        })
                        return true
                    end
                    return false
                end)
            else
                -- Diğer scriptler (qb-clothing, fivem-appearance vb.) parametresiz export
                success = pcall(function()
                    if exports[clothingResource] and exports[clothingResource][clothingExport] then
                        exports[clothingResource][clothingExport]()
                        return true
                    end
                    return false
                end)
            end
            
            if success then
                opened = true
                openedMethod = clothingResource .. " (Export: " .. clothingExport .. ")"
                print("^2[BC-Web] Kıyafet Menüsü: " .. openedMethod .. "^7")
            end
        end
        
        -- Export başarısızsa event'leri dene
        if not opened then
            -- Yaygın event pattern'lerini dene
            local eventPatterns = {
                clothingResource .. ':client:openClothingMenu',
                clothingResource .. ':client:openMenu',
                clothingResource .. ':openMenu',
                clothingResource .. ':openClothingMenu',
                clothingResource .. ':open'
            }
            
            for _, eventName in ipairs(eventPatterns) do
                TriggerEvent(eventName)
                Wait(50) -- Event işlensin
            end
            
            opened = true
            openedMethod = clothingResource .. " (Event)"
            print("^2[BC-Web] Kıyafet Menüsü: " .. openedMethod .. "^7")
        end
    end
    
    -- Hiçbir script bulunamadıysa, tüm yaygın event'leri dene (fallback)
    if not opened then
        local fallbackEvents = {
            'qb-clothing:client:openMenu',
            'qb-clothing:client:openClothingMenu',
            'illenium-appearance:client:openClothingMenu',
            'illenium-appearance:client:openMenu',
            'fivem-appearance:client:openClothingMenu',
            'fivem-appearance:client:openMenu',
            'tgiann-clothing:client:openClothingMenu',
            'tgiann-clothing:client:openMenu',
            'qbx_clothing:client:openMenu',
            'qbx_clothing:client:openClothingMenu'
        }
        
        for _, eventName in ipairs(fallbackEvents) do
            TriggerEvent(eventName)
            Wait(50)
        end
        
        print("^3[BC-Web] Kıyafet Menüsü: Tüm event'ler denendi (fallback)^7")
    end
    
    -- Bildirim göster
    if FrameworkType == 'qbx' and exports.qbx_core then
        if opened and openedMethod then
            exports.qbx_core:Notify("Kıyafet menüsü açıldı! (" .. openedMethod .. ")", "success")
        else
            exports.qbx_core:Notify("Kıyafet menüsü açılamadı! Uyumlu script bulunamadı.", "error")
        end
    elseif QBCore and QBCore.Functions and QBCore.Functions.Notify then
        if opened and openedMethod then
            QBCore.Functions.Notify("Kıyafet menüsü açıldı! (" .. openedMethod .. ")", "success")
        else
            QBCore.Functions.Notify("Kıyafet menüsü açılamadı! Uyumlu script bulunamadı.", "error")
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if FrameworkType == 'qbx' then
        -- QBX
        PlayerData = exports.qbx_core:GetPlayerData()
        PlayerJob = PlayerData.job
        PlayerGang = PlayerData.gang
        loads()
    else
        -- QBCore
        if QBCore and QBCore.Functions and QBCore.Functions.GetPlayerData then
            QBCore.Functions.GetPlayerData(function(PlayerDatas)
                PlayerData = PlayerDatas
                PlayerJob = PlayerData.job
                PlayerGang = PlayerData.gang
                loads()
            end)
        end
    end
end)