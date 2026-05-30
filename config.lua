Config = {}

-- Definition der Rucksack-Items und ihrer standardmäßigen Stats & Aussehen
Config.Backpacks = {
    ['backpack_small'] = {
        label = "Kleiner Rucksack",
        slots = 5,           -- Zusätzliche Slots im Inventar
        weight = 10000,      -- Zusätzliche Traglast in Gramm (10 kg)
        component = 5,       -- Standard GTA Ped-Komponente (5 = Rucksäcke/Taschen)
        male = { drawable = 31, texture = 0 },   -- Standard Male Modell
        female = { drawable = 31, texture = 0 }  -- Standard Female Modell
    },
    ['backpack_medium'] = {
        label = "Mittlerer Rucksack",
        slots = 10,
        weight = 15000,      -- 15 kg
        component = 5,
        male = { drawable = 82, texture = 0 },
        female = { drawable = 45, texture = 0 }
    },
    ['backpack_large'] = {
        label = "Großer Rucksack",
        slots = 20,
        weight = 30000,      -- 30 kg
        component = 5,
        male = { drawable = 86, texture = 0 },
        female = { drawable = 48, texture = 0 }
    }
}
