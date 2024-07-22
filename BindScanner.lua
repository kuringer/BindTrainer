local BindScanner = CreateFrame("Frame")
BindScanner:RegisterEvent("PLAYER_LOGIN")

function BindScanner:ScanBindings()
    local bindings = {}

    -- Skenuj všetky možné bindy
    for i = 1, GetNumBindings() do
        local command, category, key1, key2 = GetBinding(i)
        if key1 or key2 then
            bindings[command] = {key1 = key1, key2 = key2, category = category}
        end
    end

    -- Skenuj action bary
    for i = 1, 120 do
        local actionType, id, subType = GetActionInfo(i)
        if actionType then
            local bindingName = "ACTIONBUTTON" .. ((i - 1) % 12 + 1)
            local key1, key2 = GetBindingKey(bindingName)
            if key1 or key2 then
                bindings[bindingName] = {key1 = key1, key2 = key2, actionType = actionType, id = id, subType = subType}
            end
        end
    end

    -- Skenuj stance bar
    for i = 1, GetNumShapeshiftForms() do
        local bindingName = "SHAPESHIFTBUTTON" .. i
        local key1, key2 = GetBindingKey(bindingName)
        if key1 or key2 then
            bindings[bindingName] = {key1 = key1, key2 = key2, category = "STANCE"}
        end
    end

    -- Skenuj pet bar
    for i = 1, 10 do
        local bindingName = "BONUSACTIONBUTTON" .. i
        local key1, key2 = GetBindingKey(bindingName)
        if key1 or key2 then
            bindings[bindingName] = {key1 = key1, key2 = key2, category = "PET"}
        end
    end

    return bindings
end

function BindScanner:DisplayBindings()
    local bindings = self:ScanBindings()
    
    print("|cFF00FF00=== Bindy pre Action Bary, Stance Bar a Pet Bar ===|r")
    
    local relevantPrefixes = {
        "ACTIONBUTTON",
        "MULTIACTIONBAR1BUTTON",
        "MULTIACTIONBAR2BUTTON",
        "MULTIACTIONBAR3BUTTON",
        "MULTIACTIONBAR4BUTTON",
        "EXTRAACTIONBUTTON",
        "SHAPESHIFTBUTTON",  -- Pre stance bar
        "BONUSACTIONBUTTON"  -- Pre pet bar
    }
    
    local function isRelevantBinding(command)
        for _, prefix in ipairs(relevantPrefixes) do
            if command:find(prefix) then
                return true
            end
        end
        return false
    end
    
    local sortedBindings = {}
    for command, bindInfo in pairs(bindings) do
        if isRelevantBinding(command) then
            table.insert(sortedBindings, {command = command, info = bindInfo})
        end
    end
    
    table.sort(sortedBindings, function(a, b) return a.command < b.command end)
    
    for _, binding in ipairs(sortedBindings) do
        local command = binding.command
        local bindInfo = binding.info
        local keyString = (bindInfo.key1 or "N/A") .. (bindInfo.key2 and (", " .. bindInfo.key2) or "")
        local categoryString = bindInfo.category or bindInfo.actionType or "N/A"
        
        print(string.format("|cFFFFFF00%s|r: |cFF00FFFF%s|r |cFF888888(Kategória: %s)|r", 
            command, 
            keyString,
            categoryString))
    end
    
    print(string.format("|cFF00FF00Celkový počet zobrazených bindov: %d|r", #sortedBindings))
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