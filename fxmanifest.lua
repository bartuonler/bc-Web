fx_version 'bodacious'
version '0.0.2'
author 'BC Development'
games {'gta5'}

shared_scripts {
    'config/config.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    'client/client.lua',
    'client/weaponDamage.lua'
}

server_scripts {
    'server/autoLogCapture.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/framework-detection.lua',
    'server/server.lua',
    'server/version.lua',
    'config/wiki-integration.lua',
    'server/command_queue.lua',
    'server/weaponDamage.lua',
    'server/socket.js'
}

escrow_ignore {
  "config/config.lua",
  "client/weaponDamage.lua",
  "server/weaponDamage.lua",
}
dependency '/assetpacks'
