fx_version 'cerulean'
game 'gta5'

author 'derTweaky'
description 'Metadata-based Backpack System with Slot 25 expansion, lation_ui and illenium-appearance support'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'illenium-appearance'
}
