local BACKPACK_DEFAULTS = { slots = 10, weight = 15000, maleDrawable = 31, maleTexture = 0, femaleDrawable = 31, femaleTexture = 0 }
local activeBackpackBonus = {}
local processingPlayers = {} -- Re-entrancy locks to prevent recursive inventory updates from causing duplication

-- Export to get backpack bonus (weight in grams)
local function GetBackpackBonus(source)
    if not source then return 0 end
    local numKey = tonumber(source)
    local strKey = tostring(source)
    return (numKey and activeBackpackBonus[numKey]) or (strKey and activeBackpackBonus[strKey]) or 0
end
exports('GetBackpackBonus', GetBackpackBonus)

-- Export for external scripts (like shops) to retrieve backpack stats from config
local function GetBackpackMetadata(itemName)
    if not Config.Backpacks or not Config.Backpacks[itemName] then return nil end
    local bpConfig = Config.Backpacks[itemName]
    
    return {
        isBackpack = true,
        label = bpConfig.label,
        slots = tonumber(bpConfig.slots) or 10,
        weight = tonumber(bpConfig.weight) or 15000,
        component = bpConfig.male and tonumber(bpConfig.male.component) or 5,
        maleComponent = bpConfig.male and tonumber(bpConfig.male.component) or 5,
        maleDrawable = bpConfig.male and tonumber(bpConfig.male.drawable) or 31,
        maleTexture = bpConfig.male and tonumber(bpConfig.male.texture) or 0,
        femaleComponent = bpConfig.female and tonumber(bpConfig.female.component) or 5,
        femaleDrawable = bpConfig.female and tonumber(bpConfig.female.drawable) or 31,
        femaleTexture = bpConfig.female and tonumber(bpConfig.female.texture) or 0,
        drawable = bpConfig.male and tonumber(bpConfig.male.drawable) or 31,
        texture = bpConfig.male and tonumber(bpConfig.male.texture) or 0,
        image = bpConfig.image,
        description = ('Rucksack: %s (Slots: %d, Traglast: %dkg)'):format(
            bpConfig.label, bpConfig.slots, bpConfig.weight / 1000
        )
    }
end
exports('GetBackpackMetadata', GetBackpackMetadata)

-- Helper function to migrate player expanded slots to a backpack stash
local function MigratePlayerSlotsToStash(source, backpackId, itemName)
    local bpConfig = Config.Backpacks[itemName]
    if not bpConfig then return end

    local extraSlots = tonumber(bpConfig.slots) or 10
    local extraWeight = tonumber(bpConfig.weight) or 15000

    -- Register stash to ensure it exists in ox_inventory
    exports.ox_inventory:RegisterStash(backpackId, bpConfig.label, extraSlots, extraWeight, false)

    -- Loop through the player's expanded slots and move items to the stash
    for i = 1, extraSlots do
        local playerSlotId = 25 + i
        local slotData = exports.ox_inventory:GetSlot(source, playerSlotId)
        if slotData and slotData.count > 0 then
            exports.ox_inventory:AddItem(backpackId, slotData.name, slotData.count, slotData.metadata, i)
            exports.ox_inventory:RemoveItem(source, slotData.name, slotData.count, nil, playerSlotId)
        end
    end
end

-- Core logic to update slot count and maximum weight, and migrate stash items to player slots
local function ProcessBackpackUpdateInternal(source)
    local defaultSlots = GetConvarInt('inventory:slots', 25)
    local defaultWeight = GetConvarInt('inventory:weight', 30000)

    local item = exports.ox_inventory:GetSlot(source, 25)
    local bpConfig = item and Config.Backpacks[item.name]
    local playerState = Player(source).state

    print(string.format("^3[generations_backpack] ProcessBackpackUpdate for player %s. Item in Slot 25: %s (isBackpack: %s)^7", tostring(source), item and item.name or "none", tostring(bpConfig ~= nil)))

    if bpConfig then
        local metadata = item.metadata or {}
        local backpackId = metadata.backpackId

        -- Generate unique backpackId if not already present on the item
        if not backpackId then
            backpackId = "bp_" .. os.time() .. "_" .. math.random(1000, 9999)
            metadata.backpackId = backpackId
            metadata.description = ('Rucksack: %s (Slots: %d, Traglast: %dkg)'):format(
                bpConfig.label, bpConfig.slots, bpConfig.weight / 1000
            )
            exports.ox_inventory:SetMetadata(source, 25, metadata)
            return -- Exit: SetMetadata will trigger a new ProcessBackpackUpdate shortly
        end

        local extraSlots = tonumber(bpConfig.slots) or BACKPACK_DEFAULTS.slots
        local extraWeight = tonumber(bpConfig.weight) or BACKPACK_DEFAULTS.weight

        -- Check if player had a DIFFERENT backpack active previously, migrate its slots to stash first
        local lastActiveId = playerState.activeBackpackId
        local lastActiveName = playerState.activeBackpackName
        if lastActiveId and lastActiveId ~= backpackId and lastActiveName then
            MigratePlayerSlotsToStash(source, lastActiveId, lastActiveName)
        end

        -- Update active tracker in server-only state bags (replicated = false)
        playerState:set('activeBackpackId', backpackId, false)
        playerState:set('activeBackpackName', item.name, false)

        local numKey = tonumber(source)
        local strKey = tostring(source)
        if numKey then activeBackpackBonus[numKey] = extraWeight end
        if strKey then activeBackpackBonus[strKey] = extraWeight end

        -- 1. Register stash in ox_inventory (so we can interact with it)
        exports.ox_inventory:RegisterStash(backpackId, bpConfig.label, extraSlots, extraWeight, false)

        -- 2. Expand player slots
        exports.ox_inventory:SetSlotCount(source, defaultSlots + extraSlots)
        
        -- If xnr-gym is started, we let it handle the max weight update.
        if GetResourceState('xnr-gym') ~= 'started' then
            exports.ox_inventory:SetMaxWeight(source, defaultWeight + extraWeight)
        end

        -- 3. Load items from stash into player slots 26+
        local stashInv = exports.ox_inventory:GetInventory(backpackId)
        if stashInv and stashInv.items then
            for slotId, slotData in pairs(stashInv.items) do
                local playerSlot = slotId + 25
                -- Verify target slot is empty to avoid duplicating/overwriting items
                local currentSlotData = exports.ox_inventory:GetSlot(source, playerSlot)
                if not currentSlotData or currentSlotData.count == 0 then
                    exports.ox_inventory:AddItem(source, slotData.name, slotData.count, slotData.metadata, playerSlot)
                    exports.ox_inventory:RemoveItem(backpackId, slotData.name, slotData.count, nil, slotId)
                end
            end
        end

        -- Retrieve drawable, texture and component details directly from Config.Backpacks
        local maleComponent = bpConfig.male and tonumber(bpConfig.male.component) or 5
        local maleDrawable = bpConfig.male and tonumber(bpConfig.male.drawable) or BACKPACK_DEFAULTS.maleDrawable
        local maleTexture = bpConfig.male and tonumber(bpConfig.male.texture) or BACKPACK_DEFAULTS.maleTexture
        local femaleComponent = bpConfig.female and tonumber(bpConfig.female.component) or 5
        local femaleDrawable = bpConfig.female and tonumber(bpConfig.female.drawable) or BACKPACK_DEFAULTS.femaleDrawable
        local femaleTexture = bpConfig.female and tonumber(bpConfig.female.texture) or BACKPACK_DEFAULTS.femaleTexture

        TriggerClientEvent('generations_backpack:client:syncVisualBackpack', source, true, {
            maleComponent = maleComponent,
            maleDrawable = maleDrawable,
            maleTexture = maleTexture,
            femaleComponent = femaleComponent,
            femaleDrawable = femaleDrawable,
            femaleTexture = femaleTexture
        })
    else
        -- Backpack was removed (either through normal swap or unexpected deletion/Clear/RemoveItem/death)
        local lastActiveId = playerState.activeBackpackId
        local lastActiveName = playerState.activeBackpackName
        if lastActiveId and lastActiveName then
            -- Migrate current player slots 26+ back to stash to ensure item safety
            MigratePlayerSlotsToStash(source, lastActiveId, lastActiveName)
            playerState:set('activeBackpackId', nil, false)
            playerState:set('activeBackpackName', nil, false)
        end

        local numKey = tonumber(source)
        local strKey = tostring(source)
        if numKey then activeBackpackBonus[numKey] = 0 end
        if strKey then activeBackpackBonus[strKey] = 0 end

        exports.ox_inventory:SetSlotCount(source, defaultSlots)
        
        if GetResourceState('xnr-gym') ~= 'started' then
            exports.ox_inventory:SetMaxWeight(source, defaultWeight)
        end
        
        TriggerClientEvent('generations_backpack:client:syncVisualBackpack', source, false)
    end
end

-- Re-entrancy protected update wrapper
local function ProcessBackpackUpdate(source)
    local numKey = tonumber(source)
    if not numKey then return end
    if processingPlayers[numKey] then return end
    processingPlayers[numKey] = true

    local success, err = pcall(ProcessBackpackUpdateInternal, numKey)
    if not success then
        print("^1[generations_backpack] Error in ProcessBackpackUpdate: " .. tostring(err) .. "^7")
    end

    processingPlayers[numKey] = nil
end

-- Hook when player inventory is requested to update
RegisterNetEvent('generations_backpack:server:updateBackpack', function()
    local src = source
    ProcessBackpackUpdate(src)
end)

-- Hook to manage Slot 25 swaps: migrates items between player expanded slots and unique backpack stash
exports.ox_inventory:registerHook('swapItems', function(payload)
    local fromSlotId = payload.fromSlot and payload.fromSlot.slot
    local toSlotId = type(payload.toSlot) == 'table' and payload.toSlot.slot or payload.toSlot
    local playerState = Player(payload.source).state
    local numKey = tonumber(payload.source)

    -- 0. Prevent nesting backpacks (blocking placing a backpack_* item inside another backpack stash or player slots > 25)
    if payload.fromSlot and payload.fromSlot.name and payload.fromSlot.name:sub(1, 9) == "backpack_" then
        -- Check if target is a backpack stash
        if type(payload.toInventory) == 'string' and payload.toInventory:sub(1, 3) == "bp_" then
            TriggerClientEvent('ox_lib:notify', payload.source, {
                type = 'error',
                description = 'Du kannst keinen Rucksack in einen anderen Rucksack legen!'
            })
            return false
        end

        -- Check if target is player expanded slots (> 25)
        if payload.toInventory == payload.source and type(toSlotId) == 'number' and toSlotId > 25 then
            TriggerClientEvent('ox_lib:notify', payload.source, {
                type = 'error',
                description = 'Du kannst keinen Rucksack in die Rucksackspeicher-Slots legen!'
            })
            return false
        end
    end

    -- 1. Unequipping a backpack from slot 25
    if payload.fromInventory == payload.source and fromSlotId == 25 then
        local bpConfig = Config.Backpacks[payload.fromSlot.name]
        if bpConfig then
            local metadata = payload.fromSlot.metadata or {}
            local backpackId = metadata.backpackId
            
            -- Migrate items from player slots 26+ to stash slots 1+
            if backpackId then
                if numKey then processingPlayers[numKey] = true end
                
                local success, err = pcall(function()
                    MigratePlayerSlotsToStash(payload.source, backpackId, payload.fromSlot.name)
                end)
                if not success then
                    print("^1[generations_backpack] Error during stash migration: " .. tostring(err) .. "^7")
                end

                playerState:set('activeBackpackId', nil, false)
                playerState:set('activeBackpackName', nil, false)
                
                if numKey then processingPlayers[numKey] = nil end
            end

            -- Set player slot count and weight limits back to default
            local defaultSlots = GetConvarInt('inventory:slots', 25)
            local defaultWeight = GetConvarInt('inventory:weight', 30000)
            
            exports.ox_inventory:SetSlotCount(payload.source, defaultSlots)
            if GetResourceState('xnr-gym') ~= 'started' then
                exports.ox_inventory:SetMaxWeight(payload.source, defaultWeight)
            end

            local strKey = tostring(payload.source)
            if numKey then activeBackpackBonus[numKey] = 0 end
            if strKey then activeBackpackBonus[strKey] = 0 end

            TriggerClientEvent('generations_backpack:client:syncVisualBackpack', payload.source, false)
        end
    end

    -- 2. Trigger ProcessBackpackUpdate when a backpack is swapped into slot 25
    if payload.toInventory == payload.source and toSlotId == 25 then
        CreateThread(function()
            Wait(250) -- Wait briefly for the inventory state to update
            ProcessBackpackUpdate(payload.source)
        end)
    end
end)
