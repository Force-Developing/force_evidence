fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'force_evidence'
author 'Force Developments <discord:@force3883>'
description 'Police evidence lockers per citizen, stored as inventory stashes. ESX, QBCore and QBox.'
version '2.0.0'

dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/functions.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'version.lua',
    'server/custom/frameworks/*.lua',
    'server/custom/inventory.lua',
    'server/main.lua',
}

client_scripts {
    'client/custom/frameworks/*.lua',
    'client/main.lua',
}

files {
    'locales/*.json',
}
