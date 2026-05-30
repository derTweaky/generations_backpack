local isInventoryReady = false
local isBagEquipped = false
local originalBagDrawable = 0
local originalBagTexture = 0
local currentBagDrawable = -1
local currentBagTexture = 0
local activeComponent = nil

-- Sync inventory status when loaded
RegisterNetEvent('ox_inventory:setPlayerInventory', function()
    isInventoryReady = true
    TriggerServerEvent('generations_backpack:server:updateBackpack')
    print("^2[generations_backpack] Event: Inventory is ready (setPlayerInventory triggered).^7")
end)

-- Check if inventory is already ready on startup (e.g. after resource restart)
CreateThread(function()
    Wait(1000)
    if not isInventoryReady then
        local success, items = pcall(function()
            return exports.ox_inventory:GetPlayerItems()
        end)
        if success and items then
            isInventoryReady = true
            TriggerServerEvent('generations_backpack:server:updateBackpack')
            print("^2[generations_backpack] Startup sync: Inventory found, setting ready.^7")
        end
    end
end)

local function removeVisualBackpack()
    if isBagEquipped and activeComponent then
        local ped = cache.ped or PlayerPedId()
        exports["illenium-appearance"]:setPedComponent(ped, {
            component_id = activeComponent,
            drawable = originalBagDrawable,
            texture = originalBagTexture
        })
        isBagEquipped = false
        activeComponent = nil
        currentBagDrawable = -1
    end
end

local function applyVisualBackpack(component, drawable, texture)
    local ped = cache.ped or PlayerPedId()
    
    -- If already equipped on a different component, remove it first
    if isBagEquipped and activeComponent and activeComponent ~= component then
        removeVisualBackpack()
    end

    if not isBagEquipped then
        activeComponent = component
        originalBagDrawable = GetPedDrawableVariation(ped, component)
        originalBagTexture = GetPedTextureVariation(ped, component)
        isBagEquipped = true
    end

    currentBagDrawable = drawable
    currentBagTexture = texture

    exports["illenium-appearance"]:setPedComponent(ped, {
        component_id = component,
        drawable = drawable,
        texture = texture
    })
end

RegisterNetEvent('generations_backpack:client:syncVisualBackpack', function(equipped, visualData)
    if equipped and visualData then
        local ped = cache.ped or PlayerPedId()
        local model = GetEntityModel(ped)
        local isMale = (model == `mp_m_freemode_01`)

        local component, drawable, texture
        if isMale then
            component = tonumber(visualData.maleComponent) or tonumber(visualData.component) or 5
            drawable = visualData.maleDrawable
            texture = visualData.maleTexture
        else
            component = tonumber(visualData.femaleComponent) or tonumber(visualData.component) or 5
            drawable = visualData.femaleDrawable
            texture = visualData.femaleTexture
        end
        applyVisualBackpack(component, drawable, texture)
    else
        removeVisualBackpack()
    end

    if GetResourceState('xnr-gym') == 'started' then
        TriggerServerEvent('xnr-gym/server/UpdatePlayerMaxWeight')
    end
end)

-- Main Monitoring Thread
CreateThread(function()
    local lastBackpackName = nil

    while true do
        Wait(500)
        if isInventoryReady then
            local items = exports.ox_inventory:GetPlayerItems()
            if items then
                local slot25 = items[25]
                local backpackName = slot25 and slot25.name

                local isBackpack = backpackName and Config.Backpacks[backpackName] ~= nil

                if not isBackpack then
                    backpackName = nil
                end

                local changed = false
                if backpackName ~= lastBackpackName then
                    changed = true
                end

                if changed then
                    print(string.format("^3[generations_backpack] Slot 25 changed! Name: %s, isBackpack: %s^7", tostring(backpackName), tostring(isBackpack)))
                    TriggerServerEvent('generations_backpack:server:updateBackpack')
                    lastBackpackName = backpackName
                end

                -- Enforce visual model if equipped and not in customization
                if isBagEquipped and currentBagDrawable ~= -1 and activeComponent then
                    local ped = cache.ped or PlayerPedId()
                    local curDrawable = GetPedDrawableVariation(ped, activeComponent)
                    local curTexture = GetPedTextureVariation(ped, activeComponent)
                    if curDrawable ~= currentBagDrawable or curTexture ~= currentBagTexture then
                        if not LocalPlayer.state.charCreatorActive then
                            exports["illenium-appearance"]:setPedComponent(ped, {
                                component_id = activeComponent,
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
