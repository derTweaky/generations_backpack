local isInventoryReady = false
local isBagEquipped = false
local originalBagDrawable = 0
local originalBagTexture = 0
local currentBagDrawable = -1
local currentBagTexture = 0

-- Sync inventory status when loaded
RegisterNetEvent('ox_inventory:setPlayerInventory', function()
    isInventoryReady = true
    TriggerServerEvent('generations_backpack:server:updateBackpack')
end)

local function removeVisualBackpack()
    if isBagEquipped then
        local ped = cache.ped or PlayerPedId()
        exports["illenium-appearance"]:setPedComponent(ped, {
            component_id = 5,
            drawable = originalBagDrawable,
            texture = originalBagTexture
        })
        isBagEquipped = false
        currentBagDrawable = -1
    end
end

local function applyVisualBackpack(drawable, texture)
    local ped = cache.ped or PlayerPedId()
    if not isBagEquipped then
        originalBagDrawable = GetPedDrawableVariation(ped, 5)
        originalBagTexture = GetPedTextureVariation(ped, 5)
        isBagEquipped = true
    end

    currentBagDrawable = drawable
    currentBagTexture = texture

    exports["illenium-appearance"]:setPedComponent(ped, {
        component_id = 5,
        drawable = drawable,
        texture = texture
    })
end

RegisterNetEvent('generations_backpack:client:syncVisualBackpack', function(equipped, visualData)
    if equipped and visualData then
        local ped = cache.ped or PlayerPedId()
        local model = GetEntityModel(ped)
        local isMale = (model == `mp_m_freemode_01`)

        local drawable, texture
        if isMale then
            drawable = visualData.maleDrawable
            texture = visualData.maleTexture
        else
            drawable = visualData.femaleDrawable
            texture = visualData.femaleTexture
        end

        applyVisualBackpack(drawable, texture)
    else
        removeVisualBackpack()
    end
end)

-- Main Monitoring Thread
CreateThread(function()
    local lastBackpackName = nil
    local lastBackpackMetadata = nil

    while true do
        Wait(500)
        if isInventoryReady then
            local items = exports.ox_inventory:GetPlayerItems()
            if items then
                local slot6 = items[6]
                local backpackName = slot6 and slot6.name
                local metadata = slot6 and slot6.metadata

                local isBackpack = backpackName and (
                    backpackName == 'backpack' or
                    backpackName == 'backpack_large' or
                    backpackName == 'backpack_tactical' or
                    backpackName == 'backpack_medic' or
                    backpackName == 'backpack_sams'
                )

                if not isBackpack then
                    backpackName = nil
                    metadata = nil
                end

                local changed = false
                if backpackName ~= lastBackpackName then
                    changed = true
                elseif isBackpack then
                    local m1 = lastBackpackMetadata or {}
                    local m2 = metadata or {}
                    if m1.slots ~= m2.slots or m1.weight ~= m2.weight or
                       m1.maleDrawable ~= m2.maleDrawable or m1.maleTexture ~= m2.maleTexture or
                       m1.femaleDrawable ~= m2.femaleDrawable or m1.femaleTexture ~= m2.femaleTexture or
                       m1.label ~= m2.label then
                        changed = true
                    end
                end

                if changed then
                    TriggerServerEvent('generations_backpack:server:updateBackpack')
                    lastBackpackName = backpackName
                    lastBackpackMetadata = metadata and lib.table.clone(metadata) or nil
                end

                -- Enforce visual model if equipped and not in customization
                if isBagEquipped and currentBagDrawable ~= -1 then
                    local ped = cache.ped or PlayerPedId()
                    local curDrawable = GetPedDrawableVariation(ped, 5)
                    local curTexture = GetPedTextureVariation(ped, 5)
                    if curDrawable ~= currentBagDrawable or curTexture ~= currentBagTexture then
                        if not LocalPlayer.state.charCreatorActive then
                            exports["illenium-appearance"]:setPedComponent(ped, {
                                component_id = 5,
                                drawable = currentBagDrawable,
                                texture = currentBagTexture
                            })
                        end
                    end
                end
            end
        end
    end
end)

-- Admin Dialogs
RegisterNetEvent('generations_backpack:client:createBackpack', function()
    local dialog = lib.inputDialog('Rucksack Erstellen', {
        {
            type = 'select',
            label = 'Rucksack Typ',
            options = {
                { value = 'backpack', label = 'Standard Rucksack' },
                { value = 'backpack_large', label = 'Großer Wanderrucksack' },
                { value = 'backpack_tactical', label = 'Militär-Rucksack' },
                { value = 'backpack_medic', label = 'Medic-Rucksack' },
                { value = 'backpack_sams', label = 'SAMS-Rucksack' },
            },
            required = true
        },
        { type = 'input', label = 'Custom Name / Label', required = true, placeholder = 'z.B. Polizei Rucksack' },
        { type = 'number', label = 'Zusätzliche Slots (Anzahl)', required = true, default = 10 },
        { type = 'number', label = 'Zusätzliche Traglast (in kg)', required = true, default = 15 },
        { type = 'number', label = 'Männlich - Drawable ID (Component 5)', required = true, default = 31 },
        { type = 'number', label = 'Männlich - Texture ID', required = true, default = 0 },
        { type = 'number', label = 'Weiblich - Drawable ID (Component 5)', required = true, default = 31 },
        { type = 'number', label = 'Weiblich - Texture ID', required = true, default = 0 },
    })

    if not dialog then return end

    TriggerServerEvent('generations_backpack:server:createConfirm', {
        itemType = dialog[1],
        label = dialog[2],
        slots = dialog[3],
        weight = dialog[4],
        maleDrawable = dialog[5],
        maleTexture = dialog[6],
        femaleDrawable = dialog[7],
        femaleTexture = dialog[8],
    })
end)

RegisterNetEvent('generations_backpack:client:editBackpack', function(data)
    local dialog = lib.inputDialog('Rucksack Bearbeiten', {
        { type = 'input', label = 'Custom Name / Label', required = true, default = data.label },
        { type = 'number', label = 'Zusätzliche Slots (Anzahl)', required = true, default = data.slots },
        { type = 'number', label = 'Zusätzliche Traglast (in kg)', required = true, default = data.weight },
        { type = 'number', label = 'Männlich - Drawable ID (Component 5)', required = true, default = data.maleDrawable },
        { type = 'number', label = 'Männlich - Texture ID', required = true, default = data.maleTexture },
        { type = 'number', label = 'Weiblich - Drawable ID (Component 5)', required = true, default = data.femaleDrawable },
        { type = 'number', label = 'Weiblich - Texture ID', required = true, default = data.femaleTexture },
    })

    if not dialog then return end

    TriggerServerEvent('generations_backpack:server:editConfirm', {
        label = dialog[1],
        slots = dialog[2],
        weight = dialog[3],
        maleDrawable = dialog[4],
        maleTexture = dialog[5],
        femaleDrawable = dialog[6],
        femaleTexture = dialog[7],
    })
end)
