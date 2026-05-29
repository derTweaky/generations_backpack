local isInventoryReady = false
local isBagEquipped = false
local originalBagDrawable = 0
local originalBagTexture = 0
local currentBagDrawable = -1
local currentBagTexture = 0
local activeComponent = nil

-- For preview mode
local originalClothes = {}
local isCreatorActive = false
local isBrowsingMode = false
local creatorCam = nil

-- Sync inventory status when loaded
RegisterNetEvent('ox_inventory:setPlayerInventory', function()
    isInventoryReady = true
    TriggerServerEvent('generations_backpack:server:updateBackpack')
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

        local drawable, texture
        if isMale then
            drawable = visualData.maleDrawable
            texture = visualData.maleTexture
        else
            drawable = visualData.femaleDrawable
            texture = visualData.femaleTexture
        end

        local component = tonumber(visualData.component) or 5
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
    local lastBackpackMetadata = nil

    while true do
        Wait(500)
        if isInventoryReady then
            local items = exports.ox_inventory:GetPlayerItems()
            if items then
                local slot6 = items[6]
                local backpackName = slot6 and slot6.name
                local metadata = slot6 and slot6.metadata

                local isBackpack = backpackName == 'clothing' and metadata and (metadata.isBackpack or metadata.component ~= nil)

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
                       m1.component ~= m2.component or
                       m1.maleDrawable ~= m2.maleDrawable or m1.maleTexture ~= m2.maleTexture or
                       m1.femaleDrawable ~= m2.femaleDrawable or m1.femaleTexture ~= m2.femaleTexture or
                       m1.drawable ~= m2.drawable or m1.texture ~= m2.texture or
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

-- Live Preview Creator Camera & Logic
local function startCreatorCamera()
    local ped = PlayerPedId()
    
    -- Create camera looking at the back of the player
    creatorCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, -1.8, 0.4)
    SetCamCoords(creatorCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(creatorCam, ped, 0.0, 0.0, 0.2, true)
    SetCamActive(creatorCam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function stopCreatorCamera()
    if creatorCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(creatorCam, true)
        creatorCam = nil
    end
end

local function saveOriginalClothes()
    local ped = PlayerPedId()
    originalClothes[5] = { drawable = GetPedDrawableVariation(ped, 5), texture = GetPedTextureVariation(ped, 5) }
    originalClothes[7] = { drawable = GetPedDrawableVariation(ped, 7), texture = GetPedTextureVariation(ped, 7) }
    originalClothes[8] = { drawable = GetPedDrawableVariation(ped, 8), texture = GetPedTextureVariation(ped, 8) }
end

local function restoreOriginalClothes()
    local ped = PlayerPedId()
    for compId, data in pairs(originalClothes) do
        exports["illenium-appearance"]:setPedComponent(ped, {
            component_id = compId,
            drawable = data.drawable,
            texture = data.texture
        })
    end
    originalClothes = {}
end

local function cleanupCreator()
    if isCreatorActive and not isBrowsingMode then
        isCreatorActive = false
        stopCreatorCamera()
        restoreOriginalClothes()
    end
end

-- Thread to lock movement while creator is active
CreateThread(function()
    while true do
        Wait(0)
        if isCreatorActive then
            -- Disable controls to prevent moving
            DisableControlAction(0, 30, true) -- disable movement keys (left/right)
            DisableControlAction(0, 31, true) -- disable movement keys (forward/back)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 23, true) -- enter vehicle
            DisableControlAction(0, 75, true) -- exit vehicle
        else
            Wait(250)
        end
    end
end)

-- Forward declaration of showCreatorMenu
local showCreatorMenu

-- Dynamic keyboard browsing mode
local function startBrowsingMode(data, gender)
    isBrowsingMode = true
    lib.hideContext()
    
    local ped = PlayerPedId()
    local isMale = (gender == 'male')
    local currentDraw = isMale and data.maleDrawable or data.femaleDrawable
    local currentTex = isMale and data.maleTexture or data.femaleTexture
    
    -- Show instruction UI
    local function updateTextUI()
        local text = string.format(
            "**Rucksack Vorschau (%s)**  \n" ..
            "**[A / D]** Drawable ID: %d  \n" ..
            "**[W / S]** Textur ID: %d  \n" ..
            "**[ENTER]** Speichern  \n" ..
            "**[ESC / BACKSPACE]** Abbrechen",
            isMale and "Männlich" or "Weiblich",
            currentDraw, currentTex
        )
        lib.showTextUI(text, { position = 'right-center' })
    end

    updateTextUI()

    local done = false
    local saved = false
    local lastUpdate = 0

    while not done do
        Wait(0)
        
        -- Disable controls
        DisableControlAction(0, 32, true) -- W
        DisableControlAction(0, 33, true) -- S
        DisableControlAction(0, 34, true) -- A
        DisableControlAction(0, 35, true) -- D
        DisableControlAction(0, 177, true) -- ESC / Backspace
        DisableControlAction(0, 191, true) -- Enter
        DisableControlAction(0, 201, true) -- Enter
        
        local now = GetGameTimer()
        local changed = false

        if now - lastUpdate > 150 then
            if IsDisabledControlPressed(0, 34) then -- A (decrement drawable)
                currentDraw = math.max(0, currentDraw - 1)
                changed = true
                lastUpdate = now
            elseif IsDisabledControlPressed(0, 35) then -- D (increment drawable)
                currentDraw = currentDraw + 1
                changed = true
                lastUpdate = now
            elseif IsDisabledControlPressed(0, 32) then -- W (increment texture)
                currentTex = currentTex + 1
                changed = true
                lastUpdate = now
            elseif IsDisabledControlPressed(0, 33) then -- S (decrement texture)
                currentTex = math.max(0, currentTex - 1)
                changed = true
                lastUpdate = now
            end
        end

        if changed then
            -- Apply preview immediately
            exports["illenium-appearance"]:setPedComponent(ped, {
                component_id = data.component,
                drawable = currentDraw,
                texture = currentTex
            })
            updateTextUI()
        end

        if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then -- ENTER
            saved = true
            done = true
        elseif IsDisabledControlJustPressed(0, 177) then -- ESC / BACKSPACE
            done = true
        end
    end

    lib.hideTextUI()
    
    if saved then
        if isMale then
            data.maleDrawable = currentDraw
            data.maleTexture = currentTex
        else
            data.femaleDrawable = currentDraw
            data.femaleTexture = currentTex
        end
    else
        -- Revert visual preview to menu values
        local origDraw = isMale and data.maleDrawable or data.femaleDrawable
        local origTex = isMale and data.maleTexture or data.femaleTexture
        exports["illenium-appearance"]:setPedComponent(ped, {
            component_id = data.component,
            drawable = origDraw,
            texture = origTex
        })
    end

    isBrowsingMode = false
    showCreatorMenu(data)
end

showCreatorMenu = function(data)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = (model == `mp_m_freemode_01`)

    -- Apply current preview
    local previewDrawable = isMale and data.maleDrawable or data.femaleDrawable
    local previewTexture = isMale and data.maleTexture or data.femaleTexture
    
    -- Restore other components first to avoid overlapping previews
    for compId, cData in pairs(originalClothes) do
        if compId ~= data.component then
            exports["illenium-appearance"]:setPedComponent(ped, {
                component_id = compId,
                drawable = cData.drawable,
                texture = cData.texture
            })
        end
    end

    -- Apply current preview component
    exports["illenium-appearance"]:setPedComponent(ped, {
        component_id = data.component,
        drawable = previewDrawable,
        texture = previewTexture
    })

    local options = {
        {
            title = "Name / Label: " .. data.label,
            description = "Klicken zum Ändern",
            icon = "fas fa-tag",
            onSelect = function()
                local input = lib.inputDialog("Rucksack Name", {
                    { type = "input", label = "Custom Name / Label", default = data.label, required = true }
                })
                if input then
                    data.label = input[1]
                end
                showCreatorMenu(data)
            end
        },
        {
            title = "Ziel-Komponente: " .. data.component,
            description = "Toggles: 5 (Tasche), 7 (Accessoire), 8 (Unterhemd)",
            icon = "fas fa-shirt",
            onSelect = function()
                local select = lib.inputDialog("Komponente Auswählen", {
                    {
                        type = "select",
                        label = "Komponente",
                        default = tostring(data.component),
                        options = {
                            { value = "5", label = "5 - Taschen/Rucksäcke (Standard)" },
                            { value = "7", label = "7 - Ketten/Accessoires" },
                            { value = "8", label = "8 - Unterhemden/Westen" }
                        },
                        required = true
                    }
                })
                if select then
                    data.component = tonumber(select[1])
                end
                showCreatorMenu(data)
            end
        },
        {
            title = "Zusätzliche Slots: " .. data.slots,
            description = "Klicken zum Ändern",
            icon = "fas fa-cubes",
            onSelect = function()
                local input = lib.inputDialog("Slots Anzahl", {
                    { type = "number", label = "Slots", default = data.slots, min = 1, max = 100, required = true }
                })
                if input then
                    data.slots = input[1]
                end
                showCreatorMenu(data)
            end
        },
        {
            title = "Zusätzliche Traglast: " .. data.weight .. " kg",
            description = "Klicken zum Ändern",
            icon = "fas fa-weight-hanging",
            onSelect = function()
                local input = lib.inputDialog("Traglast", {
                    { type = "number", label = "Gewicht in kg", default = data.weight, min = 1, max = 500, required = true }
                })
                if input then
                    data.weight = input[1]
                end
                showCreatorMenu(data)
            end
        },
        {
            title = "Männliches Modell durchsuchen",
            description = string.format("Aktuell - Drawable: %d | Textur: %d (A/D & W/S)", data.maleDrawable, data.maleTexture),
            icon = "fas fa-mars",
            onSelect = function()
                startBrowsingMode(data, 'male')
            end
        },
        {
            title = "Weibliches Modell durchsuchen",
            description = string.format("Aktuell - Drawable: %d | Textur: %d (A/D & W/S)", data.femaleDrawable, data.femaleTexture),
            icon = "fas fa-venus",
            onSelect = function()
                startBrowsingMode(data, 'female')
            end
        }
    }

    if data.isEdit then
        table.insert(options, {
            title = "In Slot 6 Speichern & Anwenden",
            description = "Übernimmt Änderungen für den aktiven Rucksack in Slot 6",
            icon = "fas fa-check-double",
            onSelect = function()
                isCreatorActive = false
                stopCreatorCamera()
                restoreOriginalClothes()
                TriggerServerEvent('generations_backpack:server:editConfirm', data)
            end
        })
    else
        table.insert(options, {
            title = "Rucksack erstellen (Gibt Item)",
            description = "Erstellt den Rucksack und gibt ihn dir",
            icon = "fas fa-plus",
            onSelect = function()
                isCreatorActive = false
                stopCreatorCamera()
                restoreOriginalClothes()
                TriggerServerEvent('generations_backpack:server:createConfirm', data)
            end
        })
    end

    table.insert(options, {
        title = "Als Preset speichern",
        description = "Speichert diesen Rucksack als Preset zum späteren Generieren",
        icon = "fas fa-save",
        onSelect = function()
            TriggerServerEvent('generations_backpack:server:savePreset', {
                id = data.id,
                label = data.label,
                slots = data.slots,
                weight = data.weight,
                component = data.component,
                maleDrawable = data.maleDrawable,
                maleTexture = data.maleTexture,
                femaleDrawable = data.femaleDrawable,
                femaleTexture = data.femaleTexture
            })
            showCreatorMenu(data)
        end
    })

    table.insert(options, {
        title = "Abbrechen",
        description = "Schließt das Menü und setzt Kleidung zurück",
        icon = "fas fa-xmark",
        onSelect = function()
            isCreatorActive = false
            stopCreatorCamera()
            restoreOriginalClothes()
            TriggerEvent('ox_lib:notify', { type = 'info', description = 'Creator abgebrochen.' })
        end
    })

    lib.registerContext({
        id = 'backpack_creator_main',
        title = data.isEdit and 'Rucksack Bearbeiten' or 'Rucksack Creator',
        options = options,
        onExit = function()
            cleanupCreator()
        end
    })

    lib.showContext('backpack_creator_main')
end

RegisterNetEvent('generations_backpack:client:openCreator', function(editData)
    print("^3[generations_backpack] client received openCreator event^7")
    isCreatorActive = true
    saveOriginalClothes()
    startCreatorCamera()
    
    local initialData = editData or {
        isEdit = false,
        label = "Standard Rucksack",
        slots = 10,
        weight = 15,
        component = 5,
        maleDrawable = 31,
        maleTexture = 0,
        femaleDrawable = 31,
        femaleTexture = 0
    }
    showCreatorMenu(initialData)
end)

-- Preset Manager Menu
RegisterNetEvent('generations_backpack:client:openPresetManager', function()
    print("^3[generations_backpack] client received openPresetManager event^7")
    lib.callback('generations_backpack:server:getPresets', false, function(presets)
        local options = {}
        if #presets == 0 then
            table.insert(options, {
                title = "Keine Rucksäcke gefunden",
                description = "Verwende /createbackpack, um einen Rucksack zu erstellen."
            })
        else
            for _, preset in ipairs(presets) do
                table.insert(options, {
                    title = preset.label,
                    description = string.format("Slots: %d | Gewicht: %dkg | Komponente: %d", preset.slots, preset.weight, preset.component or 5),
                    onSelect = function()
                        lib.registerContext({
                            id = 'backpack_preset_actions_' .. preset.id,
                            title = preset.label,
                            menu = 'backpack_preset_manager_main',
                            options = {
                                {
                                    title = "Rucksack nehmen (In Inventar legen)",
                                    icon = "fas fa-hand-holding",
                                    onSelect = function()
                                        TriggerServerEvent('generations_backpack:server:givePreset', preset)
                                    end
                                },
                                {
                                    title = "Rucksack bearbeiten (Im Live-Editor)",
                                    icon = "fas fa-edit",
                                    onSelect = function()
                                        isCreatorActive = true
                                        saveOriginalClothes()
                                        startCreatorCamera()
                                        showCreatorMenu({
                                            id = preset.id,
                                            isEdit = false,
                                            label = preset.label,
                                            slots = preset.slots,
                                            weight = preset.weight,
                                            component = preset.component or 5,
                                            maleDrawable = preset.maleDrawable,
                                            maleTexture = preset.maleTexture,
                                            femaleDrawable = preset.femaleDrawable,
                                            femaleTexture = preset.femaleTexture
                                        })
                                    end
                                },
                                {
                                    title = "Rucksack löschen",
                                    icon = "fas fa-trash",
                                    onSelect = function()
                                        local confirm = lib.alertDialog({
                                            header = 'Preset löschen?',
                                            content = string.format('Möchtest du das Preset "%s" wirklich löschen?', preset.label),
                                            centered = true,
                                            cancel = true
                                        })
                                        if confirm == 'confirm' then
                                            TriggerServerEvent('generations_backpack:server:deletePreset', preset.id)
                                        else
                                            TriggerEvent('generations_backpack:client:openPresetManager')
                                        end
                                    end
                                }
                            }
                        })
                        lib.showContext('backpack_preset_actions_' .. preset.id)
                    end
                })
            end
        end

        lib.registerContext({
            id = 'backpack_preset_manager_main',
            title = 'Rucksack Preset Manager',
            options = options
        })
        lib.showContext('backpack_preset_manager_main')
    end)
end)
