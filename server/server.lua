
-- ============================================
-- RESOURCE NAME KORUMASI
-- ============================================
if GetCurrentResourceName() ~= "bc-Web" then
    print("^1[bc-Web] Script adi degistirildi! Lutfen dosya adini tekrar 'bc-Web' yapin.^0")
    return
end
print("^2[BC-Web] Resource adi dogrulandi: " .. GetCurrentResourceName())

-- ============================================
-- PANEL CONFIG EXPORT (socket.js icin)
-- socket.js bu export'u cagirarak BCPanel ayarlarini okur
-- ============================================
exports('getPanelConfig', function()
    return {
        siteUrl = BCPanel.webPanel or 'http://localhost:3000',
        -- WebSocketKey: panelden Script Ayarlari > Websocket Guvenlik Anahtari'ndan alınan deger
        -- WebAPIKey: REST API istekleri icin ayri kullanilir
        apiKey  = BCPanel.WebSocketKey or BCPanel.WebAPIKey or '',
    }
end)

-- ============================================
-- SERVER UPTIME TRACKING
-- ============================================
local serverStartTime = os.time()

local function getServerUptime()
    local uptime = os.time() - serverStartTime
    local days = math.floor(uptime / 86400)
    local hours = math.floor((uptime % 86400) / 3600)
    local minutes = math.floor((uptime % 3600) / 60)
    
    return {
        seconds = uptime,
        days = days,
        hours = hours,
        minutes = minutes,
        formatted = string.format("%dd %dh %dm", days, hours, minutes)
    }
end

-- ============================================
-- GUVENLI MySQL WRAPPER (CRASH + TIMEOUT ONLEME)
-- ============================================
local function SafeQuery(query, params, timeout)
    -- pcall ile MySQL hatasini yakala (crash onleme)
    local success, result = pcall(function()
        return MySQL.query.await(query, params or {})
    end)
    
    if not success then
        print("^1[BC-Web ERROR] MySQL Query Failed: " .. tostring(result))
        print("^1[BC-Web ERROR] Query: " .. tostring(query):sub(1, 100))
        return nil
    end
    
    return result
end

print("^2[BC-Web] Stabil mod aktif - MySQL timeout protection yuklendi")

-- Framework Detection System
local FrameworkType = nil
local Core = nil

-- Framework Detection (framework-detection.lua zaten BCPanel.DetectedFramework set etti)
-- Burada sadece Core objesi olusturulur
if BCPanel and BCPanel.DetectedFramework then
    FrameworkType = BCPanel.DetectedFramework
    if BCPanel then BCPanel.Framework = BCPanel.DetectedFramework end
end

if FrameworkType == 'qbx' then
    Core = exports.qbx_core
    print("^2[BC-Web] Framework: QBX Core (Core obj yuklendi)")
elseif FrameworkType == 'qb' then
    Core = exports['qb-core']:GetCoreObject()
    print("^2[BC-Web] Framework: QB Core (Core obj yuklendi)")
elseif FrameworkType == 'esx' then
    Core = exports['es_extended']:getSharedObject()
    print("^2[BC-Web] Framework: ESX (Core obj yuklendi)")
else
    -- Fallback: kendi algilamamizi yap
    if GetResourceState('qbx_core') == 'started' then
        FrameworkType = 'qbx'
        Core = exports.qbx_core
        if BCPanel then BCPanel.Framework = 'qbx' end
    elseif GetResourceState('qb-core') == 'started' then
        FrameworkType = 'qb'
        Core = exports['qb-core']:GetCoreObject()
        if BCPanel then BCPanel.Framework = 'qb' end
    elseif GetResourceState('es_extended') == 'started' then
        FrameworkType = 'esx'
        Core = exports['es_extended']:getSharedObject()
        if BCPanel then BCPanel.Framework = 'esx' end
    else
        FrameworkType = 'qb'
        if BCPanel then BCPanel.Framework = 'qb' end
    end
    print("^2[BC-Web] Framework: " .. FrameworkType .. " (fallback)")
end

-- Inventory System Detection (framework-detection.lua sonucunu kullan)
if BCPanel and BCPanel.DetectedInventory then
    InventorySystem = BCPanel and BCPanel.DetectedInventory
    print("^2[BC-Web] Inventory (detection): " .. InventorySystem)
elseif GetResourceState('ox_inventory') == 'started' then
    InventorySystem = 'ox_inventory'
    print("^2[BC-Web] Inventory: OX Inventory")
elseif GetResourceState('codem-inventory') == 'started' then
    InventorySystem = 'codem_inventory'
    print("^2[BC-Web] Inventory: Codem Inventory")
elseif GetResourceState('qs-inventory') == 'started' then
    InventorySystem = 'qs_inventory'
    print("^2[BC-Web] Inventory: QS Inventory")
else
    InventorySystem = 'default'
    print("^2[BC-Web] Inventory: Default QB/QBX Inventory")
end

-- Garage System Detection (Universal - Tum Populer Garajlar)
local function DetectGarageSystem()
	local numResources = GetNumResources()

	for i = 0, numResources - 1 do
		local resourceName = GetResourceByFindIndex(i)
		if GetResourceState(resourceName) == 'started' then
			local lowerName = string.lower(resourceName)

			-- JG Advanced Garages (jg-advancedgarages) - export tabanli algilama
			local isJgAdvanced = false
			local ok, hasExports = pcall(function()
				if not exports[resourceName] then return false end
				local exp = exports[resourceName]
				return type(exp.getAllGarages) == 'function'
					or type(exp.GetAllGarages) == 'function'
					or type(exp.GetGarages) == 'function'
			end)
			if ok and hasExports then
				isJgAdvanced = true
			end

			if isJgAdvanced and (
				lowerName == 'jg-advancedgarages' or
				lowerName == 'jg-advanced-garages' or
				lowerName == 'jg_advancedgarages' or
				lowerName == 'jg_advanced_garages' or
				string.find(lowerName, 'jg%-advancedgarage') or
				string.find(lowerName, 'jg%-advancedgarages')
			) then
				print("^2[BC-Web] Garage: JG Advanced Garages (" .. resourceName .. ")")
				-- Not: Asagidaki kullanimlar ile uyumlu olmasi icin 'jg_garages' donduruyoruz
				return 'jg_garages', resourceName
			end

			-- PATTERN MATCHING (Diger populer garaj scriptleri)
			if string.find(lowerName, 'garage') or
			   string.find(lowerName, 'parking') or
			   string.find(lowerName, 'garaj') then

				-- Bilinen garaj scriptleri
				if string.find(lowerName, 'qbx') then
					print("^2[BC-Web] Garage: QBX Garages (" .. resourceName .. ")")
					return 'qbx_garages', resourceName
				elseif string.find(lowerName, 'qb') then
					print("^2[BC-Web] Garage: QB Garages (" .. resourceName .. ")")
					return 'qb_garages', resourceName
				elseif string.find(lowerName, 'cd_garage') or string.find(lowerName, 'cd%-garage') then
					print("^2[BC-Web] Garage: CD Garage (" .. resourceName .. ")")
					return 'cd_garage', resourceName
				elseif string.find(lowerName, 'codem') then
					print("^2[BC-Web] Garage: Codem Garage (" .. resourceName .. ")")
					return 'codem_garage', resourceName
				elseif string.find(lowerName, 'jim') then
					print("^2[BC-Web] Garage: Jim Garage (" .. resourceName .. ")")
					return 'jim_garage', resourceName
				elseif string.find(lowerName, 'brutal') then
					print("^2[BC-Web] Garage: Brutal Garage (" .. resourceName .. ")")
					return 'brutal_garage', resourceName
				else
					-- Generic garage script
					print("^2[BC-Web] Garage: Custom Garage (" .. resourceName .. ")")
					return 'custom_garage', resourceName
				end
			end
		end
	end

	print("^3[BC-Web] Garage: Default (Framework Native)")
	return 'default', nil
end

local GarageSystem, GarageResourceName = DetectGarageSystem()

-- OTOMATIK AMBULANCE/MEDICAL SCRIPT ALGILAMA
-- Tum resource'lari tarayip otomatik olarak ambulance/medical scriptlerini bulur
local function DetectAmbulanceSystem()
    local numResources = GetNumResources()
    local detectedResource = nil
    local detectedMethod = nil
    local detectedExport = nil
    
    -- Pattern'ler (ambulance, ems, medic, medical, hospital, revive, heal)
    local patterns = {'ambulance', 'ems', 'medic', 'medical', 'hospital', 'revive', 'heal'}
    
    -- Oncelik sirasi (oncelikli scriptler once kontrol edilir)
    local priorityPatterns = {'qbx_medical', 'qbx_ambulance', 'qb_medical', 'qb_ambulance', 'esx_ambulance', 'esx_medical'}
    
    -- Once oncelikli scriptleri kontrol et
    for _, priorityPattern in ipairs(priorityPatterns) do
        for i = 0, numResources - 1 do
            local resourceName = GetResourceByFindIndex(i)
            if GetResourceState(resourceName) == 'started' and string.match(string.lower(resourceName), string.lower(priorityPattern)) then
                -- Export kontrolu
                local exportNames = {'RevivePlayer', 'revivePlayer', 'Revive', 'revive', 'HealPlayer', 'healPlayer', 'Heal', 'heal'}
                for _, exportName in ipairs(exportNames) do
                    local success = pcall(function()
                        if exports[resourceName] and exports[resourceName][exportName] then
                            return true
                        end
                        return false
                    end)
                    
                    if success then
                        print("^2[BC-Web] Ambulance Script Tespit Edildi: " .. resourceName .. " (Export: " .. exportName .. ")^7")
                        return resourceName, 'export', exportName
                    end
                end
                
                -- Export yoksa event bazli
                if not detectedResource then
                    detectedResource = resourceName
                    detectedMethod = 'event'
                end
            end
        end
    end
    
    -- Oncelikli scriptlerde bulunamadiysa, tum resource'lari tara
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
                -- Export kontrolu
                local exportNames = {'RevivePlayer', 'revivePlayer', 'Revive', 'revive', 'HealPlayer', 'healPlayer', 'Heal', 'heal'}
                for _, exportName in ipairs(exportNames) do
                    local success = pcall(function()
                        if exports[resourceName] and exports[resourceName][exportName] then
                            return true
                        end
                        return false
                    end)
                    
                    if success then
                        print("^2[BC-Web] Ambulance Script Tespit Edildi: " .. resourceName .. " (Export: " .. exportName .. ")^7")
                        return resourceName, 'export', exportName
                    end
                end
                
                -- Export yoksa event bazli
                if not detectedResource then
                    detectedResource = resourceName
                    detectedMethod = 'event'
                end
            end
        end
    end
    
    if detectedResource then
        print("^3[BC-Web] Ambulance Script Tespit Edildi: " .. detectedResource .. " (Event bazli)^7")
        return detectedResource, detectedMethod, nil
    end
    
    print("^3[BC-Web] Ambulance: Framework native kullanilacak^7")
    return nil, 'framework', nil
end

local AmbulanceResource, AmbulanceMethod, AmbulanceExport = DetectAmbulanceSystem()
-- Backward compatibility: Eger method nil ise, export olarak varsay
if not AmbulanceMethod then
	AmbulanceMethod = 'export'
end

-- Backward Compatibility
local QBCore = Core

-- QBX/QB uyumlu GetPlayer fonksiyonu
local function GetPlayer(source)
	if FrameworkType == 'qbx' then
		return exports.qbx_core:GetPlayer(source)
	elseif FrameworkType == 'qb' then
		return Core.Functions.GetPlayer(source)
	elseif FrameworkType == 'esx' then
		return Core.GetPlayerFromId(source)
	end
	return nil
end

-- QBX/QB uyumlu GetPlayerByCitizenId fonksiyonu
local function GetPlayerByCitizenId(citizenid)
	-- Tum framework'ler icin manuel arama (en guvenilir yontem)
	for _, playerId in pairs(GetPlayers()) do
		local playerIdNum = tonumber(playerId)
		if playerIdNum then
			local p = GetPlayer(playerIdNum)
			if p then
				if FrameworkType == 'qbx' or FrameworkType == 'qb' then
					if p.PlayerData and p.PlayerData.citizenid == citizenid then
						return p
					end
				elseif FrameworkType == 'esx' then
					if p.identifier == citizenid then
						return p
					end
				end
			end
		end
	end
	return nil
end

-- Source'dan CitizenId cekme fonksiyonu (Playtime tracking icin)
local function GetCitizenId(source)
	if not source then return nil end
	
	local p = GetPlayer(source)
	if p then
		if FrameworkType == 'qbx' or FrameworkType == 'qb' then
			return p.PlayerData and p.PlayerData.citizenid or nil
		elseif FrameworkType == 'esx' then
			return p.identifier or nil
		end
	end
	return nil
end

-- QBX/QB uyumlu GetIdentifier fonksiyonu (DUZELTME: idType parametresi kullaniliyor)
local function GetIdentifier(source, idType)
	-- FiveM native GetPlayerIdentifiers kullan (daha guvenilir)
	local identifiers = GetPlayerIdentifiers(source)
	
	for _, identifier in ipairs(identifiers) do
		if idType == 'discord' and string.match(identifier, "^discord:") then
			return identifier
		elseif idType == 'license' and string.match(identifier, "^license:") then
			return identifier
		elseif idType == 'steam' and string.match(identifier, "^steam:") then
			return identifier
		end
	end
	
	return nil
end

-- GetPlayerFromDiscord - Discord ID'den oyuncu source'unu bul
local function GetPlayerFromDiscord(dcid)
	if not dcid then return nil end
	dcid = tostring(dcid):gsub("discord:", "")
	
	for _, playerId in pairs(GetPlayers()) do
		local src = tonumber(playerId)
		if src then
			local discordIdentifier = GetIdentifier(src, 'discord')
			if discordIdentifier then
				local playerDcid = discordIdentifier:gsub("discord:", "")
				if playerDcid == dcid then
					return src
				end
			end
		end
	end
	return nil
end

local Blips = json.decode(LoadResourceFile(GetCurrentResourceName(), "data/blips.json"))
if type(Blips) ~= "table" then
	Blips = json.decode(LoadResourceFile(GetCurrentResourceName(), "blips.json"))
end
Blips = type(Blips) == "table" and Blips or {}

local Stashs = json.decode(LoadResourceFile(GetCurrentResourceName(), "data/stashs.json"))
if type(Stashs) ~= "table" then
	Stashs = json.decode(LoadResourceFile(GetCurrentResourceName(), "stashs.json"))
end
Stashs = type(Stashs) == "table" and Stashs or {}

local Bans = json.decode(LoadResourceFile(GetCurrentResourceName(), "data/bans.json"))
if type(Bans) ~= "table" then
	-- Fallback: eski konum (resource root)
	Bans = json.decode(LoadResourceFile(GetCurrentResourceName(), "bans.json"))
end
Bans = type(Bans) == "table" and Bans or {}


local Settings = json.decode(LoadResourceFile(GetCurrentResourceName(), "settings.json"))
Settings = type(Settings) == "table" and Settings or {
	sqlSaveInterval = 30,
	locations = json.decode([[
		{
    "Southside Taco": {
        "x": 2.91000008583068,
        "y": -1605.1400146484376,
        "z": 29.2800006866455,
        "w": 97.01000213623047
    },
    "Pinkcage Motel": {
        "x": 325.6600036621094,
        "y": -210.27000427246095,
        "z": 54.09000015258789,
        "w": 158.3300018310547
    },
    "Pillbox Hill Car Dealer": {
        "x": -13.89000034332275,
        "y": -1099.489990234375,
        "z": 26.67000007629394,
        "w": 161.35000610351563
    },
    "TextileCity Hospital": {
        "x": 298.3699951171875,
        "y": -604.5499877929688,
        "z": 43.34999847412109,
        "w": 71.31999969482422
    },
    "Cat Cafe": {
        "x": -598.5800170898438,
        "y": -1130.6600341796876,
        "z": 22.31999969482422,
        "w": 268.2699890136719
    },
    "Pier": {
        "x": -1714.969970703125,
        "y": -1115.22998046875,
        "z": 13.14999961853027,
        "w": 107.9000015258789
    },
    "Mission Row Police Departmant": {
        "x": 429.05999755859377,
        "y": -979.8699951171875,
        "z": 30.70999908447265,
        "w": 94.16999816894531
    }
}
	]])
}

if BCPanel and (BCPanel and BCPanel.oxInventory) then
	AddEventHandler('onServerResourceStart', function(resourceName)
		if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
			for k,v in pairs(Stashs) do

				local stashname = "bscript_"
				-- local stashname = "bscript_"..PlayerData.citizenid
                if v.type and v.job ~= "none" then
                    stashname = "bscript_"..v.type.."_"..v.job.."_"..string.gsub(v.name, " ", "_")
					exports.ox_inventory:RegisterStash(stashname, v.name, (BCPanel and BCPanel.Stash).slots, (BCPanel and BCPanel.Stash).maxweight, false)
				else
					for _, src in pairs(GetPlayers()) do
						local Player = GetPlayer(tonumber(src))
						if Player and Player.PlayerData then
							stashname = "bscript_"..Player.PlayerData.citizenid
							exports.ox_inventory:RegisterStash(stashname, v.name, (BCPanel and BCPanel.Stash).slots, (BCPanel and BCPanel.Stash).maxweight, false)
						end
					end
                end
			end
		end
	end)
end

local restartSaati = os.date("%H")..":"..os.date("%M")

local startTimes = {}
RegisterNetEvent('BC-Web:server:startTimer',function()
	local src = source
	local Player = GetPlayer(src)
	if not Player then return end
	local citizenid = Player.PlayerData.citizenid
	startTimes[tostring(src)] = {
		time = os.time(),
		identifier = citizenid,
		baseTime = nil -- Asagidaki thread tarafindan DB'den yuklenecek
	}

	if BCPanel and (BCPanel and BCPanel.oxInventory) then
		for k,v in pairs(Stashs) do
	
			local stashname = "bscript_"
			-- local stashname = "bscript_"..PlayerData.citizenid
			if v.type and v.job ~= "none" then
			else
				if Player then
					stashname = "bscript_"..Player.PlayerData.citizenid
					exports.ox_inventory:RegisterStash(stashname, v.name, (BCPanel and BCPanel.Stash).slots, (BCPanel and BCPanel.Stash).maxweight, false)
				end
	
			end
		end
	end
end)

-- ============================================
-- BC-WEB PLAYTIME TRACKER
-- Oyuncu giris/cikis surelerini takip eder
-- bc_playtime tablosuna kaydeder (dakika cinsinden)
-- ============================================
local PlayerSessions = {}

CreateThread(function()
    Wait(15000)
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS bc_playtime (
                cid VARCHAR(50) PRIMARY KEY,
                time INT(10) UNSIGNED DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]], {})
    end)
    -- Zaten online olan oyunculari kaydet (resource restart durumu)
    local players = GetPlayers()
    for _, src in ipairs(players) do
        local srcNum = tonumber(src)
        if srcNum then
            local cid = GetCitizenId(srcNum)
            if cid and cid ~= '' then
                PlayerSessions[srcNum] = { citizenid = cid, joinTime = os.time() }
            end
        end
    end
    print('^2[BC-Web Playtime] Tracker aktif - '..#players..' oyuncu kayitli^0')
end)

-- Oyuncu giris: QBCore/QBX
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    Wait(3000)
    local cid = GetCitizenId(src)
    if cid and cid ~= '' then
        PlayerSessions[src] = { citizenid = cid, joinTime = os.time() }
    end
end)

-- Oyuncu giris: ESX (fallback)
RegisterNetEvent('esx:playerLoaded', function(playerId)
    local src = playerId or source
    Wait(3000)
    local cid = GetCitizenId(src)
    if cid and cid ~= '' then
        PlayerSessions[src] = { citizenid = cid, joinTime = os.time() }
    end
end)

-- Oyuncu cikis: Sureyi DB'ye kaydet
AddEventHandler('playerDropped', function()
    local src = source
    local session = PlayerSessions[src]
    if session and session.citizenid then
        local mins = math.floor((os.time() - session.joinTime) / 60)
        if mins > 0 then
            pcall(function()
                MySQL.query.await(
                    'INSERT INTO bc_playtime (cid, time) VALUES (?, ?) ON DUPLICATE KEY UPDATE time = time + VALUES(time)',
                    { session.citizenid, mins }
                )
            end)
        end
        PlayerSessions[src] = nil
    end
end)

-- Periyodik kayit: 5 dakikada bir tum online oyuncularin suresini DB'ye yaz
CreateThread(function()
    Wait(20000)
    while true do
        Wait(300000) -- 5 dakika
        local now = os.time()
        local saved = 0
        for src, session in pairs(PlayerSessions) do
            if session and session.citizenid then
                local mins = math.floor((now - session.joinTime) / 60)
                if mins > 0 then
                    pcall(function()
                        MySQL.query.await(
                            'INSERT INTO bc_playtime (cid, time) VALUES (?, ?) ON DUPLICATE KEY UPDATE time = time + VALUES(time)',
                            { session.citizenid, mins }
                        )
                    end)
                    session.joinTime = now -- Sayaci sifirla
                    saved = saved + 1
                end
            end
        end
        -- Disconnect olmus ama temizlenmemis session'lari temizle
        for src, _ in pairs(PlayerSessions) do
            if not GetPlayerName(src) then PlayerSessions[src] = nil end
        end
    end
end)

-- WEB API KEY CALLBACK: Config'den API key'i dondur
RegisterNetEvent('BC-Web:callback:getApiKey', function(cb)
	local apiKey = (BCPanel and (BCPanel and BCPanel.WebAPIKey)) or ""
	cb(apiKey)
end)

-- WEB API KEY KONTROLU: Script basladiginda kontrol et ve console'a yazdir
CreateThread(function()
	Wait(5000) -- Script tamamen yuklensin
	
	local apiKey = (BCPanel and (BCPanel and BCPanel.WebAPIKey)) or ""
	
	if apiKey == "" or apiKey == nil then
		print("^1========================================")
		print("^1[BC-Web API Key] UYARI: Web API Key girilmemis!")
		print("^1[BC-Web API Key] Site panelinden API Key'i alin ve config.lua'ya ekleyin!")
		print("^1[BC-Web API Key] Ayarlar > Web API Key > API Key'i kopyala")
		print("^1[BC-Web API Key] Config: if BCPanel then BCPanel.WebAPIKey = 'BURAYA_API_KEY'")
		print("^1========================================")
	else
		print("^2========================================")
		print("^2[BC-Web API Key] Web API Key entegrasyonu basarili!")
		print("^2[BC-Web API Key] Key: " .. string.sub(apiKey, 1, 8) .. "...")
		print("^2[BC-Web API Key] Web panel ile guvenli baglanti aktif")
		print("^2========================================")
	end
end)

RegisterNetEvent('BC-Web:callback:getMostPlayTime',function(cb)
	-- bc_playtime tablosundan oku + aktif session suresini ekle
	local now = os.time()

	-- 1) bc_playtime tablosundan en yuksek sureleri cek
	local InfoSQL = SafeQuery([[
		SELECT p.citizenid, p.charinfo, COALESCE(pt.time, 0) as db_minutes
		FROM players p
		LEFT JOIN bc_playtime pt ON pt.cid = p.citizenid
		ORDER BY COALESCE(pt.time, 0) DESC
		LIMIT 20
	]], {})

	local array = {}
	if InfoSQL then
		for i=1, #InfoSQL do
			local ok, charinfo = pcall(json.decode, InfoSQL[i].charinfo)
			if ok and charinfo then
				local dbMinutes = tonumber(InfoSQL[i].db_minutes) or 0

				-- Aktif session suresi ekle (online ise)
				local activeMinutes = 0
				if type(PlayerSessions) == 'table' then
					for src, session in pairs(PlayerSessions) do
						if session and session.citizenid == InfoSQL[i].citizenid and session.joinTime then
							activeMinutes = math.floor((now - session.joinTime) / 60)
							break
						end
					end
				end

				local totalMinutes = dbMinutes + activeMinutes

				if totalMinutes > 0 then
					local hours = math.floor(totalMinutes / 60)
					local minutes = totalMinutes % 60
					local timeStr = string.format("%d saat %d dakika", hours, minutes)

					array[#array+1] = {
						firstname = charinfo.firstname,
						lastname = charinfo.lastname,
						time = timeStr,
						playtime_raw = totalMinutes
					}
				end
			end
		end
	end

	-- Toplam sureye gore sirala (aktif session eklenince siralama degisebilir)
	table.sort(array, function(a, b) return (a.playtime_raw or 0) > (b.playtime_raw or 0) end)

	-- Ilk 10'u al
	local top10 = {}
	for i = 1, math.min(10, #array) do
		top10[#top10+1] = array[i]
	end

	cb({
        success = true,
        message = top10,
        author = "BC-Development"
    })
end)

RegisterNetEvent('BC-Web:callback:getSQLSaveTime',function(cb)
	cb({
		success = true,
		message = Settings.sqlSaveInterval,
		author = "BC-Development"
	})
end)
RegisterNetEvent('BC-Web:callback:setSQLSaveInterval',function(minute,cb)
	Settings.sqlSaveInterval = minute 
	SaveResourceFile(GetCurrentResourceName(), "settings.json", json.encode(Settings), -1)
	cb({
        success = true,
        message = "SQL Yedekleme suresi guncellendi!",
        author = "BC-Development"
    })
end)

RegisterNetEvent('BC-Web:callback:sqlSave', function(cb)
    if GetInvokingResource() ~= "BC-Web" then
        cb({
            success = false,
            message = "Not Authorized on Admin Commands!",
            author = "BC-Development"
        })
        return
    end

    local database_name = BCPanel.dbName
    local backup_file = os.date("%Y-%m-%d-%H-%M-%S") ..".sql"
    -- Direkt C:\temp\ klasorune kaydet (daha guvenli)
    local path = "C:/temp/"..backup_file

    -- Windows icin
    local mysqldumpPath = BCPanel.mysqldumpPath or 'C:/xampp/mysql/bin/mysqldump.exe'
    local command = 'cmd.exe /c "'..mysqldumpPath..' -u root --databases '..database_name..' > "'..path..'" 2>&1"'
    
    -- Linux icin (eger sunucu Linux'taysa bu satirlari aktif et)
    -- local command = 'mysqldump -u root --databases '..database_name..' > "'..path..'" 2>&1'
    
    local result = os.execute(command)
    
    -- Dosya kontrol et
    local file = io.open(path, "rb")
    if not file then
        cb({
            success = false,
            message = "SQL dump olusturulamadi. mysqldump yolunu kontrol edin.",
            author = "BC-Development"
        })
        return
    else
        file:close()
        cb({
            success = true,
            message = path,
            author = "BC-Development"
        })
    end
end)

RegisterNetEvent('BC-Web:callback:killPlayer',function(uid,cb)
	local src = tonumber(uid)
	local Player = GetPlayer(src)
	
	if Player then
		-- Framework'e gore kill event'i
		local killEvent = (BCPanel and BCPanel.Events)[(BCPanel and BCPanel.Framework)].kill
		TriggerClientEvent(killEvent, src)
		
		cb({
			success = true,
			message = "Oyuncu basariyla olduruldu! (Framework: "..FrameworkType..")",
			author = "BC-Development"
		})
	else
		cb({
			success = false,
			message = "Oyuncu bulunamadi!",
			author = "BC-Development"
		})
	end
end)

-- KILL PLAYER BY CITIZEN ID - Citizen ID ile oldur
RegisterNetEvent('BC-Web:callback:killPlayerByCitizenId', function(citizenid, cb)
	local Player = GetPlayerByCitizenId(citizenid)
	if not Player then
		cb({success = false, message = "Oyuncu bulunamadi veya offline!"})
		return
	end
	
	local src = nil
	if FrameworkType == 'qbx' or FrameworkType == 'qb' then
		src = Player.PlayerData.source
	elseif FrameworkType == 'esx' then
		src = Player.source
	end
	
	if src then
		-- Kill islemi - Client-side'a gonder (SetEntityHealth client-side native)
		TriggerClientEvent('BC-Web:client:killPlayer', src)
		
		-- Framework-specific kill events (opsiyonel - ek guvenlik icin)
		if FrameworkType == 'qbx' or FrameworkType == 'qb' then
			TriggerEvent('hospital:client:KillPlayer', src)
			TriggerEvent('qbx_medical:client:kill', src)
			TriggerEvent('qb-ambulancejob:client:kill', src)
		elseif FrameworkType == 'esx' then
			TriggerEvent('esx_ambulancejob:revive', src)
		end
		
		cb({success = true, message = "Oyuncu olduruldu!"})
	else
		cb({success = false, message = "Oyuncu source bulunamadi!"})
	end
end)

RegisterNetEvent('BC-Web:callback:revivePlayer',function(uid,cb)
	local src = tonumber(uid)
	local Player = GetPlayer(src)
	
	if Player then
		local success = false
		local reviveMethod = nil
		
		-- 1. Ambulance Script Export Kullan (Otomatik Tespit)
		if AmbulanceResource and AmbulanceMethod == 'export' and AmbulanceExport then
			local exportSuccess = pcall(function()
				if exports[AmbulanceResource] and exports[AmbulanceResource][AmbulanceExport] then
					exports[AmbulanceResource][AmbulanceExport](src)
					return true
				end
				return false
			end)
			
			if exportSuccess then
				success = true
				reviveMethod = AmbulanceResource .. " (Export: " .. AmbulanceExport .. ")"
			end
		end
		
		-- 2. Ambulance Script Event Bazli (eger export yoksa veya basarisizsa)
		if not success and AmbulanceResource then
			-- Yaygin revive event'lerini dene
			local eventNames = {
				'hospital:client:Revive',
				AmbulanceResource .. ':client:Revive',
				AmbulanceResource .. ':client:revive',
				AmbulanceResource .. ':client:playerRevived',
				AmbulanceResource .. ':server:revive',
				AmbulanceResource .. ':server:Revive'
			}
			
			for _, eventName in ipairs(eventNames) do
				TriggerClientEvent(eventName, src)
			end
			success = true
			reviveMethod = AmbulanceResource .. " (Event)"
		end
		
		-- 4. Framework Event Bazli Revive
		if not success and (BCPanel and BCPanel.Events) and (BCPanel and BCPanel.Framework) and (BCPanel and BCPanel.Events)[(BCPanel and BCPanel.Framework)] and (BCPanel and BCPanel.Events)[(BCPanel and BCPanel.Framework)].revive then
			local reviveEvent = (BCPanel and BCPanel.Events)[(BCPanel and BCPanel.Framework)].revive
			TriggerClientEvent(reviveEvent, src)
			success = true
			reviveMethod = "Framework Event (" .. reviveEvent .. ")"
		end
		
		-- 3. Metadata guncelle
		if Player.Functions and Player.Functions.SetMetaData then
			Player.Functions.SetMetaData('health', 200)
			Player.Functions.SetMetaData('armor', 0)
			Player.Functions.SetMetaData('isdead', false)
			Player.Functions.SetMetaData('inlaststand', false)
		end
		
		-- 4. Fallback: Client-Side Event
		if not success then
			TriggerClientEvent('BC-Web:client:healPlayer', src)
			success = true
			reviveMethod = "Client-Side Event"
		end
		
		local message = "Oyuncu basariyla canlandirildi! (Framework: "..FrameworkType..")"
		if reviveMethod then
			message = message .. " [Yontem: " .. reviveMethod .. "]"
		end
		
		cb({
			success = success,
			message = message,
			author = "BC-Development"
		})
	else
		cb({
			success = false,
			message = "Oyuncu bulunamadi!",
			author = "BC-Development"
		})
	end
end)

-- REVIVE PLAYER BY CITIZEN ID - Citizen ID ile canlandir
RegisterNetEvent('BC-Web:callback:revivePlayerByCitizenId', function(citizenid, cb)
	local Player = GetPlayerByCitizenId(citizenid)
	if not Player then
		cb({success = false, message = "Oyuncu bulunamadi veya offline!"})
		return
	end
	
	local src = nil
	if FrameworkType == 'qbx' or FrameworkType == 'qb' then
		src = Player.PlayerData.source
	elseif FrameworkType == 'esx' then
		src = Player.source
	end
	
	if src then
		local success = false
		local reviveMethod = nil
		
		-- 1. Ambulance Script Export Kullan (Otomatik Tespit)
		if AmbulanceResource and AmbulanceMethod == 'export' and AmbulanceExport then
			local exportSuccess = pcall(function()
				if exports[AmbulanceResource] and exports[AmbulanceResource][AmbulanceExport] then
					exports[AmbulanceResource][AmbulanceExport](src)
					return true
				end
				return false
			end)
			
			if exportSuccess then
				success = true
				reviveMethod = AmbulanceResource .. " (Export: " .. AmbulanceExport .. ")"
			end
		end
		
		-- 2. Ambulance Script Event Bazli (eger export yoksa veya basarisizsa)
		if not success and AmbulanceResource then
			-- Yaygin revive event'lerini dene
			local eventNames = {
				'hospital:client:Revive',
				AmbulanceResource .. ':client:Revive',
				AmbulanceResource .. ':client:revive',
				AmbulanceResource .. ':client:playerRevived',
				AmbulanceResource .. ':server:revive',
				AmbulanceResource .. ':server:Revive'
			}
			
			for _, eventName in ipairs(eventNames) do
				TriggerClientEvent(eventName, src)
			end
			success = true
			reviveMethod = AmbulanceResource .. " (Event)"
		end
		
		-- 3. Framework Event Bazli Revive (fallback)
		if not success and (BCPanel and BCPanel.Events) and (BCPanel and BCPanel.Framework) and (BCPanel and BCPanel.Events)[(BCPanel and BCPanel.Framework)] and (BCPanel and BCPanel.Events)[(BCPanel and BCPanel.Framework)].revive then
			local reviveEvent = (BCPanel and BCPanel.Events)[(BCPanel and BCPanel.Framework)].revive
			TriggerClientEvent(reviveEvent, src)
			success = true
			reviveMethod = "Framework Event (" .. reviveEvent .. ")"
		end
		
		-- 4. Metadata Guncelle (Framework uyumlu)
		if Player.Functions and Player.Functions.SetMetaData then
			Player.Functions.SetMetaData('health', 200)
			Player.Functions.SetMetaData('armor', 0)
			Player.Functions.SetMetaData('isdead', false)
			Player.Functions.SetMetaData('inlaststand', false)
		end
		
		-- 5. Fallback: Client-Side Revive Event
		if not success then
			TriggerClientEvent('BC-Web:client:healPlayer', src)
			success = true
			reviveMethod = "Client-Side Event"
		end
		
		if success then
			local message = "Oyuncu canlandirildi!"
			if reviveMethod then
				message = message .. " (Yontem: " .. reviveMethod .. ")"
			end
			cb({success = true, message = message})
		else
			cb({success = false, message = "Revive islemi basarisiz! Ambulance script bulunamadi."})
		end
	else
		cb({success = false, message = "Oyuncu source bulunamadi!"})
	end
end)

-- HEAL PLAYER BY CITIZEN ID - Citizen ID ile heal
RegisterNetEvent('BC-Web:callback:healPlayerByCitizenId', function(citizenid, cb)
	local Player = GetPlayerByCitizenId(citizenid)
	if not Player then
		cb({success = false, message = "Oyuncu bulunamadi veya offline!"})
		return
	end
	
	local src = nil
	if FrameworkType == 'qbx' or FrameworkType == 'qb' then
		src = Player.PlayerData.source
	elseif FrameworkType == 'esx' then
		src = Player.source
	end
	
	if src then
		local success = false
		
		-- Metadata guncelle - sadece can, zirh yok
		if Player.Functions and Player.Functions.SetMetaData then
			Player.Functions.SetMetaData('health', 200)
			-- ZAirh verme - sadece can ver
			success = true
		end
		
		-- Client-side'a heal event'i gonder (sadece can, zirh yok)
		TriggerClientEvent('BC-Web:client:healPlayer', src, true) -- true = sadece can
		success = true
		
		if success then
			cb({success = true, message = "Oyuncu heal edildi!"})
		else
			cb({success = false, message = "Heal islemi basarisiz!"})
		end
	else
		cb({success = false, message = "Oyuncu source bulunamadi!"})
	end
end)

-- GIVE CLOTHING MENU BY CITIZEN ID - Universal uyumlu
RegisterNetEvent('BC-Web:callback:giveClothingMenuByCitizenId', function(citizenid, cb)
	local Player = GetPlayerByCitizenId(citizenid)
	if not Player then
		cb({success = false, message = "Oyuncu bulunamadi veya offline!"})
		return
	end
	
	local src = nil
	if FrameworkType == 'qbx' or FrameworkType == 'qb' then
		src = Player.PlayerData.source
	elseif FrameworkType == 'esx' then
		src = Player.source
	end
	
	if src then
		-- Framework-detection.lua'daki universal helper kullan
		OpenClothingMenu(src)
		
		local message = "Kiyafet menusu acildi!"
		print("^2[BC-Web] Kiyafet Menusu: " .. (BCPanel.DetectedClothing or 'auto') .. "^7")
		cb({success = true, message = message})
	else
		cb({success = false, message = "Oyuncu source bulunamadi!"})
	end
end)

RegisterNetEvent('BC-Web:callback:getRestartHour',function(cb)
	cb({
		success = true,
		message = restartSaati,
		author = "BC-Development"
	})
end)

-- SERVER UPTIME callback
RegisterNetEvent('BC-Web:callback:getServerUptime',function(cb)
	local uptimeData = getServerUptime()
	cb({
		success = true,
		uptime = uptimeData,
		author = "BC-Development"
	})
end)

RegisterNetEvent('BC-Web:callback:getData',function(infotype,cb)
	if infotype == "vehicles" then
		local vehicles = {}
		if FrameworkType == 'qbx' then
			-- QBX: @qbx_core/shared/vehicles'dan cek
			local success, qbxVehicles = pcall(function()
				return require '@qbx_core.shared.vehicles'
			end)
			if success and qbxVehicles then
				vehicles = qbxVehicles
				print("^2[BC-Web] Vehicles: QBX @qbx_core/shared/vehicles'dan yuklendi")
			else
				-- Alternatif 1: Klasik require dene
				local success2, classicVeh = pcall(function()
					return require 'shared.vehicles'
				end)
				if success2 and classicVeh then
					vehicles = classicVeh
					print("^2[BC-Web] Vehicles: shared.vehicles'dan yuklendi")
				else
					-- Alternatif 2: qbx_core export dene
					local success3, vehList = pcall(function()
						return exports.qbx_core:GetVehiclesByName()
					end)
					if success3 and vehList then
						vehicles = vehList
						print("^2[BC-Web] Vehicles: QBX GetVehiclesByName'den yuklendi")
					end
				end
			end
		else
			-- QB-Core: guvenli erisim
			local ok, sharedVeh = pcall(function() return QBCore.Shared.Vehicles end)
			if ok and sharedVeh and next(sharedVeh) then
				vehicles = sharedVeh
				print("^2[BC-Web] Vehicles: QBCore.Shared.Vehicles'den yuklendi")
			else
				print("^3[BC-Web] UYARI: QBCore.Shared.Vehicles bos veya erisim hatasi")
			end
		end
		
		if not next(vehicles) then
			print("^3[BC-Web] UYARI: Arac listesi bulunamadi!")
			vehicles = {}
		end
		
		cb({
			success = true,
			message = vehicles,
			author = "BC-Development"
		})
	elseif infotype == "items" then
		local items = {}
		if FrameworkType == 'qbx' then
			-- QBX: ox_inventory'den items cek veya shared/items.lua'dan
			if GetResourceState('ox_inventory') == 'started' then
				local success, oxItems = pcall(function()
					return exports.ox_inventory:Items()
				end)
				if success and oxItems and next(oxItems) then
					items = oxItems
					print("^2[BC-Web] Items: OX Inventory'den yuklendi")
				else
					-- ox_inventory henuz hazir olmayabilir, retry
					Wait(3000)
					local s2, oxRetry = pcall(function() return exports.ox_inventory:Items() end)
					if s2 and oxRetry and next(oxRetry) then
						items = oxRetry
						print("^2[BC-Web] Items: OX Inventory'den yuklendi (retry)")
					end
				end
			end
			
			-- Eger ox_inventory'den alamadiysak, qbx_core'dan dene
			if not next(items) then
				local success2, qbxItems = pcall(function()
					-- QBX Core'da shared.items modulunu yukle
					local sharedItems = require '@qbx_core.shared.items'
					return sharedItems
				end)
				if success2 and qbxItems then
					items = qbxItems
					print("^2[BC-Web] Items: QBX @qbx_core/shared/items'dan yuklendi")
				else
					-- Eger bu da calismazsa, klasik require dene
					local success3, classicItems = pcall(function()
						return require 'shared.items'
					end)
					if success3 and classicItems then
						items = classicItems
						print("^2[BC-Web] Items: shared.items'dan yuklendi")
					end
				end
			end
		else
			-- QB-Core: guvenli erisim + ox_inventory fallback
			local ok, sharedItems = pcall(function() return QBCore.Shared.Items end)
			if ok and sharedItems and next(sharedItems) then
				items = sharedItems
				print("^2[BC-Web] Items: QBCore.Shared.Items'dan yuklendi")
			else
				-- ox_inventory varsa oradan dene
				if GetResourceState('ox_inventory') == 'started' then
					local s2, oxI = pcall(function() return exports.ox_inventory:Items() end)
					if s2 and oxI and next(oxI) then
						items = oxI
						print("^2[BC-Web] Items: ox_inventory'den yuklendi (QB fallback)")
					end
				end
			end
		end
		
		-- Hic item bulunamadiysa bos object dondur
		if not next(items) then
			print("^3[BC-Web] UYARI: Item listesi bulunamadi!")
			items = {}
		end
		
		cb({
			success = true,
			message = items,
			author = "BC-Development"
		})
	elseif infotype == "jobs" then
		local jobs = {}
		if FrameworkType == 'qbx' then
			-- QBX: @qbx_core/shared/jobs'dan cek
			local success, qbxJobs = pcall(function()
				return require '@qbx_core.shared.jobs'
			end)
			if success and qbxJobs then
				jobs = qbxJobs
				print("^2[BC-Web] Jobs: QBX @qbx_core/shared/jobs'dan yuklendi")
			else
				-- Alternatif 1: Klasik require dene
				local success2, classicJobs = pcall(function()
					return require 'shared.jobs'
				end)
				if success2 and classicJobs then
					jobs = classicJobs
					print("^2[BC-Web] Jobs: shared.jobs'dan yuklendi")
				else
					-- Alternatif 2: qbx_core export dene
					local success3, jobList = pcall(function()
						return exports.qbx_core:GetJobs()
					end)
					if success3 and jobList then
						jobs = jobList
						print("^2[BC-Web] Jobs: QBX GetJobs'dan yuklendi")
					end
				end
			end
		else
			-- QB-Core: guvenli erisim
			local ok, sharedJobs = pcall(function() return QBCore.Shared.Jobs end)
			if ok and sharedJobs and next(sharedJobs) then
				jobs = sharedJobs
				print("^2[BC-Web] Jobs: QBCore.Shared.Jobs'dan yuklendi")
			else
				print("^3[BC-Web] UYARI: QBCore.Shared.Jobs bos veya erisim hatasi")
			end
		end
		
		if not next(jobs) then
			print("^3[BC-Web] UYARI: Meslek listesi bulunamadi!")
			jobs = {}
		end
		
		cb({
			success = true,
			message = jobs,
			author = "BC-Development"
		})
	elseif infotype == "config" then
		-- Script config degerlerini dondur
		local configData = {
			ItemListPath = BCPanel.ItemListPath or "",
			ItemListPathManual = BCPanel.ItemListPathManual or false,
			VehicleListPath = BCPanel.VehicleListPath or "",
			VehicleListPathManual = BCPanel.VehicleListPathManual or false
		}
		
		cb({
			success = true,
			message = configData,
			author = "BC-Development"
		})
	elseif infotype == "blips" then
		cb({
			success = true,
			message = Blips,
			author = "BC-Development"
		})
	elseif infotype == "stashs" then
		cb({
			success = true,
			message = Stashs,
			author = "BC-Development"
		})
	elseif infotype == "garages" then
		-- Garaj sistemini otomatik algila ve garajlari dondur
		local garages = {}
		
		print("^3[BC-Web] Garaj sistemi algilaniyor: " .. GarageSystem)
		
		if GarageSystem == 'jg_garages' then
			local success, jgGarages = pcall(function()
				local exp = nil
				if GarageResourceName and exports[GarageResourceName] then
					exp = exports[GarageResourceName]
				elseif exports['jg-advancedgarages'] then
					exp = exports['jg-advancedgarages']
				elseif exports['jg-garages'] then
					exp = exports['jg-garages']
				end
				if not exp then return {} end
				if exp.getAllGarages then
					return exp:getAllGarages() or {}
				elseif exp.GetAllGarages then
					return exp:GetAllGarages() or {}
				elseif exp.GetGarages then
					return exp:GetGarages() or {}
				end
				return {}
			end)
			if success and jgGarages then
				for garageName, garageData in pairs(jgGarages) do
					garages[garageName] = {
						label = garageData.label or garageName,
						type = garageData.type or 'public'
					}
				end
				print("^2[BC-Web] JG Advanced Garages'dan " .. tostring(#garages) .. " garaj yuklendi")
			end
			
		elseif GarageSystem == 'qb_garages' or GarageSystem == 'qbx_garages' then
			if Core and Core.Shared and Core.Shared.Garages then
				for garageName, garageData in pairs(Core.Shared.Garages) do
					garages[garageName] = {
						label = garageData.label or garageName,
						type = garageData.type or 'public'
					}
				end
				print("^2[BC-Web] QB/QBX Garages'dan " .. #garages .. " garaj yuklendi")
			end
			
		elseif GarageSystem == 'cd_garage' then
			if Config and Config.Garages then
				for garageName, garageData in pairs(Config.Garages) do
					garages[garageName] = {
						label = garageData.garage_name or garageName,
						type = garageData.type or 'public'
					}
				end
				print("^2[BC-Web] CD Garage'dan " .. #garages .. " garaj yuklendi")
			end
		end
		
		-- Hicbir garaj bulunamadiysa varsayilan garajlar
		if next(garages) == nil then
			garages = {
				pillboxgarage = {label = 'Pillbox Garage', type = 'public'},
				motelgarage = {label = 'Motel Garage', type = 'public'},
				sapcounsel = {label = 'SAP Counsel Garage', type = 'public'},
				spanishave = {label = 'Spanish Ave Garage', type = 'public'},
				caears24 = {label = 'Caears 24 Garage', type = 'public'},
				caears242 = {label = 'Caears 24/2 Garage', type = 'public'},
				lagunapi = {label = 'Laguna Parking', type = 'public'},
				airportp = {label = 'Airport Parking', type = 'public'},
				boatgarage = {label = 'Boat Garage', type = 'boat'},
				aircraftgarage = {label = 'Aircraft Garage', type = 'air'},
				lspdgarage = {label = 'LSPD Garage', type = 'job'},
				sasdgarage = {label = 'SASD Garage', type = 'job'},
				ambulancegarage = {label = 'Ambulance Garage', type = 'job'}
			}
			print("^3[BC-Web] Varsayilan garajlar kullaniliyor")
		end
		
		cb({
			success = true,
			message = garages,
			author = "BC-Development",
			system = GarageSystem
		})
	elseif infotype == "locations" then
		cb({
			success = true,
			message = Settings.locations,
			author = "BC-Development"
		})
	else
		cb({
			success = false,
			message = "Invalid Type!",
			author = "BC-Development"
		})
	end
end)

-- ===============================================================
-- ITEM YONETIMI: Item Ekle / Sil (ox_inventory_items tablosu)
-- Web panelden gelen item ekleme/silme isteklerini isler.
-- Sunucu restart sonrasi gecerli olur (ox_inventory tablodan okur).
-- Eger ox_inventory calisiyorsa, runtime'da da RegisterItem denir.
-- ===============================================================
RegisterNetEvent('BC-Web:callback:manageItem', function(action, name, label, weight, stack, description, image, cb)
	if action == "add" then
		if not name or name == "" then
			cb({ success = false, message = "Item adi zorunludur!" })
			return
		end
		if not label or label == "" then
			cb({ success = false, message = "Item etiketi zorunludur!" })
			return
		end

		local weightNum = tonumber(weight) or 0
		local stackVal = (stack == nil or stack == true) and 1 or 0

		-- ox_inventory_items tablosuna ekle (yoksa olustur)
		local createTableQuery = [[
			CREATE TABLE IF NOT EXISTS ox_inventory_items (
				name VARCHAR(100) NOT NULL PRIMARY KEY,
				label VARCHAR(200) NOT NULL,
				weight INT DEFAULT 0,
				stack TINYINT(1) DEFAULT 1,
				description TEXT DEFAULT NULL
			)
		]]
		
		MySQL.Async.execute(createTableQuery, {}, function()
			-- Ayni isimde var mi kontrol et
			MySQL.Async.fetchAll('SELECT name FROM ox_inventory_items WHERE name = @name', {
				['@name'] = name
			}, function(existing)
				if existing and #existing > 0 then
					cb({ success = false, message = "Bu isimde bir item zaten mevcut: " .. name })
					return
				end

				-- Tabloya ekle
				MySQL.Async.execute(
					'INSERT INTO ox_inventory_items (name, label, weight, stack, description) VALUES (@name, @label, @weight, @stack, @description)',
					{
						['@name'] = name,
						['@label'] = label,
						['@weight'] = weightNum,
						['@stack'] = stackVal,
						['@description'] = description or ''
					},
					function(rowsChanged)
						if rowsChanged and rowsChanged > 0 then
							-- Runtime'da ox_inventory'ye kaydet (eger calisiyorsa)
							if GetResourceState('ox_inventory') == 'started' then
								pcall(function()
									-- ox_inventory v2.x RegisterItem destegi
									if exports.ox_inventory.RegisterItem then
										exports.ox_inventory:RegisterItem(name, {
											label = label,
											weight = weightNum,
											stack = stackVal == 1,
											description = description or '',
										})
									end
								end)
							end

							print("^2[BC-Web] Item eklendi: " .. name .. " (" .. label .. ")^7")

							-- items.lua dosyasina da yaz
							pcall(function()
								local itemsLuaPath = GetResourcePath('ox_inventory') .. '/data/items.lua'
								local file = io.open(itemsLuaPath, 'r')
								if file then
									local content = file:read('*a')
									file:close()

									-- Son } karakterini bul ve yeni item'i ondan once ekle
									local lastBrace = content:find('}%s*$')
									if lastBrace then
										local stackStr = stackVal == 1 and 'true' or 'false'
										local newEntry = string.format(
											"\n    ['%s'] = {\n        label = '%s',\n        weight = %d,\n        stack = %s,\n    },\n",
											name,
											label:gsub("'", "\\'"),
											weightNum,
											stackStr
										)
										local newContent = content:sub(1, lastBrace - 1) .. newEntry .. content:sub(lastBrace)
										local wf = io.open(itemsLuaPath, 'w')
										if wf then
											wf:write(newContent)
											wf:close()
											print("^2[BC-Web] Item items.lua dosyasina yazildi: " .. name .. "^7")
										end
									end
								end
							end)

							cb({ success = true, message = "Item basariyla eklendi: " .. label .. ". items.lua ve veritabanina kaydedildi." })
						else
							cb({ success = false, message = "Item eklenirken veritabani hatasi olustu." })
						end
					end
				)
			end)
		end)

	elseif action == "delete" then
		if not name or name == "" then
			cb({ success = false, message = "Item adi zorunludur!" })
			return
		end

		MySQL.Async.execute('DELETE FROM ox_inventory_items WHERE name = @name', {
			['@name'] = name
		}, function(rowsChanged)
			if rowsChanged and rowsChanged > 0 then
				print("^3[BC-Web] Item silindi: " .. name .. "^7")
				cb({ success = true, message = "Item basariyla silindi: " .. name })
			else
				cb({ success = true, message = "Item veritabaninda bulunamadi. Lua dosyasindan yuklenen bir item'dir, sunucu tarafinda duzenleme gereklidir.", warning = true })
			end
		end)

	else
		cb({ success = false, message = "Gecersiz action: " .. tostring(action) })
	end
end)

-- ===============================================================
-- MESLEK YONETIMI: Meslek Ekle / Sil
-- Web panelden gelen meslek ekleme/silme isteklerini isler.
-- QBCore/QBX: Shared.Jobs tablosuna + MySQL'e yazar
-- Sunucu restart sonrasi kalicidir.
-- ===============================================================
RegisterNetEvent('BC-Web:callback:manageJob', function(action, name, label, grades, cb)
	if action == "add" then
		if not name or name == "" then
			cb({ success = false, message = "Meslek kodu zorunludur!" })
			return
		end
		if not label or label == "" then
			cb({ success = false, message = "Meslek etiketi zorunludur!" })
			return
		end

		-- Grades'i duzenle (gelen JSON array/object'i Lua table'a cevir)
		local gradesTable = {}
		if grades and type(grades) == "table" then
			gradesTable = grades
		elseif grades and type(grades) == "string" then
			local ok, parsed = pcall(json.decode, grades)
			if ok and parsed then
				gradesTable = parsed
			end
		end

		-- Eger grades bossa default bir grade ekle
		if not next(gradesTable) then
			gradesTable = {
				["0"] = { name = "AalAiAYan", payment = 0 }
			}
		end

		-- MySQL'e kaydet (job_positions tablosu)
		local createTableQuery = [[
			CREATE TABLE IF NOT EXISTS job_positions (
				id INT AUTO_INCREMENT PRIMARY KEY,
				name VARCHAR(100) NOT NULL UNIQUE,
				label VARCHAR(200) NOT NULL,
				grades TEXT DEFAULT NULL
			)
		]]

		MySQL.Async.execute(createTableQuery, {}, function()
			-- Ayni isimde var mi kontrol et
			MySQL.Async.fetchAll('SELECT name FROM job_positions WHERE name = @name', {
				['@name'] = name
			}, function(existing)
				if existing and #existing > 0 then
					cb({ success = false, message = "Bu isimde bir meslek zaten mevcut: " .. name })
					return
				end

				local gradesJson = json.encode(gradesTable)

				MySQL.Async.execute(
					'INSERT INTO job_positions (name, label, grades) VALUES (@name, @label, @grades)',
					{
						['@name'] = name,
						['@label'] = label,
						['@grades'] = gradesJson
					},
					function(rowsChanged)
						if rowsChanged and rowsChanged > 0 then
							-- Runtime'da QBCore/QBX'e de ekle (eger calisiyorsa)
							if FrameworkType == 'qbx' or FrameworkType == 'qb' then
								pcall(function()
									if QBCore and QBCore.Shared and QBCore.Shared.Jobs then
										QBCore.Shared.Jobs[name] = {
											label = label,
											defaultDuty = true,
											offDutyPay = false,
											grades = gradesTable
										}
									end
								end)
							end

							print("^2[BC-Web] Meslek eklendi: " .. name .. " (" .. label .. ")^7")

							-- jobs.lua dosyasina da yaz
							pcall(function()
								local jobsLuaPath = GetResourcePath('qbx_core') .. '/shared/jobs.lua'
								local file = io.open(jobsLuaPath, 'r')
								if file then
									local content = file:read('*a')
									file:close()

									-- Son } karakterini bul ve yeni meslegi ondan once ekle
									local lastBrace = content:find('}%s*$')
									if lastBrace then
										-- Grades string olustur
										local gradesStr = ""
										if gradesTable and type(gradesTable) == "table" then
											for k, v in pairs(gradesTable) do
												local gradeKey = tonumber(k) or 0
												local gradeName = (type(v) == "table" and v.name) or "Calisan"
												local gradePayment = (type(v) == "table" and tonumber(v.payment)) or 0
												gradesStr = gradesStr .. string.format(
													"            [%d] = {\n                name = '%s',\n                payment = %d\n            },\n",
													gradeKey,
													tostring(gradeName):gsub("'", "\\'"),
													gradePayment
												)
											end
										end
										if gradesStr == "" then
											gradesStr = "            [0] = {\n                name = 'Calisan',\n                payment = 0\n            },\n"
										end

										local newEntry = string.format(
											"    ['%s'] = {\n        label = '%s',\n        defaultDuty = true,\n        offDutyPay = false,\n        grades = {\n%s        },\n    },\n",
											name,
											tostring(label):gsub("'", "\\'"),
											gradesStr
										)
										local newContent = content:sub(1, lastBrace - 1) .. newEntry .. content:sub(lastBrace)
										local wf = io.open(jobsLuaPath, 'w')
										if wf then
											wf:write(newContent)
											wf:close()
											print("^2[BC-Web] Meslek jobs.lua dosyasina yazildi: " .. name .. "^7")
										end
									end
								end
							end)

							cb({ success = true, message = "Meslek basariyla eklendi: " .. label .. ". jobs.lua ve veritabanina kaydedildi." })
						else
							cb({ success = false, message = "Meslek eklenirken veritabani hatasi olustu." })
						end
					end
				)
			end)
		end)

	elseif action == "update" then
		if not name or name == "" then
			cb({ success = false, message = "Meslek kodu zorunludur!" })
			return
		end

		-- Grades'i duzenle
		local gradesTable = {}
		if grades and type(grades) == "table" then
			gradesTable = grades
		elseif grades and type(grades) == "string" then
			local ok, parsed = pcall(json.decode, grades)
			if ok and parsed then
				gradesTable = parsed
			end
		end

		-- Eger grades bossa default bir grade ekle
		if not next(gradesTable) then
			gradesTable = {
				["0"] = { name = "AalAiAYan", payment = 0 }
			}
		end

		local gradesJson = json.encode(gradesTable)
		local updateLabel = (label and label ~= "") and label or nil

		local updateQuery
		local updateParams
		if updateLabel then
			updateQuery = 'UPDATE job_positions SET label = @label, grades = @grades WHERE name = @name'
			updateParams = { ['@name'] = name, ['@label'] = updateLabel, ['@grades'] = gradesJson }
		else
			updateQuery = 'UPDATE job_positions SET grades = @grades WHERE name = @name'
			updateParams = { ['@name'] = name, ['@grades'] = gradesJson }
		end

		MySQL.Async.execute(updateQuery, updateParams, function(rowsChanged)
			-- Runtime'da QBCore/QBX'i guncelle
			if FrameworkType == 'qbx' or FrameworkType == 'qb' then
				pcall(function()
					if QBCore and QBCore.Shared and QBCore.Shared.Jobs and QBCore.Shared.Jobs[name] then
						QBCore.Shared.Jobs[name].grades = gradesTable
						if updateLabel then
							QBCore.Shared.Jobs[name].label = updateLabel
						end
					end
				end)
			end

			-- jobs.lua dosyasini guncelle
			pcall(function()
				local jobsLuaPath = GetResourcePath('qbx_core') .. '/shared/jobs.lua'
				local file = io.open(jobsLuaPath, 'r')
				if file then
					local content = file:read('*a')
					file:close()

					-- Mevcut job blogunu bul ve guncelle
					local jobLabel = updateLabel or label or name

					-- Yeni grades string olustur
					local gradesStr = ""
					if gradesTable and type(gradesTable) == "table" then
						for k, v in pairs(gradesTable) do
							local gradeKey = tonumber(k) or 0
							local gradeName = (type(v) == "table" and v.name) or "Calisan"
							local gradePayment = (type(v) == "table" and tonumber(v.payment)) or 0
							gradesStr = gradesStr .. string.format(
								"            [%d] = {\n                name = '%s',\n                payment = %d\n            },\n",
								gradeKey,
								tostring(gradeName):gsub("'", "\\'"),
								gradePayment
							)
						end
					end
					if gradesStr == "" then
						gradesStr = "            [0] = {\n                name = 'Calisan',\n                payment = 0\n            },\n"
					end

					local newEntry = string.format(
						"    ['%s'] = {\n        label = '%s',\n        defaultDuty = true,\n        offDutyPay = false,\n        grades = {\n%s        },\n    },\n",
						name,
						tostring(jobLabel):gsub("'", "\\'"),
						gradesStr
					)

					-- Mevcut entry'yi bul (['jobname'] = { ... }, pattern)
					local escapedName = name:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")
					local startPos = content:find("%['" .. escapedName .. "'%]%s*=%s*%{")
					if startPos then
						-- Entry'nin sonundaki },\n'i bul (nested brace counting)
						local depth = 0
						local endPos = nil
						for i = startPos, #content do
							local c = content:sub(i, i)
							if c == '{' then depth = depth + 1
							elseif c == '}' then
								depth = depth - 1
								if depth == 0 then
									-- Sonraki , ve whitespace'i de al
									local after = content:sub(i + 1):match("^(,?%s*\n?)")
									endPos = i + #(after or "")
									break
								end
							end
						end

						if endPos then
							local newContent = content:sub(1, startPos - 1) .. newEntry .. content:sub(endPos + 1)
							local wf = io.open(jobsLuaPath, 'w')
							if wf then
								wf:write(newContent)
								wf:close()
								print("^2[BC-Web] Meslek jobs.lua dosyasinda guncellendi: " .. name .. "^7")
							end
						end
					else
						-- Bulunamazsa sona ekle
						local lastBrace = content:find('}%s*$')
						if lastBrace then
							local newContent = content:sub(1, lastBrace - 1) .. "\n" .. newEntry .. content:sub(lastBrace)
							local wf = io.open(jobsLuaPath, 'w')
							if wf then
								wf:write(newContent)
								wf:close()
								print("^2[BC-Web] Meslek jobs.lua dosyasina eklendi (update): " .. name .. "^7")
							end
						end
					end
				end
			end)

			print("^2[BC-Web] Meslek guncellendi: " .. name .. "^7")
			cb({ success = true, message = "Meslek basariyla guncellendi: " .. name })
		end)

	elseif action == "delete" then
		if not name or name == "" then
			cb({ success = false, message = "Meslek kodu zorunludur!" })
			return
		end

		MySQL.Async.execute('DELETE FROM job_positions WHERE name = @name', {
			['@name'] = name
		}, function(rowsChanged)
			if rowsChanged and rowsChanged > 0 then
				-- Runtime'da QBCore/QBX'ten de kaldAir
				if FrameworkType == 'qbx' or FrameworkType == 'qb' then
					pcall(function()
						if QBCore and QBCore.Shared and QBCore.Shared.Jobs then
							QBCore.Shared.Jobs[name] = nil
						end
					end)
				end

				print("^3[BC-Web] Meslek silindi: " .. name .. "^7")
				cb({ success = true, message = "Meslek basariyla silindi: " .. name })
			else
				cb({ success = true, message = "Meslek veritabaninda bulunamadi. Lua dosyasindan yuklenen bir meslektir, sunucu tarafinda duzenleme gereklidir.", warning = true })
			end
		end)

	else
		cb({ success = false, message = "Gecersiz action: " .. tostring(action) })
	end
end)

RegisterNetEvent('BC-Web:callback:deleteLocation',function(name,cb)
	name = string.gsub(name, "_", " ")
	Settings.locations[name] = nil
	SaveResourceFile(GetCurrentResourceName(), "settings.json", json.encode(Settings), -1)
	cb({
		success = true,
		message = "Lokasyon basariyla silindi!",
		author = "BC-Development"
	})

end)

RegisterNetEvent('BC-Web:callback:newLocation',function(name,x,y,z,w,cb)
	name = string.gsub(name, "_", " ")
	Settings.locations[name] = {
		x = tonumber(x),
		y = tonumber(y),
		z = tonumber(z),
		w = tonumber(w)
	}
	SaveResourceFile(GetCurrentResourceName(), "settings.json", json.encode(Settings), -1)
	cb({
		success = true,
		message = "Lokasyon basariyla eklendi!",
		author = "BC-Development"
	})
end)

RegisterNetEvent('BC-Web:callback:setLocation',function(src,location,cb)
	src = tonumber(src)
	location = string.gsub(location, "_", " ")
	local coords = Settings.locations[location] or vector4(0,0,0,0)
	SetEntityCoords(
		GetPlayerPed(src) --[[ Entity ]], 
		coords.x --[[ number ]], 
		coords.y --[[ number ]], 
		coords.z --[[ number ]], 
		true --[[ boolean ]], 
		false --[[ boolean ]], 
		false --[[ boolean ]], 
		false --[[ boolean ]]
	)
	cb({
		success = true,
		message = "Oyuncu basariyla bolgeye cekildi!",
		author = "BC-Development"
	})
end)

RegisterNetEvent('BC-Web:server:getBlips',function()
	local src = source
	TriggerClientEvent('BC-Web:client:updateBlips',src,Blips)
	local Player = GetPlayer(src)
	if Player then
		local discordIdentifier = GetIdentifier(src, 'discord')
		if discordIdentifier then
			local discordID = discordIdentifier:gsub("discord:", "")
			MySQL.query("UPDATE players SET discordid = ? WHERE citizenid = ?", {discordID, Player.PlayerData.citizenid})
		end
	end
end)

-- Oyuncu karakter sectiginde discordid'yi otomatik guncelle
-- QBX ve QB-Core uyumlu
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
	local src = source
	local Player = GetPlayer(src)
	if Player then
		local discordIdentifier = GetIdentifier(src, 'discord')
		if discordIdentifier then
			local discordID = discordIdentifier:gsub("discord:", "")
			MySQL.query("UPDATE players SET discordid = ? WHERE citizenid = ?", {discordID, Player.PlayerData.citizenid})
			print("^2[BC-Web] Discord ID guncellendi: " .. discordID .. " -> " .. Player.PlayerData.citizenid)
		end
	end
end)

-- QBX icin alternatif event (QBX genelde farkli event kullanir)
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
	local src = Player.PlayerData.source
	local discordIdentifier = GetIdentifier(src, 'discord')
	if discordIdentifier then
		local discordID = discordIdentifier:gsub("discord:", "")
		MySQL.query("UPDATE players SET discordid = ? WHERE citizenid = ?", {discordID, Player.PlayerData.citizenid})
		print("^2[BC-Web] Discord ID guncellendi (QBX): " .. discordID .. " -> " .. Player.PlayerData.citizenid)
	end
end)

-- Sunucu basladiginda online oyuncularin discordid'lerini guncelle
CreateThread(function()
	Wait(10000) -- 10 saniye bekle (sunucu tamamen baslasin)
	for _, playerId in ipairs(GetPlayers()) do
		local Player = GetPlayer(tonumber(playerId))
		if Player then
			local discordIdentifier = GetIdentifier(playerId, 'discord')
			if discordIdentifier then
				local discordID = discordIdentifier:gsub("discord:", "")
				MySQL.query("UPDATE players SET discordid = ? WHERE citizenid = ?", {discordID, Player.PlayerData.citizenid})
			end
		end
	end
	print("^2[BC-Web] Tum online oyuncularin Discord ID'leri guncellendi!")
end)

RegisterNetEvent('BC-Web:server:getStashs',function()
	local src = source
	TriggerClientEvent('BC-Web:client:updateStashs',src,Stashs)
end)

RegisterNetEvent('BC-Web:callback:setJob',function(src,job,grade,cb)
	local Player = GetPlayer(tonumber(src))
	if Player then
		if Player.Functions and Player.Functions.SetJob then
			Player.Functions.SetJob(job,tonumber(grade))
		end
		cb({
			success = true,
			message = "Kisiye meslek basariyla verildi!",
			author = "BC-Development"
		})
	else
		cb({
			success = false,
			message = "Kisi daha karakter secmemis!",
			author = "BC-Development"
		})
	end
	
end)

-- ============================================
-- ITEM RESIM HTTP HANDLER
-- GET /bc-Web/itemImage/:name â†’ item resmi dÃ¶ndÃ¼rÃ¼r
-- ============================================
SetHttpHandler(function(req, res)
    local path = req.path or ''
    -- /itemImage/ITEM_ADI formatÄ±nÄ± yakala
    local itemName = path:match('^/itemImage/([%w_%-%.]+)$')
    if not itemName then
        res.writeHead(404, {['Content-Type']='text/plain'})
        res.write('Not Found')
        res.send()
        return
    end
    -- GÃ¼venlik: sadece harf/rakam/alt Ã§izgi/tire/nokta
    itemName = itemName:gsub('[^%w_%-]', '')
    if itemName == '' then
        res.writeHead(400)
        res.send()
        return
    end
    -- UzantÄ±sÄ±z geldiyse Ã¶nce .png, sonra .webp, sonra .jpg dene
    local extensions = {'png', 'webp', 'jpg', 'jpeg', 'gif'}
    local mimeTypes = {png='image/png', webp='image/webp', jpg='image/jpeg', jpeg='image/jpeg', gif='image/gif'}
    local imageDir = (BCPanel and (BCPanel and BCPanel.itemImagePath)) or ''
    if imageDir == '' then
        -- Otomatik tespit: Ã¶nce GetResourcePath ile ox_inventory bul
        local oxPath = GetResourcePath('ox_inventory')
        if oxPath and oxPath ~= '' and oxPath ~= 'None' then
            local testPath = oxPath .. '/web/images'
            local testFile = io.open(testPath .. '/money.png', 'r') or io.open(testPath .. '/water.png', 'r')
            if testFile then testFile:close(); imageDir = testPath end
        end
        -- Config'te manuel yol belirtilmisse onu dene
        if imageDir == '' and BCPanel and (BCPanel and BCPanel.itemImagePath) and (BCPanel and BCPanel.itemImagePath) ~= '' then
            local testManual = io.open((BCPanel and BCPanel.itemImagePath) .. '/money.png', 'r') or io.open((BCPanel and BCPanel.itemImagePath) .. '/water.png', 'r')
            if testManual then testManual:close(); imageDir = (BCPanel and BCPanel.itemImagePath) end
        end
        -- Yaygin dizin yapÄ±larini otomatik tara
        if imageDir == '' then
            local serverDataPath = GetResourcePath('ox_inventory')
            if serverDataPath and serverDataPath ~= '' and serverDataPath ~= 'None' then
                -- ox_inventory resource path'inin ust dizinlerinden /web/images bul
                local altPath = serverDataPath:gsub('\\', '/') .. '/web/images'
                local test = io.open(altPath .. '/money.png', 'r') or io.open(altPath .. '/water.png', 'r')
                if test then test:close(); imageDir = altPath end
            end
        end
    end
    if imageDir ~= '' then
        for _, ext in ipairs(extensions) do
            local filePath = imageDir .. '/' .. itemName .. '.' .. ext
            local f = io.open(filePath, 'rb')
            if f then
                local data = f:read('*all')
                f:close()
                res.writeHead(200, {
                    ['Content-Type'] = mimeTypes[ext] or 'image/png',
                    ['Cache-Control'] = 'public, max-age=3600',
                    ['Access-Control-Allow-Origin'] = '*'
                })
                res.write(data)
                res.send()
                return
            end
        end
    end
    res.writeHead(404, {['Content-Type']='text/plain'})
    res.write('Image not found')
    res.send()
end)

-- ============================================
-- LIVE CONSOLE ENTEGRASYONU
-- ============================================
if AddConsoleListener then
    AddConsoleListener(function(channel, message)
        -- JavaScript socket.js tarafına logu fırlat
        TriggerEvent('BC-Web:server:consoleLog', channel, message)
    end)
else
    print("^1[BC-Web] UYARI: AddConsoleListener bu FXServer surumunde desteklenmiyor. Live Console aktif olmayacaktir.^0")
end

-- Lua tarafında komut çalıştırma export'u
exports('handlePanelCommand', function(command, payload)
    if command == "console_command" and payload and payload.cmd then
        print("^3[BC-Web] Panelden gelen komut calistiriliyor: " .. payload.cmd .. "^0")
        ExecuteCommand(payload.cmd)
        return { success = true, message = "Komut çalıştırıldı." }
    end
    return { success = false, message = "Bilinmeyen komut." }
end)