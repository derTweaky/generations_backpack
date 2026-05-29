-- Backpack Defaults Lookup
local BACKPACK_DEFAULTS = {
    backpack = { slots = 10, weight = 15000, maleDrawable = 31, maleTexture = 0, femaleDrawable = 31, femaleTexture = 0 },
    backpack_large = { slots = 20, weight = 30000, maleDrawable = 32, maleTexture = 0, femaleDrawable = 32, femaleTexture = 0 },
    backpack_tactical = { slots = 30, weight = 45000, maleDrawable = 33, maleTexture = 0, femaleDrawable = 33, femaleTexture = 0 },
    backpack_medic = { slots = 15, weight = 20000, maleDrawable = 34, maleTexture = 0, femaleDrawable = 34, femaleTexture = 0 },
    backpack_sams = { slots = 20, weight = 25000, maleDrawable = 35, maleTexture = 0, femaleDrawable = 35, femaleTexture = 0 },
}

local function IsAdmin(source)
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:HasPermission(source, 'admin') or exports.qbx_core:HasPermission(source, 'god')
    end
    
    -- Fallback for ESX
    if GetResourceState('es_extended') == 'started' then
        local ESX = exports.es_extended:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local group = xPlayer.getGroup()
            return group == 'admin' or group == 'superadmin'
        end
    end
    
    return false
end

-- Helper to update player inventory limits based on slot 6 content
local function ProcessBackpackUpdate(source)
    local defaultSlots = GetConvarInt('inventory:slots', 50)
    local defaultWeight = GetConvarInt('inventory:weight', 30000)

    local item = exports.ox_inventory:GetSlot(source, 6)
    local isBackpack = item and BACKPACK_DEFAULTS[item.name] ~= nil

    if isBackpack then
        local metadata = item.metadata or {}
        local defaults = BACKPACK_DEFAULTS[item.name]

        -- Read metadata values or fall back to defaults
        local extraSlots = tonumber(metadata.slots) or defaults.slots
        local extraWeight = tonumber(metadata.weight) or defaults.weight

        exports.ox_inventory:SetSlotCount(source, defaultSlots + extraSlots)
        exports.ox_inventory:SetMaxWeight(source, defaultWeight + extraWeight)

        -- Determine drawable and texture for client syncing
        local maleDrawable = tonumber(metadata.maleDrawable) or defaults.maleDrawable
        local maleTexture = tonumber(metadata.maleTexture) or defaults.maleTexture
        local femaleDrawable = tonumber(metadata.femaleDrawable) or defaults.femaleDrawable
        local femaleTexture = tonumber(metadata.femaleTexture) or defaults.femaleTexture

        TriggerClientEvent('generations_backpack:client:syncVisualBackpack', source, true, {
            maleDrawable = maleDrawable,
            maleTexture = maleTexture,
            femaleDrawable = femaleDrawable,
            femaleTexture = femaleTexture
        })
    else
        exports.ox_inventory:SetSlotCount(source, defaultSlots)
        exports.ox_inventory:SetMaxWeight(source, defaultWeight)
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
    if source == 0 then return end
    if not IsAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Dazu hast du keine Rechte.' })
        return
    end
    TriggerClientEvent('generations_backpack:client:createBackpack', source)
end, false)

-- Admin command /editbackpack
RegisterCommand('editbackpack', function(source, args)
    if source == 0 then return end
    if not IsAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Dazu hast du keine Rechte.' })
        return
    end

    local item = exports.ox_inventory:GetSlot(source, 6)
    if not item or not BACKPACK_DEFAULTS[item.name] then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Du musst einen Rucksack in Slot 6 haben, um ihn zu bearbeiten.' })
        return
    end

    local metadata = item.metadata or {}
    local defaults = BACKPACK_DEFAULTS[item.name]

    local slots = tonumber(metadata.slots) or defaults.slots
    local weightKg = (tonumber(metadata.weight) or defaults.weight) / 1000
    local maleDrawable = tonumber(metadata.maleDrawable) or defaults.maleDrawable
    local maleTexture = tonumber(metadata.maleTexture) or defaults.maleTexture
    local femaleDrawable = tonumber(metadata.femaleDrawable) or defaults.femaleDrawable
    local femaleTexture = tonumber(metadata.femaleTexture) or defaults.femaleTexture
    local label = metadata.label or item.label

    TriggerClientEvent('generations_backpack:client:editBackpack', source, {
        itemType = item.name,
        label = label,
        slots = slots,
        weight = weightKg,
        maleDrawable = maleDrawable,
        maleTexture = maleTexture,
        femaleDrawable = femaleDrawable,
        femaleTexture = femaleTexture
    })
end, false)

-- Server Callback to finalize creation
RegisterNetEvent('generations_backpack:server:createConfirm', function(data)
    local src = source
    if not IsAdmin(src) then return end

    if not data or not BACKPACK_DEFAULTS[data.itemType] then return end

    local metadata = {
        label = data.label,
        slots = tonumber(data.slots) or 0,
        weight = (tonumber(data.weight) or 0) * 1000, -- convert kg to grams
        maleDrawable = tonumber(data.maleDrawable) or 0,
        maleTexture = tonumber(data.maleTexture) or 0,
        femaleDrawable = tonumber(data.femaleDrawable) or 0,
        femaleTexture = tonumber(data.femaleTexture) or 0,
        description = ('Erweitert dein Inventar um %d Slots und %dkg, wenn er in Slot 6 liegt.'):format(data.slots, data.weight)
    }

    exports.ox_inventory:AddItem(src, data.itemType, 1, metadata)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Rucksack erfolgreich erstellt!' })
end)

-- Server Callback to finalize editing
RegisterNetEvent('generations_backpack:server:editConfirm', function(data)
    local src = source
    if not IsAdmin(src) then return end

    local item = exports.ox_inventory:GetSlot(src, 6)
    if not item or not BACKPACK_DEFAULTS[item.name] then return end

    local newMetadata = {
        label = data.label,
        slots = tonumber(data.slots) or 0,
        weight = (tonumber(data.weight) or 0) * 1000, -- convert kg to grams
        maleDrawable = tonumber(data.maleDrawable) or 0,
        maleTexture = tonumber(data.maleTexture) or 0,
        femaleDrawable = tonumber(data.femaleDrawable) or 0,
        femaleTexture = tonumber(data.femaleTexture) or 0,
        description = ('Erweitert dein Inventar um %d Slots und %dkg, wenn er in Slot 6 liegt.'):format(data.slots, data.weight)
    }

    exports.ox_inventory:SetMetadata(src, 6, newMetadata)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Rucksack erfolgreich aktualisiert!' })
    
    -- Force slot 6 update/sync
    ProcessBackpackUpdate(src)
end)

-- Hook to prevent unequipping/moving backpack out of slot 6 when items are in expanded slots (>24)
exports.ox_inventory:registerHook('swapItems', function(payload)
    if payload.fromInventory == payload.source and payload.fromSlot.slot == 6 then
        local isBackpack = BACKPACK_DEFAULTS[payload.fromSlot.name] ~= nil
        if isBackpack then
            local inv = exports.ox_inventory:GetInventory(payload.source)
            if inv and inv.items then
                for slotId, slotData in pairs(inv.items) do
                    if slotId > 24 and slotData and slotData.count > 0 then
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
end)
