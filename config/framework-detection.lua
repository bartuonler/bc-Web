
local FrameworkDetection = {}

-- Framework algılama
function FrameworkDetection.DetectFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbx', exports.qbx_core:GetCoreObject()
    elseif GetResourceState('qb-core') == 'started' then
        return 'qb', exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx', exports['es_extended']:getSharedObject()
    else
        return 'standalone', nil
    end
end

-- Envanter sistemi algılama (Export Tabanlı - Lisanslı Scriptler İçin)
function FrameworkDetection.DetectInventory()
    local numResources = GetNumResources()
    
    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if GetResourceState(resourceName) == 'started' then
            -- Export fonksiyonlarına göre algıla (lisans güvenli)
            
            -- OX Inventory - Search, AddItem exports
            local hasOxExports = pcall(function()
                return exports[resourceName].Search ~= nil or exports[resourceName].AddItem ~= nil
            end)
            if hasOxExports then
                print("^2[BC-Web] Envanter algılandı: OX Inventory (" .. resourceName .. ")^0")
                return 'ox_inventory', resourceName
            end
            
            -- Codem Inventory - OpenInventory export
            local hasCodemExports = pcall(function()
                return exports[resourceName].OpenInventory ~= nil
            end)
            if hasCodemExports then
                print("^2[BC-Web] Envanter algılandı: Codem Inventory (" .. resourceName .. ")^0")
                return 'codem_inventory', resourceName
            end
            
            -- QS Inventory - GetItemList export
            local hasQsExports = pcall(function()
                return exports[resourceName].GetItemList ~= nil or exports[resourceName].GetInventory ~= nil
            end)
            if hasQsExports then
                print("^2[BC-Web] Envanter algılandı: QS Inventory (" .. resourceName .. ")^0")
                return 'qs_inventory', resourceName
            end
            
            -- PS Inventory - İsim pattern kontrolü (export yok genelde)
            local lowerName = string.lower(resourceName)
            if string.match(lowerName, 'ps[-_]?inv') then
                print("^2[BC-Web] Envanter algılandı: PS Inventory (" .. resourceName .. ")^0")
                return 'ps_inventory', resourceName
            end
        end
    end
    
    print("^3[BC-Web] Özel envanter bulunamadı, framework default kullanılıyor^0")
    return 'default', nil
end

-- Garaj sistemi algılama (Export Tabanlı - Lisanslı Scriptler İçin)
function FrameworkDetection.DetectGarage()
    local numResources = GetNumResources()
    
    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if GetResourceState(resourceName) == 'started' then
            -- Export fonksiyonlarına göre algıla (lisans güvenli)
            
            -- JG Garage - GetAllGarages, GetGarages exports
            local hasJgExports = pcall(function()
                local jgTest = exports[resourceName].GetAllGarages or exports[resourceName].GetGarages
                return jgTest ~= nil
            end)
            if hasJgExports then
                print("^2[BC-Web] Garaj algılandı: JG Garages (" .. resourceName .. ")^0")
                return 'jg_garages', resourceName
            end
            
            -- CD Garage - ManageGarage export
            local hasCdExports = pcall(function()
                return exports[resourceName].ManageGarage ~= nil or exports[resourceName].GetGarage ~= nil
            end)
            if hasCdExports then
                print("^2[BC-Web] Garaj algılandı: CD Garage (" .. resourceName .. ")^0")
                return 'cd_garage', resourceName
            end
            
            -- T1GER Garage - openGarage export
            local hasT1gerExports = pcall(function()
                return exports[resourceName].openGarage ~= nil or exports[resourceName].OpenGarage ~= nil
            end)
            if hasT1gerExports then
                print("^2[BC-Web] Garaj algılandı: T1GER Garage (" .. resourceName .. ")^0")
                return 't1ger_garage', resourceName
            end
            
            -- QB/QBX Garages - İsim pattern kontrolü (framework içinde)
            local lowerName = string.lower(resourceName)
            if string.match(lowerName, 'qbx[-_]?garage') then
                print("^2[BC-Web] Garaj algılandı: QBX Garages (" .. resourceName .. ")^0")
                return 'qbx_garages', resourceName
            elseif string.match(lowerName, 'qb[-_]?garage') then
                print("^2[BC-Web] Garaj algılandı: QB Garages (" .. resourceName .. ")^0")
                return 'qb_garages', resourceName
            end
        end
    end
    
    print("^3[BC-Web] Garaj scripti bulunamadı, default garajlar kullanılıyor^0")
    return 'default', nil
end

-- Garajları çek
function FrameworkDetection.GetGarages()
    local garageSystem, resourceName = FrameworkDetection.DetectGarage()
    local garages = {}
    
    if garageSystem == 'jg_garages' and resourceName then
        local success, jgGarages = pcall(function()
            return exports[resourceName]:GetAllGarages() or {}
        end)
        if success and jgGarages then
            for garageName, garageData in pairs(jgGarages) do
                garages[garageName] = {
                    label = garageData.label or garageName,
                    type = garageData.type or 'public',
                    coords = garageData.coords or vector4(0,0,0,0)
                }
            end
        else
            print("^3[BC-Web] JG Garages export çağrılamadı^0")
        end
        
    elseif garageSystem == 'qb_garages' or garageSystem == 'qbx_garages' then
        local _, Core = FrameworkDetection.DetectFramework()
        if Core and Core.Shared and Core.Shared.Garages then
            for garageName, garageData in pairs(Core.Shared.Garages) do
                garages[garageName] = {
                    label = garageData.label or garageName,
                    type = garageData.type or 'public',
                    coords = garageData.coords or vector4(0,0,0,0)
                }
            end
        end
        
    elseif garageSystem == 'cd_garage' then
        -- cd_garage için Config.Garages
        if Config and Config.Garages then
            for garageName, garageData in pairs(Config.Garages) do
                garages[garageName] = {
                    label = garageData.garage_name or garageName,
                    type = garageData.type or 'public',
                    coords = garageData.Blip or vector4(0,0,0,0)
                }
            end
        end
    end
    
    -- Hiçbir garaj scripti yoksa varsayılan garajlar
    if next(garages) == nil then
        garages = {
            pillboxgarage = {label = 'Pillbox Garage', type = 'public', coords = vector4(-275.52, -888.98, 31.08, 340.88)},
            motelgarage = {label = 'Motel Garage', type = 'public', coords = vector4(273.14, -343.94, 44.92, 342.84)},
            sapcounsel = {label = 'SAP Counsel Garage', type = 'public', coords = vector4(-330.61, -780.48, 33.96, 137.84)},
            spanishave = {label = 'Spanish Ave Garage', type = 'public', coords = vector4(-1160.91, -741.56, 19.64, 37.44)},
            caears24 = {label = 'Caears 24 Garage', type = 'public', coords = vector4(69.84, 12.64, 69.00, 163.08)},
            lagunapi = {label = 'Laguna Parking', type = 'public', coords = vector4(364.52, 297.61, 103.49, 164.12)},
            airportp = {label = 'Airport Parking', type = 'public', coords = vector4(-796.71, -2023.04, 8.88, 47.88)},
            boatgarage = {label = 'Boat Garage', type = 'boat', coords = vector4(-794.99, -1510.65, 1.59, 111.72)},
            aircraftgarage = {label = 'Aircraft Garage', type = 'air', coords = vector4(-1617.49, -3155.26, 13.99, 329.48)},
            lspdgarage = {label = 'LSPD Garage', type = 'job', coords = vector4(452.0, -1024.24, 28.54, 0.0)},
            sasdgarage = {label = 'SASD Garage', type = 'job', coords = vector4(1868.93, 3696.67, 33.59, 210.03)},
            ambulancegarage = {label = 'Ambulance Garage', type = 'job', coords = vector4(334.65, -583.61, 43.28, 252.16)}
        }
    end
    
    return garages
end

-- Item verme (inventory uyumlu)
function FrameworkDetection.GiveItem(source, itemName, amount, metadata)
    local inventorySystem = FrameworkDetection.DetectInventory()
    local frameworkType, Core = FrameworkDetection.DetectFramework()
    
    if inventorySystem == 'ox_inventory' then
        exports.ox_inventory:AddItem(source, itemName, amount, metadata)
        return true
        
    elseif inventorySystem == 'codem_inventory' then
        exports['codem-inventory']:AddItem(source, itemName, amount, metadata)
        return true
        
    elseif inventorySystem == 'qs_inventory' then
        exports['qs-inventory']:AddItem(source, itemName, amount)
        return true
        
    else
        -- QB/QBX default inventory
        if Core then
            local Player = Core.Functions.GetPlayer(source)
            if Player then
                Player.Functions.AddItem(itemName, amount, false, metadata)
                return true
            end
        end
    end
    
    return false
end

-- Item silme (inventory uyumlu)
function FrameworkDetection.RemoveItem(source, itemName, amount, slot)
    local inventorySystem = FrameworkDetection.DetectInventory()
    local frameworkType, Core = FrameworkDetection.DetectFramework()
    
    if inventorySystem == 'ox_inventory' then
        exports.ox_inventory:RemoveItem(source, itemName, amount, nil, slot)
        return true
        
    elseif inventorySystem == 'codem_inventory' then
        exports['codem-inventory']:RemoveItem(source, itemName, amount, slot)
        return true
        
    elseif inventorySystem == 'qs_inventory' then
        exports['qs-inventory']:RemoveItem(source, itemName, amount)
        return true
        
    else
        -- QB/QBX default inventory
        if Core then
            local Player = Core.Functions.GetPlayer(source)
            if Player then
                Player.Functions.RemoveItem(itemName, amount, slot)
                return true
            end
        end
    end
    
    return false
end

-- Player object çekme
function FrameworkDetection.GetPlayer(source)
    local frameworkType, Core = FrameworkDetection.DetectFramework()
    
    if frameworkType == 'qbx' or frameworkType == 'qb' then
        return Core.Functions.GetPlayer(source)
    elseif frameworkType == 'esx' then
        return Core.GetPlayerFromId(source)
    end
    
    return nil
end

-- Citizen ID çekme
function FrameworkDetection.GetCitizenId(source)
    local frameworkType, Core = FrameworkDetection.DetectFramework()
    local Player = FrameworkDetection.GetPlayer(source)
    
    if not Player then return nil end
    
    if frameworkType == 'qbx' or frameworkType == 'qb' then
        return Player.PlayerData.citizenid
    elseif frameworkType == 'esx' then
        return Player.identifier
    end
    
    return nil
end

return FrameworkDetection


