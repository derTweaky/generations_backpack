fx_version 'cerulean'
game 'gta5'

author 'derTweaky'
description 'Metadata-based Backpack System with Slot 6 expansion, lation_ui and illenium-appearance support'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'ox_lib',
    'lation_ui',
    'ox_inventory',
    'illenium-appearance'
}
