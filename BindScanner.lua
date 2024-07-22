local BindScanner = CreateFrame("Frame")
BindScanner:RegisterEvent("PLAYER_LOGIN")

-- Funkcia na získanie relevantných bindov
local function GetRelevantBindings(actionType, id, name, slot)
    local bindings = {}
    local actionBarBindings = {
        "ACTIONBUTTON", "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON",
        "MULTIACTIONBAR3BUTTON", "MULTIACTIONBAR4BUTTON", "EXTRAACTIONBUTTON"
    }

    -- Check action bar bindings
    for _, bindingType in ipairs(actionBarBindings) do
        local binding = bindingType .. ((slot - 1) % 12 + 1)
        local key = GetBindingKey(binding)
        if key then
            table.insert(bindings, key)
        end
    end

    -- Check for direct spell bindings
    if actionType == "spell" and name then
        local spellBinding = "SPELL " .. name:upper()
        local key = GetBindingKey(spellBinding)
        if key then
            table.insert(bindings, key)
        end
    end

    -- Check for item bindings
    if actionType == "item" and id then
        local itemBinding = "ITEM " .. id
        local key = GetBindingKey(itemBinding)
        if key then
            table.insert(bindings, key)
        end
    end

    -- Check for macro bindings
    if actionType == "macro" and name then
        local macroIndex = GetMacroIndexByName(name)
        if macroIndex > 0 then
            local macroBinding = "MACRO " .. macroIndex
            local key = GetBindingKey(macroBinding)
            if key then
                table.insert(bindings, key)
            end
        end
    end

    return bindings
end

function BindScanner:ScanBindings()
    local newFlashcards = {}
    local seenSpells = {}
    local count = 0

    for i = 1, 180 do
        local actionType, id, subType = GetActionInfo(i)
        local name, icon
        
        if actionType == "spell" then
            name, _, icon = GetSpellInfo(id)
        elseif actionType == "item" then
            name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
        elseif actionType == "macro" then
            name, icon = GetMacroInfo(id)
        end
        
        if actionType and name and icon then
            local bindings = GetRelevantBindings(actionType, id, name, i)
            
            if #bindings > 0 then
                if not seenSpells[name] then
                    table.insert(newFlashcards, {spell = name, bind = table.concat(bindings, ", "), icon = icon, id = id, type = actionType, slot = i})
                    seenSpells[name] = i
                    count = count + 1
                end
            end
        end
    end

    print(string.format("Celkový počet unikátnych akcií pridaných: %d", count))
    return newFlashcards
end

function BindScanner:DisplayBindings()
    local bindings = self:ScanBindings()
    
    print("|cFF00FF00=== Bindy pre Action Bary ===|r")
    
    table.sort(bindings, function(a, b) return a.spell < b.spell end)
    
    for _, binding in ipairs(bindings) do
        print(string.format("|T%s:0|t |cFFFFFF00%s|r: |cFF00FFFF%s|r |cFF888888(Typ: %s, Slot: %d)|r", 
            binding.icon,
            binding.spell, 
            binding.bind,
            binding.type,
            binding.slot))
    end
    
    print(string.format("|cFF00FF00Celkový počet zobrazených bindov: %d|r", #bindings))
end

BindScanner:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        print("BindScanner je pripravený. Použite /showbinds na zobrazenie všetkých bindov.")
    end
end)

SLASH_SHOWBINDS1 = "/showbinds"
SlashCmdList["SHOWBINDS"] = function()
    BindScanner:DisplayBindings()
end