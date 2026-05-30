Config = {}

-- Definition der Rucksack-Items und ihrer standardmäßigen Stats & Aussehen
Config.Backpacks = {
    ['backpack_small'] = {
        label = "Kleiner Rucksack",
        slots = 5,           -- Zusätzliche Slots im Inventar
        weight = 10000,      -- Zusätzliche Traglast in Gramm (10 kg)
        male = { component = 5, drawable = 31, texture = 0 },   -- Standard Male Modell (5 = Rucksäcke)
        female = { component = 5, drawable = 31, texture = 0 }  -- Standard Female Modell (5 = Rucksäcke)
    },
    ['backpack_medium'] = {
        label = "Mittlerer Rucksack",
        slots = 10,
        weight = 15000,      -- 15 kg
        male = { component = 5, drawable = 82, texture = 0 },
        female = { component = 5, drawable = 45, texture = 0 }
    },
    ['backpack_large'] = {
        label = "Großer Rucksack",
        slots = 20,
        weight = 30000,      -- 30 kg
        male = { component = 5, drawable = 86, texture = 0 },
        female = { component = 5, drawable = 48, texture = 0 }
    }
}
