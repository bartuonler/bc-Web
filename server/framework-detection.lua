-- ============================================
-- FRAMEWORK & RESOURCE OTOMATIK TESPIT
-- Tum populer scriptleri export + isim taramasi ile bulur
-- Config'te 'auto' birakilirsa otomatik algilar
-- ============================================

-- Debug modu (true = detayli log, false = sadece ozet)
local DEBUG = (BCPanel and BCPanel.Debug == true) or false

if BCPanel then
    BCPanel.DetectedFramework = nil
    BCPanel.DetectedInventory = nil
    BCPanel.DetectedClothing = nil
    BCPanel.DetectedGarage = nil
    BCPanel.DetectedPhone = nil
    BCPanel.DetectedDealership = nil
    BCPanel.DetectedStaticID = nil
end

-- ============================================
-- FRAMEWORK ALGILAMA
-- ============================================
local function detectFramework()
    if not BCPanel then return end
    if BCPanel.Framework ~= 'auto' then
        BCPanel.DetectedFramework = BCPanel.Framework
        if DEBUG then print("^3[BC-Web] Framework: " .. BCPanel.Framework .. " (Manuel)") end
        return
    end
    if GetResourceState('qbx_core') == 'started' then
        BCPanel.DetectedFramework = 'qbx'
        if DEBUG then print("^2[BC-Web] Framework tespit edildi: QBX") end
    elseif GetResourceState('qb-core') == 'started' then
        BCPanel.DetectedFramework = 'qb'
        if DEBUG then print("^2[BC-Web] Framework tespit edildi: QBCore") end
    else
        BCPanel.DetectedFramework = 'qb'
        if DEBUG then print("^3[BC-Web] Framework tespit edilemedi, varsayilan: QBCore") end
    end
end

-- ============================================
-- INVENTORY ALGILAMA (Export + Isim taramasi)
-- ============================================
local function detectInventory()
    if not BCPanel then return end
    if BCPanel.Inventory ~= 'auto' then
        BCPanel.DetectedInventory = BCPanel.Inventory
        if DEBUG then print("^3[BC-Web] Inventory: " .. BCPanel.Inventory .. " (Manuel)") end
        return
    end

    local knownInventories = {
        { names = {'ox_inventory'},                      id = 'ox_inventory',     oxFlag = true },
        { names = {'qb-inventory', 'qb_inventory'},      id = 'qb-inventory',    oxFlag = false },
        { names = {'ps-inventory', 'ps_inventory'},      id = 'ps-inventory',    oxFlag = false },
        { names = {'qs-inventory', 'qs_inventory'},      id = 'qs-inventory',    oxFlag = false },
        { names = {'codem-inventory', 'codem_inventory'}, id = 'codem-inventory', oxFlag = false },
        { names = {'core_inventory'},                    id = 'core_inventory',  oxFlag = false },
        { names = {'mf-inventory', 'mf_inventory'},      id = 'mf-inventory',   oxFlag = false },
        { names = {'origen_inventory'},                  id = 'origen_inventory', oxFlag = false },
        { names = {'tgiann-inventory'},                  id = 'tgiann-inventory', oxFlag = false },
    }

    for _, inv in ipairs(knownInventories) do
        for _, name in ipairs(inv.names) do
            if GetResourceState(name) == 'started' then
                BCPanel.DetectedInventory = inv.id
                BCPanel.oxInventory = inv.oxFlag
                if DEBUG then print("^2[BC-Web] Inventory tespit edildi: " .. inv.id .. " (" .. name .. ")") end
                return
            end
        end
    end

    -- Export taramasi: bilinmeyen inventory scriptleri icin
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if GetResourceState(resName) == 'started' then
            local lower = string.lower(resName)
            if string.find(lower, 'inventory') or string.find(lower, 'envanter') then
                local hasExport = false
                pcall(function()
                    if exports[resName].AddItem or exports[resName].Search or exports[resName].GetInventory then
                        hasExport = true
                    end
                end)
                if hasExport then
                    BCPanel.DetectedInventory = resName
                    BCPanel.oxInventory = false
                    if DEBUG then print("^2[BC-Web] Inventory tespit edildi (export scan): " .. resName) end
                    return
                end
            end
        end
    end

    BCPanel.DetectedInventory = 'ox_inventory'
    BCPanel.oxInventory = true
    if DEBUG then print("^3[BC-Web] Inventory tespit edilemedi, varsayilan: ox_inventory") end
end

-- ============================================
-- CLOTHING ALGILAMA
-- ============================================
local function detectClothing()
    if not BCPanel then return end
    if BCPanel.Clothing ~= 'auto' then
        BCPanel.DetectedClothing = BCPanel.Clothing
        if DEBUG then print("^3[BC-Web] Clothing: " .. BCPanel.Clothing .. " (Manuel)") end
        return
    end

    local knownClothing = {
        'illenium-appearance',
        'fivem-appearance',
        'qb-clothing',
        'qbx_clothing',
        'tgiann-clothing',
        'codem-appearance',
        'ak47_clothing',
        'ox_appearance',
    }

    for _, name in ipairs(knownClothing) do
        if GetResourceState(name) == 'started' then
            BCPanel.DetectedClothing = name
            if DEBUG then print("^2[BC-Web] Clothing tespit edildi: " .. name) end
            return
        end
    end

    -- Export taramasi
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if GetResourceState(resName) == 'started' then
            local lower = string.lower(resName)
            if string.find(lower, 'cloth') or string.find(lower, 'appearance') or string.find(lower, 'skin') or string.find(lower, 'outfit') then
                local hasExport = false
                pcall(function()
                    if exports[resName].openMenu or exports[resName].openClothingMenu or exports[resName].openClothingShop then
                        hasExport = true
                    end
                end)
                if hasExport then
                    BCPanel.DetectedClothing = resName
                    if DEBUG then print("^2[BC-Web] Clothing tespit edildi (export scan): " .. resName) end
                    return
                end
            end
        end
    end

    BCPanel.DetectedClothing = 'illenium-appearance'
    if DEBUG then print("^3[BC-Web] Clothing tespit edilemedi, varsayilan: illenium-appearance") end
end

-- ============================================
-- GARAGE ALGILAMA (Export + Isim taramasi)
-- ============================================
local function detectGarage()
    if not BCPanel then return end
    if BCPanel.Garage ~= 'auto' then
        BCPanel.DetectedGarage = BCPanel.Garage
        if DEBUG then print("^3[BC-Web] Garage: " .. BCPanel.Garage .. " (Manuel)") end
        return
    end

    local knownGarages = {
        { names = {'jg-advancedgarages', 'jg-advanced-garages', 'jg_advancedgarages'}, id = 'jg-advancedgarages' },
        { names = {'qbx_garages', 'qbx-garages'},     id = 'qbx_garages' },
        { names = {'qb-garages', 'qb_garages'},        id = 'qb-garages' },
        { names = {'cd_garage', 'cd-garage'},           id = 'cd_garage' },
        { names = {'codem-garage', 'codem_garage'},     id = 'codem-garage' },
        { names = {'okokGarage', 'okok-garage'},        id = 'okokGarage' },
        { names = {'t1ger_garages', 't1ger-garages'},  id = 't1ger_garages' },
        { names = {'jim-garage', 'jim_garage'},         id = 'jim-garage' },
        { names = {'brutal_garages'},                   id = 'brutal_garages' },
        { names = {'loaf_garage'},                      id = 'loaf_garage' },
        { names = {'ak47_garage'},                      id = 'ak47_garage' },
        { names = {'r_garages'},                        id = 'r_garages' },
        { names = {'qs-garages', 'qs_garages'},         id = 'qs-garages' },
    }

    for _, gar in ipairs(knownGarages) do
        for _, name in ipairs(gar.names) do
            if GetResourceState(name) == 'started' then
                BCPanel.DetectedGarage = gar.id
                if DEBUG then print("^2[BC-Web] Garage tespit edildi: " .. gar.id .. " (" .. name .. ")") end
                return
            end
        end
    end

    -- Export taramasi
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if GetResourceState(resName) == 'started' then
            local lower = string.lower(resName)
            if string.find(lower, 'garage') or string.find(lower, 'parking') or string.find(lower, 'garaj') then
                local hasExport = false
                pcall(function()
                    if exports[resName].GetAllGarages or exports[resName].GetGarages or exports[resName].getAllGarages or exports[resName].ManageGarage or exports[resName].openGarage then
                        hasExport = true
                    end
                end)
                if hasExport then
                    BCPanel.DetectedGarage = resName
                    if DEBUG then print("^2[BC-Web] Garage tespit edildi (export scan): " .. resName) end
                    return
                end
                BCPanel.DetectedGarage = resName
                if DEBUG then print("^2[BC-Web] Garage tespit edildi (isim): " .. resName) end
                return
            end
        end
    end

    BCPanel.DetectedGarage = 'qb-garages'
    if DEBUG then print("^3[BC-Web] Garage tespit edilemedi, varsayilan: qb-garages") end
end

-- ============================================
-- PHONE ALGILAMA (Export + Isim taramasi)
-- ============================================
local function detectPhone()
    if not BCPanel then return end
    if BCPanel.Phone and BCPanel.Phone ~= 'auto' then
        BCPanel.DetectedPhone = BCPanel.Phone
        if DEBUG then print("^3[BC-Web] Phone: " .. BCPanel.Phone .. " (Manuel)") end
        return
    end

    local knownPhones = {
        { names = {'qs-smartphone', 'qs_smartphone'},            id = 'qs-smartphone' },
        { names = {'gksphone'},                                   id = 'gksphone' },
        { names = {'npphone', 'np-phone'},                        id = 'npphone' },
        { names = {'lb-phone', 'lb_phone'},                       id = 'lb-phone' },
        { names = {'roadphone', 'road-phone'},                    id = 'roadphone' },
        { names = {'d-phone', 'dphone'},                          id = 'd-phone' },
        { names = {'yflip-phone', 'yflip_phone'},                 id = 'yflip-phone' },
        { names = {'qb-phone', 'qb_phone'},                       id = 'qb-phone' },
        { names = {'gcphone'},                                     id = 'gcphone' },
        { names = {'renewed-phone', 'renewed_phone'},             id = 'renewed-phone' },
        { names = {'high-phone', 'high_phone'},                   id = 'high-phone' },
        { names = {'jpr-phone', 'jpr_phone'},                     id = 'jpr-phone' },
        { names = {'p-phone', 'pphone'},                           id = 'p-phone' },
        { names = {'ak47_phone'},                                  id = 'ak47_phone' },
        { names = {'codem-phone', 'codem_phone'},                 id = 'codem-phone' },
    }

    for _, phone in ipairs(knownPhones) do
        for _, name in ipairs(phone.names) do
            if GetResourceState(name) == 'started' then
                BCPanel.DetectedPhone = phone.id
                if DEBUG then print("^2[BC-Web] Phone tespit edildi: " .. phone.id .. " (" .. name .. ")") end
                return
            end
        end
    end

    -- Export taramasi
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if GetResourceState(resName) == 'started' then
            local lower = string.lower(resName)
            if string.find(lower, 'phone') or string.find(lower, 'smartphone') then
                BCPanel.DetectedPhone = resName
                if DEBUG then print("^2[BC-Web] Phone tespit edildi (isim scan): " .. resName) end
                return
            end
        end
    end

    BCPanel.DetectedPhone = 'none'
    if DEBUG then print("^3[BC-Web] Phone tespit edilemedi") end
end

-- ============================================
-- DEALERSHIP / GALERI ALGILAMA
-- ============================================
local function detectDealership()
    if not BCPanel then return end
    if BCPanel.Dealership and BCPanel.Dealership ~= 'auto' then
        BCPanel.DetectedDealership = BCPanel.Dealership
        if DEBUG then print("^3[BC-Web] Dealership: " .. BCPanel.Dealership .. " (Manuel)") end
        return
    end

    local knownDealerships = {
        { names = {'jg-dealership', 'jg_dealership', 'jg-advanceddealership', 'jg_advanceddealership'}, id = 'jg-dealership' },
        { names = {'qb-dealership', 'qb_dealership'},      id = 'qb-dealership' },
        { names = {'qbx_dealership', 'qbx-dealership'},    id = 'qbx_dealership' },
        { names = {'t1ger_dealership', 't1ger-dealership'}, id = 't1ger_dealership' },
        { names = {'codem-dealership', 'codem_dealership'}, id = 'codem-dealership' },
        { names = {'okokDealership', 'okok-dealership'},    id = 'okokDealership' },
        { names = {'qs-dealership', 'qs_dealership'},       id = 'qs-dealership' },
        { names = {'ak47_dealership'},                       id = 'ak47_dealership' },
        { names = {'loaf_dealership'},                       id = 'loaf_dealership' },
        { names = {'renewed-vehicleshop'},                   id = 'renewed-vehicleshop' },
            { names = {'brutal_dealership'},                     id = 'brutal_dealership' },
    }

    for _, deal in ipairs(knownDealerships) do
        for _, name in ipairs(deal.names) do
            if GetResourceState(name) == 'started' then
                BCPanel.DetectedDealership = deal.id
                if DEBUG then print("^2[BC-Web] Dealership tespit edildi: " .. deal.id .. " (" .. name .. ")") end
                return
            end
        end
    end

    -- Export + isim taramasi
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if GetResourceState(resName) == 'started' then
            local lower = string.lower(resName)
            if string.find(lower, 'dealer') or string.find(lower, 'vehicleshop') or string.find(lower, 'galeri') or string.find(lower, 'carlot') then
                BCPanel.DetectedDealership = resName
                if DEBUG then print("^2[BC-Web] Dealership tespit edildi (isim scan): " .. resName) end
                return
            end
        end
    end

    BCPanel.DetectedDealership = 'none'
    if DEBUG then print("^3[BC-Web] Dealership tespit edilemedi") end
end

-- ============================================
-- SABIT ID SISTEMI (SHX-SID) ALGILAMA
-- ============================================
local function detectStaticID()
    if not BCPanel then return end
    if BCPanel.StaticID and BCPanel.StaticID ~= 'auto' then
        BCPanel.DetectedStaticID = BCPanel.StaticID
        if DEBUG then print("^3[BC-Web] StaticID: " .. BCPanel.StaticID .. " (Manuel)") end
        return
    end

    local knownStaticId = {
        { names = {'shx-sid', 'shx_sid'},        id = 'shx-sid' },
        { names = {'static-id', 'static_id'},    id = 'static-id' },
        { names = {'sid', 'player-sid'},          id = 'sid' },
    }

    for _, sid in ipairs(knownStaticId) do
        for _, name in ipairs(sid.names) do
            if GetResourceState(name) == 'started' then
                BCPanel.DetectedStaticID = sid.id
                if DEBUG then print("^2[BC-Web] StaticID tespit edildi: " .. sid.id .. " (" .. name .. ")") end
                return
            end
        end
    end

    -- Export taramasi
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if GetResourceState(resName) == 'started' then
            local lower = string.lower(resName)
            if string.find(lower, 'sid') or string.find(lower, 'static') then
                local hasExport = false
                pcall(function()
                    if exports[resName].GetStaticId or exports[resName].getStaticId or exports[resName].GetSid then
                        hasExport = true
                    end
                end)
                if hasExport then
                    BCPanel.DetectedStaticID = resName
                    if DEBUG then print("^2[BC-Web] StaticID tespit edildi (export scan): " .. resName) end
                    return
                end
            end
        end
    end

    BCPanel.DetectedStaticID = 'none'
    if DEBUG then print("^3[BC-Web] StaticID (SHX-SID) tespit edilemedi - source ID kullanilacak") end
end

-- ============================================
-- BASLATMA (Direkt calistir - fxmanifest sira: framework-detection > server.lua)
-- ============================================
if DEBUG then
    print("^2========================================")
    print("^2[BC-Web] Sistem Tespiti Baslatiliyor...")
    print("^2========================================")
end

detectFramework()
detectInventory()
detectClothing()
detectGarage()
detectPhone()
detectDealership()
detectStaticID()

-- Global degiskenlere set et (server.lua uyumlulugu icin)
FrameworkType = BCPanel and BCPanel.DetectedFramework

print("^2========================================")
print("^2[BC-Web] Tespit Tamamlandi!")
print("^2  Framework:  " .. ((BCPanel and BCPanel.DetectedFramework) or "HATA"))
print("^2  Inventory:  " .. ((BCPanel and BCPanel.DetectedInventory) or "HATA"))
print("^2  Clothing:   " .. ((BCPanel and BCPanel.DetectedClothing) or "HATA"))
print("^2  Garage:     " .. ((BCPanel and BCPanel.DetectedGarage) or "HATA"))
print("^2  Phone:      " .. ((BCPanel and BCPanel.DetectedPhone) or "HATA"))
print("^2  Dealership: " .. ((BCPanel and BCPanel.DetectedDealership) or "HATA"))
print("^2  StaticID:   " .. ((BCPanel and BCPanel.DetectedStaticID) or "HATA"))
print("^2========================================")

-- Gecikmiş tekrar tarama (bazi resourcelar gec baslarsa)
CreateThread(function()
    Wait(5000)
    local updated = false

    if BCPanel and (not BCPanel.DetectedInventory or BCPanel.DetectedInventory == 'ox_inventory') then
        local oldInv = BCPanel.DetectedInventory
        detectInventory()
        if BCPanel.DetectedInventory ~= oldInv then
            if DEBUG then print("^2[BC-Web] Gecikmiş tespit - Inventory guncellendi: " .. BCPanel.DetectedInventory) end
            updated = true
        end
    end

    if BCPanel and (not BCPanel.DetectedGarage or BCPanel.DetectedGarage == 'qb-garages') then
        local oldGar = BCPanel.DetectedGarage
        detectGarage()
        if BCPanel.DetectedGarage ~= oldGar then
            if DEBUG then print("^2[BC-Web] Gecikmiş tespit - Garage guncellendi: " .. BCPanel.DetectedGarage) end
            updated = true
        end
    end

    if BCPanel and (not BCPanel.DetectedPhone or BCPanel.DetectedPhone == 'none') then
        detectPhone()
        if BCPanel.DetectedPhone ~= 'none' then
            if DEBUG then print("^2[BC-Web] Gecikmiş tespit - Phone bulundu: " .. BCPanel.DetectedPhone) end
            updated = true
        end
    end

    if BCPanel and (not BCPanel.DetectedDealership or BCPanel.DetectedDealership == 'none') then
        detectDealership()
        if BCPanel.DetectedDealership ~= 'none' then
            if DEBUG then print("^2[BC-Web] Gecikmiş tespit - Dealership bulundu: " .. BCPanel.DetectedDealership) end
            updated = true
        end
    end

    if BCPanel and (not BCPanel.DetectedStaticID or BCPanel.DetectedStaticID == 'none') then
        detectStaticID()
        if BCPanel.DetectedStaticID ~= 'none' then
            if DEBUG then print("^2[BC-Web] Gecikmiş tespit - StaticID bulundu: " .. BCPanel.DetectedStaticID) end
            updated = true
        end
    end

    if updated then
        if DEBUG then print("^2[BC-Web] Gecikmiş tespit tamamlandi - bazi sistemler guncellendi") end
    end
end)

-- ============================================
-- HELPER FONKSIYONLAR (Diger dosyalar kullanir)
-- ============================================

function GetFrameworkObject()
    if not BCPanel then return nil end
    if BCPanel.DetectedFramework == 'qbx' then
        return exports.qbx_core
    elseif BCPanel.DetectedFramework == 'qb' then
        return exports['qb-core']:GetCoreObject()
    end
    return nil
end

function GetPlayer(src)
    if not BCPanel then return nil end
    local fw = BCPanel.DetectedFramework
    if fw == 'qbx' then
        return exports.qbx_core:GetPlayer(src)
    elseif fw == 'qb' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.GetPlayer(src)
    end
    return nil
end

function OpenClothingMenu(src)
    if not BCPanel then return end
    local clothing = BCPanel.DetectedClothing
    if clothing == 'illenium-appearance' then
        TriggerClientEvent('illenium-appearance:client:openClothingShop', src)
    elseif clothing == 'fivem-appearance' then
        TriggerClientEvent('fivem-appearance:client:openClothingShop', src)
    elseif clothing == 'qb-clothing' then
        TriggerClientEvent('qb-clothing:client:openMenu', src)
    elseif clothing == 'qbx_clothing' then
        TriggerClientEvent('qbx_clothing:client:openMenu', src)
    elseif clothing == 'tgiann-clothing' then
        TriggerClientEvent(clothing .. ':client:openMenu', src)
    else
        pcall(function()
            TriggerClientEvent(clothing .. ':client:openMenu', src)
        end)
    end
end

function GetInventory(citizenid)
    if not BCPanel then return {} end
    local inventory = BCPanel.DetectedInventory
    if inventory == 'ox_inventory' then
        local ok, inv = pcall(function() return exports.ox_inventory:GetInventory(citizenid) end)
        return (ok and inv) or {}
    elseif inventory == 'qb-inventory' or inventory == 'ps-inventory' then
        local result = MySQL.query.await('SELECT * FROM player_items WHERE citizenid = ?', {citizenid})
        return result or {}
    end
    return {}
end

function GetStash(citizenid)
    if not BCPanel then return {} end
    local inventory = BCPanel.DetectedInventory
    if inventory == 'ox_inventory' then
        local stashId = 'motelstash_' .. citizenid
        local ok, inv = pcall(function() return exports.ox_inventory:GetInventory(stashId) end)
        return (ok and inv) or {}
    else
        local result = MySQL.query.await('SELECT * FROM stashitems WHERE stash = ?', {'motelstash_' .. citizenid})
        return result or {}
    end
end
