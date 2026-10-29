-- luacheck config for the FiveM templates (CfxLua = Lua 5.4 + FiveM globals)
std = "lua54"
max_line_length = false
unused_args = false

-- Scaffolds intentionally define example helpers that the user wires up later.
ignore = {
    "211", -- unused local variable
    "212", -- unused argument
    "542", -- empty if branch (placeholder "-- logic here" blocks)
}

-- Globals the templates define on purpose (shared across a resource's scripts)
globals = {
    "Config",
    "SendDiscordEmbed", "SendDiscordEmbeds", "BuildEmbed",
    "LogPlayerAction", "LogServerEvent", "LogAdminAction", "LogError",
}

-- FiveM runtime, natives, framework and library globals (read-only)
read_globals = {
    -- CfxLua runtime
    "Citizen", "CreateThread", "Wait", "SetTimeout", "promise", "json", "msgpack",
    "vector2", "vector3", "vector4", "vec2", "vec3", "vec4", "quat", "joaat",
    "source", "exports", "LocalPlayer", "GlobalState", "Entity", "Player",

    -- Events
    "RegisterNetEvent", "AddEventHandler", "TriggerEvent", "TriggerServerEvent",
    "TriggerClientEvent", "CancelEvent", "GetInvokingResource", "AddStateBagChangeHandler",

    -- Resources / commands / convars
    "GetCurrentResourceName", "GetResourceState", "RegisterCommand", "IsPlayerAceAllowed",
    "GetConvar", "GetConvarInt", "PerformHttpRequest", "PerformHttpRequestAwait",

    -- Players / entities
    "GetPlayers", "GetPlayerName", "GetPlayerPed", "GetPlayerIdentifiers", "GetPlayerIdentifierByType",
    "DropPlayer", "PlayerPedId", "GetEntityCoords", "GetEntityHeading", "DoesEntityExist",
    "NetworkGetEntityFromNetworkId", "NetworkGetNetworkIdFromEntity", "GetGameTimer",

    -- Input / NUI
    "IsControlJustPressed", "SendNUIMessage", "RegisterNUICallback", "SetNuiFocus",

    -- Frameworks & libraries
    "ESX", "lib", "cache", "locale", "MySQL",
}

-- fxmanifest directives are globals called with string/table arguments
files["**/fxmanifest.lua"] = {
    read_globals = {
        "fx_version", "game", "games", "name", "author", "description", "version", "lua54",
        "shared_script", "shared_scripts", "client_script", "client_scripts",
        "server_script", "server_scripts", "ui_page", "file", "files",
        "dependency", "dependencies", "export", "exports", "server_export", "server_exports",
        "data_file", "this_is_a_map", "server_only", "loadscreen", "loadscreen_manual_shutdown",
        "node_version", "ox_lib", "ox_libs", "provide",
    },
}
