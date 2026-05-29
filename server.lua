local BACKPACK_DEFAULTS = { slots = 10, weight = 15000, maleDrawable = 31, maleTexture = 0, femaleDrawable = 31, femaleTexture = 0 }

local function IsAdmin(source)
    -- Check Qbox
    if GetResourceState('qbx_core') == 'started' then
        local success, result = pcall(function()
            return exports.qbx_core:HasPermission(source, 'admin') or exports.qbx_core:HasPermission(source, 'god')
        end)
        if success then return result end
    end

    -- Check QBCore
    if GetResourceState('qb-core') == 'started' then
        local success, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if success and QBCore then
            local Player = QBCore.Functions.GetPlayer(source)
            if Player then
                local isAdm = QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')
                if isAdm or Player.PlayerData.group == 'admin' or Player.PlayerData.group == 'god' then
                    return true
                end
            end
        end
    end
    
    -- Check ESX
    if GetResourceState('es_extended') == 'started' then
        local success, ESX = pcall(function()
            return exports.es_extended:getSharedObject()
        end)
        if success and ESX then
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                local group = xPlayer.getGroup()
                return group == 'admin' or group == 'superadmin'
            end
        end
    end
    
    -- Fallback for Ace Permissions
    if IsPlayerAceAllowed(source, "command") or IsPlayerAceAllowed(source, "admin") then
        return true
    end
    
    return false
end

local activeBackpackBonus = {}

local function GetBackpackBonus(source)
    return activeBackpackBonus[source] or 0
end
exports('GetBackpackBonus', GetBackpackBonus)

-- Helper to load presets from backpacks.json
local function LoadPresets()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), "backpacks.json")
    if not fileContent then
        return {}
    end
    local ok, parsed = pcall(json.decode, fileContent)
    return ok and parsed or {}
end

-- Helper to save presets to backpacks.json
local function SavePresets(presets)
    SaveResourceFile(GetCurrentResourceName(), "backpacks.json", json.encode(presets, { indent = true }), -1)
end

-- Export for lation_shops to get backpack metadata by preset ID or label
local function GetBackpackMetadata(presetIdOrLabel)
    local presets = LoadPresets()
    for _, preset in ipairs(presets) do
        if preset.id == presetIdOrLabel or preset.label == presetIdOrLabel or tostring(preset.id) == tostring(presetIdOrLabel) then
            return {
                isBackpack = true,
                label = preset.label,
                component = tonumber(preset.component) or 5,
                slots = tonumber(preset.slots) or 10,
                weight = (tonumber(preset.weight) or 15) * 1000,
                maleDrawable = tonumber(preset.maleDrawable) or 31,
                maleTexture = tonumber(preset.maleTexture) or 0,
                femaleDrawable = tonumber(preset.femaleDrawable) or 31,
                femaleTexture = tonumber(preset.femaleTexture) or 0,
                drawable = tonumber(preset.maleDrawable) or 31,
                texture = tonumber(preset.maleTexture) or 0,
                description = ('Rucksack: %s (Slots: %d, Traglast: %dkg, Komponente: %d)'):format(
                    preset.label, preset.slots, preset.weight, preset.component or 5
                )
            }
        end
    end
    return nil
end
exports('GetBackpackMetadata', GetBackpackMetadata)

-- Ox lib callback for retrieving presets
lib.callback.register('generations_backpack:server:getPresets', function(source)
    if not IsAdmin(source) then return {} end
    return LoadPresets()
end)

-- Event to save a preset
RegisterNetEvent('generations_backpack:server:savePreset', function(presetData)
    local src = source
    if not IsAdmin(src) then return end

    local presets = LoadPresets()
    if not presetData.id then
        presetData.id = os.time() .. "_" .. math.random(1000, 9999)
    end

    local found = false
    for i, preset in ipairs(presets) do
        if preset.id == presetData.id then
            presets[i] = presetData
            found = true
            break
        end
    end

    if not found then
        table.insert(presets, presetData)
    end

    SavePresets(presets)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Preset erfolgreich gespeichert!' })
end)

-- Event to delete a preset
RegisterNetEvent('generations_backpack:server:deletePreset', function(presetId)
    local src = source
    if not IsAdmin(src) then return end

    local presets = LoadPresets()
    local newPresets = {}
    for _, preset in ipairs(presets) do
        if preset.id ~= presetId then
            table.insert(newPresets, preset)
        end
    end

    SavePresets(newPresets)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Preset erfolgreich gelöscht!' })
end)

-- Event to give a preset to admin
RegisterNetEvent('generations_backpack:server:givePreset', function(presetData)
    local src = source
    if not IsAdmin(src) then return end

    local metadata = {
        isBackpack = true,
        label = presetData.label,
        component = tonumber(presetData.component) or 5,
        slots = tonumber(presetData.slots) or 10,
        weight = (tonumber(presetData.weight) or 15) * 1000,
        maleDrawable = tonumber(presetData.maleDrawable) or 31,
        maleTexture = tonumber(presetData.maleTexture) or 0,
        femaleDrawable = tonumber(presetData.femaleDrawable) or 31,
        femaleTexture = tonumber(presetData.femaleTexture) or 0,
        drawable = tonumber(presetData.maleDrawable) or 31,
        texture = tonumber(presetData.maleTexture) or 0,
        description = ('Rucksack: %s (Slots: %d, Traglast: %dkg, Komponente: %d)'):format(
            presetData.label, presetData.slots, presetData.weight, presetData.component or 5
        )
    }

    exports.ox_inventory:AddItem(src, 'clothing', 1, metadata)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Rucksack erfolgreich ins Inventar gelegt!' })
end)

-- Helper to update player inventory limits based on slot 6 content
local function ProcessBackpackUpdate(source)
    local defaultSlots = GetConvarInt('inventory:slots', 50)
    local defaultWeight = GetConvarInt('inventory:weight', 30000)

    local item = exports.ox_inventory:GetSlot(source, 6)
    local isBackpack = item and item.name == 'clothing' and item.metadata and (item.metadata.isBackpack or item.metadata.component ~= nil)

    print(string.format("^3[generations_backpack] ProcessBackpackUpdate for player %s. Item in Slot 6: %s (isBackpack: %s)^7", tostring(source), item and item.name or "none", tostring(isBackpack)))

    if isBackpack then
        local metadata = item.metadata or {}

        -- Read metadata values or fall back to defaults
        local extraSlots = tonumber(metadata.slots) or BACKPACK_DEFAULTS.slots
        local extraWeight = tonumber(metadata.weight) or BACKPACK_DEFAULTS.weight
        local component = tonumber(metadata.component) or 5

        activeBackpackBonus[source] = extraWeight

        exports.ox_inventory:SetSlotCount(source, defaultSlots + extraSlots)
        
        -- If xnr-gym is started, we let it handle the max weight update.
        if GetResourceState('xnr-gym') ~= 'started' then
            exports.ox_inventory:SetMaxWeight(source, defaultWeight + extraWeight)
        end

        -- Determine drawable and texture for client syncing
        local maleDrawable = tonumber(metadata.maleDrawable) or tonumber(metadata.drawable) or BACKPACK_DEFAULTS.maleDrawable
        local maleTexture = tonumber(metadata.maleTexture) or tonumber(metadata.texture) or BACKPACK_DEFAULTS.maleTexture
        local femaleDrawable = tonumber(metadata.femaleDrawable) or tonumber(metadata.drawable) or BACKPACK_DEFAULTS.femaleDrawable
        local femaleTexture = tonumber(metadata.femaleTexture) or tonumber(metadata.texture) or BACKPACK_DEFAULTS.femaleTexture

        TriggerClientEvent('generations_backpack:client:syncVisualBackpack', source, true, {
            component = component,
            maleDrawable = maleDrawable,
            maleTexture = maleTexture,
            femaleDrawable = femaleDrawable,
            femaleTexture = femaleTexture
        })
    else
        activeBackpackBonus[source] = 0
        exports.ox_inventory:SetSlotCount(source, defaultSlots)
        
        if GetResourceState('xnr-gym') ~= 'started' then
            exports.ox_inventory:SetMaxWeight(source, defaultWeight)
        end
        
        TriggerClientEvent('generations_backpack:client:syncVisualBackpack', source, false)
    end
end

-- Client triggers this when slot 6 changes
RegisterNetEvent('generations_backpack:server:updateBackpack', function()
    local src = source
    ProcessBackpackUpdate(src)
end)

-- Admin command /createbackpack
RegisterCommand('createbackpack', function(source, args)
    print("^3[generations_backpack] /createbackpack command run by source: " .. tostring(source) .. "^7")
    if source == 0 then return end
    local isAdmin = IsAdmin(source)
    print("^3[generations_backpack] IsAdmin result: " .. tostring(isAdmin) .. "^7")
    if not isAdmin then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Dazu hast du keine Rechte.' })
        return
    end
    print("^2[generations_backpack] Triggering client event generations_backpack:client:openCreator^7")
    TriggerClientEvent('generations_backpack:client:openCreator', source)
end, false)

-- Admin command /managebackpacks
RegisterCommand('managebackpacks', function(source, args)
    print("^3[generations_backpack] /managebackpacks command run by source: " .. tostring(source) .. "^7")
    if source == 0 then return end
    local isAdmin = IsAdmin(source)
    print("^3[generations_backpack] IsAdmin result: " .. tostring(isAdmin) .. "^7")
    if not isAdmin then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Dazu hast du keine Rechte.' })
        return
    end
    print("^2[generations_backpack] Triggering client event generations_backpack:client:openPresetManager^7")
    TriggerClientEvent('generations_backpack:client:openPresetManager', source)
end, false)

-- Admin command /editbackpack
RegisterCommand('editbackpack', function(source, args)
    print("^3[generations_backpack] /editbackpack command run by source: " .. tostring(source) .. "^7")
    if source == 0 then return end
    local isAdmin = IsAdmin(source)
    print("^3[generations_backpack] IsAdmin result: " .. tostring(isAdmin) .. "^7")
    if not isAdmin then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Dazu hast du keine Rechte.' })
        return
    end

    local item = exports.ox_inventory:GetSlot(source, 6)
    if not item or item.name ~= 'clothing' or not item.metadata or (not item.metadata.isBackpack and item.metadata.component == nil) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Du musst einen Rucksack (Kleidung) in Slot 6 haben, um ihn zu bearbeiten.' })
        return
    end

    local metadata = item.metadata or {}

    local slots = tonumber(metadata.slots) or BACKPACK_DEFAULTS.slots
    local weightKg = (tonumber(metadata.weight) or BACKPACK_DEFAULTS.weight) / 1000
    local component = tonumber(metadata.component) or 5
    local maleDrawable = tonumber(metadata.maleDrawable) or tonumber(metadata.drawable) or BACKPACK_DEFAULTS.maleDrawable
    local maleTexture = tonumber(metadata.maleTexture) or tonumber(metadata.texture) or BACKPACK_DEFAULTS.maleTexture
    local femaleDrawable = tonumber(metadata.femaleDrawable) or tonumber(metadata.drawable) or BACKPACK_DEFAULTS.femaleDrawable
    local femaleTexture = tonumber(metadata.femaleTexture) or tonumber(metadata.texture) or BACKPACK_DEFAULTS.femaleTexture
    local label = metadata.label or item.label

    print("^2[generations_backpack] Triggering client event generations_backpack:client:openCreator (edit)^7")
    TriggerClientEvent('generations_backpack:client:openCreator', source, {
        isEdit = true,
        label = label,
        slots = slots,
        weight = weightKg,
        component = component,
        maleDrawable = maleDrawable,
        maleTexture = maleTexture,
        femaleDrawable = femaleDrawable,
        femaleTexture = femaleTexture
    })
end, false)

-- Server Callback to finalize creation/updating from creator
RegisterNetEvent('generations_backpack:server:createConfirm', function(data)
    local src = source
    if not IsAdmin(src) then return end

    if not data then return end

    local metadata = {
        isBackpack = true,
        label = data.label,
        component = tonumber(data.component) or 5,
        slots = tonumber(data.slots) or BACKPACK_DEFAULTS.slots,
        weight = (tonumber(data.weight) or (BACKPACK_DEFAULTS.weight / 1000)) * 1000, -- convert kg to grams
        maleDrawable = tonumber(data.maleDrawable) or BACKPACK_DEFAULTS.maleDrawable,
        maleTexture = tonumber(data.maleTexture) or BACKPACK_DEFAULTS.maleTexture,
        femaleDrawable = tonumber(data.femaleDrawable) or BACKPACK_DEFAULTS.femaleDrawable,
        femaleTexture = tonumber(data.femaleTexture) or BACKPACK_DEFAULTS.femaleTexture,
        drawable = tonumber(data.maleDrawable) or BACKPACK_DEFAULTS.maleDrawable,
        texture = tonumber(data.maleTexture) or BACKPACK_DEFAULTS.maleTexture,
        description = ('Rucksack: %s (Slots: %d, Traglast: %dkg, Komponente: %d)'):format(
            data.label, data.slots, data.weight, data.component or 5
        )
    }

    exports.ox_inventory:AddItem(src, 'clothing', 1, metadata)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Rucksack erfolgreich erstellt!' })
end)

-- Server Callback to finalize editing active slot 6 backpack
RegisterNetEvent('generations_backpack:server:editConfirm', function(data)
    local src = source
    if not IsAdmin(src) then return end

    local item = exports.ox_inventory:GetSlot(src, 6)
    if not item or item.name ~= 'clothing' or not item.metadata or (not item.metadata.isBackpack and item.metadata.component == nil) then return end

    local newMetadata = {
        isBackpack = true,
        label = data.label,
        component = tonumber(data.component) or 5,
        slots = tonumber(data.slots) or BACKPACK_DEFAULTS.slots,
        weight = (tonumber(data.weight) or (BACKPACK_DEFAULTS.weight / 1000)) * 1000, -- convert kg to grams
        maleDrawable = tonumber(data.maleDrawable) or BACKPACK_DEFAULTS.maleDrawable,
        maleTexture = tonumber(data.maleTexture) or BACKPACK_DEFAULTS.maleTexture,
        femaleDrawable = tonumber(data.femaleDrawable) or BACKPACK_DEFAULTS.femaleDrawable,
        femaleTexture = tonumber(data.femaleTexture) or BACKPACK_DEFAULTS.femaleTexture,
        drawable = tonumber(data.maleDrawable) or BACKPACK_DEFAULTS.maleDrawable,
        texture = tonumber(data.maleTexture) or BACKPACK_DEFAULTS.maleTexture,
        description = ('Rucksack: %s (Slots: %d, Traglast: %dkg, Komponente: %d)'):format(
            data.label, data.slots, data.weight, data.component or 5
        )
    }

    exports.ox_inventory:SetMetadata(src, 6, newMetadata)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Rucksack erfolgreich in Slot 6 aktualisiert!' })
    
    -- Force slot 6 update/sync
    ProcessBackpackUpdate(src)
end)

-- Hook to manage Slot 6 swaps: blocks unequipping if items are in expanded slots, and triggers ProcessBackpackUpdate
exports.ox_inventory:registerHook('swapItems', function(payload)
    local fromSlotId = payload.fromSlot and payload.fromSlot.slot
    local toSlotId = type(payload.toSlot) == 'table' and payload.toSlot.slot or payload.toSlot

    -- 1. Prevent unequipping/moving backpack out of slot 6 when items are in expanded slots (>25)
    if payload.fromInventory == payload.source and fromSlotId == 6 then
        local isBackpack = payload.fromSlot.name == 'clothing' and payload.fromSlot.metadata and (payload.fromSlot.metadata.isBackpack or payload.fromSlot.metadata.component ~= nil)
        if isBackpack then
            local inv = exports.ox_inventory:GetInventory(payload.source)
            if inv and inv.items then
                for slotId, slotData in pairs(inv.items) do
                    if slotId > 25 and slotData and slotData.count > 0 then
                        TriggerClientEvent('ox_lib:notify', payload.source, {
                            type = 'error',
                            description = 'Du kannst den Rucksack nicht ablegen/bewegen, solange noch Gegenstände in den erweiterten Slots sind!'
                        })
                        return false
                    end
                end
            end
        end
    end

    -- 2. Trigger ProcessBackpackUpdate when any item is swapped in/out of player's slot 6
    if (payload.fromInventory == payload.source and fromSlotId == 6) or
       (payload.toInventory == payload.source and toSlotId == 6) then
        CreateThread(function()
            Wait(250) -- Wait briefly for the inventory state to be updated
            ProcessBackpackUpdate(payload.source)
        end)
    end
end)
