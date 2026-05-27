local Config = {
    WebPanelAPI = "http://localhost/britney/captureGameLog.php",
    SecretKey = "bc-web-secret-2025",
    
    Keywords = {
        admin = {"admin", "ban", "kick", "teleport", "revive", "heal", "warn", "spectate", "freeze", "noclip"},
        inventory = {"item", "inventory", "give", "remove", "drop", "pickup", "use", "craft", "stash"},
        vehicle = {"vehicle", "car", "spawn", "delete", "garage", "impound", "park", "repair"},
        money = {"money", "cash", "bank", "payment", "transfer", "pay", "withdraw", "deposit"},
        job = {"job", "duty", "hire", "fire", "salary", "grade", "boss", "society"},
        police = {"arrest", "cuff", "fine", "jail", "evidence", "seized", "warrant", "mdt"},
        ambulance = {"revive", "heal", "diagnose", "ambulance", "ems", "hospital"},
        mechanic = {"repair", "tune", "upgrade", "mechanic", "performance"},
        death = {"death", "kill", "died", "murdered", "suicide"},
        property = {"house", "property", "apartment", "rent", "buy", "shell"},
        weapon = {"weapon", "gun", "shoot", "ammo", "armory"}
    }
}

local function DetectCategory(data, resourceName)
    local text = (resourceName or ""):lower()
    if data.embeds and data.embeds[1] then
        text = text .. " " .. (data.embeds[1].title or ""):lower()
        text = text .. " " .. (data.embeds[1].description or ""):lower()
    end
    if data.content then text = text .. " " .. data.content:lower() end
    
    for category, keywords in pairs(Config.Keywords) do
        for _, keyword in ipairs(keywords) do
            if text:find(keyword) then return category end
        end
    end
    return "general"
end

local function ParsePlayerInfo(text)
    if not text then return nil end
    local patterns = {"%[(%d+)%]", "%((%d+)%)", "#(%d+)", "ID:?%s*(%d+)", "Player%s+(%d+)"}
    for _, pattern in ipairs(patterns) do
        local id = text:match(pattern)
        if id then return tonumber(id) end
    end
    return nil
end

local function GetPlayerDetails(sourceId)
    if not sourceId or sourceId == 0 then return nil end
    local player, citizenId, discordId, name = nil, nil, nil, nil
    
    -- pcall ile güvenli şekilde framework'den oyuncu bilgisi al
    if GetResourceState('qbx_core') == 'started' then
        local ok, p = pcall(function() return exports.qbx_core:GetPlayer(sourceId) end)
        if ok and p then player = p end
    elseif GetResourceState('qb-core') == 'started' then
        local ok, p = pcall(function() return exports['qb-core']:GetCoreObject().Functions.GetPlayer(sourceId) end)
        if ok and p then player = p end
    end
    
    if player and player.PlayerData then
        citizenId = player.PlayerData.citizenid
        local ok, n = pcall(function()
            return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        end)
        if ok then name = n end
        discordId = player.PlayerData.license
    end
    
    if not player and GetResourceState('es_extended') == 'started' then
        local success, xPlayer = pcall(function() return exports['es_extended']:getSharedObject().GetPlayerFromId(sourceId) end)
        if success and xPlayer then
            citizenId = xPlayer.identifier
            name = xPlayer.getName()
            discordId = xPlayer.getIdentifier('discord')
        end
    end
    
    if not name then name = GetPlayerName(sourceId) or "Unknown" end
    return {server_id = sourceId, name = name, citizen_id = citizenId, discord_id = discordId}
end

local function SaveToWebPanel(category, data, resourceName)
    local title = (data.embeds and data.embeds[1] and data.embeds[1].title) or "Bilinmeyen İşlem"
    local description = (data.embeds and data.embeds[1] and data.embeds[1].description) or ""
    local sourcePlayer, targetPlayer = nil, nil
    
    local sourceId = ParsePlayerInfo(description)
    if sourceId then sourcePlayer = GetPlayerDetails(sourceId) end
    
    local targetText = description:match("→(.+)") or description:match("->(.+)")
    if targetText then
        local targetId = ParsePlayerInfo(targetText)
        if targetId then targetPlayer = GetPlayerDetails(targetId) end
    end
    
    PerformHttpRequest(Config.WebPanelAPI, function(code, res) end, 'POST', json.encode({
        category = category, action = title, details = description,
        source_resource = resourceName, source_player = sourcePlayer,
        target_player = targetPlayer, timestamp = os.time()
    }), {['Content-Type'] = 'application/json', ['X-BC-Web-Key'] = Config.SecretKey})
end

local _PHR = PerformHttpRequest
function PerformHttpRequest(url, callback, method, data, headers, options)
    -- Sadece Discord webhook'larını yakala, diğer tüm istekleri olduğu gibi geçir
    -- pcall ile sarmalayarak Tebex/diğer resource'ların çökmesini önle
    if type(url) == "string" and url:find("discord%.com/api/webhooks") then
        -- Log yakalamayı async yap, asıl isteği engelleme
        CreateThread(function()
            local ok, wData = pcall(json.decode, data)
            if ok and wData then
                pcall(SaveToWebPanel, DetectCategory(wData, GetInvokingResource() or "unknown"), wData, GetInvokingResource() or "unknown")
            end
        end)
    end
    -- Orijinal fonksiyonu TÜM parametrelerle çağır (Tebex uyumluluğu)
    return _PHR(url, callback, method, data, headers, options)
end

print("^2[BC-Web]^0 Otomatik Log Yakalama ^2AKTİF^0")

